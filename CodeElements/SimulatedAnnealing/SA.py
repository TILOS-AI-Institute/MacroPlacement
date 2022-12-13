#######################################################################################
### Author:  Zhiang Wang,  zhw033@ucsd.edu
### Version: 0.1 (2022/11/20)
### We use the FDPlacer and Cost Evaluation based on Circuit Training's Plc Client
### Please make sure you have installed Circuit Training before running this script
######################################################################################

import sys
import os
import random
from math import log
from copy import deepcopy
from math import floor
from math import ceil
from math import exp
from math import sqrt
from math import pow
import time
import matplotlib.pyplot as plt


# utility function for visualization
sys.path.append('../VisualPlacement/')
from visual_placement import VisualPlacement

# Please replace this with your own circuit training directory
#
# Check Here !!!
#
sys.path.append('/home/zf4_projects/DREAMPlace/sakundu/GB/CT/circuit_training')
sys.path.append('/home/zf4_projects/DREAMPlace/sakundu/GB/CT/')
#sys.path.append('xxxxx/CT/circuit_training')
#sys.path.append('xxxxx/CT/')

from absl import flags
from circuit_training.environment import plc_client
from circuit_training.environment import placement_util

# Descrption from Nature
# In each SA iteration, we perform 2N macro actions (N = number of macros)
# A macro action takes one of three forms: swap, shift and mirror.
# Swap selects two macros at random and swaps their locations, if feasible.
# Shift selects a macro at random and shifts that macro to a neighboring location
# (left, right, up or down). Mirror flips a macro at random across the x axis,
# across the y axis, or across both the x and y axes.
# We apply a uniform probability over the three move types,
# meaning that at each time step there is a 1/3 chance
# of swapping, a 1/3 chance of shifting and a 1/3 chance of flipping.
# After N macro actions, we use an FD method to place clusters of standard cells
# while keeping macro locations fixed, just as we do in our RL method.
# For each macro action or FD action, the new state is accepted if it leads
# to a lower cost.
# But based on our understanding, the positions of standard-cell clusters
# will be determined by the positions of macros and the FD algorithm.
# Thus, in our implementation, the FD of standard-cell clusters should NOT
# be thought as an action. The FD just is called to update the locations of
# standard-cell clusters, thus the cost function can be more accurate.


# Read netlist in protocol buffer netlist
# Currently, force-directed placement is the simple force-directed placement in Nature
# Later, the force-directed placement can be replaced as RePlAce or DreamPlace
# The key point is the conversion between protocol buffer netlist
# and bookshelf format if we want to use RePlAce or DREAMPlace


# Define the class to handle netlist in Protocol Buffer Format
# Basic data structure
# OrientMap : map the orientation
# PlcObject : a superset of attributes for different types of plc objects
# PBFNetlist: the top-level class for handling netlist in protocol buffer netlist
# ***************************************************************
# Define basic classes
# ***************************************************************
# Define the orientation map
OrientMap = {
    "N" : "R0",
    "S" : "R180",
    "W" : "R90",
    "E" : "R270",
    "FN" : "MY",
    "FS" : "MX",
    "FW" : "MX90",
    "FE" : "MY90"
}

# String Helper for string and float value#
def print_placeholder(key, value):
    line = "  attr {\n"
    line += f'    key: "{key}"\n'
    line += '    value {\n'
    line += f'      placeholder: {value}\n'
    line += '    }\n'
    line += '  }\n'
    return line

def print_float(key, value):
    value = round(value, 6)
    line = "  attr {\n"
    line += f'    key: "{key}"\n'
    line += '    value {\n'
    line += f'      f: {value}\n'
    line += '    }\n'
    line += '  }\n'
    return line


class Grid:
    def __init__(self, grid_width, grid_height, num_grids_per_row, num_grids_per_col, x_idx, y_idx, smooth_factor = 0):
        self.x_idx = x_idx
        self.y_idx = y_idx
        self.grid_width = grid_width
        self.grid_height = grid_height
        self.num_grids_per_row = num_grids_per_row
        self.num_grids_per_col = num_grids_per_col
        self.overlap_area = 0.0
        self.hor_congestion = 0.0
        self.ver_congestion = 0.0
        self.id = self.GetId()
        self.lx, self.ly, self.ux, self.uy = self.GetBBox()
        self.x = (self.lx + self.ux) / 2.0
        self.y = (self.ly + self.uy) / 2.0
        self.smooth_hor_congestion = 0.0
        self.smooth_ver_congestion = 0.0
        self.smooth_factor = smooth_factor
        self.macro_hor_congestion = 0.0
        self.macro_ver_congestion = 0.0
        self.available = True # if the grid has been occupied by a hard macro

    # reset the status of grids
    def Reset(self):
        self.overlap_area = 0.0
        self.hor_congestion = 0.0
        self.ver_congestion = 0.0
        self.smooth_hor_congestion = 0.0
        self.smooth_ver_congestion = 0.0
        self.macro_hor_congestion = 0.0
        self.macro_ver_congestion = 0.0

    # Smoothing the congestion
    def UpdateSCongestion(self):
        # smooth horizontal congestion
        h_start = max(0, self.x_idx - self.smooth_factor)
        h_end   = min(self.x_idx + self.smooth_factor, self.num_grids_per_row - 1)
        self.smooth_hor_congestion = self.hor_congestion
        self.smooth_hor_congestion += self.hor_congestion / (h_end - h_start)
        # smooth vertical congestion
        v_start = max(0, self.y_idx - self.smooth_factor)
        v_end = min(self.y_idx + self.smooth_factor, self.num_grids_per_col - 1)
        self.smooth_ver_congestion = self.ver_congestion
        self.smooth_ver_congestion += self.ver_congestion / (v_end - v_start)

    def GetSCongH(self):
        return self.smooth_hor_congestion

    def GetSCongV(self):
        return self.smooth_ver_congestion

    # all grids are arranged in a row-based manner
    def GetId(self):
        return self.y_idx * self.num_grids_per_row + self.x_idx

    # get bounding box
    def GetBBox(self):
        lx = self.x_idx * self.grid_width
        ly = self.y_idx * self.grid_height
        ux = lx + self.grid_width
        uy = ly + self.grid_height
        return lx, ly, ux, uy

    # check overlap
    def CalcOverlap(self, bbox):
        lx, ly, ux, uy = bbox
        x_overlap = min(ux, self.ux) - max(self.lx, lx)
        y_overlap = min(uy, self.uy) - max(self.ly, ly)
        if (x_overlap <= 0.0 or y_overlap <= 0.0):
            return 0.0
        else:
            return x_overlap * y_overlap

    def CalcHVOverlap(self, bbox):
        lx, ly, ux, uy = bbox
        x_overlap = min(ux, self.ux) - max(self.lx, lx)
        y_overlap = min(uy, self.uy) - max(self.ly, ly)
        x_overlap = max(0.0, x_overlap)
        y_overlap = max(0.0, y_overlap)
        return x_overlap, y_overlap

    # True for Add
    # False for Reduce
    def UpdateOverlap(self, bbox, flag = False):
        lx, ly, ux, uy = bbox
        if (flag == True):
            self.overlap_area += self.CalcOverlap(bbox)
        else:
            self.overlap_area -= self.CalcOverlap(bbox)

    # calculate density
    def GetDensity(self):
        return self.overlap_area / (self.grid_width * self.grid_height)

    # Update congestion
    # True for Add, False for Reduce
    def UpdateCongestionH(self, congestion, flag = False):
        if (flag == True):
            self.hor_congestion += congestion
        else:
            self.hor_congestion -= congestion

    def UpdateCongestionV(self, congestion, flag = False):
        if (flag == True):
            self.ver_congestion += congestion
        else:
            self.ver_congestion -= congestion

    # Get congestion
    def GetCongestionH(self):
        return self.hor_congestion

    def GetCongestionV(self):
        return self.ver_congestion

    # Update Macro Congestion
    def UpdateMacroCongH(self, congestion, flag = False):
        if (flag == True):
            self.macro_hor_congestion += congestion
        else:
            self.macro_hor_congestion -= congestion

    def UpdateMacroCongV(self, congestion, flag = False):
        if (flag == True):
            self.macro_ver_congestion += congestion
        else:
            self.macro_ver_congestion -= congestion

    # Get congestion
    def GetMacroCongH(self):
        return self.macro_hor_congestion

    def GetMacroCongV(self):
        return self.macro_ver_congestion


