###############################################################################################
# This script is used to place standard-cell clusters using force-directed method
# The input is protocol buffer netlist and plc file
# The input is the updated protocol buffer netlist and plc file
###############################################################################################
import os
import time
import shutil
import sys
import argparse
import matplotlib.pyplot as plt
from math import log
from math import sqrt
import json
import random
import math, statistics
# sys.path.append('../VisualPlacement/')
# from visual_placement import VisualPlacement
# ***************************************************************
# Define basic classes
# ***************************************************************
# Define the orientation map

'''
python3 -m Plc_client.plc_client_os_test --netlist ./Plc_client/test/ariane_fd/ariane.pb.txt            
--plc ./Plc_client/test/ariane_fd/ariane.plc.3    --width 1599.99            --height 1598.8            --col 27            --row 23            --rpmh 70.330            --rpmv 74.510            --marh 51.790            --marv 51.790            --smooth 2
'''

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
# String Helper #
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
        self.weight = 0
        self.x = -1
        self.x_offset = 0
        self.y = -1
        self.y_offset = 0
        self.m_name = None  # for macro name
        self.m_node_id = -1  # the node id for macro
        self.pb_type = None
        self.side = None
        self.orientation = None
        self.inputs = []
        self.disp_x = 0.0
        self.disp_y = 0.0
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
    def IsFixed(self):
        if (self.IsSoftMacro() == True):
            return False
        else:
            return True
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
    def GetLocation(self):
        return self.x - self.width / 2.0 , self.y - self.height / 2.0
    def GetPos(self):
        return self.x , self.y
    def GetDisp(self):
        return self.disp_x, self.disp_y
    def SetPos(self, xp, yp):
        self.x = xp
        self.y = yp
    def InitDisp(self):
        self.disp_x = 0.0
        self.disp_y = 0.0
    def AddDisp(self, f_x, f_y):
        self.disp_x += f_x
        self.disp_y += f_y
    def SetDisp(self, f_x, f_y):
        self.disp_x = f_x
        self.disp_y = f_y
    # limit the displacement. t is the threshold
    def LimitDisp(self, t):
        if (t <= 0.0):
            self.disp_x = 0.0
            self.disp_y = 0.0
        dist = sqrt(self.disp_x * self.disp_x + self.disp_y * self.disp_y)
        if (dist > t):
            self.disp_x = self.disp_x / dist * t
            self.disp_y = self.disp_y / dist * t
    def UpdateLocation(self):
        self.x += self.disp_x
        self.y += self.disp_y
    def GetWidth(self):
        return self.width
    def GetHeight(self):
        return self.height
    def __str__(self):
        self.str = ""
        if (self.IsPort() == True):
            self.str += "node {\n"
            self.str += '  name: ' + self.name + '\n'
            for sink in self.inputs:
                self.str += '  input: ' + sink + '\n'
            self.str += print_placeholder('type', self.pb_type)
            self.str += print_placeholder('side', self.side)
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
            self.str += print_float('x_offset', self.x_offset)
            self.str += print_float('y_offset', self.y_offset)
            self.str += print_float('x', self.x)
            self.str += print_float('y', self.y)
            self.str += "}\n"
        else:
            self.str += "node {\n"
            self.str += '  name: ' + self.name + '\n'
            self.str += print_placeholder('type', self.pb_type)
            self.str += print_placeholder('orientation', self.orientation)
            self.str += print_float('height', self.height)
            self.str += print_float('width', self.width)
            self.str += print_float('x', self.x)
            self.str += print_float('y', self.y)
            self.str += "}\n"
        return self.str
    def SimpleStr(self):
        self.str = ""
        self.str += str(self.node_id) + " "
        self.str += str(round(self.x, 2)) + " "
        self.str += str(round(self.y, 2)) + " "
        if (self.IsPort() == True):
            self.str += "- "
        else:
            # print("flag", self.orientation, self.node_id)
            if self.orientation:
                self.str += self.orientation[1:-1] + " "
            else:
                self.str += "N "
        self.str += "0\n"
        return self.str
