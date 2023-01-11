# distutils: language = c++
"""Open-Sourced PlacementCost client class."""
from ast import Assert
import os, io
import re
import math
from typing import Text, Tuple, overload
from absl import logging
from collections import namedtuple
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
import traceback, sys
import random
import textwrap
import numpy as np
from circuit_training.grouping import meta_netlist_data_structure as mnds
from circuit_training.grouping import meta_netlist_convertor
from circuit_training.grouping import meta_netlist_util
# Compile: cd Plc_client_v2 && python3 setup.py build_ext --inplace && cd ..
# Cython
from cython cimport view
from libcpp cimport bool
from libcpp.vector cimport vector
from libc.string cimport memset
cimport numpy as cnp
cnp.import_array()   # needed to initialize numpy-API


"""plc_client_os docstrings.

Open-sourced effort for plc_client and Google's API, plc_wrapper_main. This module
is used to initialize a PlacementCost object that computes the meta-information and
proxy cost function for RL agent's reward signal at the end of each placement.

Example:
    For testing, please refer to plc_client_os_test.py for more information.
    python3 setup.py build_ext --inplace

"""

# Block = namedtuple('Block', 'x_max y_max x_min y_min')

cdef class PlacementCost:
    # str as general purpose PyObject *
    cdef:
        public str netlist_file
        public float macro_macro_x_spacing
        public float macro_macro_y_spacing

    # meta information
    cdef:
        public meta_netlist
        str init_plc
        str project_name
        str block_name
        float width
        float height
        int grid_col
        int grid_row
        float hroutes_per_micron
        float vroutes_per_micron
        float smooth_range
        float overlap_thres
        float hrouting_alloc
        float vrouting_alloc
        float macro_horizontal_routing_allocation
        float macro_vertical_routing_allocation
        bool canvas_boundary_check
        float grid_width
        float grid_height
        dict node_fix
        dict node_placed

    # store module/component count
    cdef:
        int port_cnt
        int hard_macro_cnt
        int hard_macro_pin_cnt
        int soft_macro_cnt
        int soft_macro_pin_cnt
        int module_cnt

    # indices storage
    cdef:
        vector[int] port_indices
        vector[int] hard_macro_indices
        vector[int] hard_macro_pin_indices
        vector[int] soft_macro_indices
        vector[int] soft_macro_pin_indices
        vector[int] macro_indices

    # modules look-up table
    cdef:
        dict mod_name_to_indices
        dict macro_id_to_indices
        dict port_id_to_indices
        object modules_w_pins
        dict hard_macros_to_inpins
        dict soft_macros_to_inpins

    # store nets information
    cdef:
        int net_cnt
        dict nets

    # update flags
    cdef:
        bool FLAG_UPDATE_WIRELENGTH
        bool FLAG_UPDATE_DENSITY
        bool FLAG_UPDATE_CONGESTION
        bool FLAG_UPDATE_MACRO_ADJ
        bool FLAG_UPDATE_MACRO_AND_CLUSTERED_PORT_ADJ
        bool FLAG_UPDATE_NODE_MASK

    # density
    cdef:
        object grid_cells
        object grid_occupied

    # congestion
    cdef:
        object V_routing_cong
        object H_routing_cong
        object V_macro_routing_cong
        object H_macro_routing_cong
        float grid_v_routes
        float grid_h_routes
    
    # fd placer
    cdef:
        dict soft_macro_disp

    # miscellaneous
    cdef:
        list blockages
        list placed_macro
        bool use_incremental_cost
        object node_mask

    def __init__(self,
                str netlist_file,
                float macro_macro_x_spacing = 0.0,
                float macro_macro_y_spacing = 0.0):
        """
        Creates a PlacementCost object.
        """
        print("Creates a PlacementCost object")
        # str as general purpose PyObject *
        # Check netlist existance
        self.netlist_file = netlist_file
        self.macro_macro_x_spacing = macro_macro_x_spacing
        self.macro_macro_y_spacing = macro_macro_y_spacing

        # use google open-sourced parser
        self.meta_netlist = meta_netlist_convertor.read_netlist(self.netlist_file)
        meta_netlist_util.set_canvas_width_height(self.meta_netlist, 10, 10)

        # store nets information
        self.net_cnt = 0

        # [Experimental] Net Data Structure
        # nets[driver] => [list of sinks]
        self.nets = {}

        # modules to index look-up table
        self.mod_name_to_indices = {}
        
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

        # macro to pins look-up table: [MACRO_NAME] => [PIN_NAME]
        self.hard_macros_to_inpins = {}
        self.soft_macros_to_inpins = {}

        # Placed macro
        self.placed_macro = []

        # not used
        self.use_incremental_cost = False
        # blockage
        self.blockages = []

        # default canvas width/height based on cell area
        self.width = math.sqrt(self.get_area()/0.6)
        self.height = math.sqrt(self.get_area()/0.6)

        # default gridding
        self.grid_col = 10
        self.grid_row = 10
        self.grid_width = float(self.width/self.grid_col)
        self.grid_height = float(self.height/self.grid_row)

        # initialize congestion map
        self.V_routing_cong = np.zeros(shape=(self.grid_col * self.grid_row))
        self.H_routing_cong = np.zeros(shape=(self.grid_col * self.grid_row))
        self.V_macro_routing_cong = np.zeros(shape=(self.grid_col * self.grid_row))
        self.H_macro_routing_cong = np.zeros(shape=(self.grid_col * self.grid_row))
        # initial grid mask, flatten before output, not used
        self.node_mask = np.ones(shape=(self.grid_row, self.grid_col))
        
        # store module/component count
        self.port_cnt = len(self.port_indices)
        self.hard_macro_cnt = len(self.hard_macro_indices)
        self.hard_macro_pin_cnt = len(self.hard_macro_pin_indices)
        self.soft_macro_cnt = len(self.soft_macro_indices)
        self.soft_macro_pin_cnt = len(self.soft_macro_pin_indices)
        self.module_cnt = self.hard_macro_cnt + self.soft_macro_cnt + self.port_cnt

        # Update flags
        self.FLAG_UPDATE_WIRELENGTH = True
        self.FLAG_UPDATE_DENSITY = True
        self.FLAG_UPDATE_CONGESTION = True
        self.FLAG_UPDATE_MACRO_ADJ = True
        self.FLAG_UPDATE_MACRO_AND_CLUSTERED_PORT_ADJ = True
        

        # FD: store x/y displacement for all soft macro disp
        soft_macro_disp = {}
        self.node_fix = {}
        self.node_placed = {}
        self.macro_id_to_indices = {}
        macro_idx = 0
        port_idx = 0
        # read netlist list into data structures
        for mod in self.meta_netlist.node:
            # [MOD.NAME] => [MOD.ID]
            self.mod_name_to_indices[mod.name] = mod.id
            if mod.type == mnds.Type.STDCELL:
                # standard cell, not used
                self.std_cell_cnt += 1
            elif mod.type == mnds.Type.MACRO:
                # unfix macro
                self.node_fix[mod.id] = False
                # macro placed
                self.node_placed[mod.id] = True
                # [mod.id] ==> index
                self.macro_id_to_indices[mod.id] = macro_idx
                macro_idx += 1
                if mod.soft_macro:
                    # soft macro
                    self.soft_macro_cnt += 1
                    self.soft_macro_indices.push_back(mod.id)
                else:
                    # hard macro
                    self.hard_macro_cnt += 1
                    self.hard_macro_indices.push_back(mod.id)
                self.macro_indices.push_back(mod.id)
            elif mod.type == mnds.Type.PORT:
                # fix ports
                self.node_fix[mod.id] = True
                # port placed
                self.node_placed[mod.id] = True
                # port
                self.port_cnt += 1
                self.port_indices.push_back(mod.id)
                # self.port_id_to_indices[mod.id] = port_idx
                port_idx += 1
            elif mod.type == mnds.Type.MACRO_PIN:
                ref_id = mod.ref_node_id
                if self.meta_netlist.node[ref_id].soft_macro:
                    # soft macro pin
                    self.soft_macro_pin_cnt += 1
                    self.soft_macro_pin_indices.push_back(mod.id)
                else:
                    # hard macro pin
                    self.hard_macro_pin_cnt += 1
                    self.hard_macro_pin_indices.push_back(mod.id)
            
            # read net information
            if (mod.type == mnds.Type.MACRO_PIN or mod.type == mnds.Type.PORT) and len(mod.output_indices) > 0:
                self.nets[mod.id] = mod.output_indices.copy()
                self.net_cnt += mod.weight

    def get_netlist_obj(self):
        return self.meta_netlist

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
        _hard_macro_cnt = 0
        _hard_macro_pin_cnt = 0
        _macro_cnt = 0
        _macro_pin_cnt = 0
        _port_cnt = 0
        _soft_macro_cnt = 0
        _soft_macro_pin_cnt = 0
        _stdcell_cnt = 0

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
            elif all(it in line_item for it in ['Area', 'stdcell', 'macros']):
                # Total core area of modules
                _area = float(line_item[3])
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
                _smoothing_factor = float(line_item[2])
            elif all(it in line_item for it in ['Overlap', 'threshold']):
                # overlap
                _overlap_threshold = float(line_item[2])
            elif all(it in line_item for it in ['HARD', 'MACROs'])\
                and len(line_item) == 3:
                _hard_macro_cnt = int(line_item[2])
            elif all(it in line_item for it in ['HARD', 'MACRO', 'PINs'])\
                and len(line_item) == 4:
                _hard_macro_pin_cnt = int(line_item[3])
            elif all(it in line_item for it in ['PORTs'])\
                and len(line_item) == 2:
                _port_cnt = int(line_item[1])
            elif all(it in line_item for it in ['SOFT', 'MACROs'])\
                and len(line_item) == 3:
                _soft_macro_cnt = int(line_item[2])
            elif all(it in line_item for it in ['SOFT', 'MACRO', 'PINs'])\
                and len(line_item) == 4:
                _soft_macro_pin_cnt = int(line_item[3])
            elif all(it in line_item for it in ['STDCELLs'])\
                and len(line_item) == 2:
                _stdcell_cnt = int(line_item[1])
            elif all(it in line_item for it in ['MACROs'])\
                and len(line_item) == 2:
                _macro_cnt = int(line_item[1])
            elif all(re.match(r'[0-9FNEWS\.\-]+', it) for it in line_item)\
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
                        "hard_macro_cnt":_hard_macro_cnt,
                        "hard_macro_pin_cnt":_hard_macro_pin_cnt,
                        "macro_cnt":_macro_cnt,
                        "macro_pin_cnt":_macro_pin_cnt,
                        "port_cnt":_port_cnt,
                        "soft_macro_cnt":_soft_macro_cnt,
                        "soft_macro_pin_cnt":_soft_macro_pin_cnt,
                        "stdcell_cnt":_stdcell_cnt,
                        "node_plc":_node_plc
                    }

        return info_dict

    def restore_placement(self, plc_pth: str, ifInital=True, ifValidate=False, ifReadComment = False, retrieveFD = False):
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
                assert(self.hard_macro_cnt == info_dict['hard_macro_cnt'])
                assert(self.hard_macro_pin_cnt == info_dict['hard_macro_pin_cnt'])
                assert(self.soft_macro_cnt == info_dict['soft_macro_cnt'])
                assert(self.soft_macro_pin_cnt == info_dict['soft_macro_pin_cnt'])
                assert(self.port_cnt == info_dict['port_cnt'])
            except AssertionError:
                _, _, tb = sys.exc_info()
                traceback.print_tb(tb)
                tb_info = traceback.extract_tb(tb)
                _, line, _, text = tb_info[-1]
                print('[ERROR NETLIST/PLC MISMATCH] at line {} in statement {}'\
                    .format(line, text))
                exit(1)
        
        for mod_idx in info_dict['node_plc'].keys():
            mod_x = mod_y = mod_orient = mod_ifFixed = None
            try:
                mod_x = float(info_dict['node_plc'][mod_idx][0])
                mod_y = float(info_dict['node_plc'][mod_idx][1])
                mod_orient = info_dict['node_plc'][mod_idx][2]
                mod_ifFixed = int(info_dict['node_plc'][mod_idx][3])
                
            except Exception as e:
                print('[ERROR PLC PARSER] %s' % str(e))
            
            # extract mod object
            mod = self.meta_netlist.node[mod_idx]

            # if retrieving FD placement result, then only update soft macros
            if retrieveFD:
                if mod.soft_macro:
                    mod.coord.x = mod_x
                    mod.coord.y = mod_y 
            else:
                mod.coord.x = mod_x
                mod.coord.y = mod_y
            
            if mod_orient and mod_orient != '-':
                if mod_orient == "N":
                    mod.orientation = mnds.Orientation.N
                elif mod_orient == "FN":
                    mod.orientation = mnds.Orientation.FN
                elif mod_orient == "S":
                    mod.orientation = mnds.Orientation.S
                elif mod_orient == "FS":
                    mod.orientation = mnds.Orientation.FS
                elif mod_orient == "E":
                    mod.orientation = mnds.Orientation.E
                elif mod_orient == "FE":
                    mod.orientation = mnds.Orientation.FE
                elif mod_orient == "W":
                    mod.orientation = mnds.Orientation.W
                elif mod_orient == "FW":
                    mod.orientation = mnds.Orientation.FW
            
            if mod_ifFixed == 0:
                self.node_fix[mod_idx] = False
            elif mod_ifFixed == 1:
                self.node_fix[mod_idx] = True
        
        # set meta information
        if ifReadComment:
            print("[INFO] Retrieving Meta information from .plc comments")
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

    cpdef float get_area(self):
        """
        Compute Total Module Area
        """
        return self.meta_netlist.total_area

    cpdef int get_hard_macros_count(self):
        return self.hard_macro_cnt

    cpdef int get_ports_count(self):
        return self.port_cnt

    cpdef int get_soft_macros_count(self):
        return self.soft_macro_cnt

    cpdef int get_hard_macro_pins_count(self):
        return self.hard_macro_pin_cnt

    cpdef int get_soft_macro_pins_count(self):
        return self.soft_macro_pin_cnt

    cpdef __get_pin_position(self, int pin_idx):
        """
        private function for getting pin location
            * PORT = its own position
            * HARD MACRO PIN = ref position + offset position
            * SOFT MACRO PIN = ref position
        """
        try:
            assert (self.meta_netlist.node[pin_idx].type in [mnds.Type.MACRO_PIN, mnds.Type.PORT])
        except Exception:
            print("[ERROR PIN POSITION] Not a MACRO PIN", self.meta_netlist.node[pin_idx].name)
            exit(1)

        cdef:
            float pin_node_x_offset
            float pin_node_y_offset
            float temp_pin_node_x_offset
            float ref_node_x
            float ref_node_y

        # PORT pin pos is itself
        node = self.meta_netlist.node[pin_idx]

        if node.type == mnds.Type.PORT:
            return node.coord.x, node.coord.y

        # Retrieve node that this pin instantiated on
        ref_node_idx = node.ref_node_id

        # if ref_node_idx == -1:  
        #     print("[ERROR PIN POSITION] Parent Node Not Found.")
        #     exit(1)

        # Parent node
        ref_node = self.meta_netlist.node[ref_node_idx]
        ref_node_x = ref_node.coord.x
        ref_node_y = ref_node.coord.y

        # Retrieve current pin node position
        pin_node_x_offset = node.offset.x
        pin_node_y_offset = node.offset.y

        #macro orientation affects offset
        if ref_node.orientation in [mnds.Orientation.N, mnds.Orientation.R0, mnds.Orientation.NORMAL]:
            pass
        elif ref_node.orientation in [mnds.Orientation.FN, mnds.Orientation.MY, mnds.Orientation.FLIP_X]:
            pin_node_x_offset = -1.0 * pin_node_x_offset
        elif ref_node.orientation in [mnds.Orientation.S, mnds.Orientation.R180, mnds.Orientation.FLIP_XY]:
            pin_node_x_offset = -1.0 * pin_node_x_offset
            pin_node_y_offset = -1.0 * pin_node_y_offset
        elif ref_node.orientation in [mnds.Orientation.FS, mnds.Orientation.MX, mnds.Orientation.FLIP_Y]:
            pin_node_y_offset = -1.0 * pin_node_y_offset
        elif ref_node.orientation in [mnds.Orientation.E, mnds.Orientation.R270]:
            temp_pin_node_x_offset = pin_node_x_offset
            pin_node_x_offset = pin_node_y_offset
            pin_node_y_offset = -1.0 * temp_pin_node_x_offset
        elif ref_node.orientation in [mnds.Orientation.FE, mnds.Orientation.MX90, mnds.Orientation.MYR90]:
            temp_pin_node_x_offset = pin_node_x_offset
            pin_node_x_offset = -1.0 * pin_node_y_offset
            pin_node_y_offset = -1.0 * temp_pin_node_x_offset
        elif ref_node.orientation in [mnds.Orientation.W, mnds.Orientation.R90]:
            temp_pin_node_x_offset = pin_node_x_offset
            pin_node_x_offset = -1.0 * pin_node_y_offset
            pin_node_y_offset = temp_pin_node_x_offset
        elif ref_node.orientation in [mnds.Orientation.FW, mnds.Orientation.MY90, mnds.Orientation.MXR90]:
            temp_pin_node_x_offset = pin_node_x_offset
            pin_node_x_offset = pin_node_y_offset
            pin_node_y_offset = temp_pin_node_x_offset

        # Google's Plc client DOES NOT compute (node_position + pin_offset) when reading input
        return (ref_node_x + pin_node_x_offset, ref_node_y + pin_node_y_offset)

    cpdef float get_wirelength(self):
        """
        Proxy HPWL computation w/ [Experimental] net
        """
        total_hpwl = 0.0

        for driver_pin_idx in self.nets.keys():
            x_coord = []
            y_coord = []

            # extract net weight
            weight_fact = self.meta_netlist.node[driver_pin_idx].weight
            x_coord.append(self.__get_pin_position(driver_pin_idx)[0])
            y_coord.append(self.__get_pin_position(driver_pin_idx)[1])

            # iterate through each sink
            for sink_pin_idx in self.nets[driver_pin_idx]:
                x_coord.append(self.__get_pin_position(sink_pin_idx)[0])
                y_coord.append(self.__get_pin_position(sink_pin_idx)[1])
                
            if x_coord:
                total_hpwl += weight_fact * \
                    (abs(max(x_coord) - min(x_coord)) + \
                        abs(max(y_coord) - min(y_coord)))
        return total_hpwl
    
    cpdef float get_cost(self):
        """
        Compute wirelength cost from wirelength
        """
        
        if self.FLAG_UPDATE_WIRELENGTH:
            self.FLAG_UPDATE_WIRELENGTH = False

        # avoid zero division
        if self.net_cnt == 0:
            return self.get_wirelength() / ((self.get_canvas_width_height()[0]\
                + self.get_canvas_width_height()[1]))
        else:
            return self.get_wirelength() / ((self.get_canvas_width_height()[0]\
                + self.get_canvas_width_height()[1]) * self.net_cnt)

    def abu(self, xx, n = 0.1):
        xxs = sorted(xx, reverse = True)
        cnt = math.floor(len(xxs)*n)
        if cnt == 0:
            return max(xxs)
        return sum(xxs[0:cnt])/cnt
    
    cpdef float get_V_congestion_cost(self):
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
    
    cpdef float get_H_congestion_cost(self):
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
    
    cpdef float get_congestion_cost(self):
        """
        Return congestion cost based on routing and macro placement
        """
        if self.FLAG_UPDATE_CONGESTION:
            self.get_routing()
        # print(np.concatenate([self.V_routing_cong, self.H_routing_cong]))
        return self.abu(np.concatenate([self.V_routing_cong, self.H_routing_cong]), 0.05)

    cpdef (int, int) __get_grid_cell_location(self, float x_pos, float y_pos):
        """
        private function: for getting grid cell row/col ranging from 0...N
        """
        cdef:
            int row
            int col
        
        self.grid_width = float(self.width/self.grid_col)
        self.grid_height = float(self.height/self.grid_row)
        row = math.floor(y_pos / self.grid_height)
        col = math.floor(x_pos / self.grid_width)
        return row, col

    cpdef int get_grid_cell_of_node(self, float x_pos, float y_pos):
        """
        Returns the node's current location in terms of grid cell index
        """
        cdef:
            int row
            int col
        
        row, col = self.__get_grid_cell_location(x_pos=x_pos, y_pos=y_pos)
        return row * self.grid_col + col

    cpdef float __overlap_area(self, object bbox_i, object bbox_j, bool return_pos=False):
        """
        private function: for computing block overlapping
        """
        x_min_max = min(bbox_i.maxx, bbox_j.maxx)
        x_max_min = max(bbox_i.minx, bbox_j.minx)
        y_min_max = min(bbox_i.maxy, bbox_j.maxy)
        y_max_min = max(bbox_i.miny, bbox_j.miny)

        x_diff = x_min_max - x_max_min
        y_diff = y_min_max - y_max_min
        if x_diff >= 0 and y_diff >= 0:
            if return_pos:
                return x_diff * y_diff, (x_min_max, y_min_max), (x_max_min, y_max_min)
            else:
                return x_diff * y_diff
        return 0
    
    cpdef __overlap_dist(self, bbox_i, bbox_j):
        """
        private function: for computing block overlapping
        """
        x_diff = min(bbox_i.maxx, bbox_j.maxx) - max(bbox_i.minx, bbox_j.minx)
        y_diff = min(bbox_i.maxy, bbox_j.maxy) - max(bbox_i.miny, bbox_j.miny)
        if x_diff > 0 and y_diff > 0:
            return x_diff, y_diff
        return 0, 0

    cpdef void __add_module_to_grid_cells(self, float mod_x, float mod_y, float mod_w, float mod_h):
        """
        private function: for add module to density grid cells
        """
        # Two corners
        ur_x = mod_x + (mod_w/2)
        ur_y = mod_y + (mod_h/2)
        bl_x = mod_x - (mod_w/2)
        bl_y = mod_y - (mod_h/2)

        # construct block based on current module
        module_block =  mnds.BoundingBox(   minx=mod_x - (mod_w/2),
                                            maxx=mod_x + (mod_w/2), 
                                            miny=mod_y - (mod_h/2), 
                                            maxy=mod_y + (mod_h/2))

        # Only need two corners of a grid cell
        ur_row, ur_col = self.__get_grid_cell_location(ur_x, ur_y)
        bl_row, bl_col = self.__get_grid_cell_location(bl_x, bl_y)

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
                grid_cell_block = mnds.BoundingBox( minx=c_i * self.grid_width,
                                                    maxx=(c_i + 1) * self.grid_width, 
                                                    miny=r_i * self.grid_height, 
                                                    maxy=(r_i + 1) * self.grid_height)

                self.grid_occupied[self.grid_col * r_i + c_i] += \
                    self.__overlap_area(grid_cell_block, module_block)

    cpdef get_grid_cells_density(self):
        """
        compute density for all grid cells
        """
        # by default grid row/col is 10/10
        self.grid_width = float(self.width/self.grid_col)
        self.grid_height = float(self.height/self.grid_row)

        grid_area = self.grid_width * self.grid_height
        self.grid_occupied = [0] * (self.grid_col * self.grid_row)
        self.grid_cells = [0] * (self.grid_col * self.grid_row)


        for node_idx in self.macro_indices:
            # extract module information
            node = self.meta_netlist.node[node_idx]

            # skipping unplaced module
            # if not module.get_placed_flag():
            #     continue

            node_h = node.dimension.height
            node_w = node.dimension.width
            node_x = node.coord.x
            node_y = node.coord.y

            self.__add_module_to_grid_cells(
                                            mod_x=node_x,
                                            mod_y=node_y,
                                            mod_h=node_h,
                                            mod_w=node_w
                                            )

        for i, gcell in enumerate(self.grid_occupied):
            self.grid_cells[i] = gcell / grid_area

        return self.grid_cells

    cpdef float get_density_cost(self):
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

    cpdef bool set_canvas_size(self, float width, float height):
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

    cpdef get_canvas_width_height(self):
        """
        Return canvas size
        """
        return self.width, self.height

    cpdef bool set_placement_grid(self, grid_col:int, grid_row:int):
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

        self.V_routing_cong = np.zeros(shape=(self.grid_col * self.grid_row))
        self.H_routing_cong = np.zeros(shape=(self.grid_col * self.grid_row))
        self.V_macro_routing_cong = np.zeros(shape=(self.grid_col * self.grid_row))
        self.H_macro_routing_cong = np.zeros(shape=(self.grid_col * self.grid_row))

        self.grid_width = float(self.width/self.grid_col)
        self.grid_height = float(self.height/self.grid_row)
        return True

    cpdef get_grid_num_columns_rows(self):
        """
        Return grid col/row
        """
        return self.grid_col, self.grid_row

    cpdef list get_macro_indices(self):
        """
        Return all macro indices
        """
        return self.macro_indices

    cpdef void set_project_name(self, str project_name):
        """
        Set Project name
        """
        self.project_name = project_name

    cpdef str get_project_name(self):
        """
        Return Project name
        """
        return self.project_name
    
    cpdef void set_block_name(self, str block_name):
        """
        Return Block name
        """
        self.block_name = block_name

    cpdef str get_block_name(self):
        """
        Return Block name
        """
        return self.block_name

    cpdef void set_routes_per_micron(self, float hroutes_per_micron, 
                                        float vroutes_per_micron):
        """
        Set Routes per Micron
        """
        print("#[ROUTES PER MICRON] Hor: %.2f, Ver: %.2f" % (hroutes_per_micron,
                                                        vroutes_per_micron))
        # Flag updates
        self.FLAG_UPDATE_CONGESTION = True

        self.hroutes_per_micron = hroutes_per_micron
        self.vroutes_per_micron = vroutes_per_micron

    cpdef get_routes_per_micron(self):
        """
        Return Routes per Micron
        """
        return self.hroutes_per_micron, self.vroutes_per_micron

    cpdef void set_congestion_smooth_range(self, float smooth_range):
        """
        Set congestion smooth range
        """
        print("#[CONGESTION SMOOTH RANGE] Smooth Range: %d" % (smooth_range))
        # Flag updates
        self.FLAG_UPDATE_CONGESTION = True

        self.smooth_range = math.floor(smooth_range)

    cpdef float get_congestion_smooth_range(self):
        """
        Return congestion smooth range
        """
        return self.smooth_range

    cpdef void set_overlap_threshold(self, float overlap_thres):
        """
        Set Overlap Threshold
        """
        print("#[OVERLAP THRESHOLD] Threshold: %.4f" % (overlap_thres))
        self.overlap_thres = overlap_thres

    cpdef float get_overlap_threshold(self):
        """
        Return Overlap Threshold
        """
        return self.overlap_thres

    cpdef void set_canvas_boundary_check(self, bool ifCheck):
        """
        boundary_check: Do a boundary check during node placement.
        """
        self.canvas_boundary_check = ifCheck

    cpdef bool get_canvas_boundary_check(self):
        """
        return canvas_boundary_check
        """
        return self.canvas_boundary_check

    cpdef void set_macro_routing_allocation(self, 
                                            float hrouting_alloc, 
                                            float vrouting_alloc):
        """
        Set Vertical/Horizontal Macro Allocation
        """
        # Flag updates
        self.FLAG_UPDATE_CONGESTION = True

        self.hrouting_alloc = hrouting_alloc
        self.vrouting_alloc = vrouting_alloc

    cpdef get_macro_routing_allocation(self):
        """
        Return Vertical/Horizontal Macro Allocation
        """
        return self.hrouting_alloc, self.vrouting_alloc

    def __two_pin_net_routing(self, source_gcell, node_gcells, weight):
        """
        private function: Routing between 2-pin nets
        """
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

    def __l_routing(self, node_gcells, weight):
        """
        private function: L_shape routing in 3-pin nets
        """
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


    def __t_routing(self, node_gcells, weight):
        """
        private function: T_shape routing in 3-pin nets
        """
        node_gcells.sort()
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

    def __three_pin_net_routing(self, node_gcells, weight):
        """
        private_function: Routing Scheme for 3-pin nets
        """
        temp_gcell = list(node_gcells)
        ## Sorted based on X
        temp_gcell.sort(key = lambda x: (x[1], x[0]))
        y1, x1 = temp_gcell[0]
        y2, x2 = temp_gcell[1]
        y3, x3 = temp_gcell[2]

        if x1 < x2 and x2 < x3 and min(y1, y3) < y2 and max(y1, y3) > y2:
            self.__l_routing(temp_gcell, weight)
        elif x2 == x3 and x1 < x2 and y1 < min(y2, y3):
            for col_idx in range(x1,x2,1):
                row = y1
                col = col_idx
                self.H_routing_cong[row * self.grid_col + col] += weight
            
            for row_idx in range(y1, max(y2,y3)):
                col = x2
                row = row_idx
                self.V_routing_cong[row * self.grid_col + col] += weight
        elif y2 == y3:
            for col in range(x1, x2):
                row = y1
                self.H_routing_cong[row * self.grid_col + col] += weight
            
            for col in range(x2, x3):
                row = y2
                self.H_routing_cong[row * self.grid_col + col] += weight
            
            for row in range(min(y2, y1), max(y2, y1)):
                col = x2
                self.V_routing_cong[row * self.grid_col + col] += weight
        else: 
            self.__t_routing(temp_gcell, weight)

    cpdef void __macro_route_over_grid_cell(self, float mod_x, float mod_y, float mod_w, float mod_h):
        """
        private function for add module to grid cells
        """
        # Two corners
        ur_x = mod_x + (mod_w/2)
        ur_y = mod_y + (mod_h/2)
        bl_x = mod_x - (mod_w/2)
        bl_y = mod_y - (mod_h/2)

        # construct block based on current module
        module_block = mnds.BoundingBox(    minx=mod_x - (mod_w/2),
                                            maxx=mod_x + (mod_w/2), 
                                            miny=mod_y - (mod_h/2), 
                                            maxy=mod_y + (mod_h/2))

        # Only need two corners of a grid cell
        ur_row, ur_col = self.__get_grid_cell_location(ur_x, ur_y)
        bl_row, bl_col = self.__get_grid_cell_location(bl_x, bl_y)

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
                grid_cell_block = mnds.BoundingBox(
                                        maxx= (c_i + 1) * self.grid_width,
                                        maxy= (r_i + 1) * self.grid_height,
                                        minx= c_i * self.grid_width,
                                        miny= r_i * self.grid_height
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
                    grid_cell_block = mnds.BoundingBox(
                                        maxx= (c_i + 1) * self.grid_width,
                                        maxy= (r_i + 1) * self.grid_height,
                                        minx= c_i * self.grid_width,
                                        miny= r_i * self.grid_height
                                        )

                    x_dist, y_dist = self.__overlap_dist(module_block, grid_cell_block)
                    self.V_macro_routing_cong[r_i * self.grid_col + c_i] -= x_dist * self.vrouting_alloc

        if if_PARTIAL_OVERLAP_HORIZONTAL:
            for r_i in range(bl_row, ur_row + 1):
                for c_i in range(ur_col, ur_col + 1):
                    grid_cell_block = mnds.BoundingBox(
                                        maxx= (c_i + 1) * self.grid_width,
                                        maxy= (r_i + 1) * self.grid_height,
                                        minx= c_i * self.grid_width,
                                        miny= r_i * self.grid_height
                                        )

                    x_dist, y_dist = self.__overlap_dist(module_block, grid_cell_block)
                    self.H_macro_routing_cong[r_i * self.grid_col + c_i] -= y_dist * self.hrouting_alloc

    cpdef list __split_net(self, source_gcell, node_gcells):
        """
        private function: Split >3 pin net into multiple two-pin nets
        """
        splitted_netlist = []
        for node_gcell in node_gcells:
            if node_gcell != source_gcell:
                splitted_netlist.append({source_gcell, node_gcell})
        return splitted_netlist

    cpdef get_vertical_routing_congestion(self):
        """
        Return Vertical Routing Congestion
        """
        if self.FLAG_UPDATE_CONGESTION:
            self.get_routing()
        
        return self.V_routing_cong

    cpdef get_horizontal_routing_congestion(self):
        """
        Return Horizontal Routing Congestion
        """
        if self.FLAG_UPDATE_CONGESTION:
            self.get_routing()
        
        return self.H_routing_cong

    cpdef void get_routing(self):
        """
        H/V Routing Before Computing Routing Congestions
        """
        if self.FLAG_UPDATE_CONGESTION:
            self.grid_width = float(self.width/self.grid_col)
            self.grid_height = float(self.height/self.grid_row)

            self.grid_v_routes = self.grid_width * self.vroutes_per_micron
            self.grid_h_routes = self.grid_height * self.hroutes_per_micron

            # reset grid
            self.H_routing_cong = np.zeros(shape = self.grid_col * self.grid_row)
            self.V_routing_cong = np.zeros(shape = self.grid_col * self.grid_row)

            self.H_macro_routing_cong = np.zeros(shape = self.grid_col * self.grid_row)
            self.V_macro_routing_cong = np.zeros(shape = self.grid_col * self.grid_row)

            self.FLAG_UPDATE_CONGESTION = False

        for mod in self.meta_netlist.node:
            curr_type = mod.type
            # bounding box data structure
            node_gcells = set()
            source_gcell = None
            weight = mod.weight

            # NOTE: connection only defined on PORT, soft/hard macro pins
            if curr_type == mnds.Type.PORT and mod.output_indices:
                # add source grid location
                source_gcell = self.__get_grid_cell_location(mod.coord.x, mod.coord.y)
                node_gcells.add(self.__get_grid_cell_location(mod.coord.x, mod.coord.y))

                for sink_idx in mod.output_indices:
                    # retrieve grid location
                    node_gcells.add(
                        self.__get_grid_cell_location(
                            self.__get_pin_position(sink_idx)[0], 
                            self.__get_pin_position(sink_idx)[1]))

            elif curr_type == mnds.Type.MACRO_PIN and mod.output_indices:
                # add source position
                mod_idx = mod.id
                node_gcells.add(self.__get_grid_cell_location(
                    self.__get_pin_position(mod_idx)[0], 
                    self.__get_pin_position(mod_idx)[1]))
                source_gcell = self.__get_grid_cell_location(
                    self.__get_pin_position(mod_idx)[0], 
                    self.__get_pin_position(mod_idx)[1])

                for sink_idx in mod.output_indices:
                    # retrieve grid location                                                                                                                                                                                                                                                 
                    node_gcells.add(
                        self.__get_grid_cell_location(
                            self.__get_pin_position(sink_idx)[0],
                            self.__get_pin_position(sink_idx)[1]
                    ))
            # hard macro for macro routing congesiton
            elif curr_type == mnds.Type.MACRO and not mod.soft_macro:
                module_h = mod.dimension.height
                module_w = mod.dimension.width
                module_x = mod.coord.x
                module_y = mod.coord.y
                # compute overlap
                self.__macro_route_over_grid_cell(module_x, module_y, module_w, module_h)
            
            if len(node_gcells) == 2:
                self.__two_pin_net_routing(source_gcell=source_gcell,node_gcells=node_gcells, weight=weight)
            elif len(node_gcells) == 3:
                self.__three_pin_net_routing(node_gcells=node_gcells, weight=weight)
            elif len(node_gcells) > 3:
                for curr_net in self.__split_net(source_gcell=source_gcell, node_gcells=node_gcells):
                    self.__two_pin_net_routing(source_gcell=source_gcell, node_gcells=curr_net, weight=weight)

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
 
    cpdef void __smooth_routing_cong(self):
        """
        Smoothing V/H Routing congestion
        """
        temp_V_routing_cong = np.zeros(shape = self.grid_col * self.grid_row)
        temp_H_routing_cong = np.zeros(shape = self.grid_col * self.grid_row)

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

                for ptr in range(<int>lp, <int>rp + 1, 1):
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

                for ptr in range(<int>lp, <int>up + 1, 1):
                    temp_H_routing_cong[ptr * self.grid_col + col] += val
        
        self.H_routing_cong = temp_H_routing_cong

    cpdef bool is_node_soft_macro(self, int node_idx):
        """
        Return if node is a soft macro
        """
        try:
            return self.meta_netlist.node[node_idx].soft_macro
        except IndexError:
            print("[ERROR INDEX OUT OF RANGE] Can not process index at {}".format(node_idx))
            exit(1)

    cpdef bool is_node_hard_macro(self, int node_idx):
        """
        Return if node is a hard macro
        """
        try:
            return self.meta_netlist.node[node_idx].type == mnds.Type.MACRO \
                and not self.meta_netlist.node[node_idx].soft_macro
        except IndexError:
            print("[ERROR INDEX OUT OF RANGE] Can not process index at {}".format(node_idx))
            exit(1)

    cpdef str get_node_name(self, int node_idx):
        """
        Return node name based on given node index
        """
        try:
            return self.meta_netlist.node[node_idx].name
        except Exception:
            print("[ERROR NODE INDEX] Node not found!")
            exit(1)
    
    cpdef get_node_mask(self, node_idx: int):
        """
        Return node mask based on given node
        All legal positions must satisfy:
            - No Out-of-Bound
            - No Overlapping with previously placed MACROs
        """
        mod = self.meta_netlist.node[node_idx]

        canvas_block = mnds.BoundingBox(minx=0,
                                        maxx=self.width, 
                                        miny=0, 
                                        maxy=self.height)
        if mod.type in [mnds.Type.PORT, mnds.Type.MACRO_PIN]:
            mod_w = 1e-3
            mod_h = 1e-3
        else:
            mod_w = mod.dimension.width
            mod_h = mod.dimension.height

        temp_node_mask = np.array([1] * (self.grid_col * self.grid_row))\
            .reshape(self.grid_row, self.grid_col)

        self.grid_width = float(self.width/self.grid_col)
        self.grid_height = float(self.height/self.grid_row)

        for i in range(self.grid_row):
            for j in range(self.grid_col):
                # try every location
                # construct block based on current module dimenstion
                temp_x = j * self.grid_width + (self.grid_width/2)
                temp_y = i * self.grid_height + (self.grid_height/2)

                mod_block = mnds.BoundingBox(minx=temp_x - (mod_w/2),
                                            maxx=temp_x + (mod_w/2), 
                                            miny=temp_y - (mod_h/2), 
                                            maxy=temp_y + (mod_h/2))
                # check OOB
                if abs(self.__overlap_area(
                    bbox_i=canvas_block, bbox_j=mod_block) - (mod_w*mod_h)) > 1e-8:
                    temp_node_mask[i][j] = 0
                else:
                    # check overlapping
                    for pmod_idx in self.placed_macro:
                        pmod = self.modules_w_pins[pmod_idx]
                        if not self.node_placed[pmod_idx]:
                            continue

                        p_x, p_y = pmod.coord.x, pmod.coord.y
                        p_w = pmod.dimension.width
                        p_h = pmod.dimension.height
                        pmod_block = mnds.BoundingBox(maxx=p_x + (p_w/2),
                                            maxy=p_y + (p_h/2),
                                            minx=p_x - (p_w/2),
                                            miny=p_y - (p_h/2))
                        
                        # if overlap with placed module
                        if self.__overlap_area(bbox_i=pmod_block, bbox_j=mod_block) > 0:
                             temp_node_mask[i][j] = 0
            
        return temp_node_mask.flatten()
    
    cpdef get_node_mask_by_name(self, str node_name):
        node_idx = self.mod_name_to_indices[node_name]
        return self.get_node_mask(node_idx)

    cpdef str get_node_type(self, int node_idx):
        """
        Return node type
        """
        try:
            mod = self.meta_netlist.node[node_idx]
            if mod.type == mnds.Type.STDCELL:
                # standard cell, not used
                return "STDCELL"
            elif mod.type == mnds.Type.MACRO:
                return "MACRO"
            elif mod.type == mnds.Type.PORT:
                # port
                return "PORT"
            elif mod.type == mnds.Type.MACRO_PIN:
                return "MACRO_PIN"
        except IndexError:
            # NOTE: Google's API return NONE if out of range
            print("[WARNING INDEX OUT OF RANGE] Can not process index at {}".format(node_idx))
            return None

    cpdef get_node_width_height(self, int node_idx):
        """
        Return node dimension
        """
        node = self.meta_netlist.node[node_idx]
        return node.width, node.height

    cpdef void make_soft_macros_square(self):
        """
        make soft macros as squares
        """
        for mod_idx in self.soft_macro_indices:
            mod = self.meta_netlist.node[mod_idx]
            mod_area = mod.dimension.width * mod.dimension.height
            mod.dimension.width = math.sqrt(mod_area)
            mod.dimension.height = math.sqrt(mod_area)

    cpdef void set_use_incremental_cost(self, bool use_incremental_cost):
        """
        NOT IMPLEMENTED
        """
        self.use_incremental_cost = use_incremental_cost

    cpdef bool get_use_incremental_cost(self):
        """
        NOT IMPLEMENTED
        """
        return self.use_incremental_cost

    cpdef list get_macro_adjacency(self):
        """
        Compute Adjacency Matrix
        """
        # NOTE: in pb.txt, netlist input count exceed certain threshold will be ommitted
        #[MACRO][macro]

        cdef:
            int macro_cnt
            int row_idx
            int col_idx
            list macro_adj

        if self.FLAG_UPDATE_MACRO_ADJ:
            # do some update
            self.FLAG_UPDATE_MACRO_ADJ = False

        # adjacency matrix: [MACRO] X [MACRO]
        macro_cnt = self.hard_macro_cnt + self.soft_macro_cnt
        macro_adj = [0] * (macro_cnt) * (macro_cnt)

        for pin in self.meta_netlist.node:
            if pin.type == mnds.Type.MACRO_PIN:
                # row index should be order of discovery of the reference node
                row_idx = self.macro_id_to_indices[pin.ref_node_id]
                # col index should be from the ref node of output_indices
                for output_idx in pin.output_indices:
                    output_pin = self.meta_netlist.node[output_idx]
                    # only between MACRO_PINs
                    if output_pin.type == mnds.Type.MACRO_PIN:
                        col_idx = self.macro_id_to_indices[output_pin.ref_node_id]
                        macro_adj[row_idx * macro_cnt + col_idx] += 1.0 * pin.weight
                        macro_adj[col_idx * macro_cnt + row_idx] += 1.0 * pin.weight
        return macro_adj

    cdef get_macro_and_clustered_port_adjacency(self):
        """
        Compute Adjacency Matrix (Unclustered PORTs)
        if module is a PORT, assign it to nearest cell location even if OOB
        """
        cdef:
            int row
            int col
            int row_idx
            int col_idx
            list macro_adj
            list cell_location
            dict port_to_rc = {}
            dict rc_to_clustered_port_id = {}
            list rc = []
            int clustered_port_cnt = 0
        
        if self.FLAG_UPDATE_MACRO_ADJ:
            # do some update
            self.FLAG_UPDATE_MACRO_ADJ = False
        
        # adjacency matrix: [MACRO + clustered ports] X [MACRO + clustered ports]
        macro_cnt = self.hard_macro_cnt + self.soft_macro_cnt
        
        #[Grid Cell] => [PORT]
        for port_idx in self.port_indices:
            port = self.meta_netlist.node[port_idx]
            x_pos, y_pos = port.coord.x, port.coord.y
            
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

            if (row, col) not in rc:
                # new cluster
                clustered_port_cnt += 1
                rc.append((row, col))

            # [PORT.id] => [Row, Col]
            port_to_rc[port.id] = (row, col)

        # sort by col, this function cannot be used under cpdef
        rc = sorted(rc, key=lambda tup: tup[1])

        macro_adj = [0] * (macro_cnt + clustered_port_cnt) * (macro_cnt + clustered_port_cnt)
        cell_location = [0] * clustered_port_cnt

        for v, k in enumerate(rc):
            # add cell location
            cell_location[v] = k[0] * self.grid_col + k[1]
            # [rc] => [cluster id]
            rc_to_clustered_port_id[k] = v

        for pin in self.meta_netlist.node:
            if pin.type == mnds.Type.MACRO_PIN:
                # row index should be order of discovery of the reference node
                row_idx = self.macro_id_to_indices[pin.ref_node_id]
                # col index should be from the ref node of output_indices
                for output_idx in pin.output_indices:
                    output_pin = self.meta_netlist.node[output_idx]
                    # only between MACRO_PINs
                    if output_pin.type == mnds.Type.MACRO_PIN:
                        col_idx = self.macro_id_to_indices[output_pin.ref_node_id]
                        macro_adj[row_idx * (macro_cnt + clustered_port_cnt) + col_idx] += 1.0 * pin.weight
                        macro_adj[col_idx * (macro_cnt + clustered_port_cnt) + row_idx] += 1.0 * pin.weight
                    elif output_pin.type == mnds.Type.PORT:
                        col_idx = rc_to_clustered_port_id[port_to_rc[output_pin.id]]
                        # relocate to after macros
                        col_idx += macro_cnt
                        macro_adj[row_idx * (macro_cnt + clustered_port_cnt) + col_idx] += 1.0 * pin.weight
                        macro_adj[col_idx * (macro_cnt + clustered_port_cnt) + row_idx] += 1.0 * pin.weight
            elif pin.type == mnds.Type.PORT:
                # row index should be order of discovery of the reference node
                row_idx = rc_to_clustered_port_id[port_to_rc[pin.id]]
                # relocate to after macros
                row_idx += macro_cnt
                # col index should be from the ref node of output_indices
                for output_idx in pin.output_indices:
                    output_pin = self.meta_netlist.node[output_idx]
                    # only between MACRO_PINs
                    if output_pin.type == mnds.Type.MACRO_PIN:
                        col_idx = self.macro_id_to_indices[output_pin.ref_node_id]
                        macro_adj[row_idx * (macro_cnt + clustered_port_cnt) + col_idx] += 1.0 * pin.weight
                        macro_adj[col_idx * (macro_cnt + clustered_port_cnt) + row_idx] += 1.0 * pin.weight
                    elif output_pin.type == mnds.Type.PORT:
                        col_idx = self.port_id_to_indices[output_pin.id]
                        # relocate to after macros
                        col_idx += macro_cnt
                        macro_adj[row_idx * (macro_cnt + clustered_port_cnt) + col_idx] += 1.0 * pin.weight
                        macro_adj[col_idx * (macro_cnt + clustered_port_cnt) + row_idx] += 1.0 * pin.weight
                
        return macro_adj, sorted(cell_location)

    cpdef void unfix_node_coord(self, int node_idx):
        """
        Unfix a module
        """
        cdef: 
            object mod = None

        try:
            mod = self.meta_netlist.node[node_idx]
            assert mod.type in [mnds.Type.MACRO, mnds.Type.PORT]
        except AssertionError:
            print("[ERROR UNFIX NODE] Found {}. Only 'MACRO', ".format(mod.type)
                    +"'PORT' are considered to be fixable nodes")
            exit(1)
        except Exception:
            print("[ERROR UNFIX NODE] Could not find module by node index")
            exit(1)

        self.node_fix[node_idx] = False
    
    cpdef void fix_node_coord(self, int node_idx):
        """
        Fix a module
        """
        cdef: 
            object mod = None
        
        try:
            mod = self.meta_netlist.node[node_idx]
            assert mod.type in [mnds.Type.MACRO, mnds.Type.PORT]
        except AssertionError:
            print("[ERROR UNFIX NODE] Found {}. Only 'MACRO', ".format(mod.type)
                    +"'PORT' are considered to be fixable nodes")
            exit(1)
        except Exception:
            print("[ERROR FIX NODE] Could not find module by node index")
            exit(1)

        self.node_fix[node_idx] = True

    cpdef bool is_node_fixed(self, int node_idx):
        """
        Return if a node is fixed
        """
        cdef: 
            object mod = None

        try:
            mod = self.meta_netlist.node[node_idx]
            assert mod.type in [mnds.Type.MACRO, mnds.Type.PORT]
        except AssertionError:
            print("[ERROR UNFIX NODE] Found {}. Only 'MACRO', ".format(mod.type)
                    +"'PORT' are considered to be fixable nodes")
            exit(1)
        except Exception:
            print("[ERROR NODE FIXED] Could not find module by node index")
            exit(1)

        return self.node_fix[node_idx]

    cpdef void update_node_coords(self, int node_idx, float x_pos, float y_pos):
        """
        Update Node location if node is 'MACRO', 'STDCELL', 'PORT'
        """
        mod = None

        try:
            mod = self.meta_netlist.node[node_idx]
            assert mod.type in [mnds.Type.MACRO, mnds.Type.PORT]
        except AssertionError:
            print("[ERROR UNFIX NODE] Found {}. Only 'MACRO', ".format(mod.type)
                    +"'PORT' are considered to be placable nodes")
            exit(1)
        except Exception:
            print("[ERROR NODE LOCATION] Could not find module by node index")
            exit(1)
        
        # only update if node is not fixed
        if not self.node_fix[node_idx]:
            mod.coord.x = x_pos
            mod.coord.y = y_pos
    
    cpdef void update_node_coords_by_name(self, str node_name, float x_pos, float y_pos):
        """
        Update Node location if node is 'MACRO', 'STDCELL', 'PORT'
        """
        node_idx = self.mod_name_to_indices[node_name]
        self.update_node_coords(node_idx=node_idx, x_pos=x_pos, y_pos=y_pos)

    cpdef update_macro_orientation(self, int node_idx, str orientation):
        """ 
        Update macro orientation if node is 'MACRO'
        """
        mod = None

        try:
            mod = self.meta_netlist.node[node_idx]
            assert mod.type == mnds.Type.MACRO
        except AssertionError:
            print("[ERROR MACRO ORIENTATION] Found {}. Only 'MACRO'".format(mod.type)
                    +" are considered to be ORIENTED")
            exit(1)
        except Exception:
            print("[ERROR MACRO ORIENTATION] Could not find module by node index {}".format(node_idx))
            exit(1)
        
        mod.orientation = mnds.Orientation[orientation]
    
    cpdef update_macro_orientation_by_name(self, str node_name, str orientation):
        """ 
        Update macro orientation if node is 'MACRO'
        """
        node_idx = self.mod_name_to_indices[node_name]
        self.update_macro_orientation(node_idx=node_idx, orientation=orientation)

    def update_port_sides(self):
        pass

    def snap_ports_to_edges(self):
        pass

    cpdef (float, float) get_node_location(self, int node_idx):
        """ 
        Return Node location if node is 'MACRO', 'STDCELL', 'PORT'
        """
        mod = None

        try:
            mod = self.meta_netlist.node[node_idx]
            assert mod.type in [mnds.Type.MACRO, mnds.Type.PORT]
        except AssertionError:
            print("[ERROR NODE LOCATION] Found {}. Only 'MACRO', 'STDCELL'".format(mod.type)
                    +"'PORT' are considered to be placable nodes")
            exit(1)
        except Exception:
            print("[ERROR NODE PLACED] Could not find module by node index")
            exit(1)
        
        return mod.coord.x, mod.coord.y
    
    cpdef list get_node_locations(self, list node_indices):
        """
        Returns the (x, y) location of a list of nodes
        """
        cdef:
            int node_idx
            list node_locations = []
        
        for node_idx in node_indices:
            node_locations.append(self.get_node_location(node_idx))
        return node_locations

    cpdef get_macro_orientation(self, int node_idx):
        """
        Returns the orientation of the given node
        """
        mod = None

        try:
            mod = self.meta_netlist.node[node_idx]
            assert mod.type == mnds.Type.MACRO
        except AssertionError:
            print("[ERROR MACRO ORIENTATION] Found {}. Only 'MACRO'".format(mod.type)
                    +" are considered to be ORIENTED")
            exit(1)
        except Exception:
            print("[ERROR MACRO ORIENTATION] Could not find module by node index")
            exit(1)
        
        return mod.orientation

    def place_node(self, node_idx, grid_cell_idx):
        """
        Place the node into the center of the given grid_cell
        """
        mod = self.meta_netlist.node[node_idx]

        # TODO: add check valid clause
        if not self.node_fix[node_idx]:
            x_pos, y_pos = self.__get_grid_cell_position(grid_cell_idx)
            mod.coord.x = x_pos
            mod.coord.y = y_pos
            self.node_placed[node_idx] = True
            # update flag
            self.FLAG_UPDATE_CONGESTION = True
            self.FLAG_UPDATE_DENSITY = True
            self.FLAG_UPDATE_WIRELENGTH = True
    
    def place_node_by_name(self, node_name, grid_cell_idx):
        """
        Place the node into the center of the given grid_cell
        """
        node_idx = self.mod_name_to_indices[node_name]
        self.place_node(node_idx=node_idx, grid_cell_idx=grid_cell_idx)

    def unplace_node(self, node_idx):
        """
        Set the node's ifPlaced flag to False if not fixed node
        """
        mod = self.meta_netlist.node[node_idx]

        if not self.node_fix[node_idx]:
            if mod.type == mnds.Type.MACRO:
                self.node_placed[node_idx] = False
                # update flag
                self.FLAG_UPDATE_CONGESTION = True
                self.FLAG_UPDATE_DENSITY = True
                self.FLAG_UPDATE_WIRELENGTH = True
        else:
            print("[WARNING UNPLACE NODE] Trying to unplace a fixed node")

    def unplace_all_nodes(self):
        """
        Set all ifPlaced flag to False except for fixed nodes
        """
        for port_idx in sorted(self.port_indices):
            if self.node_fix:
                continue
            self.node_placed[port_idx] = False
        
        for mod_idx in sorted(self.macro_indices):
            if self.node_fix:
                continue
            self.node_placed[mod_idx] = False
        
        # update flag
        self.FLAG_UPDATE_CONGESTION = True
        self.FLAG_UPDATE_DENSITY = True
        self.FLAG_UPDATE_WIRELENGTH = True

    cpdef bool is_node_placed(self, int node_idx):
        """
        return if node is placed
        """
        return self.node_placed[node_idx]

    def disconnect_nets(self):
        pass

    cpdef str get_source_filename(self):
        """
        return netlist path
        """
        return self.netlist_file

    cpdef list get_blockages(self):
        """
        NOT IMPLEMENTED
        """
        return self.blockages

    cpdef create_blockage(self, minx, miny, maxx, maxy, blockage_rate):
        """
        NOT IMPLEMENTED
        """
        self.blockages.append([minx, miny, maxx, maxy, blockage_rate])
        pass

    cpdef int get_ref_node_id(self, int node_idx):
        """
        ref_node_id is used for macro_pins. Refers to the macro it belongs to
        """
        if self.meta_netlist.node[node_idx].type == mnds.Type.PORT:
            return node_idx
        else:
            return self.meta_netlist.node[node_idx].ref_node_id
    
    cpdef list get_fan_outs_of_node(self, int node_idx):
        """
        Returns the vector of node indices that are driven by given node
        """
        return self.meta_netlist.node[node_idx].output_indices

    cpdef void save_placement(self, str filename, info=""):
        """
        When writing out info line-by-line, add a "#" at front
        """
        with open(filename, 'w+') as f:
            for line in info.split('\n'):
                f.write("# " + line + '\n')

            # if first, no \newline
            HEADER = True

            # PORT
            for port_idx in self.port_indices:
                port = self.meta_netlist.node[port_idx]
                if HEADER:
                    f.write("{} {:g} {:g} {} {}".format(port_idx,\
                        port.coord.x, port.coord.y, "-",
                        "1" if self.node_fix[port_idx] else "0"))
                    HEADER = False
                else:
                    f.write("\n{} {:g} {:g} {} {}".format(port_idx,\
                        port.coord.x, port.coord.y, "-",
                        "1" if self.node_fix[port_idx] else "0"))

            # MACRO
            for mod_idx in self.macro_indices:
                # [node_index] [x] [y] [orientation] [fixed]
                mod = self.meta_netlist.node[mod_idx]

                if HEADER:
                    f.write("{} {:g} {:g} {} {}".format(mod_idx,\
                        mod.coord.x, mod.coord.y,
                        mnds.Orientation(mod.orientation.value).name if mod.orientation else "-",
                        "1" if self.node_fix[mod_idx] else "0"))
                    HEADER = False
                else:
                    f.write("\n{} {:g} {:g} {} {}".format(mod_idx,\
                        mod.coord.x, mod.coord.y,
                        mnds.Orientation(mod.orientation.value).name if mod.orientation else "-",
                        "1" if self.node_fix[mod_idx] else "0"))
    
    cpdef void __cache_placement(self, str filename):
        """
        private function: used to cache placement file for FD executable
        """
        cols, rows = self.get_grid_num_columns_rows()
        width, height = self.get_canvas_width_height()
        hor_routes, ver_routes = self.get_routes_per_micron()
        hor_macro_alloc, ver_macro_alloc = self.get_macro_routing_allocation()
        smooth = self.get_congestion_smooth_range()
        info = textwrap.dedent("""\
            Placement file for Circuit Training
            Columns : {cols}  Rows : {rows}
            Width : {width:.3f}  Height : {height:.3f}
            Area : {area}
            Wirelength : {wl:.3f}
            Wirelength cost : {wlc:.4f}
            Congestion cost : {cong:.4f}
            Density cost : {density:.4f}
            Project : {project}
            Block : {block_name}
            Routes per micron, hor : {hor_routes:.3f}  ver : {ver_routes:.3f}
            Routes used by macros, hor : {hor_macro_alloc:.3f}  ver : {ver_macro_alloc:.3f}
            Smoothing factor : {smooth}
            Overlap threshold : {overlap_threshold}
        """.format(
            cols=cols,
            rows=rows,
            width=width,
            height=height,
            area=self.get_area(),
            wl=self.get_wirelength(),
            wlc=self.get_cost(),
            cong=self.get_congestion_cost(),
            density=self.get_density_cost(),
            project=self.get_project_name(),
            block_name=self.get_block_name(),
            hor_routes=hor_routes,
            ver_routes=ver_routes,
            hor_macro_alloc=hor_macro_alloc,
            ver_macro_alloc=ver_macro_alloc,
            smooth=smooth,
            overlap_threshold=self.get_overlap_threshold()))

        self.save_placement(filename=filename, info=info)

    def display_canvas( self,
                        annotate=True, 
                        amplify=False,
                        saveName=None,
                        show=True):
        """
        Non-google function, For quick canvas view
        """
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
        for mod in self.meta_netlist.node:
            if mod.type == mnds.Type.PORT and self.node_placed[mod.id]:
                plt.plot((mod.coord.x, mod.coord.y),'ro', markersize=PORT_SIZE)
            elif mod.type == mnds.Type.MACRO and self.node_placed[mod.id]:
                if not mod.soft_macro:
                    # hard macro
                    ax.add_patch(Rectangle((mod.coord.x - mod.dimension.width/2, mod.coord.y - mod.dimension.height/2),\
                        mod.dimension.width, mod.dimension.height,\
                        alpha=0.5, zorder=1000, facecolor='b', edgecolor='darkblue'))
                    if annotate:
                        ax.annotate(mod.name, (mod.coord.x, mod.coord.y),  wrap=True,color='r', weight='bold', fontsize=FONT_SIZE, ha='center', va='center')
                else:
                    # soft macro
                    ax.add_patch(Rectangle((mod.coord.x - mod.dimension.width/2, mod.coord.y - mod.dimension.height/2),\
                        mod.dimension.width, mod.dimension.height,\
                        alpha=0.5, zorder=1000, facecolor='y'))
                    if annotate:
                        ax.annotate(mod.name, (mod.coord.x, mod.coord.y), wrap=True,color='r', weight='bold', fontsize=FONT_SIZE, ha='center', va='center')
            elif mod.type == mnds.Type.MACRO_PIN:
                macro = self.meta_netlist.node[mod.ref_node_id]
                if self.node_placed[macro.id]:
                    plt.plot(*self.__get_pin_position(mod.id),'bo', markersize=PIN_SIZE)
        if saveName:
            plt.savefig(saveName)
        if show:
            plt.show()

        plt.close('all')
    
    '''
    FD Placement below shares the same functionality as the FDPlacement/fd_placement.py
    ''' 
    def optimize_stdcells(self, use_current_loc, move_stdcells, move_macros,
                        log_scale_conns, use_sizes, io_factor, num_steps,
                        max_move_distance, attract_factor, repel_factor):
        cache_plc = self.init_plc + ".cache"
        self.__cache_placement(cache_plc)
        os.system("./fd_placer {} {}".format(self.netlist_file, cache_plc))
        fd_plc = self.init_plc + ".cache.new"
        self.restore_placement(fd_plc, retrieveFD=True)
        print("[INFO] FD ran successfully")

        # self.__fd_placement(io_factor, num_steps, max_move_distance, attract_factor, repel_factor, use_current_loc, verbose=True)