class Net:
    def __init__(self, pins, grids, weight = 1.0):
        # the first pin is always the source pin
        self.pins = pins  # pins of the net (each pin is a plc object)
        self.weight = weight
        self.grids = grids  # references to the grid list
        self.HPWL = 0.0
        self.num_grids_per_row = 0
        self.num_grids_per_col = 0

    def Reset(self):
        self.HPWL = 0.0

    def GetHPWL(self, update_flag = False):
        if (update_flag == True):
            self.UpdateHPWL()
        return self.HPWL

    def UpdateHPWL(self):
        if (len(self.pins) <= 1):
            self.HPWL = 0.0
        x_locs = []
        y_locs = []
        for pin in self.pins:
            x_locs.append(pin.GetX())
            y_locs.append(pin.GetY())
        self.HPWL = self.weight * (max(x_locs) - min(x_locs) + max(y_locs) - min(y_locs))

        x_min, y_min, x_max, y_max = 1e9, 1e9, -1e9, -1e9
        for pin in self.pins:
            x_min = min(x_min, pin.GetX())
            y_min = min(y_min, pin.GetY())
            x_max = max(x_max, pin.GetX())
            y_max = max(y_max, pin.GetY())
        self.HPWL = self.weight * (x_max - x_min + y_max - y_min)

    # True for Add; False for Reduce
    def UpdateRouting(self, flag = True):
        if (len(self.pins) <= 1):
            return
        if (len(self.pins) == 2):
            self.TwoPinNetRouting(self.pins[0], self.pins[1], flag)
        elif (len(self.pins) == 3):
            # sort pins based on column id
            sorted(self.pins, key=lambda pin: pin.GetColId())
            col_id_1, row_id_1 = self.pins[0].GetGridId()
            col_id_2, row_id_2 = self.pins[1].GetGridId()
            col_id_3, row_id_3 = self.pins[2].GetGridId()
            # check for different cases
            if (col_id_1 < col_id_2 and col_id_2 < col_id_3 and min(row_id_1, row_id_3) < row_id_2 and max(row_id_1, row_id_3) > row_id_2):
                self.LRouting(flag)
            elif (col_id_2 == col_id_3 and col_id_1 < col_id_2 and row_id_1 < min(row_id_2, row_id_3)):
                # update horizontal congestion cost
                for i in range(col_id_1, col_id_2):
                    self.grids[row_id_1 * self.num_grids_per_row + i].UpdateCongestionH(self.weight, flag)
                # update vertical congestion cost
                for j in range(row_id_1, max(row_id_2, row_id_3)):
                    self.grids[j * self.num_grids_per_row + col_id_2].UpdateCongestionV(self.weight, flag)
            elif (row_id_2 == row_id_3):
                # update horizontal congestion cost
                for i in range(col_id_1, col_id_2):
                    self.grids[row_id_1 * self.num_grids_per_row + i].UpdateCongestionH(self.weight, flag)
                for i in range(col_id_2, col_id_3):
                    self.grids[row_id_2 * self.num_grids_per_row + i].UpdateCongestionH(self.weight, flag)
                # update vertical congestion cost
                for j in range(min(row_id_2, row_id_3), max(row_id_2, row_id_3)):
                    self.grids[j * self.num_grids_per_row + col_id_2].UpdateCongestionV(self.weight, flag)
            else:
                self.TRouting(flag)
        else:
            # decompose the multiple-pin net into multiple two-pin nets
            for i in range(1, len(self.pins)):
                self.TwoPinNetRouting(self.pins[0], self.pins[i], flag)

    # 2-pin net routing
    # True for Add; False for Reduce
    def TwoPinNetRouting(self, src_pin, sink_pin, flag = True):
        src_col_idx, src_row_idx = src_pin.GetGridId()
        sink_col_idx, sink_row_idx = sink_pin.GetGridId()
        # horizontal congestion cost
        min_col_idx = min(src_col_idx, sink_col_idx)
        max_col_idx = min(src_col_idx, sink_col_idx)
        for i in range(min_col_idx, max_col_idx):
            self.grids[src_row_idx * self.num_grids_per_row + i].UpdateCongestionH(self.weight, flag)
        # vertical congestion cost
        min_row_idx = min(src_row_idx, sink_row_idx)
        max_row_idx = max(src_row_idx, sink_row_idx)
        for j in range(min_row_idx, max_row_idx):
            self.grids[j * self.num_grids_per_row + sink_col_idx].UpdateCongestionV(self.weight, flag)

    # L routig for 3-pin net
    # True for Add; False for Reduce
    def LRouting(self, flag = True):
        col_id_1, row_id_1 = self.pins[0].GetGridId()
        col_id_2, row_id_2 = self.pins[1].GetGridId()
        col_id_3, row_id_3 = self.pins[2].GetGridId()
        # add horizontal congestion cost
        for i in range(col_id_1, col_id_2):
            self.grids[row_id_1 * self.num_grids_per_row + i].UpdateCongestionH(self.weight, flag)
        for i in range(col_id_2, col_id_3):
            self.grids[row_id_2 * self.num_grids_per_row + i].UpdateCongestionH(self.weight, flag)
        # add vertical congestion cost
        for j in range(min(row_id_1, row_id_2), max(row_id_1, row_id_2)):
            self.grids[j * self.num_grids_per_row + col_id_2].UpdateCongestionV(self.weight, flag)
        for j in range(min(row_id_2, row_id_3), max(row_id_2, row_id_3)):
            self.grids[j * self.num_grids_per_row + col_id_3].UpdateCongestionV(self.weight, flag)

    # T routing for 3-pin net
    # True for Add; False for reduce
    def TRouting(self, flag = True):
        sorted(self.pins, key=lambda pin: pin.GetRowId())
        col_id_1, row_id_1 = self.pins[0].GetGridId()
        col_id_2, row_id_2 = self.pins[1].GetGridId()
        col_id_3, row_id_3 = self.pins[2].GetGridId()
        col_id_min = min(col_id_1, col_id_2, col_id_3)
        col_id_max = max(col_id_1, col_id_2, col_id_3)
        # add horizontal congestion cost
        for i in range(col_id_min, col_id_max):
            self.grids[row_id_2 * self.num_grids_per_row + i].UpdateCongestionH(self.weight, flag)
        # add vertical congestion cost
        for j in range(min(row_id_1, row_id_2), max(row_id_1, row_id_2)):
            self.grids[j * self.num_grids_per_row + col_id_1].UpdateCongestionV(self.weight, flag)
        for j in range(min(row_id_2, row_id_3), max(row_id_2, row_id_3)):
            self.grids[j * self.num_grids_per_row + col_id_3].UpdateCongestionV(self.weight, flag)


