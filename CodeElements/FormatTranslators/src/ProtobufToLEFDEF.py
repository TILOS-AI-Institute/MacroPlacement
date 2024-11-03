##############################################################
# Author: Sayak Kundu (sakundu@ucsd.edu)
# Date: 26/10/2024
##############################################################

import re
import os
import sys
import math
from tqdm import tqdm
from typing import List, Dict, Any, Tuple, Union, Optional

"""
To generate LEF/DEF from Protobuf
python ProtobufToLEFDEF.py <Protobuf file> <design name>

This will write out <design name>.lef and <design name>.def file as output
"""

def print_attr(fp, key, value_type, value):
    fp.write("  attr {\n")
    fp.write(f"    key: \"{key}\"\n")
    fp.write("    value {\n")
    if value_type == "placeholder":
        fp.write(f"      {value_type}: \"{value}\"\n")
    else:
        fp.write(f"      {value_type}: {value}\n")
    fp.write("    }\n")
    fp.write("  }\n")

def print_placeholder(fp, key, value):
    print_attr(fp, key, "placeholder", value)

def print_float(fp, key, value):
    print_attr(fp, key, "f", value)

def check_file(file_path:str) -> bool:
    if os.path.exists(file_path):
        return True
    else:
        return False

def extract_bounding_box(line):
    match = re.search(
        r'# FP bbox: \{([-\d\.]+) ([-\d\.]+)\} \{([-\d\.]+) ([-\d\.]+)\}',
        line
    )
    if match:
        return [float(match.group(i)) for i in range(1, 5)]
    return None

def print_error(error:str):
    print(f"ERROR: {error}")

class Node:
    def __init__(self, name:str):
        self.name:str = name
        self.inputs:List[str] = []
        self.attr:Dict[str, Union[str, float]] = {}
    def add_input(self, input:str):
        self.inputs.append(input)
    
    def add_attr(self, key:str, value:Union[str, float]):
        self.attr[key] = value
        
    def get_attr(self, key:str) -> Union[str, float]:
        if key not in self.attr:
            print(f"[Error:] {self.name} {self.attr['type']} {key} missing")
            return None
        return self.attr[key]
    
    def print_node(self, fp):
        fp.write("node {\n")
        fp.write(f"  name: \"{self.name}\"\n")
        
        for input in self.inputs:
            fp.write(f"  input: \"{input}\"\n")
        
        for key, value in self.attr.items():
            if type(value) == str:
                print_placeholder(fp, key, value)
            else:
                print_float(fp, key, value)
        fp.write("}\n")

class canvas_object:
    def __init__(self, pb_path:str):

        if not check_file(pb_path):
            print_error(f"{pb_path} does not exist. Exiting...")

        self.pb_path:str = pb_path
        self.design:Optional[str] = None
        self.nodes:List[Node] = []
        self.fp_box:List[float] = []
        self.nodeMap:Dict[str, Node] = {}
    
    def read_pb(self):
        node_flag = False
        attr_flag = False
        current_node = None
        current_key = None
        
        name_pattern = re.compile(r'\s*name:\s*"([^"]+)"')
        input_pattern = re.compile(r'\s*input:\s*"([^"]+)"')
        bbox_pattern = re.compile(
            r'# FP bbox: \{([-\d\.]+) ([-\d\.]+)\} \{([-\d\.]+) ([-\d\.]+)\}'
        )
        design_pattern = re.compile(r'\s*#\s*current_design:\s*(\S+)')
        attr_pattern = re.compile(r'^\s*attr\s*{')
        closebrace_pattern = re.compile(r'^\s*}')
        key_pattern = re.compile(r'\s*key:\s*"([^"]+)"')
        value_pattern = re.compile(r'\s*f:\s*([-\d\.]+)')
        placeholder_pattern = re.compile(r'\s*placeholder:\s*"([^"]+)"')
        
        with open(self.pb_path, 'r') as f:
            for line in f:
                if not node_flag:
                    match = design_pattern.match(line)
                    if match:
                        self.design = match.group(1)
                        continue
                    
                    match = bbox_pattern.match(line)
                    if match:
                        self.fp_box = [float(match.group(i)) \
                            for i in range(1, 5)]
                        continue
                
                if line.startswith("node {"):
                    node_flag = True
                    current_node = None
                    continue
                
                if node_flag and not attr_flag:
                    match = name_pattern.match(line)
                    if match:
                        current_node = Node(match.group(1))
                        self.nodes.append(current_node)
                        self.nodeMap[current_node.name] = current_node
                        continue
                    
                    match = input_pattern.match(line)
                    if match:
                        current_node.add_input(match.group(1))
                        continue
                    
                    match = attr_pattern.match(line)
                    if match:
                        attr_flag = True
                        continue
                
                if attr_flag:
                    match = key_pattern.match(line)
                    if match:
                        current_key = match.group(1)
                        continue
                    
                    match = value_pattern.match(line)
                    if match:
                        current_node.add_attr(current_key,
                                              float(match.group(1)))
                        continue
                    
                    match = placeholder_pattern.match(line)
                    if match:
                        current_node.add_attr(current_key, match.group(1))
                        continue
                    
                    match = closebrace_pattern.match(line)
                    if match:
                        current_key = None
                        attr_flag = False
                        continue
        return
    
    def write_pb(self, output_path:str):
        fp = open(output_path, 'w')
        ## Write out the current design and bounding box
        fp.write(f"# current_design: {self.design}\n")
        fp.write(f"# FP bbox: {{{self.fp_box[0]} {self.fp_box[1]}}}"
                 f" {{{self.fp_box[2]} {self.fp_box[3]}}}\n")
        
        # Now write out each node:
        for node in self.nodes:
            node.print_node(fp)
        fp.close()
    
    def get_objs(self, obj_type:str) -> List[Node]:
        nodes = []
        for node in self.nodes:
            if node.get_attr("type") == obj_type:
                nodes.append(node)
        return nodes


