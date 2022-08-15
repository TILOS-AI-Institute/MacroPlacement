"""Open-Sourced PlacementCost client class."""
import os, io
import re
import math
from typing import Text, Tuple
from absl import logging
from collections import namedtuple
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec
from matplotlib.collections import LineCollection
from matplotlib.patches import Rectangle
import numpy as np

Block = namedtuple('Block', 'x_max y_max x_min y_min')

# FLAGS = flags.FLAG

class PlacementCost(object):

    def __init__(self,
                netlist_file: Text,
                macro_macro_x_spacing: float = 0.0,
                macro_macro_y_spacing: float = 0.0) -> None:
        """
        Creates a PlacementCost object.
        """
        self.netlist_file = netlist_file
        self.macro_macro_x_spacing = macro_macro_x_spacing
        self.macro_macro_y_spacing = macro_macro_y_spacing

        # Check netlist existance
        assert os.path.isfile(self.netlist_file)

        # Set meta information
        self.init_plc = None
        self.project_name = "circuit_training"
        self.block_name = netlist_file.rsplit('/', -1)[-2]
        self.width = 0.0
        self.height = 0.0
        self.grid_col = 10
        self.grid_row = 10
        self.hroutes_per_micron = 0.0
        self.vroutes_per_micron = 0.0
        self.smooth_range = 0.0
        self.overlap_thres = 0.0
        self.hrouting_alloc = 0.0
        self.vrouting_alloc = 0.0

        # All modules look-up table
        self.modules = []
        self.modules_w_pins = []
        # modules to index look-up table
        self.indices_to_mod_name = {}
        self.mod_name_to_indices = {}
        # indices storage
        self.port_indices = []
        self.hard_macro_indices = []
        self.hard_macro_pin_indices = []
        self.soft_macro_indices = []
        self.soft_macro_pin_indices = []
        # macro to pins look-up table: [MACRO_NAME] => [PIN_NAME]
        self.hard_macros_to_inpins = {}
        self.soft_macros_to_inpins = {}
        # read netlist
        self.__read_protobuf()
        # store module/component count
        self.port_cnt = len(self.port_indices)
        self.hard_macro_cnt = len(self.hard_macro_indices)
        self.hard_macro_pin_cnt = len(self.hard_macro_pin_indices)
        self.soft_macro_cnt = len(self.soft_macro_indices)
        self.soft_macro_pin_cnt = len(self.soft_macro_pin_indices)
        self.module_cnt = self.hard_macro_cnt + self.soft_macro_cnt + self.port_cnt
        # assert module and pin count are correct
        assert (len(self.modules)) == self.module_cnt
        assert (len(self.modules_w_pins) - \
            self.hard_macro_pin_cnt - self.soft_macro_pin_cnt) \
                == self.module_cnt

    def __peek(self, f:io.TextIOWrapper):
        """
        Return String next line by peeking into the next line without moving file descriptor
        """
        pos = f.tell()
        t_line = f.readline()
        f.seek(pos)
        return t_line

    def __read_protobuf(self):
        """
        Protobuf Netlist Parser
        """
        with open(self.netlist_file) as fp:
            line = fp.readline()
            node_cnt = 0

            while line:
                line_item = re.findall(r'\w+', line)

                # skip empty lines
                if len(line_item) == 0:
                    # advance ptr
                    line = fp.readline()
                    continue

                # skip comments
                if re.search(r"\S", line)[0] == '#':
                    # advance ptr
                    line = fp.readline()
                    continue

                # node found
                if line_item[0] == 'node':
                    node_cnt += 1
                    node_name = ''
                    input_list = []

                    # advance ptr
                    line = fp.readline()
                    line_item = re.findall(r'\w+[^\:\n\\{\}\s"]*', line)
                    # retrieve node name
                    if line_item[0] == 'name':
                        node_name = line_item[1]
                    else:
                        node_name = 'N/A name'

                    # advance ptr
                    line = fp.readline()
                    line_item = re.findall(r'\w+[^\:\n\\{\}\s"]*', line)
                    # retrieve node input
                    if line_item[0] == 'input':
                        input_list.append(line_item[1])

                        while re.findall(r'\w+[^\:\n\\{\}\s"]*', self.__peek(fp))[0] == 'input':
                            line = fp.readline()
                            line_item = re.findall(r'\w+[^\:\n\\{\}\s"]*', line)
                            input_list.append(line_item[1])

                        line = fp.readline()
                        line_item = re.findall(r'\w+[^\:\n\\{\}\s"]*', line)
                    else:
                        input_list = None

                    # advance, expect multiple attributes
                    attr_dict = {}
                    while len(line_item) != 0 and line_item[0] == 'attr':

                        # advance, expect key
                        line = fp.readline()
                        line_item = re.findall(r'\w+', line)
                        key = line_item[1]

                        # advance, expect value
                        line = fp.readline()
                        line_item = re.findall(r'\w+', line)

                        # advance, expect value item
                        line = fp.readline()
                        line_item = re.findall(r'\-*\w+\.*\/{0,1}\w*[\w+\/{0,1}\w*]*', line)

                        attr_dict[key] = line_item

                        line = fp.readline()
                        line = fp.readline()
                        line = fp.readline()

                        line_item = re.findall(r'\w+', line)

                    if attr_dict['type'][1] == 'macro':
                        # soft macro
                        # check if all required information is obtained
                        try:
                            assert 'x' in attr_dict.keys()
                        except AssertionError:
                            logging.warning('x is not defined')

                        try:
                            assert 'y' in attr_dict.keys()
                        except AssertionError:
                            logging.warning('y is not defined')

                        soft_macro = self.SoftMacro(name=node_name, width=attr_dict['width'][1],
                                                    height = attr_dict['height'][1],
                                                    x = attr_dict['x'][1], y = attr_dict['y'][1])
                        self.modules_w_pins.append(soft_macro)
                        self.modules.append(soft_macro)
                        # mapping node_name ==> node idx
                        self.mod_name_to_indices[node_name] = node_cnt-1
                        # mapping node idx ==> node_name
                        self.indices_to_mod_name[node_cnt-1] = node_name
                        # store current node indx
                        self.soft_macro_indices.append(node_cnt-1)

                    elif attr_dict['type'][1] == 'macro_pin':
                        # [MACRO_NAME]/[PIN_NAME]
                        soft_macro_name = node_name.rsplit('/', 1)[0]
                        # soft macro pin
                        soft_macro_pin = self.SoftMacroPin(name=node_name,
                                                           x = attr_dict['x'][1],
                                                           y = attr_dict['y'][1],
                                                           macro_name = attr_dict['macro_name'][1])
                        if 'weight' in attr_dict.keys():
                            soft_macro_pin.set_weight(float(attr_dict['weight'][1]))

                        if input_list:
                            soft_macro_pin.add_sinks(input_list)

                        self.modules_w_pins.append(soft_macro_pin)
                        # mapping node_name ==> node idx
                        self.mod_name_to_indices[node_name] = node_cnt-1
                        # mapping node idx ==> node_name
                        self.indices_to_mod_name[node_cnt-1] = node_name
                        # store current node indx
                        self.soft_macro_pin_indices.append(node_cnt-1)

                        if soft_macro_name in self.soft_macros_to_inpins.keys():
                            self.soft_macros_to_inpins[soft_macro_name]\
                                .append(soft_macro_pin.get_name())
                        else:
                            self.soft_macros_to_inpins[soft_macro_name]\
                                = [soft_macro_pin.get_name()]

                    elif attr_dict['type'][1] == 'MACRO':
                        # hard macro
                        hard_macro = self.HardMacro(name=node_name,
                                                    width=attr_dict['width'][1],
                                                    height = attr_dict['height'][1],
                                                    x = attr_dict['x'][1],
                                                    y = attr_dict['y'][1],
                                                    orientation = attr_dict['orientation'][1])

                        self.modules_w_pins.append(hard_macro)
                        self.modules.append(hard_macro)
                        # mapping node_name ==> node idx
                        self.mod_name_to_indices[node_name] = node_cnt-1
                        # mapping node idx ==> node_name
                        self.indices_to_mod_name[node_cnt-1] = node_name
                        # store current node indx
                        self.hard_macro_indices.append(node_cnt-1)

                    elif attr_dict['type'][1] == 'MACRO_PIN':
                        # [MACRO_NAME]/[PIN_NAME]
                        hard_macro_name = node_name.rsplit('/', 1)[0]
                        # hard macro pin
                        hard_macro_pin = self.HardMacroPin(name=node_name,
                                                        x = attr_dict['x'][1],
                                                        y = attr_dict['y'][1],
                                                        x_offset = attr_dict['x_offset'][1],
                                                        y_offset = attr_dict['y_offset'][1],
                                                        macro_name = attr_dict['macro_name'][1])
                        if 'weight' in attr_dict.keys():
                            hard_macro_pin.set_weight(float(attr_dict['weight'][1]))

                        if input_list:
                            hard_macro_pin.add_sinks(input_list)

                        self.modules_w_pins.append(hard_macro_pin)
                        # mapping node_name ==> node idx
                        self.mod_name_to_indices[node_name] = node_cnt-1
                        # mapping node idx ==> node_name
                        self.indices_to_mod_name[node_cnt-1] = node_name
                        # store current node indx
                        self.hard_macro_pin_indices.append(node_cnt-1)

                        # add to dict
                        if hard_macro_name in self.hard_macros_to_inpins.keys():
                            self.hard_macros_to_inpins[hard_macro_name]\
                                .append(hard_macro_pin.get_name())
                        else:
                            self.hard_macros_to_inpins[hard_macro_name]\
                                 = [hard_macro_pin.get_name()]

                    elif attr_dict['type'][1] == 'PORT':
                        # port
                        port = self.Port(name= node_name,
                                        x = attr_dict['x'][1],
                                        y = attr_dict['y'][1],
                                        side = attr_dict['side'][1])

                        if input_list:
                            port.add_sinks(input_list)
                            port.add_connections(input_list)

                        self.modules_w_pins.append(port)
                        self.modules.append(port)
                        # mapping node_name ==> node idx
                        self.mod_name_to_indices[node_name] = node_cnt-1
                        # mapping node idx ==> node_name
                        self.indices_to_mod_name[node_cnt-1] = node_name
                        # store current node indx
                        self.port_indices.append(node_cnt-1)

        # mapping connection degree to each macros
        self.__update_connection()

    def __read_plc(self):
        """
        Plc file Parser
        """
        with open(self.init_plc) as fp:
            line = fp.readline()

            while line:
                # skip comments
                if re.search(r"\S", line)[0] == '#':
                    # IMPORTANT: Advance pt
                    line = fp.readline()
                    continue

                # words itemize into list
                line_item = re.findall(r'[0-9A-Za-z\.\-]+', line)

                # skip empty lines
                if len(line_item) == 0:
                    # IMPORTANT: Advance pt
                    line = fp.readline()
                    continue

            line = fp.readline()

    def __update_connection(self):
        """
        Update connection degree for each macro pin
        """
        for macro_idx in (self.hard_macro_indices + self.soft_macro_indices):
            macro = self.modules_w_pins[macro_idx]
            macro_name = macro.get_name()
            macro_type = macro.get_type()

            if macro_type == "MACRO":
                if macro_name in self.hard_macros_to_inpins.keys():
                    pin_names = self.hard_macros_to_inpins[macro_name]
                else:
                    return
            elif macro_type == "macro":
                if macro_name in self.soft_macros_to_inpins.keys():
                    pin_names = self.soft_macros_to_inpins[macro_name]
                else:
                    return

            for pin_name in pin_names:
                pin = self.modules_w_pins[self.mod_name_to_indices[pin_name]]
                inputs = pin.get_sink()
                if inputs:
                    for k in inputs.keys():
                        macro.add_connections(inputs[k])


    def get_cost(self) -> float:
        return 0.0

    def get_area(self) -> float:
        """
        Compute Total Module Area
        """
        total_area = 0.0
        for mod in self.modules_w_pins:
            if hasattr(mod, 'get_area'):
                total_area += mod.get_area()
        return total_area

    def get_hard_macro_count(self) -> int:
        return self.hard_macro_cnt

    def get_port_count(self) -> int:
        return self.port_cnt

    def get_soft_macro_count(self) -> int:
        return self.soft_macro_cnt

    def get_hard_macro_pin_count(self) -> int:
        return self.hard_macro_pin_cnt

    def get_soft_macro_pin_count(self) -> int:
        return self.soft_macro_pin_cnt

    def get_wirelength(self) -> float:
        """
        Proxy HPWL computation
        """
        # NOTE: in pb.txt, netlist input count exceed certain threshold will be ommitted
        total_hpwl = 0.0

        for mod in self.modules_w_pins:
            norm_fact = 1.0
            curr_type = mod.get_type()
            # bounding box data structure
            x_coord = []
            y_coord = []

            # NOTE: connection only defined on PORT, soft/hard macro pins
            if curr_type == "PORT" and mod.get_sink():
                # add source position
                x_coord.append(mod.get_pos()[0])
                y_coord.append(mod.get_pos()[1])

                for sink_name in mod.get_sink():
                    # retrieve indx in modules_w_pins
                    sink_idx = self.mod_name_to_indices[sink_name]
                    # retrieve sink object
                    sink = self.modules_w_pins[sink_idx]
                    # retrieve location
                    x_coord.append(sink.get_pos()[0])
                    y_coord.append(sink.get_pos()[1])
            elif curr_type == "macro_pin" or curr_type == "MACRO_PIN":
                # add source position
                x_coord.append(mod.get_pos()[0])
                y_coord.append(mod.get_pos()[1])

                if mod.get_sink():
                    if mod.get_weight() != 0:
                        norm_fact = mod.get_weight()
                    for input_list in mod.get_sink().values():
                        for sink_name in input_list:
                            # retrieve indx in modules_w_pins
                            input_idx = self.mod_name_to_indices[sink_name]
                            # retrieve input object
                            input = self.modules_w_pins[input_idx]
                            # retrieve location
                            x_coord.append(input.get_pos()[0])
                            y_coord.append(input.get_pos()[1])
            if x_coord:
                if norm_fact != 1.0:
                    total_hpwl += norm_fact * \
                        (abs(max(x_coord) - min(x_coord)) + \
                            abs(max(y_coord) - min(y_coord)))
                else:
                    total_hpwl += (abs(max(x_coord) - min(x_coord))\
                         + abs(max(y_coord) - min(y_coord)))

        return total_hpwl

    def get_congestion_cost(self) -> float:
        return 0.0

    def __get_grid_cell_location(self, x_pos, y_pos):
        # private function for getting grid cell row/col ranging from 0...N
        row = math.floor(y_pos / self.grid_height)
        col = math.floor(x_pos / self.grid_width)
        return row, col
    
    def __overlap_area(self, block_i, block_j):
        # private function for computing block overlapping
        x_diff = min(block_i.x_max, block_j.x_max) - max(block_i.x_min, block_j.x_min)
        y_diff = min(block_i.y_max, block_j.y_max) - max(block_i.y_min, block_j.y_min)
        if x_diff >= 0 and y_diff >= 0:
            return x_diff * y_diff
        return 0

    def __add_module_to_grid_cells(self, mod_x, mod_y, mod_w, mod_h):
        # private function for add module to grid cells
        # row/col ranging from 0...N
        row, col = self.__get_grid_cell_location(mod_x, mod_y)

        # Four corners
        ur = (mod_x + (mod_w/2), mod_y + (mod_h/2))
        br = (mod_x + (mod_w/2), mod_y - (mod_h/2))
        ul = (mod_x - (mod_w/2), mod_y + (mod_h/2))
        bl = (mod_x - (mod_w/2), mod_y - (mod_h/2))

        # construct block based on current module
        module_block = Block(
                            x_max=mod_x + (mod_w/2),
                            y_max=mod_y + (mod_h/2),
                            x_min=mod_x - (mod_w/2),
                            y_min=mod_y - (mod_h/2)
                            )
        print("Module Four corners")
        print("Upper Left",ur, "\nBottom Right", br, "\nUpper Left", ul, "\nBottom Left",bl)

        # Four corner grid cells
        ur_row, ur_col = self.__get_grid_cell_location(*ur)
        br_row, br_col = self.__get_grid_cell_location(*br)
        ul_row, ul_col = self.__get_grid_cell_location(*ul)
        bl_row, bl_col = self.__get_grid_cell_location(*bl)

        # check if out of bound
        if ur_row >= 0 and ur_col >= 0:
            if bl_row < 0:
                bl_row = 0
            
            if bl_col < 0:
                bl_col = 0
        else:
            # OOB, skip module
            print("OOB skipped")
            return
        
        if bl_row >= 0 and bl_col >= 0:
            if ur_row > self.grid_row - 1:
                ur_row = self.grid_row - 1
            
            if ur_col > self.grid_col - 1:
                ur_col = self.grid_col - 1
        else:
            # OOB, skip module
            print("OOB skipped")
            return
        
        print("Four Corner Grid")
        print("UR row",ur_row, "\nUR col", ur_col, "\nBL row", bl_row, "\nBL col",bl_col)

        for r_i in range(bl_row, ur_row + 1):
            for c_i in range(bl_col, ur_col + 1):
                print(r_i, c_i)
                # construct block based on current cell row/col
                grid_cell_block = Block(
                                        x_max= (c_i + 1) * self.grid_width,
                                        y_max= (r_i + 1) * self.grid_height,
                                        x_min= c_i * self.grid_width,
                                        y_min= r_i * self.grid_height
                                        )
                print("grid_cell_block", grid_cell_block)

                print(self.grid_row * r_i + c_i)
                self.grid_occupied[self.grid_row * r_i + c_i] += \
                    self.__overlap_area(grid_cell_block, module_block)
                
                if abs(self.grid_occupied[self.grid_row * r_i + c_i] - 1) < 1e-6:
                    self.grid_occupied[self.grid_row * r_i + c_i] = 1
                
                print("module_block", module_block)

    
    def get_grid_cells_density(self):
        # by default grid row/col is 10/10
        self.grid_width = float(self.width/self.grid_col)
        self.grid_height = float(self.height/self.grid_row)
        
        grid_area = self.grid_width * self.grid_height
        self.grid_occupied = [0] * (self.grid_col * self.grid_row)
        self.grid_cells = [0] * (self.grid_col * self.grid_row)

        for module_idx in (self.soft_macro_indices + self.hard_macro_indices):
            module = self.modules_w_pins[module_idx]
            module_h = module.get_height()
            module_w = module.get_width()
            module_x, module_y = module.get_pos()

            self.__add_module_to_grid_cells(
                                            mod_x=module_x,
                                            mod_y=module_y,
                                            mod_h=module_h,
                                            mod_w=module_w
                                            )

        for i, gcell in enumerate(self.grid_occupied):
            self.grid_cells[i] = gcell / grid_area
        
        return self.grid_cells

    def get_density_cost(self) -> float:
        # run get_grid_cells_density first
        occupied_cells = sorted([gc for gc in self.grid_cells if gc != 0.0], reverse=True)
        density_cost = 0.0

        # take top 10%
        density_cnt = math.floor(len(self.grid_cells) * 0.1)

        # if grid cell smaller than 10, take the average over occupied cells
        if len(self.grid_cells) < 10:
            density_cost = float(sum(occupied_cells) / len(occupied_cells))
            return 0.5 * density_cost

        idx = 0
        sum_density = 0
        # take top 10%
        while idx < density_cnt and idx < len(occupied_cells):
            sum_density += occupied_cells[idx]
            idx += 1

        return 0.5 * float(sum_density / density_cnt)

    def set_canvas_size(self, width:float, height:float) -> float:
        """
        Set canvas size
        """
        self.width = width
        self.height = height
        return True

    def get_canvas_width_height(self) -> Tuple[float, float]:
        """
        Return canvas size
        """
        return self.width, self.height

    def set_placement_grid(self, grid_col:int, grid_row:int) -> bool:
        """
        Set grid col/row
        """
        self.grid_col = grid_col
        self.grid_row = grid_row
        return True

    def get_grid_num_columns_rows(self) -> Tuple[int, int]:
        """
        Return grid col/row
        """
        return self.grid_col, self.grid_row

    def get_macro_indices(self) -> list:
        """
        Return all macro indices
        """
        return sorted(self.hard_macro_indices + self.soft_macro_indices)

    def get_project_name(self) -> str:
        """
        Return Project name
        """
        return self.project_name

    def get_block_name(self) -> str:
        """
        Return Block name
        """
        return self.block_name

    def set_routes_per_micron(self, hroutes_per_micron:float, vroutes_per_micron:float) -> None:
        """
        Set Routes per Micron
        """
        self.hroutes_per_micron = hroutes_per_micron
        self.vroutes_per_micron = vroutes_per_micron

    def get_routes_per_micron(self) -> Tuple[float, float]:
        """
        Return Routes per Micron
        """
        return self.hroutes_per_micron, self.vroutes_per_micron

    def set_congestion_smooth_range(self, smooth_range:float) -> None:
        """
        Set congestion smooth range
        """
        self.smooth_range = smooth_range

    def get_congestion_smooth_range(self) -> float:
        """
        Return congestion smooth range
        """
        return self.smooth_range

    def set_overlap_threshold(self, overlap_thres:float) -> None:
        """
        Set Overlap Threshold
        """
        self.overlap_thres = overlap_thres

    def get_overlap_threshold(self) -> float:
        """
        Return Overlap Threshold
        """
        return self.overlap_thres

    def get_canvas_boundary_check(self) -> bool:
        return False

    def set_macro_routing_allocation(self, hrouting_alloc:float, vrouting_alloc:float) -> None:
        """
        Set Vertical/Horizontal Macro Allocation
        """
        self.hrouting_alloc = hrouting_alloc
        self.vrouting_alloc = vrouting_alloc

    def get_macro_routing_allocation(self) -> Tuple[float, float]:
        """
        Return Vertical/Horizontal Macro Allocation
        """
        return self.hrouting_alloc, self.vrouting_alloc

    def is_node_soft_macro(self) -> bool:
        return True

    def get_node_mask(self, node_idx: int, node_name: str) -> list:
        return list

    def get_node_type(self, node_idx: int) -> str:
        """
        Return Vertical/Horizontal Macro Allocation
        """
        return self.modules[node_idx].get_type()

    def make_soft_macros_square(self):
        pass

    def get_macro_adjacency(self) -> list:
        """
        Compute Adjacency Matrix (Unclustered PORTs)
        """
        # NOTE: in pb.txt, netlist input count exceed certain threshold will be ommitted
        macro_adj = [0] * self.module_cnt * self.module_cnt
        assert len(macro_adj) == self.module_cnt * self.module_cnt

        #[MACRO][macro][PORT]
        module_indices = self.hard_macro_indices + self.soft_macro_indices + self.port_indices

        for row_idx, module_idx in enumerate(module_indices):
            # row index
            # store temp module
            curr_module = self.modules_w_pins[module_idx]
            # get module name
            curr_module_name = curr_module.get_name()

            for col_idx, h_module_idx in enumerate(module_indices):
                # col index
                entry = 0
                # store connected module
                h_module = self.modules_w_pins[h_module_idx]
                # get connected module name
                h_module_name = h_module.get_name()

                if curr_module_name in h_module.get_connection():
                    entry += h_module.get_connection()[curr_module_name]

                if h_module_name in curr_module.get_connection():
                    entry += curr_module.get_connection()[h_module_name]

                macro_adj[row_idx * self.module_cnt + col_idx] = entry

        return macro_adj

    def is_node_fixed(self):
        pass

    def unplace_all_nodes(self):
        pass

    def place_node(self):
        pass

    def restore_placement(self, init_plc_pth: str):
        """
        Read and retrieve .plc file information
        """
        self.init_plc = init_plc_pth
        self.__read_plc()

    def optimize_stdcells(self):
        pass

    def update_node_coords(self):
        pass

    def fix_node_coord(self):
        pass

    def update_port_sides(self):
        pass

    def snap_ports_to_edges(self):
        pass

    def get_macro_and_clustered_port_adjacency(self):
        """
        Compute Adjacency Matrix (Unclustered PORTs)
        """
        # NOTE: in pb.txt, netlist input count exceed certain threshold will be ommitted
        macro_adj = [0] * self.module_cnt * self.module_cnt
        assert len(macro_adj) == self.module_cnt * self.module_cnt

        #[MACRO][macro][PORT]
        module_indices = self.hard_macro_indices + self.soft_macro_indices + self.port_indices
        
        #[Grid Cell] => [PORT]
        clustered_ports = {}
        for port_idx in self.port_indices:
            port = self.modules_w_pins[port_idx]
            x_pos, y_pos = port.get_pos()

            row, col = self.__get_grid_cell_location(x_pos=x_pos, y_pos=y_pos)

            if (row, col) in clustered_ports:
                clustered_ports[(row, col)].append(port)
            else:
                clustered_ports[(row, col)] = [port]

        return clustered_ports

    def get_node_location(self):
        pass

    def get_grid_cell_of_node(self):
        pass

    def update_macro_orientation(self):
        pass

    def get_macro_orientation(self):
        pass

    def unfix_node_coord(self):
        pass

    def unplace_node(self):
        pass

    def is_node_placed(self):
        pass

    def get_source_filename(self):
        pass

    def get_blockages(self):
        pass

    def get_ref_node_id(self):
        pass

    def save_placement(self):
        pass

    def display_canvas(self):
        #define Matplotlib figure and axis
        fig, ax = plt.subplots(figsize=(8,8), dpi=80)

        # Plt config
        ax.margins(x=0.05, y=0.05)
        ax.set_aspect('equal', adjustable='box')

        # Construct grid
        x, y = np.meshgrid(np.linspace(0, self.height, self.grid_row + 1),\
             np.linspace(0, self.width, self.grid_col + 1))

        ax.plot(x, y, c='b', alpha=0.1) # use plot, not scatter
        ax.plot(np.transpose(x), np.transpose(y), c='b', alpha=0.1) # add this here

        for mod in self.modules_w_pins:
            if mod.get_type() == 'PORT':
                plt.plot(*mod.get_pos(),'ro', markersize=1)
            elif mod.get_type() == 'MACRO':
                ax.add_patch(Rectangle((mod.get_pos()[0] - mod.get_width()/2, mod.get_pos()[1] - mod.get_height()/2),\
                    mod.get_width(), mod.get_height(),\
                    alpha=0.5, zorder=1000, facecolor='b', edgecolor='darkblue'))
                ax.annotate(mod.get_name().rsplit('/', 1)[1], mod.get_pos(), color='r', weight='bold', fontsize=3, ha='center', va='center')
            elif mod.get_type() == 'macro':
                ax.add_patch(Rectangle((mod.get_pos()[0] - mod.get_width()/2, mod.get_pos()[1] - mod.get_height()/2),\
                    mod.get_width(), mod.get_height(),\
                    alpha=0.5, zorder=1000, facecolor='y'))

        plt.show()


    # Board Entity Definition
    class Port:
        def __init__(self, name, x = 0.0, y = 0.0, side = "BOTTOM"):
            self.name = name
            self.x = float(x)
            self.y = float(y)
            self.side = side # "BOTTOM", "TOP", "LEFT", "RIGHT"
            self.sink = {} # standard cells, macro pins, ports driven by this cell
            self.connection = {} # [module_name] => edge degree

        def get_name(self):
            return self.name

        def add_connection(self, module_name):
            # NOTE: assume PORT names does not contain slash
            ifPORT = False
            module_name_splited = module_name.rsplit('/', 1)
            if len(module_name_splited) == 1:
                ifPORT = not ifPORT

            if ifPORT:
                # adding PORT
                self.connection[module_name] = 1
            else:
                # adding soft/hard macros
                if module_name_splited[0] in self.connection.keys():
                    self.connection[module_name_splited[0]] += 1
                else:
                    self.connection[module_name_splited[0]] = 1

        def add_connections(self, module_names):
            # NOTE: assume PORT names does not contain slash
            for module_name in module_names:
                self.add_connection(module_name)

        def set_pos(self, x, y):
            self.x = x
            self.y = y

        def get_pos(self):
            return self.x, self.y

        def set_side(self, side):
            self.side = side

        def add_sink(self, sink_name):
            # NOTE: assume PORT names does not contain slash
            ifPORT = False
            sink_name_splited = sink_name.rsplit('/', 1)
            if len(sink_name_splited) == 1:
                ifPORT = not(ifPORT)

            if ifPORT:
                # adding PORT
                self.sink[sink_name] = [sink_name]
            else:
                # adding soft/hard macros
                if sink_name_splited[0] in self.sink.keys():
                    self.sink[sink_name_splited[0]].append(sink_name)
                else:
                    self.sink[sink_name_splited[0]] = [sink_name]

        def add_sinks(self, sink_names):
            # NOTE: assume PORT names does not contain slash
            for sink_name in sink_names:
                self.add_sink(sink_name)

        def get_sink(self):
            return self.sink

        def get_connection(self):
            return self.connection

        def get_type(self):
            return "PORT"

    class SoftMacro:
        def __init__(self, name, width, height, x = 0.0, y = 0.0):
            self.name = name
            self.width = float(width)
            self.height = float(height)
            self.x = float(x)
            self.y = float(y)
            self.sink = {} # [MACRO_NAME] => [PIN_NAME]
            self.connection = {} # [module_name] => edge degree

        def get_name(self):
            return self.name

        def add_connection(self, module_name):
            # NOTE: assume PORT names does not contain slash
            ifPORT = False
            module_name_splited = module_name.rsplit('/', 1)
            if len(module_name_splited) == 1:
                ifPORT = not(ifPORT)

            if ifPORT:
                # adding PORT
                self.connection[module_name] = 1
            else:
                # adding soft/hard macros
                if module_name_splited[0] in self.connection.keys():
                    self.connection[module_name_splited[0]] += 1
                else:
                    self.connection[module_name_splited[0]] = 1

        def add_connections(self, module_names):
            # NOTE: assume PORT names does not contain slash
            for module_name in module_names:
                self.add_connection(module_name)

        def set_pos(self, x, y):
            self.x = x
            self.y = y

        def get_pos(self):
            return self.x, self.y

        def get_sink(self):
            return self.sink

        def get_type(self):
            return "macro"

        def get_connection(self):
            return self.connection

        def get_area(self):
            return self.width * self.height
        
        def get_height(self):
            return self.height

        def get_width(self):
            return self.width

    class SoftMacroPin:
        def __init__(self, name,
                    x = 0.0, y = 0.0, macro_name = "", weight = 0.0):
            self.name = name
            self.x = float(x)
            self.y = float(y)
            self.x_offset = 0.0 # not used
            self.y_offset = 0.0 # not used
            self.macro_name = macro_name
            self.weight = weight
            self.sink = {}

        def set_weight(self, weight):
            self.weight = weight

        def get_weight(self):
            return self.weight

        def get_name(self):
            return self.name

        def set_pos(self, x, y):
            self.x = x
            self.y = y

        def get_pos(self):
            return self.x, self.y

        def get_offset(self):
            return self.x_offset, self.y_offset

        def add_sink(self, sink_name):
            # NOTE: assume PORT names does not contain slash
            ifPORT = False
            sink_name_splited = sink_name.rsplit('/', 1)
            if len(sink_name_splited) == 1:
                ifPORT = not(ifPORT)

            if ifPORT:
                # adding PORT
                self.sink[sink_name] = [sink_name]
            else:
                # adding soft/hard macros
                if sink_name_splited[0] in self.sink.keys():
                    self.sink[sink_name_splited[0]].append(sink_name)
                else:
                    self.sink[sink_name_splited[0]] = [sink_name]

        def add_sinks(self, sink_names):
            # NOTE: assume PORT names does not contain slash
            for sink_name in sink_names:
                self.add_sink(sink_name)

        def get_sink(self):
            return self.sink

        def get_type(self):
            return "macro_pin"

    class HardMacro:
        def __init__(self, name, width, height,
                     x = 0.0, y = 0.0, orientation = "N"):
            self.name = name
            self.width = float(width)
            self.height = float(height)
            self.x = float(x)
            self.y = float(y)
            self.orientation = orientation
            self.connection = {} # [module_name] => edge degree

        def get_name(self):
            return self.name

        def add_connection(self, module_name):
            # NOTE: assume PORT names does not contain slash
            ifPORT = False
            module_name_splited = module_name.rsplit('/', 1)
            if len(module_name_splited) == 1:
                ifPORT = not(ifPORT)

            if ifPORT:
                # adding PORT
                self.connection[module_name] = 1
            else:
                # adding soft/hard macros
                if module_name_splited[0] in self.connection.keys():
                    self.connection[module_name_splited[0]] += 1
                else:
                    self.connection[module_name_splited[0]] = 1

        def add_connections(self, module_names):
            # NOTE: assume PORT names does not contain slash
            for module_name in module_names:
                self.add_connection(module_name)

        def get_connection(self):
            return self.connection

        def set_pos(self, x, y):
            self.x = x
            self.y = y

        def get_pos(self):
            return self.x, self.y

        def set_orientation(self, orientation):
            self.orientation = orientation

        def get_type(self):
            return "MACRO"

        def get_area(self):
            return self.width * self.height
        
        def get_height(self):
            return self.height

        def get_width(self):
            return self.width

    class HardMacroPin:
        def __init__(self, name,
                        x = 0.0, y = 0.0,
                        x_offset = 0.0, y_offset = 0.0,
                        macro_name = "", weight = 0.0):
            self.name = name
            self.x = float(x)
            self.y = float(y)
            self.x_offset = float(x_offset)
            self.y_offset = float(y_offset)
            self.macro_name = macro_name
            self.weight = weight
            self.sink = {}

        def set_weight(self, weight):
            self.weight = weight

        def get_weight(self):
            return self.weight

        def set_pos(self, x, y):
            self.x = x
            self.y = y

        def get_pos(self):
            return self.x, self.y

        def get_offset(self):
            return self.x_offset, self.y_offset

        def get_name(self):
            return self.name

        def add_sink(self, sink_name):
            # NOTE: assume PORT names does not contain slash
            ifPORT = False
            sink_name_splited = sink_name.rsplit('/', 1)
            if len(sink_name_splited) == 1:
                ifPORT = not(ifPORT)

            if ifPORT:
                # adding PORT
                self.sink[sink_name] = [sink_name]
            else:
                # adding soft/hard macros
                if sink_name_splited[0] in self.sink.keys():
                    self.sink[sink_name_splited[0]].append(sink_name)
                else:
                    self.sink[sink_name_splited[0]] = [sink_name]

        def add_sinks(self, sink_names):
            # NOTE: assume PORT names does not contain slash
            for sink_name in sink_names:
                self.add_sink(sink_name)

        def get_sink(self):
            return self.sink

        def get_type(self):
            return "MACRO_PIN"