# Define the plc object
# This is a superset of attributes for different types of plc objects
# A plc object can only have some or all the attributes
# Please check Circuit Training repo (https://github.com/google-research/circuit_training/blob/main/docs/NETLIST_FORMAT.md) for detailed explanation
class PlcObject:
    def __init__(self, id):
        self.name = None
        self.node_id = id
        self.height = 0
        self.width = 0
        self.weight = 1
        self.x = -1  # center of the object
        self.x_offset = 0
        self.y = -1 # center of the object
        self.y_offset = 0
        self.m_name = None  # for macro name (only applied for pins)
        self.m_node_id = -1  # the node id for macro (only applied for pins)
        self.pb_type = None
        self.side = None # only applied for IO ports
        self.orientation = None
        self.inputs = [] # Repeated field that lists all nodes driven by this pin
        self.list_id = -1  # the attribute for placing plc objects in a list
        self.nets = [] # nets (id) connected this plc_object
        self.macro_object = None
        self.n_cols = 0
        self.n_rows = 0
        self.grid_width = 0.0
        self.grid_height = 0.0
        self.f_x = 0.0
        self.f_y = 0.0

    def Move(self, x_disp, y_disp, canvas_width, canvas_height):
        self.x += x_disp
        self.y += y_disp
        lx, ly, ux, uy = self.GetBBox()
        if (lx <= 0.0 or ux >= canvas_width):
            self.x -= x_disp
        if (ly <= 0.0 or uy >= canvas_height):
            self.y -= y_disp

    def ResetForce(self):
        self.f_x = 0.0
        self.f_y = 0.0

    def AddForce(self, f_x, f_y):
        self.f_x += f_x
        self.f_y += f_y

    def GetForce(self):
        return self.f_x, self.f_y

    def IsHardMacro(self):
        if (self.pb_type == '"MACRO"'):
            return True
        else:
            return False

    def IsSoftMacro(self):
        if (self.pb_type == '"macro"'):
            return True
        else:
            return False

    def UpdateSquare(self):
        area = self.width * self.height
        self.width = sqrt(area)
        self.height = sqrt(area)

    def IsPort(self):
        if (self.pb_type == '"PORT"'):
            return True
        else:
            return False

    def IsPin(self):
        if (self.pb_type == '"MACRO_PIN"' or self.pb_type == '"macro_pin"'):
            return True
        else:
            return False

    def IsSoftMacroPin(self):
        if (self.pb_type == '"macro_pin"'):
            return True
        else:
            return False


    # the center of object
    def GetPos(self):
        if (self.IsPin() == False):
            return self.x, self.y
        # check the orientation of macros
        if (self.macro_object.orientation == "N"):
            return self.macro_object.x + self.x_offset, self.macro_object.y + self.y_offset
        elif (self.macro_object.orientation == "FN"):
            return self.macro_object.x - self.x_offset, self.macro_object.y + self.y_offset
        elif (self.macro_object.orientation == "S"):
            return self.macro_object.x - self.x_offset, self.macro_object.y - self.y_offset
        elif (self.macro_object.orientation == "FS"):
            return self.macro_object.x + self.x_offset, self.macro_object.y - self.y_offset
        elif (self.macro_object.orientation == "E"):
            return self.macro_object.x + self.y_offset, self.macro_object.y - self.x_offset
        elif (self.macro_object.orientation == "FE"):
            return self.macro_object.x - self.y_offset, self.macro_object.y - self.x_offset
        elif (self.macro_object.orientation == "FW"):
            return self.macro_object.x - self.y_offset, self.macro_object.y + self.x_offset
        elif (self.macro_object.orientation == "W"):
            return self.macro_object.x + self.y_offset, self.macro_object.y + self.x_offset
        else:
            return self.macro_object.x + self.x_offset, self.macro_object.y + self.y_offset

    def GetX(self):
        x, y = self.GetPos()
        return x

    def GetY(self):
        x, y = self.GetPos()
        return y

    def SetPos(self, x, y):
        self.x = x
        self.y = y

    # get the bounding box of object
    def GetBBox(self):
        x, y = self.GetPos()
        normal_orient_list = ["N", "FN", "S", "FS"]
        reverse_orient_list = ["F", "FE", "W", "FW"]
        width = self.width
        height = self.height
        if (self.orientation in reverse_orient_list):
            width = self.height
            height = self.width
        lx = x - width / 2.0
        ly = y - height / 2.0
        ux = x + width / 2.0
        uy = y + height / 2.0
        return lx, ly, ux, uy

    # get grid information
    def GetColId(self):
        col_id = floor(self.GetX() / self.grid_width)
        col_id = max(col_id, 0)
        col_id = min(col_id, self.n_cols - 1)
        return col_id

    def GetRowId(self):
        row_id = floor(self.GetY() / self.grid_height)
        row_id = max(row_id, 0)
        row_id = min(row_id, self.n_rows - 1)
        return row_id

    def GetGridId(self):
        return self.GetColId(), self.GetRowId()

    # width respect to "N"
    def GetWidth(self):
        return self.width

    # width respect to "N"
    def GetHeight(self):
        return self.height

    def Flip(self, x_flag):
        if (self.orientation == None):
            return True

        # flip across the x axis (x_flag = True)
        if (x_flag == True):
            if (self.orientation == "N"):
                self.orientation = "FS"
            elif (self.orientation == "FN"):
                self.orientation = "S"
            elif (self.orientation == "S"):
                self.orientation = "FN"
            elif (self.orientation == "FS"):
                self.orientation = "N"
            elif (self.orientation == "E"):
                self.orientation  = "FW"
            elif (self.orientation == "FE"):
                self.orientation = "W"
            elif (self.orientation == "FW"):
                self.orientation = "E"
            elif (self.orientation == "W"):
                self.orientation = "FE"
            else:
                self.orientation = None
        else:
            # flip across the y axis
            if (self.orientation == "N"):
                self.orientation = "FN"
            elif (self.orientation == "FN"):
                self.orientation = "N"
            elif (self.orientation == "S"):
                self.orientation = "FS"
            elif (self.orientation == "FS"):
                self.orientation = "S"
            elif (self.orientation == "E"):
                self.orientation  = "FE"
            elif (self.orientation == "FE"):
                self.orientation = "E"
            elif (self.orientation == "FW"):
                self.orientation = "W"
            elif (self.orientation == "W"):
                self.orientation = "FW"
            else:
                self.orientation = None


    # for protocol buffer netlist
    def __str__(self):
        self.str = ""
        if (self.IsPort() == True):
            self.str += "node {\n"
            self.str += '  name: ' + self.name + '\n'
            for sink in self.inputs:
                self.str += '  input: ' + sink + '\n'
            self.str += print_placeholder('side', self.side)
            self.str += print_placeholder('type', self.pb_type)
            self.str += print_float('x', self.x)
            self.str += print_float('y', self.y)
            self.str += "}\n"
        elif (self.IsPin() == True):
            self.str += "node {\n"
            self.str += '  name: ' + self.name + '\n'
            for sink in self.inputs:
                self.str += '  input: ' + sink + '\n'
            self.str += print_placeholder('macro_name', self.m_name)
            self.str += print_placeholder('type', self.pb_type)
            if (self.weight > 1):
                self.str += print_float('weight', int(self.weight))
            self.str += print_float('x', self.x)
            #self.str += print_float('x_offset', self.GetX())
            self.str += print_float('x_offset', self.x_offset)
            self.str += print_float('y', self.y)
            self.str += print_float('y_offset', self.y_offset)
            #self.str += print_float('y_offset', self.GetY())
            self.str += "}\n"
        elif (self.IsHardMacro() == True):
            self.str += "node {\n"
            self.str += '  name: ' + self.name + '\n'
            self.str += print_placeholder('type', self.pb_type)
            self.str += print_float('height', self.height)
            self.str += print_placeholder('orientation', '"' + str(self.orientation) + '"')
            self.str += print_float('width', self.width)
            self.str += print_float('x', self.x)
            self.str += print_float('y', self.y)
            self.str += "}\n"
        else:
            self.str += "node {\n"
            self.str += '  name: ' + self.name + '\n'
            self.str += print_float('height', self.height)
            self.str += print_placeholder('type', self.pb_type)
            self.str += print_float('width', self.width)
            self.str += print_float('x', self.x)
            self.str += print_float('y', self.y)
            self.str += "}\n"
        return self.str

    # for plc file
    def SimpleStr(self):
        self.str = ""
        self.str += str(self.node_id) + " "
        self.str += str(round(self.x, 12)) + " "
        self.str += str(round(self.y, 12)) + " "
        if (self.IsPort() == True):
            self.str += "- "
        elif (self.orientation == None):
            self.str += "N "
        else:
            self.str += str(self.orientation) + " "
        self.str += "0\n"
        return self.str