def gcd_of_list(numbers):
    if not numbers:
        return None
    gcd_result = numbers[0]
    for num in numbers[1:]:
        gcd_result = math.gcd(gcd_result, num)
    return gcd_result

def get_site_height_width(db:canvas_object) -> float:
    std_cells = db.get_objs('stdcell')
    heights = [node.get_attr('height') for node in std_cells]
    widths = [node.get_attr('width') for node in std_cells]
    heights = list(set(heights))
    widths = list(set(widths))
    ## Report return GCD of the heights
    heights_int = [int(x*2000) for x in heights]
    widths_int = [int(x*2000) for x in widths]

    height_gcd = gcd_of_list(heights_int)/2000.0
    widths_gcd = gcd_of_list(widths_int)/2000.0
    return height_gcd, widths_gcd

def get_std_cell_height(db:canvas_object) -> float:
    std_cells = db.get_objs('stdcell')
    heights = [node.get_attr('height') for node in std_cells]
    heights = list(set(heights))
    return heights

def get_metal_pitch(row_height, track_height = 7.5):
    return round(row_height/track_height, 6)

def write_standard_cell_lef(name:str, height:float, width:float,
                            row_h:int, input_count:int, fp) -> None:
    fp.write(f"MACRO {name}\n")
    fp.write(f"  CLASS CORE ;\n")
    fp.write(f"  ORIGIN 0 0 ;\n")
    fp.write(f"  FOREIGN {name} 0 0 ;\n")
    fp.write(f"  SIZE {width} BY {height} ;\n")
    fp.write(f"  SYMMETRY Y ;\n")
    fp.write(f"  SITE FAKE_SITE_{row_h}H ;\n\n")
    
    ## all pins are at the center with width and height as half of the pitch ##
    pin_x = round(width/2, 6)
    pin_y = round(height/2, 6)
    
    ## Add input pins ##
    for i in range(1, input_count+1):
        fp.write(f"  PIN I{i}\n")
        fp.write(f"    DIRECTION INPUT ;\n")
        fp.write(f"    USE SIGNAL ;\n")
        fp.write(f"    PORT\n")
        fp.write(f"      LAYER M1 ;\n")
        fp.write(f"        RECT {pin_x} {pin_y} {pin_x} {pin_y} ;\n")
        fp.write(f"    END\n")
        fp.write(f"  END I{i}\n\n")
    
    ## Add output pin ##
    fp.write(f"  PIN O1\n")
    fp.write(f"    DIRECTION OUTPUT ;\n")
    fp.write(f"    USE SIGNAL ;\n")
    fp.write(f"    PORT\n")
    fp.write(f"      LAYER M1 ;\n")
    fp.write(f"        RECT {pin_x} {pin_y} {pin_x} {pin_y} ;\n")
    fp.write(f"    END\n")
    fp.write(f"  END O1\n\n")
    
    fp.write(f"END {name}\n\n\n")
    

def get_hyperedges(db:canvas_object) -> List[List[Node]]:
    ## First get hyper edges ##
    hyper_edges = []
    for node in db.nodes:
        if len(node.inputs) == 0:
            continue
        hyper_edge = []
        hyper_edge.append(node)
        
        ## Merge all the inputs ##
        for input in node.inputs:
            if input in db.nodeMap:
                hyper_edge.append(db.nodeMap[input])
            else:
                print(f"ERROR: {input} not found in nodeMap")
        hyper_edges.append(hyper_edge)
    return hyper_edges

