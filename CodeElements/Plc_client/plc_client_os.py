"""Open-Sourced PlacementCost client class."""
from ast import Assert
import os, io
from platform import node
import re
import math
from typing import Text, Tuple
from absl import logging
from collections import namedtuple
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
import numpy as np
import traceback, sys

"""plc_client_os docstrings.

Open-sourced effort for plc_client and Google's API, plc_wrapper_main. This module
is used to initialize a PlacementCost object that computes the meta-information and
proxy cost function for RL agent's reward signal at the end of each placement.

Example:
    For testing, please refer to plc_client_os_test.py for more information.

Todo:
    * Add Documentation
    * Clean up
    * location information update not correctly after restore placement
    * test if cell < 5, congestion cost computation

"""

Block = namedtuple('Block', 'x_max y_max x_min y_min')

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

        # Update flags
        self.FLAG_UPDATE_WIRELENGTH = True
        self.FLAG_UPDATE_DENSITY = True
        self.FLAG_UPDATE_CONGESTION = True
        self.FLAG_UPDATE_MACRO_ADJ = True
        self.FLAG_UPDATE_MACRO_AND_CLUSTERED_PORT_ADJ = True

        # Check netlist existance
        assert os.path.isfile(self.netlist_file)

        # Set meta information
        self.init_plc = None
        self.project_name = "circuit_training"
        self.block_name = netlist_file.rsplit('/', -1)[-2]
        self.hroutes_per_micron = 0.0
        self.vroutes_per_micron = 0.0
        self.smooth_range = 0.0
        self.overlap_thres = 0.0
        self.hrouting_alloc = 0.0
        self.vrouting_alloc = 0.0
        self.macro_horizontal_routing_allocation = 0.0
        self.macro_vertical_routing_allocation = 0.0
        self.canvas_boundary_check = True

        # net information
        self.net_cnt = 0

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

        # unknown
        self.use_incremental_cost = False
        # blockage
        self.blockages = []
        # read netlist
        self.__read_protobuf()

        # default canvas width/height based on cell area
        self.width = math.sqrt(self.get_area()/0.6)
        self.height = math.sqrt(self.get_area()/0.6)
        # default gridding
        self.grid_col = 10
        self.grid_row = 10
        # initialize congestion map
        # TODO recompute after new gridding
        self.V_routing_cong = [0] * self.grid_col * self.grid_row
        self.H_routing_cong = [0] * self.grid_col * self.grid_row
        self.V_macro_routing_cong = [0] * self.grid_col * self.grid_row
        self.H_macro_routing_cong = [0] * self.grid_col * self.grid_row
        # initial grid mask
        self.global_node_mask = [0] * self.grid_col * self.grid_row
        # store module/component count
        self.ports_cnt = len(self.port_indices)
        self.hard_macro_cnt = len(self.hard_macro_indices)
        self.hard_macro_pins_cnt = len(self.hard_macro_pin_indices)
        self.soft_macros_cnt = len(self.soft_macro_indices)
        self.soft_macro_pins_cnt = len(self.soft_macro_pin_indices)
        self.module_cnt = self.hard_macro_cnt + self.soft_macros_cnt + self.ports_cnt
        # assert module and pin count are correct
        assert (len(self.modules)) == self.module_cnt
        assert (len(self.modules_w_pins) - \
            self.hard_macro_pins_cnt - self.soft_macro_pins_cnt) \
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
                            logging.warning('[NETLIST PARSER ERROR] x is not defined')

                        try:
                            assert 'y' in attr_dict.keys()
                        except AssertionError:
                            logging.warning('[NETLIST PARSER ERROR] y is not defined')

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
                        soft_macro_pin = self.SoftMacroPin(name=node_name,ref_id=None,
                                                           x = attr_dict['x'][1],
                                                           y = attr_dict['y'][1],
                                                           macro_name = attr_dict['macro_name'][1])

                        if input_list:
                            if 'weight' in attr_dict.keys():
                                self.net_cnt += 1 * float(attr_dict['weight'][1])
                            else:
                                self.net_cnt += 1
                            soft_macro_pin.add_sinks(input_list)
                        
                        if 'weight' in attr_dict.keys():
                            soft_macro_pin.set_weight(float(attr_dict['weight'][1]))

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
                        hard_macro_pin = self.HardMacroPin(name=node_name,ref_id=None,
                                                        x = attr_dict['x'][1],
                                                        y = attr_dict['y'][1],
                                                        x_offset = attr_dict['x_offset'][1],
                                                        y_offset = attr_dict['y_offset'][1],
                                                        macro_name = attr_dict['macro_name'][1])
                        if 'weight' in attr_dict.keys():
                            hard_macro_pin.set_weight(float(attr_dict['weight'][1]))

                        if input_list:
                            if 'weight' in attr_dict.keys():
                                self.net_cnt += 1 * float(attr_dict['weight'][1])
                            else:
                                self.net_cnt += 1
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
                            self.net_cnt += 1
                            port.add_sinks(input_list)
                            # ports does not have pins so update connection immediately
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

    def __read_plc(self, plc_pth: str):
        """
        Plc file Parser
        """
        # meta information
        _columns = 0
        _rows = 0
        _width = 0.0
        _height = 0.0
        _area = 0.0
        _block = None
        _routes_per_micron_hor = 0.0
        _routes_per_micron_ver = 0.0
        _routes_used_by_macros_hor = 0.0
        _routes_used_by_macros_ver = 0.0
        _smoothing_factor = 0
        _overlap_threshold = 0.0

        # node information
        _hard_macros_cnt = 0
        _hard_macro_pins_cnt = 0
        _macros_cnt = 0
        _macro_pin_cnt = 0
        _ports_cnt = 0
        _soft_macros_cnt = 0
        _soft_macro_pins_cnt = 0
        _stdcells_cnt = 0

        # node placement
        _node_plc = {}

        for cnt, line in enumerate(open(plc_pth, 'r')):
            line_item = re.findall(r'[0-9A-Za-z\.\-]+', line)

            # skip empty lines
            if len(line_item) == 0:
                continue

            if 'Columns' in line_item and 'Rows' in line_item:
                # Columns and Rows should be defined on the same one-line
                _columns = int(line_item[1])
                _rows = int(line_item[3])
            elif "Width" in line_item and "Height" in line_item:
                # Width and Height should be defined on the same one-line
                _width = float(line_item[1])
                _height = float(line_item[3])
            elif "Area" in line_item:
                # Total core area of modules
                _area = float(line_item[1])
            elif "Block" in line_item:
                # The block name of the testcase
                _block = str(line_item[1])
            elif all(it in line_item for it in\
                ['Routes', 'per', 'micron', 'hor', 'ver']):
                # For routing congestion computation
                _routes_per_micron_hor = float(line_item[4])
                _routes_per_micron_ver = float(line_item[6])
            elif all(it in line_item for it in\
                    ['Routes', 'used', 'by', 'macros', 'hor', 'ver']):
                # For MACRO congestion computation
                _routes_used_by_macros_hor = float(line_item[5])
                _routes_used_by_macros_ver = float(line_item[7])
            elif all(it in line_item for it in ['Smoothing', 'factor']):
                # smoothing factor for routing congestion
                _smoothing_factor = int(line_item[2])
            elif all(it in line_item for it in ['Overlap', 'threshold']):
                # overlap
                _overlap_threshold = float(line_item[2])
            elif all(it in line_item for it in ['HARD', 'MACROs'])\
                and len(line_item) == 3:
                _hard_macros_cnt = int(line_item[2])
            elif all(it in line_item for it in ['HARD', 'MACRO', 'PINs'])\
                and len(line_item) == 4:
                _hard_macro_pins_cnt = int(line_item[3])
            elif all(it in line_item for it in ['PORTs'])\
                and len(line_item) == 2:
                _ports_cnt = int(line_item[1])
            elif all(it in line_item for it in ['SOFT', 'MACROs'])\
                and len(line_item) == 3:
                _soft_macros_cnt = int(line_item[2])
            elif all(it in line_item for it in ['SOFT', 'MACRO', 'PINs'])\
                and len(line_item) == 4:
                _soft_macro_pins_cnt = int(line_item[3])
            elif all(it in line_item for it in ['STDCELLs'])\
                and len(line_item) == 2:
                _stdcells_cnt = int(line_item[1])
            elif all(it in line_item for it in ['MACROs'])\
                and len(line_item) == 2:
                _macros_cnt = int(line_item[1])
            elif all(re.match(r'[0-9NEWS\.\-]+', it) for it in line_item)\
                and len(line_item) == 5:
                # [node_index] [x] [y] [orientation] [fixed]
                _node_plc[int(line_item[0])] = line_item[1:]
        
        # return as dictionary
        info_dict = {   "columns":_columns, 
                        "rows":_rows,
                        "width":_width,
                        "height":_height,
                        "area":_area,
                        "block":_block,
                        "routes_per_micron_hor":_routes_per_micron_hor,
                        "routes_per_micron_ver":_routes_per_micron_ver,
                        "routes_used_by_macros_hor":_routes_used_by_macros_hor,
                        "routes_used_by_macros_ver":_routes_used_by_macros_ver,
                        "smoothing_factor":_smoothing_factor,
                        "overlap_threshold":_overlap_threshold,
                        "hard_macros_cnt":_hard_macros_cnt,
                        "hard_macro_pins_cnt":_hard_macro_pins_cnt,
                        "macros_cnt":_macros_cnt,
                        "macro_pin_cnt":_macro_pin_cnt,
                        "ports_cnt":_ports_cnt,
                        "soft_macros_cnt":_soft_macros_cnt,
                        "soft_macro_pins_cnt":_soft_macro_pins_cnt,
                        "stdcells_cnt":_stdcells_cnt,
                        "node_plc":_node_plc
                    }

        return info_dict

    def restore_placement(self, plc_pth: str, ifInital=True, ifValidate=False, ifReadComment = False):
        """
            Read and retrieve .plc file information
            NOTE: DO NOT always set self.init_plc because this function is also 
            used to read final placement file.

            ifReadComment: By default, Google's plc_client does not extract 
            information from .plc comment. This is purely done in 
            placement_util.py. For purpose of testing, we included this option.
        """
        # if plc is an initial placement
        if ifInital:
            self.init_plc = plc_pth
        
        # recompute cost from new location
        self.FLAG_UPDATE_CONGESTION = True
        self.FLAG_UPDATE_DENSITY = True
        self.FLAG_UPDATE_WIRELENGTH = True
        
        # extracted information from .plc file
        info_dict = self.__read_plc(plc_pth)

        # validate netlist.pb.txt is on par with .plc
        if ifValidate:
            try:
                assert(self.hard_macro_cnt == info_dict['hard_macros_cnt'])
                assert(self.hard_macro_pins_cnt == info_dict['hard_macro_pins_cnt'])
                assert(self.soft_macros_cnt == info_dict['soft_macros_cnt'])
                assert(self.soft_macro_pins_cnt == info_dict['soft_macro_pins_cnt'])
                assert(self.ports_cnt == info_dict['ports_cnt'])
            except AssertionError:
                _, _, tb = sys.exc_info()
                traceback.print_tb(tb)
                tb_info = traceback.extract_tb(tb)
                _, line, _, text = tb_info[-1]
                print('[NETLIST/PLC MISMATCH ERROR] at line {} in statement {}'\
                    .format(line, text))
                exit(1)
        
        # restore placement for each module
        try:
            assert sorted(self.port_indices +\
                self.hard_macro_indices +\
                self.soft_macro_indices) == list(info_dict['node_plc'].keys())
        except AssertionError:
            print('[PLC INDICES MISMATCH ERROR]', len(sorted(self.port_indices +\
                self.hard_macro_indices +\
                self.soft_macro_indices)), len(list(info_dict['node_plc'].keys())))
            exit(1)
        
        for mod_idx in info_dict['node_plc'].keys():
            mod_x = mod_y = mod_orient = mod_ifFixed = None
            try:
                mod_x = float(info_dict['node_plc'][mod_idx][0])
                mod_y = float(info_dict['node_plc'][mod_idx][1])
                mod_orient = info_dict['node_plc'][mod_idx][2]
                mod_ifFixed = int(info_dict['node_plc'][mod_idx][3])
            except Exception as e:
                print('[PLC PARSER ERROR] %s' % str(e))

            #TODO ValueError: Error in calling RestorePlacement with ('./Plc_client/test/ariane/initial.plc',): Can't place macro i_ariane/i_frontend/i_icache/sram_block_3__tag_sram/mem/mem_inst_mem_256x45_256x16_0x0 at (341.75, 8.8835). Exceeds the boundaries of the placement area..

            self.modules_w_pins[mod_idx].set_pos(mod_x, mod_y)
            
            if mod_orient and mod_orient != '-':
                self.modules_w_pins[mod_idx].set_orientation(mod_orient)
            
            if mod_ifFixed == 0:
                self.modules_w_pins[mod_idx].set_fix_flag(False)
            elif mod_ifFixed == 1:
                self.modules_w_pins[mod_idx].set_fix_flag(True)
        
        # set meta information
        if ifReadComment:
            self.set_canvas_size(info_dict['width'], info_dict['height'])
            self.set_placement_grid(info_dict['columns'], info_dict['rows'])
            self.set_block_name(info_dict['block'])
            self.set_routes_per_micron(
                info_dict['routes_per_micron_hor'],
                info_dict['routes_per_micron_ver']
                )
            self.set_macro_routing_allocation(
                info_dict['routes_used_by_macros_hor'],
                info_dict['routes_used_by_macros_ver']
                )
            self.set_congestion_smooth_range(info_dict['smoothing_factor'])
            self.set_overlap_threshold(info_dict['overlap_threshold'])

    def __update_connection(self):
        """
        Update connection degree for each macro pin
        """
        for macro_idx in (self.hard_macro_indices + self.soft_macro_indices):
            macro = self.modules_w_pins[macro_idx]
            macro_name = macro.get_name()

            if not self.is_node_soft_macro(macro_idx):
                if macro_name in self.hard_macros_to_inpins.keys():
                    pin_names = self.hard_macros_to_inpins[macro_name]
                else:
                    print("[ERROR UPDATE CONNECTION] MACRO not found")
                    exit(1)
            # use is_node_soft_macro()
            elif self.is_node_soft_macro(macro_idx):
                if macro_name in self.soft_macros_to_inpins.keys():
                    pin_names = self.soft_macros_to_inpins[macro_name]
                else:
                    print("[ERROR UPDATE CONNECTION] MACRO not found")
                    exit(1)

            for pin_name in pin_names:
                pin = self.modules_w_pins[self.mod_name_to_indices[pin_name]]
                inputs = pin.get_sink()

                if inputs:
                    for k in inputs.keys():
                        if self.get_node_type(macro_idx) == "MACRO":
                            weight = pin.get_weight()
                            macro.add_connections(inputs[k], weight)

    def get_cost(self) -> float:
        """
        Compute wirelength cost from wirelength
        """
        if self.FLAG_UPDATE_WIRELENGTH:
            self.FLAG_UPDATE_WIRELENGTH = False
        return self.get_wirelength() / ((self.get_canvas_width_height()[0]\
            + self.get_canvas_width_height()[1]) * self.net_cnt)

    def get_area(self) -> float:
        """
        Compute Total Module Area
        """
        total_area = 0.0
        for mod in self.modules_w_pins:
            if hasattr(mod, 'get_area'):
                total_area += mod.get_area()
        return total_area

    def get_hard_macros_count(self) -> int:
        return self.hard_macro_cnt

    def get_ports_count(self) -> int:
        return self.ports_cnt

    def get_soft_macros_count(self) -> int:
        return self.soft_macros_cnt

    def get_hard_macro_pins_count(self) -> int:
        return self.hard_macro_pins_cnt

    def get_soft_macro_pins_count(self) -> int:
        return self.soft_macro_pins_cnt

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
                    for sink_pin in mod.get_sink()[sink_name]:
                        # retrieve indx in modules_w_pins
                        sink_idx = self.mod_name_to_indices[sink_pin]
                        # retrieve sink object
                        sink = self.modules_w_pins[sink_idx]
                        # retrieve location
                        x_coord.append(sink.get_pos()[0])
                        y_coord.append(sink.get_pos()[1])
            elif curr_type == "MACRO_PIN":
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

    def abu(self, xx, n = 0.1):
        xxs = sorted(xx, reverse = True)
        cnt = math.floor(len(xxs)*n)
        if cnt == 0:
            return max(xxs)
        return sum(xxs[0:cnt])/cnt
    
    def get_V_congestion_cost(self) -> float:
        """
        compute average of top 10% of grid cell cong and take half of it
        """
        occupied_cells = sorted([gc for gc in self.V_routing_cong if gc != 0.0], reverse=True)
        cong_cost = 0.0

        # take top 10%
        cong_cnt = math.floor(len(self.V_routing_cong) * 0.1)

        # if grid cell smaller than 10, take the average over occupied cells
        if len(self.V_routing_cong) < 10:
            cong_cost = float(sum(occupied_cells) / len(occupied_cells))
            return cong_cost

        idx = 0
        sum_cong = 0
        # take top 10%
        while idx < cong_cnt and idx < len(occupied_cells):
            sum_cong += occupied_cells[idx]
            idx += 1

        return float(sum_cong / cong_cnt)
    
    def get_H_congestion_cost(self) -> float:
        """
        compute average of top 10% of grid cell cong and take half of it
        """
        occupied_cells = sorted([gc for gc in self.H_routing_cong if gc != 0.0], reverse=True)
        cong_cost = 0.0

        # take top 10%
        cong_cnt = math.floor(len(self.H_routing_cong) * 0.1)

        # if grid cell smaller than 10, take the average over occupied cells
        if len(self.H_routing_cong) < 10:
            cong_cost = float(sum(occupied_cells) / len(occupied_cells))
            return cong_cost

        idx = 0
        sum_cong = 0
        # take top 10%
        while idx < cong_cnt and idx < len(occupied_cells):
            sum_cong += occupied_cells[idx]
            idx += 1

        return float(sum_cong / cong_cnt)
    
    def get_congestion_cost(self):
        #return max(self.get_H_congestion_cost(), self.get_V_congestion_cost())
        # TODO need to test if cong is smaller than 5
        if self.FLAG_UPDATE_CONGESTION:
            self.get_routing()

        return self.abu(self.V_routing_cong + self.H_routing_cong, 0.05)

    def __get_grid_cell_location(self, x_pos, y_pos):
        """
        private function for getting grid cell row/col ranging from 0...N
        """
        self.grid_width = float(self.width/self.grid_col)
        self.grid_height = float(self.height/self.grid_row)
        row = math.floor(y_pos / self.grid_height)
        col = math.floor(x_pos / self.grid_width)
        return row, col

    def __overlap_area(self, block_i, block_j):
        """
        private function for computing block overlapping
        """
        x_diff = min(block_i.x_max, block_j.x_max) - max(block_i.x_min, block_j.x_min)
        y_diff = min(block_i.y_max, block_j.y_max) - max(block_i.y_min, block_j.y_min)
        if x_diff >= 0 and y_diff >= 0:
            return x_diff * y_diff
        return 0
    
    def __overlap_dist(self, block_i, block_j):
        """
        private function for computing block overlapping
        """
        x_diff = min(block_i.x_max, block_j.x_max) - max(block_i.x_min, block_j.x_min)
        y_diff = min(block_i.y_max, block_j.y_max) - max(block_i.y_min, block_j.y_min)
        if x_diff > 0 and y_diff > 0:
            return x_diff, y_diff
        return 0, 0

    def __add_module_to_grid_cells(self, mod_x, mod_y, mod_w, mod_h):
        """
        private function for add module to grid cells
        """
        # Two corners
        ur = (mod_x + (mod_w/2), mod_y + (mod_h/2))
        bl = (mod_x - (mod_w/2), mod_y - (mod_h/2))

        # construct block based on current module
        module_block = Block(
                            x_max=mod_x + (mod_w/2),
                            y_max=mod_y + (mod_h/2),
                            x_min=mod_x - (mod_w/2),
                            y_min=mod_y - (mod_h/2)
                            )

        # Only need two corners of a grid cell
        ur_row, ur_col = self.__get_grid_cell_location(*ur)
        bl_row, bl_col = self.__get_grid_cell_location(*bl)

        # check if out of bound
        if ur_row >= 0 and ur_col >= 0:
            if bl_row < 0:
                bl_row = 0

            if bl_col < 0:
                bl_col = 0
        else:
            # OOB, skip module
            return

        if bl_row >= 0 and bl_col >= 0:
            if ur_row > self.grid_row - 1:
                ur_row = self.grid_row - 1

            if ur_col > self.grid_col - 1:
                ur_col = self.grid_col - 1
        else:
            # OOB, skip module
            return

        for r_i in range(bl_row, ur_row + 1):
            for c_i in range(bl_col, ur_col + 1):
                # construct block based on current cell row/col
                grid_cell_block = Block(
                                        x_max= (c_i + 1) * self.grid_width,
                                        y_max= (r_i + 1) * self.grid_height,
                                        x_min= c_i * self.grid_width,
                                        y_min= r_i * self.grid_height
                                        )

                self.grid_occupied[self.grid_col * r_i + c_i] += \
                    self.__overlap_area(grid_cell_block, module_block)

    def get_grid_cells_density(self):
        """
        compute density for all grid cells
        """
        # by default grid row/col is 10/10
        self.grid_width = float(self.width/self.grid_col)
        self.grid_height = float(self.height/self.grid_row)

        grid_area = self.grid_width * self.grid_height
        self.grid_occupied = [0] * (self.grid_col * self.grid_row)
        self.grid_cells = [0] * (self.grid_col * self.grid_row)

        for module_idx in (self.soft_macro_indices + self.hard_macro_indices):
            # extract module information
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
        """
        compute average of top 10% of grid cell density and take half of it
        """
        if self.FLAG_UPDATE_DENSITY:
            self.get_grid_cells_density()
            self.FLAG_UPDATE_DENSITY=False

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

        # Flag updates
        self.FLAG_UPDATE_CONGESTION = True
        self.FLAG_UPDATE_DENSITY = True
        self.FLAG_UPDATE_MACRO_AND_CLUSTERED_PORT_ADJ = True

        self.grid_width = float(self.width/self.grid_col)
        self.grid_height = float(self.height/self.grid_row)
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
        print("#[PLACEMENT GRID] Col: %d, Row: %d" % (grid_col, grid_row))
        self.grid_col = grid_col
        self.grid_row = grid_row

        # Flag updates
        self.FLAG_UPDATE_CONGESTION = True
        self.FLAG_UPDATE_DENSITY = True
        self.FLAG_UPDATE_MACRO_AND_CLUSTERED_PORT_ADJ = True

        self.V_routing_cong = [0] * self.grid_col * self.grid_row
        self.H_routing_cong = [0] * self.grid_col * self.grid_row
        self.V_macro_routing_cong = [0] * self.grid_col * self.grid_row
        self.H_macro_routing_cong = [0] * self.grid_col * self.grid_row

        self.grid_width = float(self.width/self.grid_col)
        self.grid_height = float(self.height/self.grid_row)
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

    def set_project_name(self, project_name):
        """
        Set Project name
        """
        self.project_name = project_name

    def get_project_name(self) -> str:
        """
        Return Project name
        """
        return self.project_name
    
    def set_block_name(self, block_name:str) -> None:
        """
        Return Block name
        """
        self.block_name = block_name

    def get_block_name(self) -> str:
        """
        Return Block name
        """
        return self.block_name

    def set_routes_per_micron(self, hroutes_per_micron:float, vroutes_per_micron:float) -> None:
        """
        Set Routes per Micron
        """
        print("#[ROUTES PER MICRON] Hor: %.2f, Ver: %.2f" % (hroutes_per_micron, vroutes_per_micron))
        # Flag updates
        self.FLAG_UPDATE_CONGESTION = True

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
        print("#[CONGESTION SMOOTH RANGE] Smooth Range: %d" % (smooth_range))
        # Flag updates
        self.FLAG_UPDATE_CONGESTION = True

        self.smooth_range = math.floor(smooth_range)

    def get_congestion_smooth_range(self) -> float:
        """
        Return congestion smooth range
        """
        return self.smooth_range

    def set_overlap_threshold(self, overlap_thres:float) -> None:
        """
        Set Overlap Threshold
        """
        print("#[OVERLAP THRESHOLD] Threshold: %.4f" % (overlap_thres))
        self.overlap_thres = overlap_thres

    def get_overlap_threshold(self) -> float:
        """
        Return Overlap Threshold
        """
        return self.overlap_thres

    def set_canvas_boundary_check(self, ifCheck:bool) -> None:
        """
        boundary_check: Do a boundary check during node placement.
        """
        self.canvas_boundary_check = ifCheck

    def get_canvas_boundary_check(self) -> bool:
        """
        return canvas_boundary_check
        """
        return self.canvas_boundary_check

    def set_macro_routing_allocation(self, hrouting_alloc:float, vrouting_alloc:float) -> None:
        """
        Set Vertical/Horizontal Macro Allocation
        """
        # Flag updates
        self.FLAG_UPDATE_CONGESTION = True

        self.hrouting_alloc = hrouting_alloc
        self.vrouting_alloc = vrouting_alloc

    def get_macro_routing_allocation(self) -> Tuple[float, float]:
        """
        Return Vertical/Horizontal Macro Allocation
        """
        return self.hrouting_alloc, self.vrouting_alloc

    def __two_pin_net_routing(self, source_gcell, node_gcells, weight):
        temp_gcell = list(node_gcells)
        if temp_gcell[0] == source_gcell:
            sink_gcell = temp_gcell[1]
        else:
            sink_gcell = temp_gcell[0]

        # y
        row_min = min(sink_gcell[0], source_gcell[0])
        row_max = max(sink_gcell[0], source_gcell[0])

        # x
        col_min = min(sink_gcell[1], source_gcell[1])
        col_max = max(sink_gcell[1], source_gcell[1])

        # H routing
        for col_idx in range(col_min, col_max, 1):
            col = col_idx
            row = source_gcell[0]
            self.H_routing_cong[row * self.grid_col + col] += weight

        # V routing
        for row_idx in range(row_min, row_max, 1):
            row = row_idx
            col = sink_gcell[1]
            self.V_routing_cong[row * self.grid_col + col] += weight

    def l_routing(self, node_gcells, weight):
        node_gcells.sort(key = lambda x: (x[1], x[0]))
        y1, x1 = node_gcells[0]
        y2, x2 = node_gcells[1]
        y3, x3 = node_gcells[2]
        # H routing (x1, y1) to (x2, y1)
        for col in range(x1, x2):
            row = y1
            self.H_routing_cong[row * self.grid_col + col] += weight
        
        # H routing (x2, y2) to (x2, y3)
        for col in range(x2,x3):
            row = y2
            self.H_routing_cong[row * self.grid_col + col] += weight
        
        # V routing (x2, min(y1, y2)) to (x2, max(y1, y2))
        for row in range(min(y1, y2), max(y1, y2)):
            col = x2
            self.V_routing_cong[row * self.grid_col + col] += weight
        
        # V routing (x3, min(y2, y3)) to (x3, max(y2, y3))
        for row in range(min(y2, y3), max(y2, y3)):
            col = x3
            self.V_routing_cong[row * self.grid_col + col] += weight
        return

    def t_routing(self, node_gcells, weight):
        node_gcells.sort()
        #print(node_gcells)
        y1, x1 = node_gcells[0]
        y2, x2 = node_gcells[1]
        y3, x3 = node_gcells[2]
        xmin = min(x1, x2, x3)
        xmax = max(x1, x2, x3)

        # H routing (xmin, y2) to (xmax, y2)
        for col in range(xmin, xmax):
            row = y2
            self.H_routing_cong[row * self.grid_col + col] += weight
        
        # V routing (x1, y1) to (x1, y2)
        for row in range(min(y1, y2), max(y1, y2)):
            col = x1
            self.V_routing_cong[row * self.grid_col + col] += weight
        
        # V routing (x3, y3) to (x3, y2)
        for row in range(min(y2, y3), max(y2, y3)):
            col = x3
            self.V_routing_cong[row * self.grid_col + col] += weight
        pass

    def __three_pin_net_routing(self, node_gcells, weight):
        temp_gcell = list(node_gcells)
        ## Sorted based on X
        temp_gcell.sort(key = lambda x: (x[1], x[0]))
        y1, x1 = temp_gcell[0]
        y2, x2 = temp_gcell[1]
        y3, x3 = temp_gcell[2]

        if x1 < x2 and x2 < x3 and min(y1, y3) < y2 and max(y1, y3) > y2:
            # print('sk1')
            self.l_routing(temp_gcell, weight)
            return
        
        if x2 == x3 and x1 < x2 and y1 < min(y2, y3):
            # print('sk2')
            for col_idx in range(x1,x2,1):
                row = y1
                col = col_idx
                self.H_routing_cong[row * self.grid_col + col] += weight
            
            for row_idx in range(y1, max(y2,y3)):
                col = x2
                row = row_idx
                self.V_routing_cong[row * self.grid_col + col] += weight
            return

        if y2 == y3:
            # print('sk3')
            for col in range(x1, x2):
                row = y1
                self.H_routing_cong[row * self.grid_col + col] += weight
            
            for col in range(x2, x3):
                row = y2
                self.H_routing_cong[row * self.grid_col + col] += weight
            
            for row in range(min(y2, y1), max(y2, y1)):
                col = x2
                self.V_routing_cong[row * self.grid_col + col] += weight
            return
        
        
        # print('sk4')
        self.t_routing(temp_gcell, weight)
        return

    def __macro_route_over_grid_cell(self, mod_x, mod_y, mod_w, mod_h):
        """
        private function for add module to grid cells
        """
        # Two corners
        ur = (mod_x + (mod_w/2), mod_y + (mod_h/2))
        bl = (mod_x - (mod_w/2), mod_y - (mod_h/2))

        # construct block based on current module
        module_block = Block(
                            x_max=mod_x + (mod_w/2),
                            y_max=mod_y + (mod_h/2),
                            x_min=mod_x - (mod_w/2),
                            y_min=mod_y - (mod_h/2)
                            )

        # Only need two corners of a grid cell
        ur_row, ur_col = self.__get_grid_cell_location(*ur)
        bl_row, bl_col = self.__get_grid_cell_location(*bl)

        # check if out of bound
        if ur_row >= 0 and ur_col >= 0:
            if bl_row < 0:
                bl_row = 0

            if bl_col < 0:
                bl_col = 0
        else:
            # OOB, skip module
            return

        if bl_row >= 0 and bl_col >= 0:
            if ur_row > self.grid_row - 1:
                ur_row = self.grid_row - 1

            if ur_col > self.grid_col - 1:
                ur_col = self.grid_col - 1
        else:
            # OOB, skip module
            return
        
        if_PARTIAL_OVERLAP_VERTICAL = False
        if_PARTIAL_OVERLAP_HORIZONTAL = False

        for r_i in range(bl_row, ur_row + 1):
            for c_i in range(bl_col, ur_col + 1):
                # construct block based on current cell row/col
                grid_cell_block = Block(
                                        x_max= (c_i + 1) * self.grid_width,
                                        y_max= (r_i + 1) * self.grid_height,
                                        x_min= c_i * self.grid_width,
                                        y_min= r_i * self.grid_height
                                        )

                x_dist, y_dist = self.__overlap_dist(module_block, grid_cell_block)

                if ur_row != bl_row:
                    if (r_i == bl_row and abs(y_dist - self.grid_height) > 1e-5) or (r_i == ur_row and abs(y_dist - self.grid_height) > 1e-5):
                        if_PARTIAL_OVERLAP_VERTICAL = True
                
                if ur_col != bl_col:
                    if (c_i == bl_col and abs(x_dist - self.grid_width) > 1e-5) or (c_i == ur_col and abs(x_dist - self.grid_width) > 1e-5):
                        if_PARTIAL_OVERLAP_HORIZONTAL = True


                self.V_macro_routing_cong[r_i * self.grid_col + c_i] += x_dist * self.vrouting_alloc
                self.H_macro_routing_cong[r_i * self.grid_col + c_i] += y_dist * self.hrouting_alloc

        if if_PARTIAL_OVERLAP_VERTICAL:
            for r_i in range(ur_row, ur_row + 1):
                for c_i in range(bl_col, ur_col + 1):
                    grid_cell_block = Block(
                                        x_max= (c_i + 1) * self.grid_width,
                                        y_max= (r_i + 1) * self.grid_height,
                                        x_min= c_i * self.grid_width,
                                        y_min= r_i * self.grid_height
                                        )

                    x_dist, y_dist = self.__overlap_dist(module_block, grid_cell_block)
                    self.V_macro_routing_cong[r_i * self.grid_col + c_i] -= x_dist * self.vrouting_alloc

        if if_PARTIAL_OVERLAP_HORIZONTAL:
            for r_i in range(bl_row, ur_row + 1):
                for c_i in range(ur_col, ur_col + 1):
                    grid_cell_block = Block(
                                        x_max= (c_i + 1) * self.grid_width,
                                        y_max= (r_i + 1) * self.grid_height,
                                        x_min= c_i * self.grid_width,
                                        y_min= r_i * self.grid_height
                                        )

                    x_dist, y_dist = self.__overlap_dist(module_block, grid_cell_block)
                    self.H_macro_routing_cong[r_i * self.grid_col + c_i] -= y_dist * self.hrouting_alloc

    def __split_net(self, source_gcell, node_gcells):
        splitted_netlist = []
        for node_gcell in node_gcells:
            if node_gcell != source_gcell:
                splitted_netlist.append({source_gcell, node_gcell})
        return splitted_netlist

    def get_vertical_routing_congestion(self):
        # TODO: detect if we need to run
        if self.FLAG_UPDATE_CONGESTION:
            self.get_routing()
        
        return self.V_routing_cong

    def get_horizontal_routing_congestion(self):
        # TODO: detect if we need to run
        if self.FLAG_UPDATE_CONGESTION:
            self.get_routing()
        
        return self.H_routing_cong

    def get_routing(self):
        """
            Route between modules
        """
        if self.FLAG_UPDATE_CONGESTION:
            self.grid_width = float(self.width/self.grid_col)
            self.grid_height = float(self.height/self.grid_row)

            self.grid_v_routes = self.grid_width * self.vroutes_per_micron
            self.grid_h_routes = self.grid_height * self.hroutes_per_micron

            # reset grid
            self.H_routing_cong = [0] * self.grid_row * self.grid_col
            self.V_routing_cong = [0] * self.grid_row * self.grid_col

            self.H_macro_routing_cong = [0] * self.grid_row * self.grid_col
            self.V_macro_routing_cong = [0] * self.grid_row * self.grid_col

            self.FLAG_UPDATE_CONGESTION = False

        for mod in self.modules_w_pins:
            curr_type = mod.get_type()
            # bounding box data structure
            node_gcells = set()
            source_gcell = None
            weight = 1

            # NOTE: connection only defined on PORT, soft/hard macro pins
            if curr_type == "PORT" and mod.get_sink():
                # add source grid location
                source_gcell = self.__get_grid_cell_location(*(mod.get_pos()))
                node_gcells.add(self.__get_grid_cell_location(*(mod.get_pos())))

                for sink_name in mod.get_sink():
                    for sink_pin in mod.get_sink()[sink_name]:
                        # retrieve indx in modules_w_pins
                        sink_idx = self.mod_name_to_indices[sink_pin]
                        # retrieve sink object
                        sink = self.modules_w_pins[sink_idx]
                        # retrieve grid location
                        node_gcells.add(self.__get_grid_cell_location(*(sink.get_pos())))

            elif curr_type == "MACRO_PIN" and mod.get_sink():
                # add source position
                node_gcells.add(self.__get_grid_cell_location(*(mod.get_pos())))
                source_gcell = self.__get_grid_cell_location(*(mod.get_pos()))

                if mod.get_weight() > 1:
                    weight = mod.get_weight()

                for input_list in mod.get_sink().values():
                    for sink_name in input_list:
                        # retrieve indx in modules_w_pins
                        sink_idx = self.mod_name_to_indices[sink_name]
                        # retrieve sink object
                        sink = self.modules_w_pins[sink_idx]
                        # retrieve grid location                                                                                                                                                                                                                                                 
                        node_gcells.add(self.__get_grid_cell_location(*(sink.get_pos())))
            
            elif curr_type == "MACRO" and self.is_node_hard_macro(self.mod_name_to_indices[mod.get_name()]):
                module_h = mod.get_height()
                module_w = mod.get_width()
                module_x, module_y = mod.get_pos()
                # compute overlap
                self.__macro_route_over_grid_cell(module_x, module_y, module_w, module_h)
            
            if len(node_gcells) == 2:
                self.__two_pin_net_routing(source_gcell=source_gcell,node_gcells=node_gcells, weight=weight)
            elif len(node_gcells) == 3:
                self.__three_pin_net_routing(node_gcells=node_gcells, weight=weight)
            elif len(node_gcells) > 3:
                for curr_net in self.__split_net(source_gcell=source_gcell, node_gcells=node_gcells):
                    self.__two_pin_net_routing(source_gcell=source_gcell, node_gcells=curr_net, weight=weight)

        # print("V_routing_cong", self.V_routing_cong)
        # print("H_routing_cong", self.H_routing_cong)
        # normalize routing congestion
        for idx, v_gcell in enumerate(self.V_routing_cong):
            self.V_routing_cong[idx] = float(v_gcell / self.grid_v_routes)
        
        for idx, h_gcell in enumerate(self.H_routing_cong):
            self.H_routing_cong[idx] = float(h_gcell / self.grid_h_routes)
        
        for idx, v_gcell in enumerate(self.V_macro_routing_cong):
            self.V_macro_routing_cong[idx] = float(v_gcell / self.grid_v_routes)
        
        for idx, h_gcell in enumerate(self.H_macro_routing_cong):
            self.H_macro_routing_cong[idx] = float(h_gcell / self.grid_h_routes)
        
        self.__smooth_routing_cong()

        # sum up routing congestion with macro congestion
        self.V_routing_cong = [sum(x) for x in zip(self.V_routing_cong, self.V_macro_routing_cong)]
        self.H_routing_cong = [sum(x) for x in zip(self.H_routing_cong, self.H_macro_routing_cong)]
 
    def __smooth_routing_cong(self):
        temp_V_routing_cong = [0] * self.grid_col * self.grid_row
        temp_H_routing_cong = [0] * self.grid_col * self.grid_row

        # v routing cong
        for row in range(self.grid_row):
            for col in range(self.grid_col):
                lp = col - self.smooth_range
                if lp < 0:
                    lp = 0

                rp = col + self.smooth_range
                if rp >= self.grid_col:
                    rp = self.grid_col - 1
                
                gcell_cnt = rp - lp + 1

                val = self.V_routing_cong[row * self.grid_col + col] / gcell_cnt

                for ptr in range(lp, rp + 1, 1):
                    temp_V_routing_cong[row * self.grid_col + ptr] += val
        
        self.V_routing_cong = temp_V_routing_cong

        # h routing cong
        for row in range(self.grid_row):
            for col in range(self.grid_col):
                lp = row - self.smooth_range
                if lp < 0:
                    lp = 0

                up = row + self.smooth_range
                if up >= self.grid_row:
                    up = self.grid_row - 1
                
                gcell_cnt = up - lp + 1

                val = self.H_routing_cong[row * self.grid_col + col] / gcell_cnt

                for ptr in range(lp, up + 1, 1):
                    temp_H_routing_cong[ptr * self.grid_col + col] += val
        
        self.H_routing_cong = temp_H_routing_cong

    def is_node_soft_macro(self, node_idx) -> bool:
        """
        Return None or return ref_id
        """
        try:
            return node_idx in self.soft_macro_indices
        except IndexError:
            print("[ERROR INDEX OUT OF RANGE] Can not process index at {}".format(node_idx))
            exit(0)

    def is_node_hard_macro(self, node_idx) -> bool:
        """
        Return None or return ref_id
        """
        try:
            return node_idx in self.hard_macro_indices
        except IndexError:
            print("[ERROR INDEX OUT OF RANGE] Can not process index at {}".format(node_idx))
            exit(0)

    def get_node_name(self, node_idx: int) -> str:
        return self.indices_to_mod_name[node_idx]

    def get_node_mask(self, node_idx: int, node_name: str) -> list:
        """
            Return Grid_col x Grid_row:
                1 == placable
                0 == unplacable

                (100, 100)  =>  5
                (99, 99)    =>  0
                (100, 99)   =>  1
                (99, 100)   =>  4

            Placement Constraint:
            -   center @ grid cell
            -   no overlapping other macro
            -   no OOB
        """
        module = self.modules_w_pins[node_idx]

    def get_node_type(self, node_idx: int) -> str:
        """
        Return node type
        """
        try:
            return self.modules_w_pins[node_idx].get_type()
        except IndexError:
            # NOTE: Google's API return NONE if out of range
            print("[INDEX OUT OF RANGE WARNING] Can not process index at {}".format(node_idx))
            return None

    
    def get_node_width_height(self, node_idx: int):
        """
        Return node dimension
        """
        mod = None
        try:
            mod = self.modules_w_pins[node_idx]
            assert mod.get_type() in ['MACRO', 'macro', 'STDCELL', 'PORT']
        except AssertionError:
            print("[ERROR NODE FIXED] Found {}. Only 'MACRO', 'macro', 'STDCELL'".format(mod.get_type())
                    +"'PORT' are considered to be fixable nodes")
            exit(1)
        except Exception:
            print("[ERROR NODE FIXED] Could not find module by node index")
            exit(1)

        return mod.get_width(), mod.get_height()

    def make_soft_macros_square(self):
        pass

    def set_use_incremental_cost(self, use_incremental_cost):
        self.use_incremental_cost = use_incremental_cost

    def get_use_incremental_cost(self):
        return self.use_incremental_cost

    def get_macro_adjacency(self) -> list:
        """
        Compute Adjacency Matrix
        """
        # NOTE: in pb.txt, netlist input count exceed certain threshold will be ommitted
        #[MACRO][macro]

        if self.FLAG_UPDATE_MACRO_ADJ:
            # do some update
            self.FLAG_UPDATE_MACRO_ADJ = False

        module_indices = self.hard_macro_indices + self.soft_macro_indices
        macro_adj = [0] * (self.hard_macro_cnt + self.soft_macros_cnt) * (self.hard_macro_cnt + self.soft_macros_cnt)
        assert len(macro_adj) == (self.hard_macro_cnt + self.soft_macros_cnt) * (self.hard_macro_cnt + self.soft_macros_cnt)

        for row_idx, module_idx in enumerate(sorted(module_indices)):
            # row index
            # store temp module
            curr_module = self.modules_w_pins[module_idx]
            # get module name
            curr_module_name = curr_module.get_name()

            for col_idx, h_module_idx in enumerate(sorted(module_indices)):
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

                macro_adj[row_idx * (self.hard_macro_cnt + self.soft_macros_cnt) + col_idx] = entry
                macro_adj[col_idx * (self.hard_macro_cnt + self.soft_macros_cnt) + row_idx] = entry

        return macro_adj

    def get_macro_and_clustered_port_adjacency(self):
        """
        Compute Adjacency Matrix (Unclustered PORTs)
        if module is a PORT, assign it to nearest cell location even if OOB
        """

        #[MACRO][macro]
        module_indices = self.hard_macro_indices + self.soft_macro_indices

        #[Grid Cell] => [PORT]
        clustered_ports = {}
        for port_idx in self.port_indices:
            port = self.modules_w_pins[port_idx]
            x_pos, y_pos = port.get_pos()

            row, col = self.__get_grid_cell_location(x_pos=x_pos, y_pos=y_pos)

            # prevent OOB
            if row >= self.grid_row:
                row = self.grid_row - 1
            
            if row < 0:
                row = 0

            if col >= self.grid_col:
                col = self.grid_col - 1
            
            if col < 0:
                col = 0

            if (row, col) in clustered_ports:
                clustered_ports[(row, col)].append(port)
            else:
                clustered_ports[(row, col)] = [port]
        
        # NOTE: in pb.txt, netlist input count exceed certain threshold will be ommitted
        macro_adj = [0] * (len(module_indices) + len(clustered_ports)) * (len(module_indices) + len(clustered_ports))
        cell_location = [0] * len(clustered_ports)

        # instantiate macros
        for row_idx, module_idx in enumerate(sorted(module_indices)):
            # store temp module
            curr_module = self.modules_w_pins[module_idx]
            # get module name
            curr_module_name = curr_module.get_name()

            for col_idx, h_module_idx in enumerate(sorted(module_indices)):
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

                macro_adj[row_idx * (len(module_indices) + len(clustered_ports)) + col_idx] = entry
                macro_adj[col_idx * (len(module_indices) + len(clustered_ports)) + row_idx] = entry
        
        # instantiate clustered ports
        for row_idx, cluster_cell in enumerate(sorted(clustered_ports, key=lambda tup: tup[1])):
            # print("cluster_cell", cluster_cell)
            # print("port cnt", len(clustered_ports[cluster_cell]))
            # add cell location
            cell_location[row_idx] = cluster_cell[0] * self.grid_col + cluster_cell[1]

            # relocate to after macros
            row_idx += len(module_indices)

            # for each port within a grid cell
            for curr_port in clustered_ports[cluster_cell]:
                # get module name
                curr_port_name = curr_port.get_name()
                # print("curr_port_name", curr_port_name, curr_port.get_pos())
                # assuming ports only connects to macros
                for col_idx, h_module_idx in enumerate(module_indices):
                    # col index
                    entry = 0
                    # store connected module
                    h_module = self.modules_w_pins[h_module_idx]
                    # get connected module name
                    h_module_name = h_module.get_name()

                    # print("other connections", h_module.get_connection(), curr_port_name)
                
                    if curr_port_name in h_module.get_connection():
                        entry += h_module.get_connection()[curr_port_name]

                    if h_module_name in curr_port.get_connection():
                        entry += curr_port.get_connection()[h_module_name]
            
                    macro_adj[row_idx * (len(module_indices) + len(clustered_ports)) + col_idx] += entry
                    macro_adj[col_idx * (len(module_indices) + len(clustered_ports)) + row_idx] += entry
                
        return macro_adj, sorted(cell_location)

    def is_node_fixed(self, node_idx: int):
        mod = None

        try:
            mod = self.modules_w_pins[node_idx]
            assert mod.get_type() in ['MACRO', 'macro', 'STDCELL', 'PORT']
        except AssertionError:
            print("[ERROR NODE FIXED] Found {}. Only 'MACRO', 'macro', 'STDCELL'".format(mod.get_type())
                    +"'PORT' are considered to be fixable nodes")
            exit(1)
        except Exception:
            print("[ERROR NODE FIXED] Could not find module by node index")
            exit(1)

        return mod.get_fix_flag()

    def optimize_stdcells(self):
        pass

    def update_node_coords(self, node_idx, x_pos, y_pos):
        """
        Update Node location if node is 'MACRO', 'macro', 'STDCELL', 'PORT'
        """
        mod = None

        try:
            mod = self.modules_w_pins[node_idx]
            assert mod.get_type() in ['MACRO', 'macro', 'STDCELL', 'PORT']
        except AssertionError:
            print("[ERROR NODE LOCATION] Found {}. Only 'MACRO', 'macro', 'STDCELL'".format(mod.get_type())
                    +"'PORT' are considered to be placable nodes")
            exit(1)
        except Exception:
            print("[ERROR NODE LOCATION] Could not find module by node index")
            exit(1)
        
        mod.set_pos(x_pos, y_pos)

    def update_macro_orientation(self, node_idx, orientation):
        """ 
        Update macro orientation if node is 'MACRO', 'macro'
        """
        mod = None

        try:
            mod = self.modules_w_pins[node_idx]
            assert mod.get_type() in ['MACRO', 'macro']
        except AssertionError:
            print("[ERROR MACRO ORIENTATION] Found {}. Only 'MACRO', 'macro'".format(mod.get_type())
                    +" are considered to be ORIENTED")
            exit(1)
        except Exception:
            print("[ERROR MACRO ORIENTATION] Could not find module by node index")
            exit(1)
        
        mod.set_orientation(orientation)

    def update_port_sides(self):
        """
        Define Port "Side" by its location on canvas
        """
        pass

    def snap_ports_to_edges(self):
        pass

    def get_node_location(self, node_idx):
        """ 
        Return Node location if node is 'MACRO', 'macro', 'STDCELL', 'PORT'
        """
        mod = None

        try:
            mod = self.modules_w_pins[node_idx]
            assert mod.get_type() in ['MACRO', 'macro', 'STDCELL', 'PORT']
        except AssertionError:
            print("[ERROR NODE LOCATION] Found {}. Only 'MACRO', 'macro', 'STDCELL'".format(mod.get_type())
                    +"'PORT' are considered to be placable nodes")
            exit(1)
        except Exception:
            print("[ERROR NODE PLACED] Could not find module by node index")
            exit(1)
        
        return mod.get_pos()
                       
    def get_grid_cell_of_node(self, node_idx):
        """ if grid_cell at grid crossing, break-tie to upper right
        """
        mod = None
        
        try:
            mod = self.modules_w_pins[node_idx]
            assert mod.get_type() in ['MACRO', 'macro']
        except AssertionError:
            print("[ERROR NODE LOCATION] Found {}. Only 'MACRO', 'macro'".format(mod.get_type())
                    +" can be called")
            exit(1)
        except Exception:
            print("[ERROR NODE LOCATION] Could not find module by node index")
            exit(1)
        
        row, col = self.__get_grid_cell_location(*mod.get_pos())

        return row * self.grid_col + col

    def get_macro_orientation(self, node_idx):
        mod = None

        try:
            mod = self.modules_w_pins[node_idx]
            assert mod.get_type() in ['MACRO', 'macro']
        except AssertionError:
            print("[ERROR MACRO ORIENTATION] Found {}. Only 'MACRO', 'macro'".format(mod.get_type())
                    +" are considered to be ORIENTED")
            exit(1)
        except Exception:
            print("[ERROR MACRO ORIENTATION] Could not find module by node index")
            exit(1)
        
        return mod.get_orientation()

    def unfix_node_coord(self, node_idx):
        """
        Unfix a module
        """
        mod = None

        try:
            mod = self.modules_w_pins[node_idx]
            assert mod.get_type() in ['MACRO', 'macro', 'STDCELL', 'PORT']
        except AssertionError:
            print("[ERROR UNFIX NODE] Found {}. Only 'MACRO', 'macro', 'STDCELL'".format(mod.get_type())
                    +"'PORT' are considered to be fixable nodes")
            exit(1)
        except Exception:
            print("[ERROR UNFIX NODE] Could not find module by node index")
            exit(1)

        self.modules_w_pins[node_idx].set_fix_flag(False)
    
    def fix_node_coord(self, node_idx):
        """
        Fix a module
        """
        mod = None
        
        try:
            mod = self.modules_w_pins[node_idx]
            assert mod.get_type() in ['MACRO', 'macro', 'STDCELL', 'PORT']
        except AssertionError:
            print("[ERROR FIX NODE] Found {}. Only 'MACRO', 'macro', 'STDCELL'".format(mod.get_type())
                    +"'PORT' are considered to be fixable nodes")
            exit(1)
        except Exception:
            print("[ERROR FIX NODE] Could not find module by node index")
            exit(1)

        self.modules_w_pins[node_idx].set_fix_flag(True)

    def unplace_all_nodes(self):
        pass

    def place_node(self, node_idx, grid_cell_idx):
        mod = None

        try:
            mod = self.modules_w_pins[node_idx]
        except AssertionError:
            pass
        except Exception:
            pass
        pass

    def can_place_node(self, node_idx, grid_cell_idx):
        return self.get_node_mask(node_idx=node_idx)[grid_cell_idx]

    def unplace_node(self, node_idx):
        # update node_mask
        pass

    def is_node_placed(self, node_idx):
        mod = None

        try:
            mod = self.modules_w_pins[node_idx]
            assert mod.get_type() in ['MACRO', 'macro', 'STDCELL', 'PORT']
        except AssertionError:
            print("[ERROR NODE PLACED] Found {}. Only 'MACRO', 'STDCELL',".format(mod.get_type())
                    +"'PORT' are considered to be placable nodes")
            exit(1)
        except Exception:
            print("[ERROR NODE PLACED] Could not find module by node index")
            exit(1)

        mod = self.modules_w_pins[node_idx]
        return mod.get_placed_flag()

    def disconnect_nets(self):
        pass

    def get_source_filename(self):
        """return netlist path
        """
        return self.netlist_file

    def get_blockages(self):
        return self.blockages

    def create_blockage(self, minx, miny, maxx, maxy, blockage_rate):
        self.blockages.append([minx, miny, maxx, maxy, blockage_rate])

    def get_ref_node_id(self, node_idx=-1):
        """ref_node_id is used for macro_pins. Refers to the macro it belongs to.
        """
        if node_idx != -1:
            if node_idx in self.soft_macro_pin_indices:
                pin = self.modules_w_pins[node_idx]
                return self.mod_name_to_indices[pin.get_macro_name()]
            elif node_idx in self.hard_macro_pin_indices:
                pin = self.modules_w_pins[node_idx]
                return self.mod_name_to_indices[pin.get_macro_name()]
        return -1

    def save_placement(self, filename, info):
        """
            When writing out info line-by-line, add a "#" at front
        """
        with open(filename, 'w+') as f:
            for line in info.split('\n'):
                f.write("# " + line + '\n')

            # if first, no \newline
            HEADER = True

            for mod_idx in sorted(self.hard_macro_indices + self.soft_macro_indices + self.port_indices):
                # [node_index] [x] [y] [orientation] [fixed]
                mod = self.modules_w_pins[mod_idx]

                if HEADER:
                    f.write("{} {:g} {:g} {} {}".format(mod_idx,
                        *mod.get_pos(),
                        mod.get_orientation() if mod.get_orientation() else "-",
                        "1" if mod.get_fix_flag() else "0"))
                    HEADER = False
                else:
                    f.write("\n{} {:g} {:g} {} {}".format(mod_idx,
                            *mod.get_pos(),
                            mod.get_orientation() if mod.get_orientation() else "-",
                            "1" if mod.get_fix_flag() else "0"))

    def display_canvas( self,
                        annotate=True, 
                        amplify=False):
        #define Matplotlib figure and axis
        fig, ax = plt.subplots(figsize=(8,8), dpi=50)

        if amplify:
            PORT_SIZE = 4
            FONT_SIZE = 10
            PIN_SIZE = 4
        else:
            PORT_SIZE = 2
            FONT_SIZE = 5
            PIN_SIZE = 2

        # Plt config
        ax.margins(x=0.05, y=0.05)
        ax.set_aspect('equal', adjustable='box')

        # Construct grid
        x, y = np.meshgrid(np.linspace(0, self.width, self.grid_col + 1),\
             np.linspace(0, self.height, self.grid_row + 1))

        ax.plot(x, y, c='b', alpha=0.1) # use plot, not scatter
        ax.plot(np.transpose(x), np.transpose(y), c='b', alpha=0.2) # add this here

        # Construct module blocks
        for mod in self.modules_w_pins:
            if mod.get_type() == 'PORT':
                plt.plot(*mod.get_pos(),'ro', markersize=PORT_SIZE)
            elif mod.get_type() == 'MACRO':
                ax.add_patch(Rectangle((mod.get_pos()[0] - mod.get_width()/2, mod.get_pos()[1] - mod.get_height()/2),\
                    mod.get_width(), mod.get_height(),\
                    alpha=0.5, zorder=1000, facecolor='b', edgecolor='darkblue'))
                if annotate:
                    ax.annotate(mod.get_name(), mod.get_pos(), color='r', weight='bold', fontsize=FONT_SIZE, ha='center', va='center')
            elif mod.get_type() == 'MACRO_PIN':
                plt.plot(*mod.get_pos(),'bo', markersize=PIN_SIZE)
            elif mod.get_type() == 'macro':
                ax.add_patch(Rectangle((mod.get_pos()[0] - mod.get_width()/2, mod.get_pos()[1] - mod.get_height()/2),\
                    mod.get_width(), mod.get_height(),\
                    alpha=0.5, zorder=1000, facecolor='y'))
                if annotate:
                    ax.annotate(mod.get_name(), mod.get_pos(), wrap=True,color='r', weight='bold', fontsize=FONT_SIZE, ha='center', va='center')

        plt.show()
        plt.close('all')

    # Board Entity Definition
    class Port:
        def __init__(self, name, x = 0.0, y = 0.0, side = "BOTTOM"):
            self.name = name
            self.x = float(x)
            self.y = float(y)
            self.side = side # "BOTTOM", "TOP", "LEFT", "RIGHT"
            self.sink = {} # standard cells, macro pins, ports driven by this cell
            self.connection = {} # [module_name] => edge degree
            self.fix_flag = True
            self.placement = 0 # needs to be updated
            self.orientation = None
            self.ifPlaced = True

        def get_name(self):
            return self.name
        
        def get_orientation(self):
            return self.orientation

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
        
        def set_fix_flag(self, fix_flag):
            self.fix_flag = fix_flag
        
        def get_fix_flag(self):
            return self.fix_flag

        def set_placed_flag(self, ifPlaced):
            self.ifPlaced = ifPlaced
        
        def get_placed_flag(self):
            return self.ifPlaced

    class SoftMacro:
        def __init__(self, name, width, height, x = 0.0, y = 0.0):
            self.name = name
            self.width = float(width)
            self.height = float(height)
            self.x = float(x)
            self.y = float(y)
            self.connection = {} # [module_name] => edge degree
            self.orientation = None
            self.fix_flag = False
            self.ifPlaced = True
            self.location = 0 # needs to be updated

        def get_name(self):
            return self.name

        def add_connection(self, module_name, weight):
            # NOTE: assume PORT names does not contain slash
            ifPORT = False
            module_name_splited = module_name.rsplit('/', 1)
            if len(module_name_splited) == 1:
                ifPORT = not(ifPORT)

            if ifPORT:
                # adding PORT
                self.connection[module_name] = 1 * weight
            else:
                # adding soft/hard macros
                if module_name_splited[0] in self.connection.keys():
                    self.connection[module_name_splited[0]] += 1 * weight
                else:
                    self.connection[module_name_splited[0]] = 1 * weight

        def add_connections(self, module_names, weight):
            # NOTE: assume PORT names does not contain slash
            # consider weight on soft macro pins
            for module_name in module_names:
                self.add_connection(module_name, weight)

        def set_pos(self, x, y):
            self.x = x
            self.y = y

        def get_pos(self):
            return self.x, self.y

        def get_type(self):
            return "MACRO"

        def get_connection(self):
            return self.connection
        
        def set_orientation(self, orientation):
            self.orientation = orientation
        
        def get_orientation(self):
            return self.orientation

        def get_area(self):
            return self.width * self.height

        def get_height(self):
            return self.height

        def get_width(self):
            return self.width
        
        def set_location(self, grid_cell_idx):
            self.location = grid_cell_idx
        
        def get_location(self):
            return self.location
        
        def set_fix_flag(self, fix_flag):
            self.fix_flag = fix_flag
        
        def get_fix_flag(self):
            return self.fix_flag

        def set_placed_flag(self, ifPlaced):
            self.ifPlaced = ifPlaced
        
        def get_placed_flag(self):
            return self.ifPlaced

    class SoftMacroPin:
        def __init__(self, name, ref_id,
                    x = 0.0, y = 0.0,
                    macro_name = "", weight = 1.0):
            self.name = name
            self.ref_id = ref_id
            self.x = float(x)
            self.y = float(y)
            self.x_offset = 0.0 # not used
            self.y_offset = 0.0 # not used
            self.macro_name = macro_name
            self.weight = weight
            self.sink = {}

        def set_weight(self, weight):
            self.weight = weight

        def set_ref_id(self, ref_id):
            self.ref_id = ref_id

        def get_ref_id(self):
            return self.ref_id

        def get_weight(self):
            return self.weight

        def get_name(self):
            return self.name

        def get_macro_name(self):
            return self.macro_name

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
        
        def get_weight(self):
            return self.weight

        def get_type(self):
            return "MACRO_PIN"

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
            self.fix_flag = False
            self.ifPlaced = True
            self.location = 0 # needs to be updated

        def get_name(self):
            return self.name

        def add_connection(self, module_name, weight):
            # NOTE: assume PORT names does not contain slash
            ifPORT = False
            module_name_splited = module_name.rsplit('/', 1)
            if len(module_name_splited) == 1:
                ifPORT = not(ifPORT)

            if ifPORT:
                # adding PORT
                self.connection[module_name] = 1 * weight
            else:
                # adding soft/hard macros
                if module_name_splited[0] in self.connection.keys():
                    self.connection[module_name_splited[0]] += 1 * weight
                else:
                    self.connection[module_name_splited[0]] = 1 * weight

        def add_connections(self, module_names, weight):
            # NOTE: assume PORT names does not contain slash
            # consider weight on soft macro pins
            for module_name in module_names:
                self.add_connection(module_name, weight)

        def get_connection(self):
            return self.connection

        def set_pos(self, x, y):
            self.x = x
            self.y = y

        def get_pos(self):
            return self.x, self.y

        def set_orientation(self, orientation):
            self.orientation = orientation
        
        def get_orientation(self):
            return self.orientation

        def get_type(self):
            return "MACRO"

        def get_area(self):
            return self.width * self.height

        def get_height(self):
            return self.height

        def get_width(self):
            return self.width
        
        def set_location(self, grid_cell_idx):
            self.location = grid_cell_idx
        
        def get_location(self):
            return self.location
        
        def set_fix_flag(self, fix_flag):
            self.fix_flag = fix_flag
        
        def get_fix_flag(self):
            return self.fix_flag
        
        def set_placed_flag(self, ifPlaced):
            self.ifPlaced = ifPlaced
        
        def get_placed_flag(self):
            return self.ifPlaced

    class HardMacroPin:
        def __init__(self, name, ref_id,
                        x = 0.0, y = 0.0,
                        x_offset = 0.0, y_offset = 0.0,
                        macro_name = "", weight = 1.0):
            self.name = name
            self.ref_id = ref_id
            self.x = float(x)
            self.y = float(y)
            self.x_offset = float(x_offset)
            self.y_offset = float(y_offset)
            self.macro_name = macro_name
            self.weight = weight
            self.sink = {}
            self.ifPlaced = True

        def set_ref_id(self, ref_id):
            self.ref_id = ref_id

        def get_ref_id(self):
            return self.ref_id

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

        def get_macro_name(self):
            return self.macro_name

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

    # TODO finish this
    # class StandardCell:
    #     def __init__(   self, name,
    #                     x = 0.0, y = 0.0, weight = 1.0):
    #         self.name = name
    #         self.x = float(x)
    #         self.y = float(y)
    #         self.x_offset = 0.0 # not used
    #         self.y_offset = 0.0 # not used
    #         self.macro_name = macro_name
    #         self.weight = weight
    #         self.sink = {}

def main():
    test_netlist_dir = './Plc_client/test/'+\
        'ariane133'
    netlist_file = os.path.join(test_netlist_dir,
                                'netlist.pb.txt')
    plc = PlacementCost(netlist_file)

    print(plc.get_block_name())
    print("Area: ", plc.get_area())
    print("Wirelength: ", plc.get_wirelength())
    print("# HARD_MACROs     :         %d"%(plc.get_hard_macros_count()))
    print("# HARD_MACRO_PINs :         %d"%(plc.get_hard_macro_pins_count()))
    print("# MACROs          :         %d"%(plc.get_hard_macros_count() + plc.get_soft_macros_count()))
    print("# MACRO_PINs      :         %d"%(plc.get_hard_macro_pins_count() + plc.get_soft_macro_pins_count()))
    print("# PORTs           :         %d"%(plc.get_ports_count()))
    print("# SOFT_MACROs     :         %d"%(plc.get_soft_macros_count()))
    print("# SOFT_MACRO_PINs :         %d"%(plc.get_soft_macro_pins_count()))
    print("# STDCELLs        :         0")

if __name__ == '__main__':
    main()