class PBFNetlist:
    def __init__(self, netlist_pbf_file, plc_file):
        self.netlist_pub_file = netlist_pbf_file
        self.plc_file = plc_file
        # information from plc file
        self.plc_header = ""
        self.n_cols = -1
        self.n_rows = -1
        self.canvas_width = 0.0
        self.canvas_height = 0.0
        self.plc_header = ""
        self.grid_width = 0.0
        self.grid_height = 0.0

        # routing information
        self.smooth_factor = 2
        self.overlap_threshold = 0.0


        self.vrouting_alloc = 0.0
        self.hrouting_alloc = 0.0

        self.hroute_per_micro = 0.0
        self.vroute_per_micro = 0.0

        # weight parameters for cost function
        self.w_wirelength = 1.0
        self.w_density = 0.5
        self.w_congestion = 0.5
        self.HPWL = 0.0
        self.cost_wirelength = 0.0
        self.cost_density = 0.0
        self.cost_congestion = 0.0

        # information from protocol buffer netlist
        self.pb_netlist_header = ""
        self.objects = []
        self.macros = []
        self.stdcell_clusters = []
        self.ports = []
        self.grids = []
        self.nets = []

        self.ParseNetlistFile()
        self.ParsePlcFile()

    def ParsePlcFile(self, plc_file = None):
        if (plc_file == None):
            plc_file = self.plc_file
        # read plc file for all the plc objects
        with open(plc_file) as f:
            content = f.read().splitlines()
        f.close()
        self.plc_header = ""

        # read the canvas and grid information
        for line in content:
            items = line.split()
            if (len(items) > 2 and items[0] == "#" and items[1] == "Columns"):
                self.n_cols = int(items[3])
                self.n_rows = int(items[6])
            elif (len(items) > 2 and items[0] == "#" and items[1] == "Width"):
                self.canvas_width = float(items[3])
                self.canvas_height = float(items[6])
            elif (len(items) == 10 and items[0] == "#" and items[1] == "Routes"):
                self.hroute_per_micro = float(items[-4])
                self.vroute_per_micro = float(items[-1])
            elif (len(items) == 11 and items[0] == "#" and items[1] == "Routes"):
                self.hrouting_alloc = float(items[-4])
                self.vrouting_alloc = float(items[-1])
            elif (len(items) > 3 and items[0] == "#" and items[1] == "Smoothing"):
                self.smooth_factor = floor(float(items[-1]))
            elif (len(items) > 3 and items[0] == "#" and items[1] == "Smoothing"):
                self.overlap_threshold = float(items[-1])
            elif (len(items) == 5 and items[0] != '#'):
                node_id = int(items[0])
                self.objects[node_id].x = float(items[1])
                self.objects[node_id].y = float(items[2])
                self.objects[node_id].orientation = items[3]
            if (len(items) > 0 and items[0] == "#"):
                self.plc_header += line + "\n"
        self.grid_width = self.canvas_width / self.n_cols
        self.grid_height = self.canvas_height / self.n_rows

        # create grids
        for y_idx in range(self.n_rows):
            for x_idx in range(self.n_cols):
                self.grids.append(Grid(self.grid_width, self.grid_height, self.n_cols, self.n_rows, x_idx, y_idx, self.smooth_factor))


        # add grid information to object
        for plc_object in self.objects:
            plc_object.n_rows = self.n_rows
            plc_object.n_cols = self.n_cols
            plc_object.grid_width = self.grid_width
            plc_object.grid_height = self.grid_height

        # add grid information to net
        for net in self.nets:
            net.num_grids_per_row = self.n_cols
            net.num_grids_per_col = self.n_rows

    # valid the col_id and row_id
    def ValidGridId(self, col_id, row_id):
        row_id = max(row_id, 0)
        row_id = min(row_id, self.n_rows - 1)
        col_id = max(col_id, 0)
        col_id = min(col_id, self.n_cols - 1)
        return col_id, row_id


    # Express the location of macro in terms of grid id
    def GetGridBBox(self, plc_object):
        lx, ly, ux, uy = plc_object.GetBBox()
        ll_col_id = floor(lx / self.grid_width)
        ll_row_id = floor(ly / self.grid_height)
        ur_col_id = ceil(ux / self.grid_width)
        ur_row_id = ceil(uy / self.grid_height)
        ll_col_id, ll_row_id = self.ValidGridId(ll_col_id, ll_row_id)
        ur_col_id, ur_row_id = self.ValidGridId(ur_col_id, ur_row_id)
        return ll_col_id, ll_row_id, ur_col_id, ur_row_id


    # Update the congestion caused by macro
    # True for Add and False for Reduce
    def UpdateMacroCongestion(self, plc_object, flag = True):
        ll_col_id, ll_row_id, ur_col_id, ur_row_id = self.GetGridBBox(plc_object)
        IF_PARTIAL_OVERLAP_H = False
        IF_PARTIAL_OVERLAP_V = False
        # check the gridcells overlapped with plc_object
        for col_id in range(ll_col_id, ur_col_id + 1):
            for row_id in range(ll_row_id, ur_row_id + 1):
                grid_id = row_id * self.n_cols + col_id
                overlap_h, overlap_v = self.grids[grid_id].CalcHVOverlap(plc_object.GetBBox())
                self.grids[grid_id].UpdateMacroCongV(overlap_v * self.vrouting_alloc, flag)
                self.grids[grid_id].UpdateMacroCongH(overlap_h * self.hrouting_alloc, flag)
                if (ll_row_id != ur_row_id):
                    if (row_id == ll_row_id and abs(self.grid_height - overlap_v) > 1e-5) \
                        or (row_id == ur_row_id and abs(self.grid_height - overlap_v) > 1e-5):
                        IF_PARTIAL_OVERLAP_H = True

                if (ll_col_id != ll_row_id):
                    if (col_id == ll_col_id and abs(self.grid_width - overlap_h) > 1e-5) \
                        or (col_id == ur_col_id) and abs(self.grid_width - overlap_h):
                        IF_PARTIAL_OVERLAP_V = True

        if (IF_PARTIAL_OVERLAP_V == True):
            for col_id in range(ll_col_id, ur_col_id):
                grid_id = ur_row_id * self.n_cols + col_id
                overlap_h, overlap_v = self.grids[grid_id].CalcHVOverlap(plc_object.GetBBox())
                self.grids[grid_id].UpdateMacroCongV(overlap_v * self.vrouting_alloc, not flag)

        if (IF_PARTIAL_OVERLAP_H == True):
            for row_id in range(ll_row_id, ur_row_id):
                grid_id = row_id * self.n_cols + ur_col_id
                overlap_h, overlap_v = self.grids[grid_id].CalcHVOverlap(plc_object.GetBBox())
                self.grids[grid_id].UpdateMacroCongH(overlap_h * self.hrouting_alloc, not flag)

    def ParseNetlistFile(self):
        # read netlist file for all the plc objects
        plc_object_id_map = {  } # map name to node_id
        # read protocol buffer netlist
        float_values = ['"height"', '"weight"', '"width"', '"x"', '"x_offset"', '"y"', '"y_offset"']
        placeholders = ['"macro_name"', '"orientation"', '"side"', '"type"']
        with open(self.netlist_pub_file) as f:
            content = f.read().splitlines()
        f.close()

        # reset all the variables
        self.pb_netlist_header = ""
        self.objects = []
        self.macros = []
        self.stdcell_clusters = []
        self.ports = []

        object_id = 0
        key = ""
        header = []
        for line in content:
            header.append(line)
            words = line.split()
            if words[0] == 'node':
                if len(self.objects) > 0 and self.objects[-1].name == '"__metadata__"':
                    self.objects.pop(-1)
                    object_id -= 1
                    for i in range(len(header) - 1):
                        self.pb_netlist_header += header[i] + "\n"
                self.objects.append(PlcObject(object_id)) # add object
                object_id += 1
            elif words[0] == 'name:':
                self.objects[-1].name = words[1]
            elif words[0] == 'input:':
                self.objects[-1].inputs.append(words[1])
            elif words[0] == 'key:' :
                key = words[1]  # the attribute name
            elif words[0] == 'placeholder:' :
                if key == placeholders[0]:
                    self.objects[-1].m_name = words[1]
                elif key == placeholders[1]:
                    self.objects[-1].orientation = words[1]
                elif key == placeholders[2]:
                    self.objects[-1].side = words[1]
                elif key == placeholders[3]:
                    self.objects[-1].pb_type = words[1]
            elif words[0] == 'f:' :
                if key == float_values[0]:
                    self.objects[-1].height = round(float(words[1]), 6)
                elif key == float_values[1]:
                    self.objects[-1].weight = round(float(words[1]), 6)
                elif key == float_values[2]:
                    self.objects[-1].width = round(float(words[1]), 6)
                elif key == float_values[3]:
                    self.objects[-1].x = round(float(words[1]),6)
                elif key == float_values[4]:
                    self.objects[-1].x_offset = round(float(words[1]), 6)
                elif key == float_values[5]:
                    self.objects[-1].y = round(float(words[1]),6)
                elif key == float_values[6]:
                    self.objects[-1].y_offset = round(float(words[1]), 6)

        # Get all the macros, standard-cell clusters and IO ports
        for plc_object in self.objects:
            plc_object_id_map[plc_object.name] = plc_object.node_id
            if (plc_object.IsHardMacro() == True):
                plc_object.list_id = len(self.macros)
                self.macros.append(plc_object.node_id)
            elif (plc_object.IsSoftMacro() == True):
                self.stdcell_clusters.append(plc_object.node_id)
            elif (plc_object.IsPort() == True):
                self.ports.append(plc_object.node_id)
            else:
                pass

        for plc_object in self.objects:
            if (plc_object.IsSoftMacro() == True):
                plc_object.UpdateSquare()

        # Map macro pin with its macro
        for plc_object in self.objects:
            if (plc_object.IsPin() == True):
                plc_object.m_node_id = plc_object_id_map[plc_object.m_name]
                plc_object.macro_object = self.objects[plc_object.m_node_id]
            else:
                plc_object.m_node_id = plc_object.node_id

        # create nets
        for plc_object in self.objects:
            if (plc_object.IsPin() == True or plc_object.IsPort() == True):
                pins = [plc_object]
                for input_pin in plc_object.inputs:
                    input_pin_id = plc_object_id_map[input_pin]
                    pins.append(self.objects[input_pin_id])
                if (len(pins) > 1):
                    plc_object.nets.append(len(self.nets))
                    self.nets.append(Net(pins, self.grids, plc_object.weight))

    # calculate the cost in an incremental order
    def CalcCostIncremental(self, pre_objects, new_objects):
        delta_HPWL = 0.0
        # reduce the contribution caused by pre_objects
        for plc_object in pre_objects:
            self.objects[plc_object.node_id] = deepcopy(plc_object)
        nets_id = []
        for plc_object in pre_objects:
            # update the density cost
            ll_col_id, ll_row_id, ur_col_id, ur_row_id = self.GetGridBBox(plc_object)
            for row_id in range(ll_row_id, ur_row_id + 1):
                for col_id in range(ll_col_id, ur_col_id + 1):
                    bbox = plc_object.GetBBox()
                    self.grids[self.n_cols * row_id + col_id].UpdateOverlap(bbox, False)
            # update the congestion cuased by macro
            self.UpdateMacroCongestion(plc_object, False)
            # update the nets connected to this object
            for net_id in plc_object.nets:
                if net_id not in nets_id:
                    nets_id.append(net_id)
        # update the net routing
        for net_id in nets_id:
            self.nets[net_id].UpdateRouting(False)
            delta_HPWL -= self.nets[net_id].GetHPWL(True)
        # update the cost based on new objects
        for plc_object in new_objects:
            self.objects[plc_object.node_id] = deepcopy(plc_object)
        for plc_object in new_objects:
            # update the density cost
            ll_col_id, ll_row_id, ur_col_id, ur_row_id = self.GetGridBBox(plc_object)
            for row_id in range(ll_row_id, ur_row_id + 1):
                for col_id in range(ll_col_id, ur_col_id + 1):
                    bbox = plc_object.GetBBox()
                    self.grids[self.n_cols * row_id + col_id].UpdateOverlap(bbox, True)
            # update the congestion cuased by macro
            self.UpdateMacroCongestion(plc_object, True)
        # update the net routing
        for net_id in nets_id:
            self.nets[net_id].UpdateRouting(True)
            delta_HPWL += self.nets[net_id].GetHPWL(True)
        # wirelength cost
        self.HPWL += delta_HPWL
        cost_wirelength = self.HPWL / (len(self.nets) * (self.canvas_width + self.canvas_height))
        self.cost_wirelength = cost_wirelength
        # density cost
        density_list = []
        for grid in self.grids:
            density_list.append(grid.GetDensity())
        # sort density in a non-increasing order
        density_list.sort(reverse = True)
        # find top k
        k = max(1, floor(self.n_cols * self.n_rows * 0.1))
        cost_density = 0.0
        for i in range(k):
            cost_density += density_list[i]
        cost_density = cost_density / k
        self.cost_density = cost_density
        # calculate congestion cost
        # smooth the congestion caused by net
        for grid in self.grids:
            grid.UpdateSCongestion()
        # update the congestion cost
        congestion_list = []
        for grid in self.grids:
            congestion_list.append((grid.GetSCongV() + grid.GetMacroCongV()) / (self.grid_width * self.vroute_per_micro) +
                                   (grid.GetSCongH() + grid.GetMacroCongH()) / (self.grid_height * self.hroute_per_micro))
        # find top 5% congested grids
        congestion_list.sort(reverse = True)
        k = max(1, floor(self.n_cols * self.n_rows * 0.05))
        cost_congestion = 0.0
        for i in range(k):
            cost_congestion += congestion_list[i]
        cost_congestion = cost_congestion / k
        self.cost_congestion = cost_congestion
        return self.w_wirelength * cost_wirelength + self.w_density * cost_density + self.w_congestion * cost_congestion


    # Calculate the cost from scratch
    def CalcCost(self):
        for grid in self.grids:
            grid.Reset()

        # calculate wirelength cost
        cost_wirelength = 0.0
        net_weight = 0.0
        for net in self.nets:
            cost_wirelength += net.GetHPWL(True)
            net_weight += net.weight
            if (net.weight <= 0.0):
                print("weight : ", net.weight)

        print("net_weight : ", net_weight, "len(net) : ", len(self.nets))
        self.HPWL = cost_wirelength
        cost_wirelength = cost_wirelength / (net_weight * (self.canvas_width + self.canvas_height))
        self.cost_wirelength = cost_wirelength
        print("cost_wirelength : ", cost_wirelength)
        print("self.cost_wirelength : ", self.cost_wirelength)

        # calculate density cost
        for plc_object in self.objects:
            if (plc_object.IsHardMacro() == True or plc_object.IsSoftMacro() == True):
                ll_col_id, ll_row_id, ur_col_id, ur_row_id = self.GetGridBBox(plc_object)
                for row_id in range(ll_row_id, ur_row_id + 1):
                    for col_id in range(ll_col_id, ur_col_id + 1):
                        bbox = plc_object.GetBBox()
                        self.grids[self.n_cols * row_id + col_id].UpdateOverlap(bbox, True)
        density_list = []
        for grid in self.grids:
            density_list.append(grid.GetDensity())
        # sort density in a non-increasing order
        density_list.sort(reverse = True)
        # find top k
        k = max(1, floor(self.n_cols * self.n_rows * 0.1))
        cost_density = 0.0
        for i in range(k):
            cost_density += density_list[i]
        cost_density = cost_density / k
        cost_density = cost_density / 2.0
        self.cost_density = cost_density

        # calculate congestion cost
        # update the congestion caused by net
        for net in self.nets:
            net.UpdateRouting(True)
        # update the congestion caused by macro
        for macro in self.macros:
            self.UpdateMacroCongestion(self.objects[macro], True)
        # smooth the congestion caused by net
        for grid in self.grids:
            grid.UpdateSCongestion()
        # update the congestion cost
        congestion_list = []
        for grid in self.grids:
            congestion_list.append((grid.GetSCongV() + grid.GetMacroCongV()) / (self.grid_width * self.vroute_per_micro) +
                                   (grid.GetSCongH() + grid.GetMacroCongH()) / (self.grid_height * self.hroute_per_micro))
        # find top 5% congested grids
        congestion_list.sort(reverse = True)
        k = max(1, floor(self.n_cols * self.n_rows * 0.05))
        cost_congestion = 0.0
        for i in range(k):
            cost_congestion += congestion_list[i]
        cost_congestion = cost_congestion / k
        self.cost_congestion = cost_congestion

        print("cost_wirelength = ", cost_wirelength, "cost_density = ", cost_density, "cost_congestion = ", cost_congestion)
        return self.w_wirelength * cost_wirelength + self.w_density * cost_density + self.w_congestion * cost_congestion

    def FDPlacer(self, io_factor, num_steps, max_move_distance, attract_factor, repel_factor, debug_mode = True):
        # io_factor is a scalar
        # num_steps, max_move_distance, attract_factor, repel_factor are vectors of the same size
        if (debug_mode == True):
            print("*******************************************************")
            print("Start Force-directed Placement")
            print("\n")
        # initialize
        self.InitSoftMacros()
        for i in range(len(num_steps)):
            if (debug_mode == True):
                print("************************************************")
                print("Start Call - ", i + 1)
            attractive_factor = attract_factor[i]
            repulsive_factor = repel_factor[i]
            num_step = num_steps[i]
            max_displacement = max_move_distance[i]
            if (debug_mode == True):
                print("[INFO] attractive_factor = ", attractive_factor)
                print("[INFO] repulsive_factor = ", repulsive_factor)
                print("[INFO] max_displaccment = ", max_displacement)
                print("[INFO] num_step = ", num_step)
                print("[INFO] io_factor = ", io_factor)
            for j in range(num_step):
                print("Move:  ", j)
                self.MoveSoftMacros(attractive_factor, repulsive_factor, io_factor, max_displacement)

    # return the direction of overlap (x_dir, y_dir)  (<0, 0, >0)
    # this is for repulsive force
    def CheckOverlap(self, src_macro, target_macro):
        src_lx, src_ly, src_ux, src_uy = self.objects[src_macro].GetBBox()
        target_lx, target_ly, target_ux, target_uy = self.objects[target_macro].GetBBox()
        x_dir = 0
        y_dir = 0
        if (src_lx >= target_ux or src_ux <= target_lx or src_ly >= target_uy or src_uy <= target_ly):
            return None, None
        else:
            src_cx = (src_lx + src_ux) / 2.0
            src_cy = (src_ly + src_uy) / 2.0
            target_cx = (target_lx + target_ux) / 2.0
            target_cy = (target_ly + target_uy) / 2.0
            x_dir = src_cx - target_cx
            y_dir = src_cy - target_cy

            # set the minimum value to 1e-12
            min_dist = 1e-2
            if (abs(x_dir) <= min_dist):
                x_dir = -1 * min_dist
            if (abs(y_dir) <= min_dist):
                y_dir = -1 * min_dist
            return x_dir, y_dir

    # check the relative position
    # This is for attractive force
    def CheckRelativePos(self, src, target):
        src_cx, src_cy = self.objects[src].GetPos()
        target_cx, target_cy = self.objects[target].GetPos()
        return -1 * (src_cx - target_cx), -1 * (src_cy - target_cy)

    def CalcRepulsiveForce(self, repulsive_factor, max_displacement):
        # traverse the soft macros and hard macros to check possible overlap
        macro_list = self.stdcell_clusters + self.macros
        macro_list.sort()
        for i in range(len(macro_list)):
            src_macro = macro_list[i]
            for j in range(i+1, len(macro_list)):
                target_macro = macro_list[j]
                x_dir, y_dir = self.CheckOverlap(src_macro, target_macro)
                f_r_x = 0.0
                f_r_y = 0.0
                if (x_dir == None):  # No overlap
                    f_r_x = 0.0
                else:
                    f_r_x = repulsive_factor * 1.0 / x_dir
                if (y_dir == None):  # No overlap
                    f_r_y = 0.0
                else:
                    f_r_y = repulsive_factor * 1.0 / y_dir

                self.objects[src_macro].AddForce(f_r_x, f_r_y)
                self.objects[target_macro].AddForce(-1 * f_r_x, -1 * f_r_y)

    def CalcAttractiveForce(self, attractive_factor, io_factor, max_displacement):
        # traverse the nets to calculate attrative force
        for net in self.nets:
            src_pin = net.pins[0]
            src_macro = src_pin.node_id
            if (src_pin.IsPort() == False):
                src_macro = src_pin.macro_object.node_id
            for i in range(1, len(net.pins)):
                target_macro = net.pins[i].node_id
                if (net.pins[i].IsPort() == False):
                    target_macro = net.pins[i].macro_object.node_id
                x_dir, y_dir = self.CheckRelativePos(src_pin.node_id, net.pins[i].node_id)
                k = net.weight
                if (src_pin.IsPort() == True or net.pins[i].IsPort() == True):
                    k = k * io_factor * attractive_factor
                else:
                    k = k * attractive_factor
                f_x_a = k * x_dir
                f_y_a = k * y_dir

                if (src_pin.IsSoftMacroPin() == True):
                    src_pin.macro_object.AddForce(f_x_a, f_y_a)
                if (net.pins[i].IsSoftMacroPin() == True):
                    net.pins[i].macro_object.AddForce(-1 * f_x_a, -1 * f_y_a)

    def InitSoftMacros(self):
        # Put all the soft macros to the center of canvas
        x = self.canvas_width / 2.0
        y = self.canvas_height / 2.0
        for node_id in self.stdcell_clusters:
            self.objects[node_id].SetPos(x, y)

    def MoveSoftMacros(self, attractive_factor, repulsive_factor, io_factor, max_displacement):
        # Move soft macros based on forces
        for soft_macro in self.stdcell_clusters:
            self.objects[soft_macro].ResetForce()
        self.CalcAttractiveForce(attractive_factor, io_factor, max_displacement)
        self.CalcRepulsiveForce(repulsive_factor, max_displacement)
        max_f_x = 0.0
        max_f_y = 0.0
        for soft_macro in self.stdcell_clusters:
            f_x, f_y = self.objects[soft_macro].GetForce()
            max_f_x = max(max_f_x, abs(f_x))
            max_f_y = max(max_f_y, abs(f_y))
        # normalize f_x and f_y
        if (max_f_x > 0.0):
            for soft_macro in self.stdcell_clusters:
                self.objects[soft_macro].f_x = self.objects[soft_macro].f_x / max_f_x * max_displacement
        if (max_f_y > 0.0):
            for soft_macro in self.stdcell_clusters:
                self.objects[soft_macro].f_y = self.objects[soft_macro].f_y / max_f_y * max_displacement
        for soft_macro in self.stdcell_clusters:
            f_x, f_y = self.objects[soft_macro].GetForce()
            self.objects[soft_macro].Move(f_x, f_y, self.canvas_width, self.canvas_height)

    def WriteNetlist(self, new_pbf_file = None, new_plc_file = None):
        if (new_pbf_file == None):
            new_pbf_file = self.netlist_pub_file + ".new"

        if (new_plc_file == None):
            new_plc_file = self.plc_file + ".new"

        # write the new_pbf_file
        f = open(new_pbf_file, "w")
        f.write(self.pb_netlist_header)
        for pb_object in self.objects:
            f.write(str(pb_object))
        f.close()

        # write the new_plc_file
        f = open(new_plc_file, "w")
        f.write(self.plc_header)
        for pb_object in self.objects:
            if (pb_object.IsPin() == False):
                f.write(pb_object.SimpleStr())
        f.close()



