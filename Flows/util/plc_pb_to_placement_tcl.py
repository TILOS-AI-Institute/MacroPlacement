'''
Convert plc to place.tcl for macros
'''
import sys
import re
import numpy as np

plc_file = sys.argv[1]
pb_file = sys.argv[2]
place_tcl = sys.argv[3]

origin_x = 0
origin_y = 0
print(f"Length of Argument: {len(sys.argv)}")
if len(sys.argv) == 6:
    origin_x = float(sys.argv[4])
    origin_y = float(sys.argv[5])

print(f'PLC:\t{plc_file}\nPB:\t{pb_file}\nTCL:\t{place_tcl}\nOrigin X:{origin_x} Y:{origin_y}')

orientMap = {
    "N" : "R0",
    "S" : "R180",
    "W" : "R90",
    "E" : "R270",
    "FN" : "MY",
    "FS" : "MX",
    "FW" : "MX90",
    "FE" : "MY90"
}

class pb_object:
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
        self.m_name = None
        self.pb_type = None
        self.side = None
        self.orientation = None

fp = open(pb_file, "r")
lines = fp.readlines()

key1 = ['"height"', '"weight"', '"width"', '"x"', '"x_offset"', '"y"', '"y_offset"']
key2 = ['"macro_name"', '"orientation"', '"side"', '"type"']
node_list = []

node_id = 0
key = ""
keys = set()
for line in lines:
    words = line.split()
    if words[0] == 'node':
        node_list.append(pb_object(node_id))
        node_id += 1
    elif words[0] == 'name:':
        node_list[-1].name = words[1]
    elif words[0] == 'key:' :
        key = words[1]
        keys.add(key)
    elif words[0] == 'placeholder:' :
        if key == key2[0]:
            node_list[-1].m_name = words[1]
        elif key == key2[1]:
            node_list[-1].orientation = words[1]
        elif key == key2[2]:
            node_list[-1].side = words[1]
        elif key == key2[3]:
            node_list[-1].pb_type = words[1]
    elif words[0] == 'f:' :
        if key == key1[0]:
            node_list[-1].height = words[1]
        elif key == key1[1]:
            node_list[-1].weight = words[1]
        elif key == key1[2]:
            node_list[-1].width = words[1]
        elif key == key1[3]:
            node_list[-1].x = np.round(float(words[1]),6)
        elif key == key1[4]:
            node_list[-1].x_offset = words[1]
        elif key == key1[5]:
            node_list[-1].y = np.round(float(words[1]),6)
        elif key == key1[6]:
            node_list[-1].y_offset = words[1]
fp.close()


fp = open(plc_file, "r")
lines = fp.readlines()
fp_out = open(place_tcl, "w")
id_pattern = re.compile("[0-9]+")
for line in lines:
    words = line.split()
    if id_pattern.match(words[0]) and (len(words) == 5):
        idx = int(words[0])
        if node_list[idx].pb_type == '"MACRO"':
            x = float(words[1]) - float(node_list[idx].width)/2.0 + origin_x
            y = float(words[2]) - float(node_list[idx].height)/2.0 + origin_y
            orient = orientMap[words[3]]
            isFixed = words[4]
            macro_name = node_list[idx].name.replace('_[', '\[')
            macro_name = macro_name.replace('_]', '\]')
            fp_out.write(f"placeInstance {macro_name} {x}"\
                        f" {y} {orient} -fixed\n")
fp.close()
fp_out.close()