def get_node_io_count(db:canvas_object) -> Dict[Node, int]:
    node_io_count:Dict[Node, int] = {}
    hyper_edges = get_hyperedges(db)
    for hyper_edge in hyper_edges:
        for node in hyper_edge[1:]:
            if node not in node_io_count:
                node_io_count[node] = 0
            node_io_count[node] += 1
    return node_io_count

def get_std_cell_details(db:canvas_object) -> \
        List[Tuple[str, float, float, int]]:
    node_io_count = get_node_io_count(db)
    std_cell_io_map:Dict[str, Node] = {}
    
    for node, value in node_io_count.items():
        if node.get_attr('type') == 'stdcell':
            std_cell_name = node.get_attr('ref_name')
            if std_cell_name not in std_cell_io_map:
                std_cell_io_map[std_cell_name] = node
            elif node_io_count[std_cell_io_map[std_cell_name]] < value:
                std_cell_io_map[std_cell_name] = node
    std_cell_details = []
    for node in std_cell_io_map.values():
        std_cell_details.append((node.get_attr('ref_name'),
                                 node.get_attr('height'),
                                 node.get_attr('width'),
                                 node_io_count[node]))
    return std_cell_details


def macro_add_pins(db:canvas_object) -> None:
    macro_nodes = db.get_objs('macro')
    ## Remove "pins" attr from macro nodes
    for node in macro_nodes:
        if 'pins' in node.attr:
            del node.attr['pins']
            
    macro_pin_nodes = db.get_objs('macro_pin')
    for macro_pin_node in macro_pin_nodes:
        macro_name = macro_pin_node.get_attr('macro_name')
        if macro_name in db.nodeMap:
            macro_node = db.nodeMap[macro_name]
            if 'pins' not in macro_node.attr:
                macro_node.attr['pins'] = []
            macro_node.attr['pins'].append(macro_pin_node)
        else:
            print(f"ERROR: {macro_name} not found in nodeMap")
    return

def get_macro_pin_list(db:canvas_object):
    macro_add_pins(db)
    
    macro_refs = []
    macro_ref_pin_count = {}
    # Name, x_offset, y_offset, direction
    macro_ref_pin_details = {} 
    ### Check pin counts ###
    for macro_node in db.get_objs('macro'):
        ref_name = macro_node.get_attr('ref_name')
        if ref_name not in macro_ref_pin_count:
            macro_ref_pin_count[ref_name] = macro_node
        else:
            pin_count = len(macro_node.get_attr('pins'))
            ref_count = len(macro_ref_pin_count[ref_name].get_attr('pins'))
            if ref_count != pin_count:
                print(f"ERROR: {ref_name} has different pin counts {pin_count}"
                      f" {ref_count}")
                if pin_count > ref_count:
                    macro_ref_pin_count[ref_name] = macro_node
    
    for macro_ref, macro_node in macro_ref_pin_count.items():
        ## Pin name, x_offset, y_offset, direction ##
        pin_list = []
        macro_width = macro_node.get_attr('width')
        macro_height = macro_node.get_attr('height')
        for pin_node in macro_node.get_attr('pins'):
            direction = 'INPUT' if len(pin_node.inputs) == 0 else 'OUTPUT'
            pin_name = pin_node.name.split('/')[-1]
            pin_x = pin_node.get_attr('x_offset') + macro_width/2
            pin_y = pin_node.get_attr('y_offset') + macro_height/2
            pin_x = round(pin_x, 6)
            pin_y = round(pin_y, 6)
            pin_list.append((pin_name, pin_x, pin_y, direction))
        macro_ref_pin_details[macro_ref] = pin_list
        macro_refs.append((macro_ref, macro_width, macro_height))
    return macro_refs, macro_ref_pin_details

def write_macro_lef(macro_ref:str, macro_height:float, macro_width:float,
                    macro_pin_details, fp):
    fp.write(f"MACRO {macro_ref}\n")
    fp.write(f"  CLASS BLOCK ;\n")
    fp.write(f"  ORIGIN 0 0 ;\n")
    fp.write(f"  FOREIGN {macro_ref} 0 0 ;\n")
    fp.write(f"  SIZE {macro_width} BY {macro_height} ;\n")
    fp.write(f"  SYMMETRY X Y ;\n")
    
    ## Add the pins
    for pin_name, pin_x, pin_y, direction in macro_pin_details:
        fp.write(f"  PIN {pin_name}\n")
        fp.write(f"    DIRECTION {direction} ;\n")
        fp.write(f"    USE SIGNAL ;\n")
        fp.write(f"    PORT\n")
        fp.write(f"      LAYER M1 ;\n")
        fp.write(f"        RECT {pin_x} {pin_y} {pin_x} {pin_y} ;\n")
        fp.write(f"    END\n")
        fp.write(f"  END {pin_name}\n")
    
    fp.write(f"END {macro_ref}\n\n\n")
    
