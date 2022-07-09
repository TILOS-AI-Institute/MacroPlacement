'''
To run this scripts use the below command
python gen_plc_from_pb.py <netlist.pb.txt file>

This will generate the 'init.plc' as output
'''

import sys
import numpy as np

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

pb_file = sys.argv[1]
print(f'Protocol buffer file {pb_file}')

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
      node_list[-1].x = words[1]
    elif key == key1[4]:
      node_list[-1].x_offset = words[1]
    elif key == key1[5]:
      node_list[-1].y = words[1]
    elif key == key1[6]:
      node_list[-1].y_offset = words[1]

fp.close()
fp = open("init.plc", "w")

hard_macro_list = []
soft_macro_list = []
port_list = []

for node in node_list:
  if node.pb_type == '"MACRO"':
    hard_macro_list.append(node)
  elif node.pb_type == '"macro"':
    soft_macro_list.append(node)
  elif node.pb_type == '"port"' or node.pb_type == '"PORT"':
    port_list.append(node)

area1 = 0
area2 = 0
for node in port_list:
  fp.write(f"{node.node_id} {node.x} {node.y} - 1\n")
for node in hard_macro_list:
  fp.write(f"{node.node_id} {np.round(float(node.x),3)} {np.round(float(node.y),3)} N 0\n")
  area1 += float(node.height)*float(node.width)

for node in soft_macro_list:
  fp.write(f"{node.node_id} {np.round(float(node.x),3)} {np.round(float(node.y),3)} N 0\n")
  area2 += float(node.height)*float(node.width)

area = area1 + area2
fp.write(f"# Area: {area}\n")
fp.close()