class FDPlacement:
    def __init__(self, pb_netlist_file, plc_file):
        self.pb_netlist_file = pb_netlist_file
        self.plc_file = plc_file
        self.objects = []  # store all the plc objects
        self.ports = []  # store the node_id for ports
        self.macros = [] # store the node_id for hard macros
        self.stdcell_clusters = [] # store the node_id for standard-cell clusters
        self.adj_matrix = {  } # store the adjacency matrix between nodes
        self.n_rows = 0
        self.n_cols = 0
        self.canvas_width = 0.0
        self.canvas_height = 0.0
        self.grid_width = 0.0
        self.grid_height = 0.0
        self.grid_width = 0.0
        self.grid_height = 0.0
        self.init_flag = True
        # force-related parameters
        self.attractive_factor = 0.1
        self.attractive_exponent = 1
        self.repulsive_factor = 0.1
        # self.repulsive_exponent = 4
        self.max_displacement = 10.0
        self.io_factor = 10.0
        ### User-specified parameters
        self.num_steps = []
        self.move_distance_factors = []
        self.attract_factor = []
        self.repel_factor = []
        ### Read the initial files
        self.pb_netlist_header = ""
        self.plc_header = ""
        self.ParseProtocolBufferNetlist()
        self.ParsePlcFile()
    # Parse protocol buffer netlist
    def ParseProtocolBufferNetlist(self):
        plc_object_id_map = {  } # map name to node_id
        # read protocol buffer netlist
        float_values = ['"height"', '"weight"', '"width"', '"x"', '"x_offset"', '"y"', '"y_offset"']
        placeholders = ['"macro_name"', '"orientation"', '"side"', '"type"']
        with open(self.pb_netlist_file) as f:
            content = f.read().splitlines()
        f.close()
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
                    # print("flag parse:", words)
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
                self.macros.append(plc_object.node_id)
            elif (plc_object.IsSoftMacro() == True):
                self.stdcell_clusters.append(plc_object.node_id)
            elif (plc_object.IsPort() == True):
                self.ports.append(plc_object.node_id)
            else:
                pass
        # Map macro pin with its macro
        for plc_object in self.objects:
            if (plc_object.IsPin() == True):
                plc_object.m_node_id = plc_object_id_map[plc_object.m_name]
            else:
                plc_object.m_node_id = plc_object.node_id
        # Calculate adjacency matrix
        for macro in self.macros:
            self.adj_matrix[macro] = set()
        for stdcell_cluster in self.stdcell_clusters:
            self.adj_matrix[stdcell_cluster] = set()
        for port in self.ports:
            self.adj_matrix[port] = set()
        # We use star model to calculate adjacent matrix
        # Get connections between nodes
        for plc_object in self.objects:
            driver = plc_object.m_node_id
            sinks = set()
            for sink in plc_object.inputs:
                sinks.add(self.objects[plc_object_id_map[sink]].m_node_id)
            # update adjacency matrix
            for sink in sinks:
                self.adj_matrix[driver].add(sink)
                self.adj_matrix[sink].add(driver)
        print("***************************************************")
        print("num_macros = ", len(self.macros))
        print("num_stdcell_clusters = ", len(self.stdcell_clusters))
        print("num_ports = ", len(self.ports))
    # Parse plc file
    def ParsePlcFile(self):
        # read plc file for all the plc objects
        with open(self.plc_file) as f:
            content = f.read().splitlines()
        f.close()
        # read the canvas and grid information
        for line in content:
            items = line.split()
            if (len(items) > 2 and items[0] == "#" and items[1] == "Columns"):
                self.n_cols = int(items[3])
                self.n_rows = int(items[6])
            elif (len(items) > 2 and items[0] == "#" and items[1] == "Width"):
                self.canvas_width = float(items[3])
                self.canvas_height = float(items[6])
            if (len(items) > 0 and items[0] == "#"):
                self.plc_header += line + "\n"
        print("***************************************************")
        print("canvas_width = ", self.canvas_width)
        print("canvas_height = ", self.canvas_height)
        print("n_cols = ", self.n_cols)
        print("n_rows = ", self.n_rows)
        self.grid_width = self.canvas_width / self.n_cols
        self.grid_height = self.canvas_height / self.n_rows
    
    # if overlap dont do anything
    def ifOverlap(self, u_i, v_i, ux=0, uy=0, vx=0, vy=0):
        u_side = self.make_square(u_i)
        u_x1 = self.objects[u_i].x + ux - u_side/2 # left
        u_x2 = self.objects[u_i].x + ux + u_side/2 # right
        u_y1 = self.objects[u_i].y + uy + u_side/2 # top
        u_y2 = self.objects[u_i].y + uy - u_side/2 # bottom

        v_side = self.make_square(v_i)
        v_x1 = self.objects[v_i].x + vx - v_side/2 # left
        v_x2 = self.objects[v_i].x + vx + v_side/2 # right
        v_y1 = self.objects[v_i].y + vy + v_side/2 # top
        v_y2 = self.objects[v_i].y + vy - v_side/2 # bottom

        return u_x1 < v_x2 and u_x2 > v_x1 and u_y1 > v_y2 and u_y2 < v_y1
        
    # Define the forces
    # Attractive force
    # x is the distance between two vertices
    def func_a(self, x, io_flag = True):
        if (io_flag == True):
            return self.io_factor * (x ** self.attractive_exponent)
        else:
            return self.attractive_factor * (x ** self.attractive_exponent)
    # Calculate attractive force between two nodes (u, v are node_ids) (u - v)
    def f_a(self, u, v, io_flag = True):
        # distance should consider dimension as well
        x_dist = self.objects[u].x - self.objects[v].x - self.make_square(u)/2 - self.make_square(v)/2
        y_dist = self.objects[u].y - self.objects[v].y - self.make_square(u)/2 - self.make_square(v)/2
        dist = sqrt(x_dist * x_dist + y_dist * y_dist)
            
        if (dist <= 0.0 or self.ifOverlap(u, v)):
            return 0.0, 0.0
        else:
            f = self.func_a(dist, io_flag)
            # enforece distance not as close as we hope
            f_x = x_dist / dist * f
            f_y = y_dist / dist * f
            return f_x, f_y

    def make_square(self, u):
        return sqrt(self.objects[u].width * self.objects[u].height)
    # Repulsive force
    # x is the distance between two vertices
    # def func_r(self, x):
    #     return self.repulsive_factor / (x ** self.repulsive_exponent)
    # Calculate repulsive force between two nodes (u, v are node_ids) (u - v)
    # def f_r(self, u, v):
    #     if (self.repulsive_factor == 0.0):
    #         return 0.0, 0.0
    #     x_dist = self.objects[u].x - self.objects[v].x - self.make_square(u)/2 - self.make_square(v)/2
    #     y_dist = self.objects[u].y - self.objects[v].y - self.make_square(u)/2 - self.make_square(v)/2
    #     dist = sqrt(x_dist * x_dist + y_dist * y_dist)
        
    #     if (dist <= 1e-10):
    #         return sqrt(self.repulsive_factor), sqrt(self.repulsive_factor)
    #     else:
    #         return sqrt(self.repulsive_factor) * x_dist *  2, sqrt(self.repulsive_factor) * y_dist * 2
    #     # else:
    def f_r(self, u, v):
        if (self.repulsive_factor == 0.0):
            return 0.0, 0.0
        x_dist = self.objects[u].x - self.objects[v].x
        y_dist = self.objects[u].y - self.objects[v].y
        dist = sqrt(x_dist * x_dist + y_dist * y_dist)

        if (dist <= 1e-10):
            return sqrt(self.repulsive_factor), sqrt(self.repulsive_factor)
        else:
            f_x = self.repulsive_factor * x_dist / dist
            f_y = self.repulsive_factor * y_dist / dist
            return f_x, f_y
        #     f_x = self.repulsive_factor * x_dist / dist
        #     f_y = self.repulsive_factor * y_dist / dist
        #     return f_x, f_y
    
    def f_r_m(self, u, v):
        if (self.repulsive_factor == 0.0):
            return 0.0, 0.0
        x_dist = self.objects[u].x - self.objects[v].x
        y_dist = self.objects[u].y - self.objects[v].y
        dist = sqrt(x_dist * x_dist + y_dist * y_dist)
        
        if (dist <= 1e-10):
            # print("dist found", dist)
            return x_dist / dist * (self.make_square(u)/2 + self.make_square(v)/2), \
                    y_dist / dist * (self.make_square(u)/2 + self.make_square(v)/2)
        elif self.ifOverlap(u, v):
            # if overlap, double the force? keep x
            # print("overlap found", dist)
            return x_dist / dist * (self.make_square(u)/2 + self.make_square(v)/2), \
                    y_dist / dist * (self.make_square(u)/2 + self.make_square(v)/2)
        else:
            return 0.0, 0.0

    # Pull the objects to the nearest center of the gridcell
    def RoundCenter(self, object_id):
        col_id = round((self.objects[object_id].x - self.grid_width / 2.0) / self.grid_width)
        if (col_id < 0):
            col_id = 0
        elif (col_id > self.n_cols - 1):
            col_id = self.n_cols - 1
        self.objects[object_id].x = (col_id + 0.5) * self.grid_width
        row_id = round((self.objects[object_id].y - self.grid_height / 2.0) / self.grid_height)
        if (row_id < 0):
            row_id = 0
        elif (row_id > self.n_rows - 1):
            row_id = self.n_rows - 1
        self.objects[object_id].y = (row_id + 0.5) * self.grid_height
    
    def centeralize(self, object_id):
        self.objects[object_id].SetPos(self.canvas_width / 2, self.canvas_height / 2)
    
    def centeralize_circle(self, object_id):
        r = 1 * sqrt(random.random())
        theta = random.random() * 2 * math.pi
        centerX = self.canvas_width / 2
        centerY = self.canvas_height / 2
        self.objects[object_id].SetPos(centerX + r * math.cos(theta), centerY + r * math.sin(theta))

    # Make sure all the clusters are placed within the canvas
    def FitCanvas(self, object_id):
        if (self.objects[object_id].x <= 0.0):
            self.objects[object_id].x = 0.0
        if (self.objects[object_id].x >= self.canvas_width):
            self.objects[object_id].x = self.canvas_width
        if (self.objects[object_id].y <= 0.0):
            self.objects[object_id].y = 0.0
        if (self.objects[object_id].y >= self.canvas_height):
            self.objects[object_id].y = self.canvas_height
    
    def shift_sigmoid(self, x, a = 100):
        return 1/(1 + math.exp(-x + a))
    
    def shift_elu(self, x, shift = 100, a=0.3):
        if x > shift + a:
            return x
        else:
            return a * math.exp(x-shift)

    def piecewise_leaky_relu(self, x, shift = 100, a = 0.1):
        if x >= 0:
            return max(a * (x - shift), (x - shift)) + a * shift
        else:
            return -max(a * (x - shift), (x - shift)) - a * shift
    
    def piecewise_sigmoid(self, x, shift = 50):
        if x >= 0:
            return 1/(math.exp(-x+shift) + 1)
        else:
            return -1/(math.exp(x+shift) + 1)

    # Force-directed Placement for standard-cell clusters
    def Placement(self):
        # initialize the displacement for standard-cell clusters
        for cluster in self.stdcell_clusters:
            self.objects[cluster].InitDisp()
        # calculate the repulsive forces
        # repulsive forces between stdcell clusters

        ################################################################################################################
        # if False:
        if self.repulsive_factor != 0.0:
            xr_collection = [0] * len(self.objects)
            yr_collection = [0] * len(self.objects)
            for u in self.stdcell_clusters:
                # randomize which stdcell to
                for v in self.stdcell_clusters:
                    if (u <= v): # we just need calculate once
                        continue
                    f_x, f_y = self.f_r(u, v)
                    # self.objects[u].AddDisp(self.objects[u].height * self.objects[u].width * 200 * f_x, self.objects[u].height * self.objects[u].width * 200 * f_y)
                    # self.objects[v].AddDisp(self.objects[v].height * self.objects[v].width * -200 * f_x, self.objects[v].height * self.objects[v].width * -200 * f_y)
                    xr_collection[u] += 1.0 * f_x
                    yr_collection[u] += 1.0* f_y

                    xr_collection[v] += -1.0 * f_x
                    yr_collection[v] += -1.0 * f_y
                    # self.objects[u].AddDisp(1 * f_x, 1 * f_y)
                    # self.objects[v].AddDisp(-1 * f_x, -1 * f_y)
            
            max_x_disp, max_y_disp = (0.0, 0.0)
            min_x_disp, min_y_disp = (0.0, 0.0)
            # limit max displacement to threshold : self.max_displacement
            for xr, yr in zip(xr_collection, yr_collection):
                if xr != 0.0:
                    max_x_disp = max(max_x_disp, abs(xr))
                    min_x_disp = min(min_x_disp, abs(xr))
                if yr != 0.0:
                    max_y_disp = max(max_y_disp, abs(yr))
                    min_y_disp = min(min_y_disp, abs(yr))
            
            scaling = 2.0
            for cluster in self.stdcell_clusters:
                # self.objects[cluster].AddDisp((2*((xr_collection[cluster]-min_x_disp)/(max_x_disp - min_x_disp)) - 1),
                #                                 (2*((yr_collection[cluster]-min_y_disp)/(max_y_disp-min_y_disp)) - 1))
                # keeping the sign while normalize
                self.objects[cluster].AddDisp(scaling * xr_collection[cluster] / max_x_disp, scaling * yr_collection[cluster]/ max_y_disp)
        ################################################################################################################
        # if False:
            xr_collection = [0] * len(self.objects)
            yr_collection = [0] * len(self.objects)

            # repulsive forces between stdcell clusters and macros
            for u in self.stdcell_clusters:
                for v in self.macros:
                    f_x, f_y = self.f_r_m(u, v)
                    # self.objects[u].AddDisp(5 * f_x, 5 * f_y)
                    xr_collection[u] += 1.0 * f_x
                    yr_collection[u] += 1.0 * f_y
        
            max_x_disp, max_y_disp = (0.0, 0.0)
            min_x_disp, min_y_disp = (0.0, 0.0)
            # limit max displacement to threshold : self.max_displacement
            for xr, yr in zip(xr_collection, yr_collection):
                if xr != 0.0:
                    max_x_disp = max(max_x_disp, abs(xr))
                    min_x_disp = min(min_x_disp, abs(xr))
                if yr != 0.0:
                    max_y_disp = max(max_y_disp, abs(yr))
                    min_y_disp = min(min_y_disp, abs(yr))
            
            if max_x_disp == 0.0:
                max_x_disp = 1.0
            if max_y_disp == 0.0:
                max_y_disp = 1.0
            
            scaling = 4.0
            for cluster in self.stdcell_clusters:
                # self.objects[cluster].AddDisp((2*((xr_collection[cluster]-min_x_disp)/(max_x_disp - min_x_disp)) - 1),
                #                                (2*((yr_collection[cluster]-min_y_disp)/(max_y_disp-min_y_disp)) - 1))
                # keeping the sign while normalize
                self.objects[cluster].AddDisp(scaling * xr_collection[cluster] / max_x_disp, scaling * yr_collection[cluster]/ max_y_disp)

        ################################################################################################################
        # calculate the attractive force traverse each edge
        # the adj_matrix is a symmetric matrix
        if self.attractive_factor != 0:
        # if False:
            xr_collection = [0] * len(self.objects)
            yr_collection = [0] * len(self.objects)
            for driver, sinks in self.adj_matrix.items():
                if (self.objects[driver].IsSoftMacro() == False):
                    continue
                for sink in sinks:
                    if self.ifOverlap(driver, sink):
                        # if overlapped, no changes
                        # print("overlap intially")
                        continue    
                    f_x, f_y = self.f_a(driver, sink)
                    if self.ifOverlap(driver, sink, self.piecewise_sigmoid(-1 * f_x), self.piecewise_sigmoid(-1 * f_y)):
                        # if overlapped after moving, no changes
                        # print("overlap after change")
                        continue
                    xr_collection[driver] += self.piecewise_sigmoid(-1.0 * f_x)
                    yr_collection[driver] += self.piecewise_sigmoid(-1.0 * f_y)
            
            max_x_disp, max_y_disp = (0.0, 0.0)
            min_x_disp, min_y_disp = (0.0, 0.0)
            # limit max displacement to threshold : self.max_displacement
            for xr, yr in zip(xr_collection, yr_collection):
                if xr != 0.0:
                    max_x_disp = max(max_x_disp, abs(xr))
                    min_x_disp = min(min_x_disp, abs(xr))
                if yr != 0.0:
                    max_y_disp = max(max_y_disp, abs(yr))
                    min_y_disp = min(min_y_disp, abs(yr))
            
            # not too much attract
            scaling = 0.1
            for cluster in self.stdcell_clusters:
                # self.objects[cluster].AddDisp((2*((xr_collection[cluster]-min_x_disp)/(max_x_disp - min_x_disp)) - 1),
                #                                 (2*((yr_collection[cluster]-min_y_disp)/(max_y_disp-min_y_disp)) - 1))
                # keeping the sign while normalize
                # self.objects[cluster].AddDisp(scaling * xr_collection[cluster] / max_x_disp, scaling * yr_collection[cluster]/ max_y_disp)
                self.objects[cluster].AddDisp(scaling * xr_collection[cluster]/max_x_disp, scaling * yr_collection[cluster]/max_x_disp)

            # self.objects[cluster].LimitDisp(self.max_displacement)
        ################################################################################################################

        # push all the macros to the nearest center of gridcell
        for cluster in self.stdcell_clusters:
            self.objects[cluster].UpdateLocation()
            #self.RoundCenter(cluster)
    # Run placement
    def Run(self):
        # initialize the position for all the macros and stdcell clusters
        if (self.init_flag == True):
            for cluster in self.stdcell_clusters:
                # self.RoundCenter(cluster)
                # self.centeralize(cluster)
                self.centeralize_circle(cluster)

            for macro in self.macros:
                self.RoundCenter(macro)
        # check the initial parameter setting first
        flag = True
        flag = flag and (len(self.num_steps) > 0)
        flag = flag and (len(self.num_steps) == len(self.move_distance_factors))
        flag = flag and (len(self.num_steps) == len(self.attract_factor))
        flag = flag and (len(self.num_steps) == len(self.repel_factor))
        if (flag == False):
            print("**************************************************")
            print("Error ! Please check your inputs.")
            exit()
        # Write initial files
        self.WritePbNetlist(self.pb_netlist_file + ".0")
        self.WritePlcFile(self.plc_file + ".0")
        print("*******************************************************")
        print("Start Force-directed Placement")
        print("\n")
        for i in range(len(self.num_steps)):
            print("************************************************")
            print("Start Call - ", i + 1)
            self.attractive_factor = self.attract_factor[i]
            self.repulsive_factor = self.repel_factor[i]
            factor = self.move_distance_factors[i] * max(self.canvas_width, self.canvas_height)
            self.num_step = self.num_steps[i]
            self.max_displacement = factor / self.num_step
            print("[INFO] attractive_factor = ", self.attractive_factor)
            print("[INFO] repulsive_factor = ", self.repulsive_factor)
            print("[INFO] max_displaccment = ", self.max_displacement)
            print("[INFO] num_step = ", self.num_step)
            print("[INFO] io_factor = ", self.io_factor)
            for j in range(self.num_step):
                print("Runing Step ", j)
                self.Placement()
            # Based on our understanding, the stdcell clusters can be placed
            # at any place in the canvas instead of the center of gridcells
            #for cluster in self.stdcell_clusters:
            #    self.RoundCenter(cluster)
            for cluster in self.stdcell_clusters:
                self.FitCanvas(cluster)
            self.WritePbNetlist(self.pb_netlist_file + "." + str(i + 1))
            self.WritePlcFile(self.plc_file + "." + str(i + 1))
        self.WritePbNetlist(self.pb_netlist_file + ".final")
        self.WritePlcFile(self.plc_file + ".final")
    # Write the output_file
    def WritePbNetlist(self, netlist_file):
        f = open(netlist_file, "w")
        f.write(self.pb_netlist_header)
        for pb_object in self.objects:
            f.write(str(pb_object))
        f.close()
    def WritePlcFile(self, plc_file):
        f = open(plc_file, "w")
        f.write(self.plc_header)
        for pb_object in self.objects:
            if (pb_object.IsPin() == False):
                f.write(pb_object.SimpleStr())
        f.close()
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--netlist", help="protocol buffer netlist", type = str, default = "./test/ariane.pb.txt")
    parser.add_argument("--plc", help="plc_file", type = str, default = "./test/ariane.plc")
    args = parser.parse_args()
    netlist_file = args.netlist
    plc_file = args.plc
    io_factor = 1.0
    num_steps = [100, 100, 100]
    move_distance_factors = [1.0, 1.0, 1.0]
    attract_factor = [100.0, 1.0e-3, 1.0e-3]
    repel_factor = [0.0, 1.0e6, 1.0e7]
    # Run force-directed placement
    placement = FDPlacement(netlist_file, plc_file)
    placement.io_factor = io_factor
    placement.num_steps = num_steps
    placement.move_distance_factors = move_distance_factors
    placement.attract_factor = attract_factor
    placement.repel_factor = repel_factor
    placement.Run()
    # Visual results
    iterations = 1 + len(num_steps)
    for i in range(iterations):
        print("*********************************************")
        print("Iteration ", i)
        print("\n\n")
        tp_netlist_file = netlist_file + "." + str(i)
        tp_plc_file = plc_file + "." + str(i)
        # VisualPlacement(tp_netlist_file, tp_plc_file)