def write_fake_lef(db:canvas_object, lef_file:str) -> None:
    fp = open(lef_file, 'w')
    fp.write("VERSION 5.8 ;\n")
    fp.write("BUSBITCHARS \"[]\" ;\n")
    fp.write("DIVIDERCHAR \"/\" ;\n\n")
    
    fp.write("UNITS\n")
    fp.write("  DATABASE MICRONS 2000 ;\n")
    fp.write("END UNITS\n\n")
    
    fp.write("MANUFACTURINGGRID 0.0005 ;\n\n")
    
    ## Add Site definition ##
    height, width = get_site_height_width(db)
    cell_heights = get_std_cell_height(db)
    for cell_height in cell_heights:
        i = int(cell_height / height)
        fp.write(f"SITE FAKE_SITE_{i}H\n")
        fp.write(f"  SIZE {width} BY {cell_height} ;\n")
        fp.write(f"  CLASS CORE ;\n")
        fp.write(f"  SYMMETRY Y ;\n")
        fp.write(f"END FAKE_SITE_{i}H\n\n")
        
    ## Add metal layer definition ##
    pitch = get_metal_pitch(height)
    width = round(pitch/2, 6)
    spacing = round(pitch/2, 6)
    for i in range(1, 6, 2):
        fp.write(f"LAYER M{i}\n")
        fp.write("  TYPE ROUTING ;\n")
        fp.write("  DIRECTION HORIZONTAL ;\n")
        fp.write(f"  PITCH {pitch} ;\n")
        fp.write(f"  WIDTH {width} ;\n")
        fp.write(f"  SPACING {spacing} ;\n")
        fp.write(f"END M{i}\n\n")
        
        ## Add cut layer definition ##
        fp.write(f"LAYER VIA{i}\n")
        fp.write("  TYPE CUT ;\n")
        fp.write(f"  SPACING {spacing} ;\n")
        fp.write(f"  WIDTH {width} ;\n")
        fp.write(f"END VIA{i}\n\n")
        
        ## M2 same as M1 only direction is vertical ##
        fp.write(f"LAYER M{i+1}\n")
        fp.write("  TYPE ROUTING ;\n")
        fp.write("  DIRECTION VERTICAL ;\n")
        fp.write(f"  PITCH {pitch} ;\n")
        fp.write(f"  WIDTH {width} ;\n")
        fp.write(f"  SPACING {spacing} ;\n")
        fp.write(f"END M{i+1}\n\n")
        
        ## Add cut layer definition ##
        fp.write(f"LAYER VIA{i+1}\n")
        fp.write("  TYPE CUT ;\n")
        fp.write(f"  SPACING {spacing} ;\n")
        fp.write(f"  WIDTH {width} ;\n")
        fp.write(f"END VIA{i+1}\n\n")
    
    ## Add standard cell lefs ##
    std_cell_details = get_std_cell_details(db)
    for cell_name, height, width, input_count in std_cell_details:
        row_h = int(height / height)
        write_standard_cell_lef(cell_name, height, width, row_h,
                                input_count, fp)
    
    macro_refs, macro_ref_pin_details = get_macro_pin_list(db)
    for macro_ref, macro_width, macro_height in macro_refs:
        write_macro_lef(macro_ref, macro_height, macro_width,
                        macro_ref_pin_details[macro_ref], fp)
    
    fp.write("END LIBRARY")
    fp.close()
    return