class SimulatedAnnealing:
    def __init__(self, design_name, run_dir, netlist_file, plc_file, action_probs, num_actions, max_temperature, num_iters, seed, spiral_flag = False):
        self.design_name = design_name
        self.open_source_flag = False
        self.run_dir = run_dir
        self.t_min = 1e-8
        self.t_max = max_temperature
        self.max_num_steps = num_iters
        # cost related parameters
        self.accept_tolerance = 1e-9
        self.netlist_pbf_file = netlist_file
        self.plc_file = plc_file
        self.action_probs = action_probs
        for i in range(1, len(self.action_probs)):
            self.action_probs[i] = self.action_probs[i] + self.action_probs[i-1]

        # update plc file
        self.temp_netlist_pbf_file =  self.run_dir + "/" + self.design_name + ".pb.txt.temp"
        self.temp_plc_file = self.run_dir + "/" + self.design_name + ".plc.temp"
        self.temp_plc_fig = self.run_dir + "/" + self.design_name + ".plc.temp.png"
        # final plc file
        self.final_netlist_pbf_file =  self.run_dir + "/" + self.design_name + ".pb.txt.final"
        self.final_plc_file = self.run_dir + "/" + self.design_name + ".plc.final"
        self.final_plc_fig = self.run_dir + "/" + self.design_name + ".plc.final.png"
        self.summary_file =  self.run_dir + "/" + self.design_name + ".summary"

        # read the netlist and plc file
        self.design = PBFNetlist(self.netlist_pbf_file, self.plc_file)
        self.pre_objects = []
        self.seed = seed
        self.num_actions = num_actions
        self.spiral_flag = spiral_flag

        # set the random seed
        random.seed(self.seed)

        # make the standard-cell clusters become square
        self.design.WriteNetlist(self.temp_netlist_pbf_file, self.temp_plc_file)
        # create the plc client
        self.plc = plc_client.PlacementCost(self.temp_netlist_pbf_file)
        self.plc.set_canvas_boundary_check(False)
        self.plc.make_soft_macros_square()
        self.plc.set_placement_grid(self.design.n_cols, self.design.n_rows)
        self.plc.set_routes_per_micron(self.design.hroute_per_micro, self.design.vroute_per_micro)
        self.plc.set_macro_routing_allocation(self.design.hrouting_alloc, self.design.vrouting_alloc)
        self.plc.set_congestion_smooth_range(self.design.smooth_factor)
        self.plc.set_overlap_threshold(self.design.overlap_threshold)
        #self.plc.unplace_all_nodes()
        self.plc.restore_placement(self.temp_plc_file)
        self.plc.set_canvas_size(self.design.canvas_width, self.design.canvas_height)

        self.InitMacroPlacement(self.spiral_flag)
        self.FDPlacer(self.open_source_flag)
        self.RunSA()
        self.FDPlacer(self.open_source_flag)
        self.WritePlcFile(self.final_plc_file)
        self.PlotFromPlc(figure_file = self.final_plc_fig)

    def PlotFromPlc(self, open_source_flag = False, figure_file = None):
        plt.figure(constrained_layout= True, figsize=(8,5), dpi=600)
        if (open_source_flag == True):
            for node_id in self.design.macros:
                color = 'blue'
                width = self.design.objects[node_id].GetWidth()
                height = self.design.objects[node_id].GetHeight()
                cx, cy = self.design.objects[node_id].GetPos()
                lx, ly = cx - width / 2.0, cy - height / 2.0
                rectangle = plt.Rectangle((lx, ly), width, height, fc = color, ec = "black")
                plt.gca().add_patch(rectangle)
            for node_id in self.design.stdcell_clusters:
                color = 'red'
                width = self.design.objects[node_id].GetWidth()
                height = self.design.objects[node_id].GetHeight()
                cx, cy = self.design.objects[node_id].GetPos()
                lx, ly = cx - width / 2.0, cy - height / 2.0
                rectangle = plt.Rectangle((lx, ly), width, height, fc = color, ec = "black")
                plt.gca().add_patch(rectangle)
        else:
            for idx in self.plc.get_macro_indices():
                color = 'blue'
                if self.plc.is_node_soft_macro(idx):
                    color = 'red'
                width, height = self.plc.get_node_width_height(idx)
                cx, cy = self.plc.get_node_location(idx)
                lx, ly = cx - width / 2.0, cy - height / 2.0
                rectangle = plt.Rectangle((lx, ly), width, height, fc = color, ec = "black")
                plt.gca().add_patch(rectangle)

        lx, ly, lw = 0.0, 0.0, 1.0
        ux, uy = lx + self.design.canvas_width, ly + self.design.canvas_height
        x, y = [lx, ux], [ly, ly]
        plt.plot(x, y, '-k', lw = lw)

        x, y = [lx, ux], [uy, uy]
        plt.plot(x, y, '-k', lw = lw)

        x, y = [lx, lx], [ly, uy]
        plt.plot(x,y, '-k', lw = lw)

        x, y = [ux, ux], [ly, uy]
        plt.plot(x,y, '-k', lw = lw)

        plt.xlim(lx, ux)
        plt.ylim(ly, uy)
        plt.axis("scaled")
        title = figure_file.split('.')[-2]
        title = "step = " + title
        plt.title(title)

        if (figure_file == None):
            plt.show()
        else:
            plt.savefig(figure_file, bbox_inches='tight')

    # Check if there is an overlap with other placed macros
    def CheckOverlap(self, lx, ly, ux, uy, macro_box):
        # macro_box : bounding boxes for all the placed macros
        # lx, ly, ux, uy for current macro
        for bbox in macro_box:
            bbox_lx, bbox_ly, bbox_ux, bbox_uy = bbox
            if (lx >= bbox_ux or ly >= bbox_uy or ux <= bbox_lx or uy <= bbox_ly):
                pass
            else:
                return True  # there is an overlap
        return False

    # Initialize the location of macros
    # Puts all macros on the center of grid cells
    # without no overlap
    def InitMacroPlacement(self, spiral_flag = True):
        # place macro one by one in a row based manner
        # like gridding process
        macro_bbox = []
        grids = []
        if (spiral_flag == False):
            grids = self.design.grids.copy()
        else:
            visited_flag = [False for _ in range(self.design.n_cols * self.design.n_rows)]
            # direction in a counter clock-wise manner
            dir_row = [0, 1, 0, -1]
            dir_col = [1, 0, -1, 0]
            row_id = 0
            col_id = 0
            dir_id = 0
            for i in range(self.design.n_cols * self.design.n_rows):
                grid_id = row_id * self.design.n_cols + col_id
                grids.append(self.design.grids[row_id * self.design.n_cols + col_id])
                visited_flag[grid_id] = True
                next_row = row_id + dir_row[dir_id]
                next_col = col_id + dir_col[dir_id]
                next_grid_id = next_row * self.design.n_cols + next_col
                if (0 <= next_row and next_row < self.design.n_rows and 0 <= next_col and next_col < self.design.n_cols and visited_flag[next_grid_id] == False):
                    col_id = next_col
                    row_id = next_row
                else:
                    dir_id = (dir_id + 1) % 4
                    row_id += dir_row[dir_id]
                    col_id += dir_col[dir_id]

        # sort macros based on size in an non-increasing order
        sort_macros_map = { }
        for macro in self.design.macros:
            sort_macros_map[macro] = self.design.objects[macro].width * self.design.objects[macro].height
        sort_macros = [k for k, v in sorted(sort_macros_map.items(), key = lambda item: item[1], reverse = True)]
        for macro in sort_macros:
            for grid in grids:
                if (grid.available == False):
                    continue # this grid has been occupied by other macros
                self.design.objects[macro].x = grid.x
                self.design.objects[macro].y = grid.y
                lx, ly, ux, uy = self.design.objects[macro].GetBBox()
                if (ux > self.design.canvas_width or uy > self.design.canvas_height or lx < 0.0 or ly < 0.0):
                    continue
                # check if there is an overlap with other macros
                if (self.CheckOverlap(lx, ly, ux, uy, macro_bbox) == True):
                    continue
                # place macro on current grid
                grid.available = False
                macro_bbox.append([lx, ly, ux, uy])
                break
        # update the location of macros in plc_client
        for macro in self.design.macros:
            self.plc.update_node_coords(macro, self.design.objects[macro].x, self.design.objects[macro].y)

    ### Call the plc client for cost evulation
    def CalCostPlc(self, isPrint = False):
        wl_cost = self.plc.get_cost()
        den_cost = self.plc.get_density_cost()
        cong_cost = self.plc.get_congestion_cost()
        # the weight parameters are given by Circuit Training
        proxy_cost = wl_cost + 0.5 * den_cost + 0.5 * cong_cost
        if (isPrint == True):
            print("WL cost : ", wl_cost, "Density cost : ", den_cost, "Congestion Cost : ", cong_cost, "Proxy cost : ", proxy_cost)
        return proxy_cost

    ### Call the FD placer in Circuit Training
    def FDPlacer(self, open_source_flag = False):
        # parameter settings from Circuit Training
        use_current_loc = False
        move_stdcells = True
        move_macros = False
        log_scale_conns = False
        use_sizes = False
        io_factor = 1.0
        num_steps = [100, 100, 100]
        attract_factor = [100, 1.0e-3, 1.0e-5]
        repel_factor = [0, 1.0e6, 1.0e7]
        move_distance_factors = [1.0, 1.0, 1.0]
        canvas_size = max(self.design.canvas_width, self.design.canvas_height)
        max_move_distance = [ f * canvas_size / s
                for s, f in zip(num_steps, move_distance_factors)]
        if (open_source_flag == True):
            self.design.FDPlacer(io_factor , num_steps, max_move_distance, attract_factor, repel_factor)
        else:
            self.plc.optimize_stdcells(use_current_loc, move_stdcells, move_macros,
                log_scale_conns, use_sizes, io_factor, num_steps, max_move_distance, attract_factor, repel_factor)

    ### Write Plc file using Plc Client
    def WritePlcFile(self, plc_file_name):
        # write the header
        info = ""
        with open(self.plc_file) as f:
            content = f.read().splitlines()
        f.close()
        for line in content:
            items = line.split()
            if (len(items) > 0 and items[0] == '#'):
                for i in range(1, len(items)):
                    info += items[i] + " "
                info += "\n"
        # write current location
        #self.plc.save_placement(plc_file_name, info[0:-1])
        placement_util.save_placement(self.plc, plc_file_name)

    ### define operation set : Swap,  Shift, Flip
    # Swap:  Randomly pick two macros and swap them
    #        Try five times at most. If fail, restore the status
    def Swap(self):
        for _ in range(5):
            macro_a = random.choice(self.design.macros)
            macro_b = random.choice(self.design.macros)
            if (macro_a == macro_b):
                continue

            macro_a_object = deepcopy(self.design.objects[macro_a])
            macro_b_object = deepcopy(self.design.objects[macro_b])
            self.pre_objects.append(deepcopy(macro_a_object))
            self.pre_objects.append(deepcopy(macro_b_object))

            # swap the location of two macros
            self.design.objects[macro_a].x = macro_b_object.x
            self.design.objects[macro_a].y = macro_b_object.y
            self.design.objects[macro_b].x = macro_a_object.x
            self.design.objects[macro_b].y = macro_a_object.y

            # check the possible overlap
            if (self.IsFeasible(macro_a) == True and self.IsFeasible(macro_b) == True):
                self.plc.update_node_coords(macro_a, self.design.objects[macro_a].x, self.design.objects[macro_a].y)
                self.plc.update_node_coords(macro_b, self.design.objects[macro_b].x, self.design.objects[macro_b].y)
                return True

            # restore the objects
            self.design.objects[macro_a] = deepcopy(macro_a_object)
            self.design.objects[macro_b] = deepcopy(macro_b_object)
        return False


    # Move: Move a randomly selected macro to a new random location
    def Move(self):
        # randomly pick a macro
        macro_a = random.choice(self.design.macros)
        self.pre_objects.append(deepcopy(self.design.objects[macro_a]))
        macro_object = deepcopy(self.design.objects[macro_a])

        # randomly pick a valid grid
        col_id = random.randrange(self.design.n_cols)
        row_id = random.randrange(self.design.n_rows)
        grid_id = row_id * self.design.n_cols + col_id
        self.design.objects[macro_a].x = self.design.grids[grid_id].x
        self.design.objects[macro_a].y = self.design.grids[grid_id].y
        if (self.IsFeasible(macro_a) == True):
            self.plc.update_node_coords(macro_a, self.design.objects[macro_a].x, self.design.objects[macro_a].y)
            return True
        # restore
        self.design.objects[macro_a] = deepcopy(macro_object)
        return False

    # Shuffle : permute 4 macros at a time
    def Shuffle(self):
        # find four macros randomly
        random_macros = []
        while (len(random_macros) < 4):
            macro = random.choice(self.design.macros)
            if macro not in random_macros:
                random_macros.append(macro)

        # create the location map
        loc_map = { }
        for macro in random_macros:
            loc_map[macro] = [self.design.objects[macro].x, self.design.objects[macro].y]

        # permute the random macros
        shuffled_macros = random_macros.copy()
        random.shuffle(shuffled_macros)
        self.pre_objects = []
        for macro in random_macros:
            self.pre_objects.append(deepcopy(self.design.objects[macro]))

        # update the locations of macros
        for i in range(len(random_macros)):
            self.design.objects[random_macros[i]].x = loc_map[shuffled_macros[i]][0]
            self.design.objects[random_macros[i]].y = loc_map[shuffled_macros[i]][1]

        # check Feasible
        for macro in random_macros:
            if (self.IsFeasible(macro) == False):
                for i in range(len(random_macros)):
                    self.design.objects[random_macros[i]].x = loc_map[random_macros[i]][0]
                    self.design.objects[random_macros[i]].y = loc_map[random_macros[i]][1]
                    return False

        # update the macro in plc_client
        for macro in random_macros:
            self.plc.update_node_coords(macro, self.design.objects[macro].x, self.design.objects[macro].y)

        return True

    # Shift: Randomly pick a macro, then shuffle all the neighboring locations,
    #        Try the location one by one. If fail, restore the status
    def Shift(self):
        # randomly pick a macro
        macro_a = random.choice(self.design.macros)
        self.pre_objects.append(deepcopy(self.design.objects[macro_a]))

        # calculate the neighboring locations and randomly shuffle
        neighbor_locs = []
        x = self.design.objects[macro_a].x
        y = self.design.objects[macro_a].y
        neighbor_locs.append([x - self.design.grid_width, y])
        neighbor_locs.append([x + self.design.grid_width, y])
        neighbor_locs.append([x, y - self.design.grid_height])
        neighbor_locs.append([x, y + self.design.grid_height])
        random.shuffle(neighbor_locs)
        for loc in neighbor_locs:
            macro_object = deepcopy(self.design.objects[macro_a])
            self.design.objects[macro_a].x = loc[0]
            self.design.objects[macro_a].y = loc[1]
            if (self.IsFeasible(macro_a) == True):
                self.plc.update_node_coords(macro_a, self.design.objects[macro_a].x, self.design.objects[macro_a].y)
                return True
            # restore
            self.design.objects[macro_a] = deepcopy(macro_object)
        return False


    # Flip:  Randomly pick a macro, then randomly flop the picked macro (X or Y)
    def Flip(self):
        # random pick a macro
        macro = random.choice(self.design.macros)
        self.pre_objects.append(deepcopy(self.design.objects[macro]))
        options = ['X', 'Y', 'XY']
        option = random.choice(options)
        if (option == 'X'):
            self.design.objects[macro].Flip(True)
        elif (option == 'Y'):
            self.design.objects[macro].Flip(False)
        else:
            self.design.objects[macro].Flip(True)
            self.design.objects[macro].Flip(False)
        # update the orientation
            self.plc.update_macro_orientation(macro, self.design.objects[macro].orientation)
        return True

    # Operation
    def Action(self):
        options = ["Swap", "Shift", "Flip", "Move", "Shuffle"]
        self.pre_objects = []
        # pick the options based on action probs
        prob = random.uniform(0, 1)
        if (prob < self.action_probs[0]):
            return self.Swap()
        elif (prob < self.action_probs[1]):
            return self.Shift()
        elif (prob < self.action_probs[2]):
            return self.Flip()
        elif (prob < self.action_probs[3]):
            return self.Move()
        else:
            return self.Shuffle()

    def Restore(self):
        new_objects = [deepcopy(self.design.objects[macro_object.node_id]) for macro_object in self.pre_objects]
        for macro_object in self.pre_objects:
            self.design.objects[macro_object.node_id] = deepcopy(macro_object)
            self.plc.update_macro_orientation(macro_object.node_id, macro_object.orientation)
            self.plc.update_node_coords(macro_object.node_id, macro_object.x, macro_object.y)

    # The utility function for checking if the change is feasible
    def IsFeasible(self, target_macro):
        [target_lx, target_ly, target_ux, target_uy] = self.design.objects[target_macro].GetBBox()
        if target_lx < 0.0 or target_ly < 0.0 or target_ux > self.design.canvas_width or target_uy > self.design.canvas_height:
            return False

        for macro in self.design.macros:
            if (macro == target_macro):
                continue
            [lx, ly, ux, uy] = self.design.objects[macro].GetBBox()
            if (lx > target_ux or ux < target_lx or ly > target_uy or uy < target_ly):
                continue
            else:
                return False
        return True

    # Run simulated annealing
    def RunSA(self):
        # calculate temperature updating factor firstly
        N = len(self.design.macros) * self.num_actions # number of macros
        t_factor = log(self.t_min / self.t_max)
        t = self.t_max
        cur_cost= 0.0
        cost_list = []
        self.FDPlacer(self.open_source_flag)
        fd_runtime = 0.0
        action_runtime = 0.0
        for step in range(self.max_num_steps):
            # call FD placer to update the location of standard-cell clusters
            start_time = time.time()
            self.FDPlacer(self.open_source_flag)
            cur_cost = self.CalCostPlc()
            end_time = time.time()
            fd_runtime += end_time - start_time
            # perturb macros for 2N times
            start_time = time.time()
            for _ in range(N):
                if (self.Action() == True):
                    new_cost = self.CalCostPlc()
                    if (new_cost < cur_cost):
                        cur_cost = new_cost
                        continue

                    prob = exp((cur_cost - new_cost) / t)
                    if (prob < random.uniform(0, 1)):
                        self.Restore()
                    else:
                        cur_cost = new_cost
                cost_list.append(cur_cost)
            end_time = time.time()
            action_runtime += end_time - start_time
            t = self.t_max * exp(t_factor * step / self.max_num_steps)
            if (step % 100 == 0):
                self.FDPlacer(self.open_source_flag)
                temp_plc_file = self.temp_plc_file + "." + str(step)
                temp_plc_fig = self.temp_plc_file + "." + str(step) + ".png"
                #self.WritePlcFile(temp_plc_file)
                placement_util.save_placement(self.plc, temp_plc_file)
                self.PlotFromPlc(figure_file = temp_plc_fig)

        f = open(self.summary_file, "w")
        f.write("[INFO] Total Runtime : " + str(fd_runtime + action_runtime) + " s\n")
        f.write("[INFO] Final cost : " + str(cost_list[-1]) + "\n")
        f.write("[INFO] runtime per FD: " + str(fd_runtime / self.max_num_steps) + " s\n")
        f.write("[INFO] runtime per move : " + str(action_runtime / self.max_num_steps / N) + " s\n")
        for cost in cost_list:
            f.write(str(cost) + "\n")
        f.close()

