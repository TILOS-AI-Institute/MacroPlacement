###############################################################################################
# This script is used to visualize the placement results for macros and standard-cell clusters
# The input is protocol buffer netlist and plc file
# All the hard macros are in blue color
# All the standard-cell clusters are in red color
###############################################################################################
import os
import time
import shutil
import sys
import argparse
import matplotlib.pyplot as plt
from math import log
import json

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
        self.pb_type = None
        self.side = None
        self.orientation = None

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

    def IsPort(self):
        if (self.pb_type == '"PORT"'):
            return True
        else:
            return False

    def GetLocation(self):
        return self.x - self.width / 2.0 , self.y - self.height / 2.0

    def GetWidth(self):
        return self.width

    def GetHeight(self):
        return self.height



def VisualPlacement(netlist_file, plc_file):
    n_rows = -1
    n_cols = -1
    width  = 0.0
    height = 0.0

    plc_object_list = []  # store all the plc objects

    # read protocol buffer netlist
    float_values = ['"height"', '"weight"', '"width"', '"x"', '"x_offset"', '"y"', '"y_offset"']
    placeholders = ['"macro_name"', '"orientation"', '"side"', '"type"']
    with open(netlist_file) as f:
        content = f.read().splitlines()
    f.close()

    object_id = 0
    key = ""
    for line in content:
        words = line.split()
        if words[0] == 'node':
            if len(plc_object_list) > 0 and plc_object_list[-1].name == '"__metadata__"':
                plc_object_list.pop(-1)
            plc_object_list.append(PlcObject(object_id)) # add object
            object_id += 1
        elif words[0] == 'name:':
            plc_object_list[-1].name = words[1]
        elif words[0] == 'key:' :
            key = words[1]  # the attribute name
        elif words[0] == 'placeholder:' :
            if key == placeholders[0]:
                plc_object_list[-1].m_name = words[1]
            elif key == placeholders[1]:
                plc_object_list[-1].orientation = words[1]
            elif key == placeholders[2]:
                plc_object_list[-1].side = words[1]
            elif key == placeholders[3]:
                plc_object_list[-1].pb_type = words[1]
        elif words[0] == 'f:' :
            if key == float_values[0]:
                plc_object_list[-1].height = round(float(words[1]), 6)
            elif key == float_values[1]:
                plc_object_list[-1].weight = round(float(words[1]), 6)
            elif key == float_values[2]:
                plc_object_list[-1].width = round(float(words[1]), 6)
            elif key == float_values[3]:
                plc_object_list[-1].x = round(float(words[1]),6)
            elif key == float_values[4]:
                plc_object_list[-1].x_offset = round(float(words[1]), 6)
            elif key == float_values[5]:
                plc_object_list[-1].y = round(float(words[1]),6)
            elif key == float_values[6]:
                plc_object_list[-1].y_offset = round(float(words[1]), 6)


    # read plc file for all the plc objects
    with open(plc_file) as f:
        content = f.read().splitlines()
    f.close()

    # read the canvas and grid information
    for line in content:
        items = line.split()
        if (len(items) > 2 and items[0] == "#" and items[1] == "Columns"):
            n_cols = int(items[3])
            n_rows = int(items[6])
        elif (len(items) > 2 and items[0] == "#" and items[1] == "Width"):
            canvas_width = float(items[3])
            canvas_height = float(items[6])

    print("***************************************************")
    print("canvas_width = ", canvas_width)
    print("canvas_height = ", canvas_height)
    print("n_cols = ", n_cols)
    print("n_rows = ", n_rows)
    print("\n\n")


    # Plot the hard macros and standard-cell clusters
    plt.figure()
    for plc_object in plc_object_list:
        if (plc_object.IsHardMacro() == True or plc_object.IsSoftMacro() == True):
            color = "blue"
            if (plc_object.IsSoftMacro() == True):
                color = "red"
            lx, ly = plc_object.GetLocation()
            width = plc_object.GetWidth()
            height = plc_object.GetHeight()
            rectangle = plt.Rectangle((lx, ly), width, height, fc = color, ec = "black")
            plt.gca().add_patch(rectangle)

    # Add boundries
    lx = 0.0
    ly = 0.0
    ux = lx + canvas_width
    uy = ly + canvas_height
    lw = 5.0

    x = []
    y = []
    x.append(lx)
    y.append(ly)
    x.append(ux)
    y.append(ly)
    plt.plot(x,y, '-k', lw = lw)

    x = []
    y = []
    x.append(lx)
    y.append(uy)
    x.append(ux)
    y.append(uy)
    plt.plot(x,y, '-k', lw = lw)


    x = []
    y = []
    x.append(lx)
    y.append(ly)
    x.append(lx)
    y.append(uy)
    plt.plot(x,y, '-k', lw = lw)


    x = []
    y = []
    x.append(ux)
    y.append(ly)
    x.append(ux)
    y.append(uy)
    plt.plot(x,y, '-k', lw = lw)

    plt.xlim(lx, ux)
    plt.ylim(ly, uy)
    plt.axis("scaled")
    plt.show()



if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--netlist", help="protocol buffer netlist", type = str, default = "./test/ariane.pb.txt")
    parser.add_argument("--plc", help="plc_file", type = str, default = "./test/ariane.plc")
    args = parser.parse_args()

    netlist_file = args.netlist
    plc_file = args.plc

    VisualPlacement(netlist_file, plc_file)