def main():
    test_netlist_dir = '/home/yuw/Desktop/Github/CT_runnable/circuit_training/circuit_training/environment/test_data/'+\
        'ariane'
    netlist_file = os.path.join(test_netlist_dir,
                                'netlist.pb.txt')
    plc = PlacementCost(netlist_file)

    print(plc.get_block_name())
    print("Area: ", plc.get_area())
    print("Wirelength: ", plc.get_wirelength())
    print("# HARD_MACROs     :         %d"%(plc.get_hard_macro_count()))
    print("# HARD_MACRO_PINs :         %d"%(plc.get_hard_macro_pin_count()))
    print("# MACROs          :         %d"%(plc.get_hard_macro_count() + plc.get_soft_macro_count()))
    print("# MACRO_PINs      :         %d"%(plc.get_hard_macro_pin_count() + plc.get_soft_macro_pin_count()))
    print("# PORTs           :         %d"%(plc.get_port_count()))
    print("# SOFT_MACROs     :         %d"%(plc.get_soft_macro_count()))
    print("# SOFT_MACRO_PINs :         %d"%(plc.get_soft_macro_pin_count()))
    print("# STDCELLs        :         0")
    
    # print(adj[137])
    # print(np.unique(adj))
    print(plc.set_canvas_size(356.592, 356.640))
    print(plc.set_placement_grid(35, 33))
    # print(plc.set_canvas_size(80, 80))
    # print(plc.set_placement_grid(5, 5))
    print(plc.get_grid_cells_density())
    print(plc.get_density_cost())
    print(plc.display_canvas())
    print(len(plc.get_macro_and_clustered_port_adjacency()))
    

if __name__ == '__main__':
    main()