def write_def(db, def_file:str):
    fp = open(def_file, 'w')
    fp.write(f"VERSION 5.8 ;\n")
    fp.write(f"DIVIDERCHAR \"/\" ;\n")
    fp.write(f"BUSBITCHARS \"[]\" ;\n\n")
    fp.write(f"DESIGN {db.name} ;\n")
    db_unit = 2000
    fp.write(f"UNITS DISTANCE MICRONS {db_unit} ;\n")
    
    fp_box = db.fp_box
    llx = int(fp_box[0]*db_unit)
    lly = int(fp_box[1]*db_unit)
    urx = int(fp_box[2]*db_unit)
    ury = int(fp_box[3]*db_unit)
    fp.write(f"DIEAREA ( {llx} {lly} ) ( {urx} {ury} ) ;\n")
    
    ## Get the Site details ##
    height, width = get_site_height_width(db)
    height_db = int(height*db_unit)
    width_db = int(width*db_unit)
    
    ## Number of SITE in X DIRECTION
    num_sites_x = int((fp_box[2] - fp_box[0])/width)
    num_rows_y = int((fp_box[3] - fp_box[1])/height)
    site_name = f"FAKE_SITE_1H"
    ## Write the Row definitions
    for i in range(0, num_rows_y):
        row_y = int((i)*height_db + lly)
        orient = 'N' if i % 2 == 0 else 'FS'
        fp.write(f"ROW ROW_{i} {site_name} {llx} {row_y} {orient} DO"
                 f" {num_sites_x} BY 1 STEP {width_db} 0  ;\n")
    
    ## Add the standard cell instances and macro instances
    std_nodes = db.get_objs('stdcell')
    macro_nodes = db.get_objs('macro')
    inst_nodes = std_nodes + macro_nodes
    fp.write(f"\nCOMPONENTS {len(inst_nodes)} ;\n")
    for node in inst_nodes:
        # - u0.w\[3\]\[2\]$_DFF_P_ DFF_X1 + PLACED ( 223820 352800 ) N ;
        if node.get_attr('type') in ['stdcell', 'macro'] :
            ref_name = node.get_attr('ref_name')
            width = node.get_attr('width') / 2.0
            height = node.get_attr('height') / 2.0
            x = int((node.get_attr('x') - width)*db_unit)
            y = int((node.get_attr('y') - height)*db_unit)
            orient = "N"
            fp.write(f"\t- {node.name} {ref_name} + PLACED ( {x} {y} ) N ;\n")
    fp.write("END COMPONENTS\n\n")
    
    ## Write out the pins 
    pin_nodes = db.get_objs('port')
    fp.write(f"PINS {len(pin_nodes)} ;\n")
    pitch = get_metal_pitch(height)
    pin_d = int(pitch*db_unit/2)
    for node in pin_nodes:
        side = 'S' 
        if node.get_attr('side') == 'left':
            side = 'W'
        elif node.get_attr('side') == 'right':
            side = 'E'
        elif node.get_attr('side') == 'top':
            side = 'N'
            
        direction = 'INPUT' if len(node.inputs) > 0 else 'OUTPUT'
        fp.write(f"\t- {node.name} + NET {node.name} + DIRECTION"
                 f" {direction} + USE SIGNAL\n")
        fp.write(f"\t\t  + PORT + LAYER M1 ( -{pin_d} -{pin_d} )"
                 f" ( {pin_d} {pin_d} )\n")
        fp.write(f"\t\t + FIXED ( {int(node.get_attr('x')*db_unit)}"
                 f" {int(node.get_attr('y')*db_unit)} ) {side} ;\n")
    fp.write("END PINS\n\n")
    
    ## Write out the nets
    hyper_edges = get_hyperedges(db)
    fp.write(f"NETS {len(hyper_edges)} ;\n")
    net_id = 0
    net = f"n{net_id}"
    for hyper_edge in hyper_edges:
        ## Check if any port node is there or not
        is_port = False
        cc = 0
        pin_details = ""
        for node in hyper_edge:
            if node.get_attr('type') == 'port':
                is_port = True
                pin_details += f" ( PIN {node.name} )"
                cc += 1
                net = node.name
            elif node.get_attr('type') == 'macro_pin':
                macro_name = node.get_attr('macro_name')
                pin_name =  node.name.split('/')[-1]
                
                pin_details += f" ( {macro_name} {pin_name} )"
                cc += 1
            elif node.get_attr('type') == 'stdcell':
                ipin = 1
                if cc != 0:
                    if 'pins' not in node.attr:
                        node.attr['pins'] = ipin
                    else:
                        ipin = node.attr['pins'] + 1
                        node.attr['pins'] += 1
                    ipin = f"I{ipin}"
                else:
                    ipin = "O1"
                pin_details += f" ( {node.name} {ipin} )"
                cc += 1
        if not is_port:
            net_id += 1
        
        pin_details = f"\t- {net} {pin_details} + USE SIGNAL ;\n"
        fp.write(pin_details)
    fp.write("END NETS\n\n")
    fp.write("END DESIGN\n")
    fp.close()
    return

if __name__ == '__main__':
    protobuf_file = sys.argv[1]
    design_name = sys.argv[2]
    design_db = canvas_object(protobuf_file)
    design_db.read_pb()
    design_db.name = design_name
    write_fake_lef(design_db, f"{design_name}.lef")
    write_def(design_db, f"{design_name}.def")