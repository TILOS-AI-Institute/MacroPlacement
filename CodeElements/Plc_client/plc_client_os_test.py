from ast import Assert
import numpy as np
import pandas as pd
import sys
import os
import traceback
import math
import re
from random import randrange
from absl import flags
from absl.flags import argparse_flags
from absl import app
from Plc_client import plc_client_os as plc_client_os
from Plc_client import placement_util_os as placement_util
from Plc_client import observation_extractor_os as observation_extractor
from Plc_client import environment_os as environment
from Plc_client import observation_config

try:
    from Plc_client import plc_client as plc_client
except ImportError:
    print("[PLC CLIENT MISSING] Downloading Google's API for testing!")
    os.system("curl 'https://raw.githubusercontent.com/google-research/circuit_training/main/circuit_training/environment/plc_client.py' > ./Plc_client/plc_client.py")
    from Plc_client import plc_client as plc_client
np.set_printoptions(threshold=sys.maxsize)
# FLAGS = flags.FLAGS

"""plc_client_os_test docstrings

Test Utility Class for Google's API plc_wrapper_main with plc_client.py and plc_client_os.py

Example:
    At ./MacroPlacement/CodeElement, run the following command:

        $ python3 -m Plc_client.plc_client_os_test --netlist ./Plc_client/test/ariane/netlist.pb.txt\
            --plc ./Plc_client/test/ariane/initial.plc\
            --width 356.592\
            --height 356.640\
            --col 35\
            --row 33\
            --rpmh 70.330\
            --rpmv 74.510\
            --marh 51.790\
            --marv 51.790\
            --smooth 2
        
        $ python3 -m Plc_client.plc_client_os_test --netlist ./Plc_client/test/ariane_68_1.3/netlist.pb.txt\
            --plc ./Plc_client/test/ariane_68_1.3/legalized.plc\
            --width 1347.100\
            --height 1346.800\
            --col 23\
            --row 28\
            --rpmh 11.285\
            --rpmv 12.605\
            --marh 7.143\
            --marv 8.339\
            --smooth 2

         $ python3 -m Plc_client.plc_client_os_test --netlist ./Plc_client/test/g657_ub5_nruns10_c5_r3_v3_rc1/netlist.pb.txt\
            --plc ./Plc_client/test/g657_ub5_nruns10_c5_r3_v3_rc1/legalized.plc\
            --width 1357.360\
            --height 1356.880\
            --col 22\
            --row 30\
            --rpmh 11.285\
            --rpmv 12.605\
            --marh 7.143\
            --marv 8.339\
            --smooth 0
        
        $ python3 -m Plc_client.plc_client_os_test --netlist ./Plc_client/test/0P2M0m/netlist.pb.txt\
            --width 500\
            --height 500\
            --col 5\
            --row 5\
            --rpmh 10\
            --rpmv 10\
            --marh 5\
            --marv 5\
            --smooth 2

        $ python3 -m Plc_client.plc_client_os_test --netlist ./Plc_client/test/ariane_fd/ariane.pb.txt\
            --plc ./Plc_client/test/ariane_fd/ariane.plc\
            --width 1599.99\
            --height 1598.8\
            --col 27\
            --row 23\
            --rpmh 70.330\
            --rpmv 74.510\
            --marh 51.790\
            --marv 51.790\
            --smooth 2

Todo:
    * Clean up code
    * Extract argument from command line
    * Report index for each mismatch array entry 

"""


class PlacementCostTest():

    """ Canvas Setting Reference Table
        ++ Google's Ariane ++
        - CANVAS_WIDTH = 356.592
        - CANVAS_HEIGHT = 356.640
        - GRID_COL = 35
        - GRID_ROW = 33

        ++ Ariane133 ++
        - CANVAS_WIDTH = 1599.99
        - CANVAS_HEIGHT = 1600.06
        - GRID_COL = 24
        - GRID_ROW = 21

        ++ Sample clustered ++
        - CANVAS_WIDTH = 400
        - CANVAS_HEIGHT = 400
        - GRID_COL = 4
        - GRID_ROW = 4

        ++ PMm ++
        - CANVAS_WIDTH = 100
        - CANVAS_HEIGHT = 100
        - GRID_COL = 5
        - GRID_ROW = 5
    """

    def __init__(self, NETLIST_PATH, PLC_PATH=None,
                 width=0, height=0,
                 column=0, row=0, rpmv=10, rpmh=10,
                 marh=10, marv=10, smooth=1) -> None:
        self.NETLIST_PATH = NETLIST_PATH
        self.PLC_PATH = PLC_PATH
        self.CANVAS_WIDTH = width
        self.CANVAS_HEIGHT = height
        self.GRID_COL = column
        self.GRID_ROW = row

        # for congestion computation
        self.RPMV = rpmv
        self.RPMH = rpmh
        self.MARH = marh
        self.MARV = marv
        self.SMOOTH = smooth

    def test_metadata(self):
        print("############################ TEST METADATA ############################")
        # Google's Binary Executable
        self.plc = plc_client.PlacementCost(self.NETLIST_PATH)
        # Open-sourced Implementation
        self.plc_os = plc_client_os.PlacementCost(netlist_file=self.NETLIST_PATH,
                                                  macro_macro_x_spacing=50,
                                                  macro_macro_y_spacing=50)

        # NOTE: must set canvas before restoring placement, otherwise OOB error
        self.plc.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc.set_placement_grid(self.GRID_COL, self.GRID_ROW)
        self.plc_os.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc_os.set_placement_grid(self.GRID_COL, self.GRID_ROW)

        if self.PLC_PATH:
            print("#[PLC FILE FOUND] Loading info from .plc file")
            self.plc_os.set_canvas_boundary_check(False)
            self.plc_os.restore_placement(self.PLC_PATH,
                                          ifInital=True,
                                          ifValidate=True,
                                          ifReadComment=False)
            self.plc.set_canvas_boundary_check(False)
            self.plc.restore_placement(self.PLC_PATH)
        else:
            print("#[PLC FILE MISSING] Using only netlist info")

        try:
            assert int(self.plc_os.get_area()) == int(self.plc.get_area())

            self.plc.set_routes_per_micron(1.0, 2.0)
            self.plc_os.set_routes_per_micron(1.0, 2.0)
            assert self.plc.get_routes_per_micron() == self.plc_os.get_routes_per_micron()

            self.plc.set_overlap_threshold(2.0)
            self.plc_os.set_overlap_threshold(2.0)
            assert self.plc.get_overlap_threshold() == self.plc_os.get_overlap_threshold()

            self.plc.set_congestion_smooth_range(2.0)
            self.plc_os.set_congestion_smooth_range(2.0)
            assert self.plc.get_congestion_smooth_range(
            ) == self.plc_os.get_congestion_smooth_range()

            self.plc.set_macro_routing_allocation(3.0, 4.0)
            self.plc_os.set_macro_routing_allocation(3.0, 4.0)
            assert self.plc.get_macro_routing_allocation(
            ) == self.plc_os.get_macro_routing_allocation()
        except Exception as e:
            _, _, tb = sys.exc_info()
            traceback.print_tb(tb)
            tb_info = traceback.extract_tb(tb)
            _, line, _, text = tb_info[-1]
            print('[METADATA ERROR] at line {} in statement {}'
                  .format(line, text))
            exit(1)

        # test get_macro_adjacency
        plc_macroadj = self.plc.get_macro_adjacency()
        plc_macroadj = np.array(plc_macroadj).reshape(int(math.sqrt(len(plc_macroadj))),
                                                      int(math.sqrt(len(plc_macroadj))))

        plcos_macroadj = self.plc_os.get_macro_adjacency()
        plcos_macroadj = np.array(plcos_macroadj).reshape(int(math.sqrt(len(plcos_macroadj))),
                                                          int(math.sqrt(len(plcos_macroadj))))

        try:
            assert(np.sum(np.nonzero(plc_macroadj - plcos_macroadj)) == 0)
        except Exception as e:
            print("[MACRO ADJ ERROR] Mismatched found -- {}".format(str(e)))
            exit(1)

        # test get_macro_and_clustered_port_adjacency
        plc_clusteradj, plc_cell = self.plc.get_macro_and_clustered_port_adjacency()
        plc_clusteradj = np.array(plc_clusteradj).reshape(int(math.sqrt(len(plc_clusteradj))),
                                                          int(math.sqrt(len(plc_clusteradj))))

        plcos_clusteradj, plcos_cell = self.plc_os.get_macro_and_clustered_port_adjacency()
        plcos_clusteradj = np.array(plcos_clusteradj).reshape(int(math.sqrt(len(plcos_clusteradj))),
                                                              int(math.sqrt(len(plcos_clusteradj))))

        try:
            for plc_adj, plcos_adj in zip(plc_clusteradj, plcos_clusteradj):
                assert(np.sum(np.nonzero(plc_adj - plcos_adj)) == 0)
        except Exception as e:
            print(
                "[MACRO AND CLUSTERED PORT ADJ ERROR] Mismatched found -- {}".format(str(e)))
            exit(1)

        print("                  +++++++++++++++++++++++++++")
        print("                  +++ TEST METADATA: PASS +++")
        print("                  +++++++++++++++++++++++++++")

    def view_canvas(self, ifInital=False, ifReadComment=False):
        print("############################ VIEW CANVAS ############################")
        self.plc_os = plc_client_os.PlacementCost(netlist_file=self.NETLIST_PATH,
                                                  macro_macro_x_spacing=50,
                                                  macro_macro_y_spacing=50)
        self.plc_os.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc_os.set_placement_grid(self.GRID_COL, self.GRID_ROW)

        if self.PLC_PATH:
            print("#[PLC FILE FOUND] Loading info from .plc file")
            self.plc_os.set_canvas_boundary_check(False)
            self.plc_os.restore_placement(self.PLC_PATH,
                                          ifInital=ifInital,
                                          ifValidate=False,
                                          ifReadComment=ifReadComment)
        
        self.plc_os.set_routes_per_micron(self.RPMH, self.RPMV)
        self.plc_os.set_macro_routing_allocation(self.MARH, self.MARV)
        self.plc_os.set_congestion_smooth_range(self.SMOOTH)
        self.plc_os.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc_os.set_placement_grid(self.GRID_COL, self.GRID_ROW)
        # show canvas
        self.plc_os.make_soft_macros_square()
        self.plc_os.display_canvas(annotate=False, amplify=False)
        

    def test_proxy_cost(self):
        print("############################ TEST PROXY COST ############################")
        # Google's Binary Executable
        self.plc = plc_client.PlacementCost(self.NETLIST_PATH)

        # Open-sourced Implementation
        self.plc_os = plc_client_os.PlacementCost(netlist_file=self.NETLIST_PATH,
                                                  macro_macro_x_spacing=50,
                                                  macro_macro_y_spacing=50)

        self.plc.get_overlap_threshold()
        print("overlap_threshold default", self.plc.get_overlap_threshold())

        # self.plc.make_soft_macros_square()

        if self.PLC_PATH:
            print("#[PLC FILE FOUND] Loading info from .plc file")
            self.plc_os.set_canvas_boundary_check(False)
            self.plc_os.restore_placement(self.PLC_PATH,
                                          ifInital=True,
                                          ifValidate=True,
                                          ifReadComment=False)
            self.plc.set_canvas_boundary_check(False)
            self.plc.restore_placement(self.PLC_PATH)
        else:
            print("#[PLC FILE MISSING] Using only netlist info")
        
        # self.plc.make_soft_macros_square()

        self.plc.set_routes_per_micron(self.RPMH, self.RPMV)
        self.plc_os.set_routes_per_micron(self.RPMH, self.RPMV)

        # self.plc.make_soft_macros_square()

        self.plc.set_macro_routing_allocation(self.MARH, self.MARV)
        self.plc_os.set_macro_routing_allocation(self.MARH, self.MARV)

        # self.plc.make_soft_macros_square()

        self.plc.set_congestion_smooth_range(self.SMOOTH)
        self.plc_os.set_congestion_smooth_range(self.SMOOTH)

        # self.plc.make_soft_macros_square()

        self.plc.set_placement_grid(self.GRID_COL, self.GRID_ROW)
        self.plc.make_soft_macros_square() #  in effect
        self.plc.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        

        self.plc_os.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc_os.set_placement_grid(self.GRID_COL, self.GRID_ROW)

        self.plc_os.make_soft_macros_square()

        # [IGNORE] create_blockage must be defined BEFORE set_canvas_size 
        # and set_placement_grid in order to be considered on the canvas
        if False:
            self.plc.create_blockage(0.0, 100.0, 300.0, 300.0, 1.0)
            self.plc.create_blockage(300, 0, 500, 200, 1)
            print(self.plc.get_blockages())
            print(self.plc.make_soft_macros_square())
            print(self.plc.set_use_incremental_cost(True))
            print(self.plc_os.get_soft_macros_count())

        # self.plc_os.display_canvas(annotate=False)
        
        # HPWL
        try:
            assert int(self.plc_os.get_wirelength()) == int(self.plc.get_wirelength())
            assert abs(self.plc.get_cost() - self.plc_os.get_cost()) <= 1e-2
            print("#[INFO WIRELENGTH] Matched Wirelength cost -- GL {}, OS {}".format(
                str(self.plc.get_cost()), self.plc_os.get_cost()))
        except Exception as e:
            print("[ERROR WIRELENGTH] Discrepancies found when computing wirelength -- GL {}, OS {}".format(
                str(self.plc.get_cost()), self.plc_os.get_cost()))
            print("GL WIRELENGTH: ", self.plc.get_wirelength())
            print("OS WIRELENGTH: ", self.plc_os.get_wirelength())
            # exit(1)

        # Density
        try:
            assert int(sum(self.plc_os.get_grid_cells_density())) == int(
                sum(self.plc.get_grid_cells_density()))
            assert int(self.plc_os.get_density_cost()) == int(
                self.plc.get_density_cost())
            print("#[INFO DENSITY] Matched density cost -- GL {}, OS {}".format(
                str(self.plc.get_density_cost()), self.plc_os.get_density_cost()))
        except Exception as e:
            print("[ERROR DENSITY] Discrepancies found when computing density -- GL {}, OS {}".format(
                str(self.plc.get_density_cost()), self.plc_os.get_density_cost()))
            exit(1)

        # Congestion
        try:
            # NOTE: [IGNORE] grid-wise congestion not tested because
            # miscellaneous implementation differences.
            assert abs(self.plc.get_congestion_cost() -
                       self.plc_os.get_congestion_cost()) <= 1e-2
            print("#[INFO CONGESTION] Matched congestion cost -- GL {}, OS {}".format(
                str(self.plc.get_congestion_cost()), self.plc_os.get_congestion_cost()))
        except Exception as e:
            print("[ERROR CONGESTION] Discrepancies found when computing congestion -- GL {}, OS {}"
                  .format(str(self.plc.get_congestion_cost()),
                          str(self.plc_os.get_congestion_cost())))
            exit(1)

        print("                  +++++++++++++++++++++++++++++")
        print("                  +++ TEST PROXY COST: PASS +++")
        print("                  +++++++++++++++++++++++++++++")

    def test_miscellaneous(self):
        print("****************** miscellaneous ******************")
        # Google's Binary Executable
        self.plc = plc_client.PlacementCost(self.NETLIST_PATH)
        self.plc_os = plc_client_os.PlacementCost(netlist_file=self.NETLIST_PATH,
                                                  macro_macro_x_spacing=50,
                                                  macro_macro_y_spacing=50)
        self.plc.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc.set_placement_grid(self.GRID_COL, self.GRID_ROW)

        self.plc_util = placement_util.create_placement_cost(
            plc_client=plc_client,
            netlist_file=self.NETLIST_PATH,
            init_placement=self.PLC_PATH
        )

        self.plc_os.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc_os.set_placement_grid(self.GRID_COL, self.GRID_ROW)

        self.plc_os.display_canvas()
        self.plc_os.unplace_all_nodes()
        print(np.flip(np.array(self.plc_util.get_node_mask(0)).reshape(35, 33), axis=0))

        print(np.flip(np.array(self.plc.get_node_mask(0)).reshape(35, 33), axis=0))
        # self.plc.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        # self.plc.set_placement_grid(self.GRID_COL, self.GRID_ROW)
        # self.plc_os.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        # self.plc_os.set_placement_grid(self.GRID_COL, self.GRID_ROW)
        # NODE_IDX = 22853
        # print("get_macro_indices", self.plc.get_macro_indices())
        # print("get_node_name", self.plc.get_node_name(NODE_IDX))
        # print("get_node_type", self.plc.get_node_type(NODE_IDX))
        # print("get_node_location", self.plc.get_node_location(NODE_IDX))
        # print("get_grid_cell_of_node", self.plc.get_grid_cell_of_node(NODE_IDX))
        # print("get_macro_orientation", self.plc.get_macro_orientation(NODE_IDX))
        # print("is_node_placed", self.plc.is_node_placed(NODE_IDX))
        # print("get_source_filename", self.plc.get_source_filename())
        # print("get_blockages", self.plc.get_blockages())
        # print("get_ref_node_id", self.plc.get_ref_node_id(NODE_IDX), self.plc.get_ref_node_id(NODE_IDX))
        # print("get_node_mask\n", np.array(self.plc.get_node_mask(NODE_IDX)).reshape((4,4)))
        # print("can_place_node", self.plc.can_place_node(0, 1))
        print("***************************************************")

    def test_proxy_hpwl(self):
        print("############################ TEST PROXY WIRELENGTH ############################")
        # Google's Binary Executable
        self.plc = plc_client.PlacementCost(self.NETLIST_PATH)

        # Open-sourced Implementation
        self.plc_os = plc_client_os.PlacementCost(netlist_file=self.NETLIST_PATH,
                                                  macro_macro_x_spacing=50,
                                                  macro_macro_y_spacing=50)

        self.plc.get_overlap_threshold()
        print("overlap_threshold default", self.plc.get_overlap_threshold())

        if self.PLC_PATH:
            print("#[PLC FILE FOUND] Loading info from .plc file")
            self.plc_os.set_canvas_boundary_check(False)
            self.plc_os.restore_placement(self.PLC_PATH,
                                          ifInital=True,
                                          ifValidate=True,
                                          ifReadComment=False)
            self.plc.set_canvas_boundary_check(False)
            self.plc.restore_placement(self.PLC_PATH)
        else:
            print("#[PLC FILE MISSING] Using only netlist info")

        self.plc.set_routes_per_micron(self.RPMH, self.RPMV)
        self.plc_os.set_routes_per_micron(self.RPMH, self.RPMV)

        self.plc.set_macro_routing_allocation(self.MARH, self.MARV)
        self.plc_os.set_macro_routing_allocation(self.MARH, self.MARV)

        self.plc.set_congestion_smooth_range(self.SMOOTH)
        self.plc_os.set_congestion_smooth_range(self.SMOOTH)

        self.plc.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc.set_placement_grid(self.GRID_COL, self.GRID_ROW)
        self.plc_os.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc_os.set_placement_grid(self.GRID_COL, self.GRID_ROW)

        # HPWL
        try:
            assert int(self.plc_os.get_wirelength()) == int(self.plc.get_wirelength())
            assert abs(self.plc.get_cost() - self.plc_os.get_cost()) <= 1e-2
            print("#[INFO WIRELENGTH] Matched Wirelength cost -- GL {}, OS {}".format(
                str(self.plc.get_cost()), self.plc_os.get_cost()))
        except Exception as e:
            print("[ERROR WIRELENGTH] Discrepancies found when computing wirelength -- GL {}, OS {}".format(
                str(self.plc.get_cost()), self.plc_os.get_cost()))
            print("GL WIRELENGTH: ", self.plc.get_wirelength())
            print("OS WIRELENGTH: ", self.plc_os.get_wirelength())



    def test_proxy_density(self):
        print("############################ TEST PROXY DENSITY ############################")
        # Google's Binary Executable
        self.plc = plc_client.PlacementCost(self.NETLIST_PATH)

        # Open-sourced Implementation
        self.plc_os = plc_client_os.PlacementCost(netlist_file=self.NETLIST_PATH,
                                                  macro_macro_x_spacing=50,
                                                  macro_macro_y_spacing=50)

        self.plc.get_overlap_threshold()
        print("overlap_threshold default", self.plc.get_overlap_threshold())

        if self.PLC_PATH:
            print("#[PLC FILE FOUND] Loading info from .plc file")
            self.plc_os.set_canvas_boundary_check(False)
            self.plc_os.restore_placement(self.PLC_PATH,
                                          ifInital=True,
                                          ifValidate=True,
                                          ifReadComment=False)
            self.plc.set_canvas_boundary_check(False)
            self.plc.restore_placement(self.PLC_PATH)
        else:
            print("#[PLC FILE MISSING] Using only netlist info")

        self.plc.set_routes_per_micron(self.RPMH, self.RPMV)
        self.plc_os.set_routes_per_micron(self.RPMH, self.RPMV)

        self.plc.set_macro_routing_allocation(self.MARH, self.MARV)
        self.plc_os.set_macro_routing_allocation(self.MARH, self.MARV)

        self.plc.set_congestion_smooth_range(self.SMOOTH)
        self.plc_os.set_congestion_smooth_range(self.SMOOTH)

        self.plc.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc.set_placement_grid(self.GRID_COL, self.GRID_ROW)
        self.plc_os.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc_os.set_placement_grid(self.GRID_COL, self.GRID_ROW)

        # self.plc.make_soft_macros_square()
        # self.plc_os.make_soft_macros_square()
        # Density
        try:
            assert int(sum(self.plc_os.get_grid_cells_density())) == int(
                sum(self.plc.get_grid_cells_density()))
            assert int(self.plc_os.get_density_cost()) == int(
                self.plc.get_density_cost())
            print("#[INFO DENSITY] Matched density cost -- GL {}, OS {}".format(
                str(self.plc.get_density_cost()), self.plc_os.get_density_cost()))
        except Exception as e:
            print("[ERROR DENSITY] Discrepancies found when computing density -- GL {}, OS {}".format(
                str(self.plc.get_density_cost()), self.plc_os.get_density_cost()))
        gl_density = self.plc.get_grid_cells_density()
        os_density = self.plc_os.get_grid_cells_density()
        for cell_idx, (gl_dens, os_des) in enumerate(zip(gl_density, os_density)):
            print("PASS {}".format(str(cell_idx)) if abs(gl_dens - os_des) <= 1e-3 else "FAILED", gl_dens, os_des)
            if cell_idx == 0:
                break
        self.plc_os.display_canvas(annotate=True, amplify=True)

    def test_proxy_congestion(self):
        # Google's API
        self.plc = plc_client.PlacementCost(self.NETLIST_PATH)
        self.plc_os = plc_client_os.PlacementCost(self.NETLIST_PATH)

        # set rpm
        self.plc.set_routes_per_micron(self.RPMH, self.RPMV)
        self.plc_os.set_routes_per_micron(self.RPMH, self.RPMV)

        self.plc.set_macro_routing_allocation(self.MARH, self.MARV)
        self.plc_os.set_macro_routing_allocation(self.MARH, self.MARV)

        self.plc.set_congestion_smooth_range(2.0)
        self.plc_os.set_congestion_smooth_range(2.0)

        self.plc.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc.set_placement_grid(self.GRID_COL, self.GRID_ROW)
        self.plc_os.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc_os.set_placement_grid(self.GRID_COL, self.GRID_ROW)

        if self.PLC_PATH:
            print("#[PLC FILE FOUND] Loading info from .plc file")
            self.plc_os.set_canvas_boundary_check(False)
            self.plc_os.restore_placement(self.PLC_PATH,
                                          ifInital=True,
                                          ifValidate=True,
                                          ifReadComment=False)
            self.plc.set_canvas_boundary_check(False)
            self.plc.restore_placement(self.PLC_PATH)
        else:
            print("#[PLC FILE MISSING] Using only netlist info")

        temp_gl_h = np.array(self.plc.get_horizontal_routing_congestion())
        temp_os_h = np.array(self.plc_os.get_horizontal_routing_congestion())
        print(temp_gl_h.reshape(self.GRID_COL, self.GRID_ROW))
        print(temp_os_h.reshape(self.GRID_COL, self.GRID_ROW))

        print("GL H Congestion: ", self.plc.get_horizontal_routing_congestion())
        print("OS H Congestion: ", self.plc_os.get_horizontal_routing_congestion())

        temp_gl_v = np.array(self.plc.get_vertical_routing_congestion())
        temp_os_v = np.array(self.plc_os.get_vertical_routing_congestion())

        print(temp_gl_v.reshape(self.GRID_COL, self.GRID_ROW))
        print(temp_os_v.reshape(self.GRID_COL, self.GRID_ROW))

        print("GL V Congestion: ", self.plc.get_vertical_routing_congestion())
        print("OS V Congestion: ", self.plc_os.get_vertical_routing_congestion())

        print("congestion GL: ", self.plc.get_congestion_cost())
        print("congestion OS: ", self.plc_os.get_congestion_cost())
        if abs(self.plc.get_congestion_cost() - self.plc_os.get_congestion_cost()) > 1e-3:
            print("MISMATCH FOUND!!!****************")
        else:
            print("MATCHED!!! **********************")

        # EXTRACT ROUTING CONGESTION
        self.plc.set_macro_routing_allocation(0, 0)
        self.plc_os.set_macro_routing_allocation(0, 0)

        temp_gl_h_rt = np.array(self.plc.get_horizontal_routing_congestion())
        temp_os_h_rt = np.array(
            self.plc_os.get_horizontal_routing_congestion())

        temp_gl_v_rt = np.array(self.plc.get_vertical_routing_congestion())
        temp_os_v_rt = np.array(self.plc_os.get_vertical_routing_congestion())

        # H Macro congesiton = H Total congestion - H Routing congestion
        temp_gl_h_mc = (temp_gl_h - temp_gl_h_rt)
        temp_os_h_mc = (temp_os_h - temp_os_h_rt)

        # V Macro congesiton = V Total congestion - V Routing congestion
        temp_gl_v_mc = (temp_gl_v - temp_gl_v_rt)
        temp_os_v_mc = (temp_os_v - temp_os_v_rt)

        # print("GL H MACRO Congestion", (temp_gl_h_mc).reshape(self.GRID_COL, self.GRID_ROW))
        # print("OS H MACRO Congestion", (temp_os_h_mc).reshape(self.GRID_COL, self.GRID_ROW))
        print("H MACRO Congestion DIFF", np.where(
            abs(temp_gl_h_mc - temp_os_h_mc) > 1e-5))
        # print("GL V MACRO Congestion", (temp_gl_v_mc).reshape(self.GRID_COL, self.GRID_ROW))
        # print("OS V MACRO Congestion", (temp_os_v_mc).reshape(self.GRID_COL, self.GRID_ROW))
        print("V MACRO Congestion DIFF", np.where(
            abs(temp_gl_v_mc - temp_os_v_mc) > 1e-5))

        print("H Routing Congestion DIFF", np.where(
            abs(temp_gl_h_rt - temp_os_h_rt) > 1e-5))
        print("V Routing Congestion DIFF", np.where(
            abs(temp_gl_v_rt - temp_os_v_rt) > 1e-5))

        # self.plc_os.display_canvas()
        # BY ENTRY
        print("**************BY ENTRY DIFF")
        CELL_IDX = 0
        r = (CELL_IDX // 35)
        c = int(CELL_IDX % 35)
        print(r, c)
        print(temp_gl_h_rt[CELL_IDX], temp_os_h_rt[CELL_IDX])
        print(temp_gl_v_rt[CELL_IDX], temp_os_v_rt[CELL_IDX])

    def test_placement_util(self, keep_save_file=False):
        """
            * Read same input, perturb placement and orientation, write to new .plc
        """
        print(
            "############################ TEST PLACEMENT UTIL ############################")
        try:
            assert self.PLC_PATH
        except AssertionError:
            print("[ERROR PLACEMENT UTIL TEST] Facilitate required .plc file")
            exit(1)

        self.plc_util = placement_util.create_placement_cost(
            plc_client=plc_client,
            netlist_file=self.NETLIST_PATH,
            init_placement=self.PLC_PATH
        )

        self.plc_util_os = placement_util.create_placement_cost(
            plc_client=plc_client_os,
            netlist_file=self.NETLIST_PATH,
            init_placement=self.PLC_PATH
        )

        # node_xy_coordinates
        NODE_XY_DICT = {}
        for i in placement_util.nodes_of_types(self.plc_util_os, ['MACRO', 'STDCELL', 'PORT']):
            NODE_XY_DICT[i] = (randrange(int(self.plc_util.get_canvas_width_height()[0])),
                               randrange(int(self.plc_util.get_canvas_width_height()[1])))

        # macro_orientation
        MACRO_ORIENTATION = {}
        for i in placement_util.nodes_of_types(self.plc_util_os, ['MACRO']):
            MACRO_ORIENTATION[i] = "S"

        # ********************** plc_client_os **********************
        # placement_util.restore_node_xy_coordinates(self.plc_util_os, NODE_XY_DICT)

        placement_util.restore_macro_orientations(
            self.plc_util_os, MACRO_ORIENTATION)

        # fix ports
        placement_util.fix_port_coordinates(self.plc_util_os)

        # write out new plc
        placement_util.save_placement(
            self.plc_util_os, "save_test_os.plc", 'this is a comment')

        # ********************** plc_client **********************
        # placement_util.restore_node_xy_coordinates(self.plc_util, NODE_XY_DICT)

        placement_util.restore_macro_orientations(
            self.plc_util, MACRO_ORIENTATION)

        # fix ports
        placement_util.fix_port_coordinates(self.plc_util)

        # write out new plc
        placement_util.save_placement(
            self.plc_util, "save_test_gl.plc", 'this is a comment')

        # This is only for node information, line-by-line test
        try:
            with open('save_test_gl.plc') as f1, open('save_test_os.plc') as f2:
                for idx, (line1, line2) in enumerate(zip(f1, f2)):
                    if line1.strip() != line2.strip():
                        if not re.match(r"(# )\w+", line1.strip()):
                            print("PLC MISMATCH (GL, OS)\n",
                                  line1.strip(), "\n", line2.strip())
                            raise AssertionError("false")
        except AssertionError:
            print("[ERROR PLACEMENT UTIL] Saved PLC Discrepency found at line {}".format(
                str(idx)))
            exit(1)

        # if keep plc file for detailed comparison
        if not keep_save_file:
            os.remove('save_test_gl.plc')
            os.remove('save_test_os.plc')

        print("                  +++++++++++++++++++++++++++++++++")
        print("                  +++ TEST PLACEMENT UTIL: PASS +++")
        print("                  +++++++++++++++++++++++++++++++++")

    def test_observation_extractor(self):
        """
        plc = placement_util.create_placement_cost(
            netlist_file=netlist_file, init_placement='')
        plc.set_canvas_size(300, 200)
        plc.set_placement_grid(9, 4)
        plc.unplace_all_nodes()
        # Manually adds I/O port locations, this step is not needed for real
        # netlists.
        plc.update_node_coords('P0', 0.5, 100)  # Left
        plc.update_node_coords('P1', 150, 199.5)  # Top
        plc.update_port_sides()
        plc.snap_ports_to_edges()
        self.extractor = observation_extractor.ObservationExtractor(
            plc=plc, observation_config=self._observation_config)
        """

        print("############################ TEST OBSERVATION EXTRACTOR ############################")

        try:
            assert self.PLC_PATH
        except AssertionError:
            print("[ERROR OBSERVATION EXTRACTOR TEST] Facilitate required .plc file")
            exit(1)

        # Using the default edge/node
        self._observation_config = observation_config.ObservationConfig(
            max_num_edges=28400, max_num_nodes=5000, max_grid_size=128)

        self.plc_util = placement_util.create_placement_cost(
            plc_client=plc_client,
            netlist_file=self.NETLIST_PATH,
            init_placement=self.PLC_PATH
        )

        self.plc_util_os = placement_util.create_placement_cost(
            plc_client=plc_client_os,
            netlist_file=self.NETLIST_PATH,
            init_placement=self.PLC_PATH
        )

        self.extractor = observation_extractor.ObservationExtractor(
            plc=self.plc_util, observation_config=self._observation_config
        )

        self.extractor_os = observation_extractor.ObservationExtractor(
            plc=self.plc_util_os, observation_config=self._observation_config
        )
        # Unplacing all the nodes b/c by default everything is placed on board at initialization
        self.plc_util_os.unplace_all_nodes()
        self.plc_util.unplace_all_nodes()

        # Static features that are invariant across training steps
        static_feature_gl = self.extractor._extract_static_features()
        static_feature_os = self.extractor_os._extract_static_features()

        #
        for feature_gl, feature_os in zip(static_feature_gl, static_feature_os):
            try:
                assert (static_feature_gl[feature_gl] ==
                        static_feature_os[feature_os]).all()
            except AssertionError:
                print(
                    "[ERROR OBSERVATION EXTRACTOR TEST] Observation Feature Mismatch on "+str(feature_gl))
                print("GL FEATURE:")
                print(static_feature_gl[feature_gl])
                print("OS FEATURE:")
                print(static_feature_os[feature_os])
                exit(1)

        print("                  ++++++++++++++++++++++++++++++++++++++++")
        print("                  +++ TEST OBSERVATION EXTRACTOR: PASS +++")
        print("                  ++++++++++++++++++++++++++++++++++++++++")

    def test_place_node(self):
        print("############################ TEST PLACE NODE ############################")
        self.plc_util = placement_util.create_placement_cost(
            plc_client=plc_client,
            netlist_file=self.NETLIST_PATH,
            init_placement=None
        )

        self.plc_util_os = placement_util.create_placement_cost(
            plc_client=plc_client_os,
            netlist_file=self.NETLIST_PATH,
            init_placement=None
        )

        self.plc_util.set_routes_per_micron(self.RPMH, self.RPMV)
        self.plc_util_os.set_routes_per_micron(self.RPMH, self.RPMV)

        self.plc_util.set_macro_routing_allocation(self.MARH, self.MARV)
        self.plc_util_os.set_macro_routing_allocation(self.MARH, self.MARV)

        self.plc_util.set_congestion_smooth_range(self.SMOOTH)
        self.plc_util_os.set_congestion_smooth_range(self.SMOOTH)

        self.plc_util.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc_util.set_placement_grid(self.GRID_COL, self.GRID_ROW)
        self.plc_util_os.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc_util_os.set_placement_grid(self.GRID_COL, self.GRID_ROW)

        # MACRO placement order
        ordered_node_gl = placement_util.get_ordered_node_indices(
            mode='descending_size_macro_first', plc=self.plc_util)
        ordered_node_os = placement_util.get_ordered_node_indices(
            mode='descending_size_macro_first', plc=self.plc_util_os)

        try:
            assert (np.array(ordered_node_gl) == np.array(ordered_node_os)).all()
        except:
            print("[ERROR PLACE NODE] Node Ordering not matching!")

        # Initialize Placement
        self.plc_util_os.unplace_all_nodes()
        self.plc_util.unplace_all_nodes()

        self.plc_util_os.get_macro_indices()
        self._hard_macro_indices = [
            m for m in self.plc_util_os.get_macro_indices()
            if not self.plc_util_os.is_node_soft_macro(m)
        ]

        NODE_TO_PLACE_IDX = self._hard_macro_indices[0]
        # make sure this is within grid cell range
        CELL_TO_PLACE_IDX = 6
        print("[INFO PLACE NODE] MASK FOR PLACING FIRST NODE:")
        self.plc_util_os.display_canvas(annotate=False)
        print("OS NODE MASK:")
        print(np.flip(np.array(self.plc_util_os.get_node_mask(
            NODE_TO_PLACE_IDX)).reshape(self.GRID_ROW, self.GRID_COL), axis=0))
        print("GL NODE MASK:")
        print(np.flip(np.array(self.plc_util.get_node_mask(NODE_TO_PLACE_IDX)).reshape(
            self.GRID_ROW, self.GRID_COL), axis=0))

        self.plc_util_os.place_node(NODE_TO_PLACE_IDX, CELL_TO_PLACE_IDX)
        self.plc_util.place_node(NODE_TO_PLACE_IDX, CELL_TO_PLACE_IDX)

        # place node NODE_TO_PLACE_IDX @ position CELL_TO_PLACE_IDX
        NODE_TO_PLACE_IDX = self._hard_macro_indices[1]
        # make sure this is within grid cell range
        CELL_TO_PLACE_IDX = 18
        print("[INFO PLACE NODE] MASK FOR PLACING SECOND NODE:")
        print("OS NODE MASK:")
        print(np.flip(np.array(self.plc_util_os.get_node_mask(
            NODE_TO_PLACE_IDX)).reshape(self.GRID_ROW, self.GRID_COL), axis=0))
        print("GL NODE MASK:")
        print(np.flip(np.array(self.plc_util.get_node_mask(NODE_TO_PLACE_IDX)).reshape(
            self.GRID_ROW, self.GRID_COL), axis=0))
        self.plc_util_os.place_node(NODE_TO_PLACE_IDX, CELL_TO_PLACE_IDX)
        self.plc_util.place_node(NODE_TO_PLACE_IDX, CELL_TO_PLACE_IDX)

        self.plc_util_os.display_canvas(annotate=False)

    def test_google_fd(self):
        print("############################ TEST GOOGLE's FD Placer ############################")
        self.plc_util = placement_util.create_placement_cost(
            plc_client=plc_client,
            netlist_file=self.NETLIST_PATH,
            init_placement=self.PLC_PATH
        )

        self.plc_util.set_routes_per_micron(self.RPMH, self.RPMV)
        self.plc_util.set_macro_routing_allocation(self.MARH, self.MARV)
        self.plc_util.set_congestion_smooth_range(self.SMOOTH)
        self.plc_util.make_soft_macros_square()
        self.plc_util.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc_util.set_placement_grid(self.GRID_COL, self.GRID_ROW)

        self.plc_util_os = placement_util.create_placement_cost(
            plc_client=plc_client_os,
            netlist_file=self.NETLIST_PATH,
            init_placement=self.PLC_PATH
        )
        self.plc_util_os.set_routes_per_micron(self.RPMH, self.RPMV)
        self.plc_util_os.set_macro_routing_allocation(self.MARH, self.MARV)
        self.plc_util_os.set_congestion_smooth_range(self.SMOOTH)
        self.plc_util_os.make_soft_macros_square()
        self.plc_util_os.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc_util_os.set_placement_grid(self.GRID_COL, self.GRID_ROW)

        ## For final result
        # placement_util.fd_placement_schedule(self.plc_util, 
        #                 num_steps=(100,100),
        #                 io_factor=1.0,
        #                 move_distance_factors=(1.0,1.0),
        #                 attract_factor=(100.0,100.0),
        #                 repel_factor=(0.0,0.0),
        #                 use_current_loc=True,
        #                 move_macros=False)
        # for node_index in placement_util.nodes_of_types(self.plc_util, ['MACRO']):
        #         x_pos, y_pos = self.plc_util.get_node_location(node_index)
        #         print(x_pos, y_pos)
        #         self.plc_util_os.set_soft_macro_position(node_index, x_pos, y_pos)
            
        # self.plc_util_os.display_canvas(annotate=False, amplify=False)

        # For Step-by-step result
        temp_pos_collection= [[0,0]] * 10
        for node_index in placement_util.nodes_of_types(self.plc_util, ['MACRO']):
            x_pos, y_pos = self.plc_util.get_node_location(node_index)
            if self.plc_util.is_node_soft_macro(node_index):
                print(0, node_index,
                        x_pos, 
                        y_pos, 
                        x_pos - temp_pos_collection[node_index][0], 
                        y_pos - temp_pos_collection[node_index][1])
                temp_pos_collection[node_index] = [x_pos, y_pos]
            self.plc_util_os.set_soft_macro_position(node_index, x_pos, y_pos)
        
        # Step by step iteration
        for i in range(1, 41):
            # resetting the placement util
            self.plc_util = placement_util.create_placement_cost(
                plc_client=plc_client,
                netlist_file=self.NETLIST_PATH,
                init_placement=self.PLC_PATH
            )

            self.plc_util.set_routes_per_micron(self.RPMH, self.RPMV)
            self.plc_util.set_macro_routing_allocation(self.MARH, self.MARV)
            self.plc_util.set_congestion_smooth_range(self.SMOOTH)
            self.plc_util.make_soft_macros_square()
            self.plc_util.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
            self.plc_util.set_placement_grid(self.GRID_COL, self.GRID_ROW)
            
            placement_util.fd_placement_schedule(
                        self.plc_util, 
                        num_steps=(i,),
                        io_factor=1.0,
                        move_distance_factors=(1.0,),
                        attract_factor=(100.0,),
                        repel_factor=(100.0,),
                        use_current_loc=True,
                        move_macros=False)
            
            # sync with plc_util_os for visualization
            for node_index in placement_util.nodes_of_types(self.plc_util, ['MACRO']):
                x_pos, y_pos = self.plc_util.get_node_location(node_index)
                # print(temp_pos_collection)
                if self.plc_util.is_node_soft_macro(node_index):
                    print(i, node_index, 
                            x_pos, 
                            y_pos, 
                            x_pos - temp_pos_collection[node_index][0], 
                            y_pos - temp_pos_collection[node_index][1])
                    temp_pos_collection[node_index] = [x_pos, y_pos]
                self.plc_util_os.set_soft_macro_position(node_index, x_pos, y_pos)

            self.plc_util_os.display_canvas(annotate=True, amplify=True, saveName=str(i))

    def test_environment(self):
        print("############################ TEST ENVIRONMENT ############################")
        env = environment.CircuitEnv(
            _plc=plc_client,
            create_placement_cost_fn=placement_util.create_placement_cost,
            netlist_file=self.NETLIST_PATH,
            init_placement=self.PLC_PATH,
            unplace_all_nodes_in_init=False)

        env_os = environment.CircuitEnv(
            _plc=plc_client_os,
            create_placement_cost_fn=placement_util.create_placement_cost,
            netlist_file=self.NETLIST_PATH,
            init_placement=self.PLC_PATH,
            unplace_all_nodes_in_init=False)

        # Init Mask
        try:
            assert (env_os._get_mask() == env._get_mask()).all()
        except AssertionError:
            print("[ERROR ENVIRONMENT TEST] Init Mask failed")
            print("GL INIT MASK:")
            node_idx = env._sorted_node_indices[0]
            print(np.flip(np.array(env._plc.get_node_mask(node_idx)).reshape(
                env._plc.get_grid_num_columns_rows()), axis=0))
            print("OS INIT MASK:")
            print(np.flip(np.array(env_os._plc.get_node_mask(node_idx)).reshape(
                env_os._plc.get_grid_num_columns_rows()), axis=0))

            # check if node information is matching
            for idx in env._plc.get_macro_indices():
                try:
                    assert (env._plc.get_node_location(idx) != env_os._plc.get_node_location(idx))
                except AssertionError:
                    print("[ERROR ENVIRONMENT TEST] Node location not matching!")
                    print(idx, env._plc.get_node_location(idx), env_os._plc.get_node_location(idx))
                    exit(1)
                
                try:
                    assert abs(env._plc.get_node_width_height(idx)[0] - env_os._plc.get_node_width_height(idx)[0]) >= 1e-3 and \
                            abs(env._plc.get_node_width_height(idx)[1] - env_os._plc.get_node_width_height(idx)[1]) >= 1e-3
                except AssertionError:
                    print("[ERROR ENVIRONMENT TEST] Node dimension not matching!")
                    print(idx, env._plc.get_node_width_height(idx), env_os._plc.get_node_width_height(idx))
                    exit(1)

            env_os._plc.display_canvas(annotate=False)

        # check observation state
        obs_gl = env._get_obs()
        obs_os = env_os._get_obs()

        # env_os.reset()
        # env.reset()

        for feature_gl, feature_os in zip(obs_gl, obs_os):
            try:
                assert (obs_gl[feature_gl] == obs_os[feature_os]).all()
            except AssertionError:
                print("[ERROR ENVIRONMENT TEST] Failing on "+str(feature_gl))
                print(np.where(obs_gl[feature_gl] != obs_os[feature_os]))
                exit(1)

        print("                  ++++++++++++++++++++++++++++++")
        print("                  +++ TEST ENVIRONMENT: PASS +++")
        print("                  ++++++++++++++++++++++++++++++")

    def test_fd_placement(self):
        print("############################ TEST FDPLACEMENT ############################")
        # test FD placement in plc_client_os
        self.plc_util_os = placement_util.create_placement_cost(
            plc_client=plc_client_os,
            netlist_file=self.NETLIST_PATH,
            init_placement=self.PLC_PATH
        )

        # placement util is incapable of setting routing resources
        self.plc_util_os.set_routes_per_micron(self.RPMH, self.RPMV)
        self.plc_util_os.set_macro_routing_allocation(self.MARH, self.MARV)

        self.plc_util_os.set_congestion_smooth_range(self.SMOOTH)

        self.plc_util_os.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc_util_os.set_placement_grid(self.GRID_COL, self.GRID_ROW)

        # placement_util.fd_placement_schedule(self.plc_util_os)
        for i in range(1, 41):
            placement_util.fd_placement_schedule(
                        self.plc_util_os, 
                        num_steps=(i,),
                        io_factor=1.0,
                        move_distance_factors=(1.0,),
                        attract_factor=(100.0,),
                        repel_factor=(100.0,),
                        use_current_loc=True,
                        move_macros=False)

            self.plc_util_os.display_canvas(annotate=True, amplify=True, saveName=str(i))

        # test FD placement under FDPlacement folder
        # print(os.getcwd())
        # os.system("cd FDPlacement/ && python3 fd_placement_exp.py --netlist .{} \
        #     --width {} --height {} --col {} --row {} && cd -".format(
        #         self.NETLIST_PATH, self.CANVAS_WIDTH, 
        #         self.CANVAS_HEIGHT, self.GRID_COL, self.GRID_ROW
        #     )
        # )

        # self.plc_util_os = placement_util.create_placement_cost(
        #     plc_client=plc_client_os,
        #     netlist_file=self.NETLIST_PATH + ".final",
        # )
        # print(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        # self.plc_util_os.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        # self.plc_util_os.set_placement_grid(self.GRID_COL, self.GRID_ROW)
        # self.plc_util_os.make_soft_macros_square()
        # print(self.plc_util_os.get_canvas_width_height())

        # self.plc_util_os.display_canvas(annotate=True, amplify=True)

        # os.chdir()

def parse_flags(argv):
    parser = argparse_flags.ArgumentParser(
        description='An argparse + app.run example')
    parser.add_argument("--netlist", required=True,
                        help="Path to netlist in pb.txt")
    parser.add_argument("--plc", required=False,
                        help="Path to plc in .plc")
    parser.add_argument("--width", type=float, required=True,
                        help="Canvas width")
    parser.add_argument("--height", type=float, required=True,
                        help="Canvas height")
    parser.add_argument("--col", type=int, required=True,
                        help="Grid column")
    parser.add_argument("--row", type=int, required=True,
                        help="Grid row")
    parser.add_argument("--rpmh", type=float, default=10, required=False,
                        help="Grid row")
    parser.add_argument("--rpmv", type=float, default=10, required=False,
                        help="Grid row")
    parser.add_argument("--marh", type=float, default=10, required=False,
                        help="Grid row")
    parser.add_argument("--marv", type=float, default=10, required=False,
                        help="Grid row")
    parser.add_argument("--smooth", type=float, default=1, required=False,
                        help="Grid row")
    return parser.parse_args(argv[1:])


def main(args):
    if args.plc:
        PCT = PlacementCostTest(NETLIST_PATH=args.netlist,
                                PLC_PATH=args.plc,
                                width=args.width,
                                height=args.height,
                                column=args.col,
                                row=args.row,
                                rpmv=args.rpmv,
                                rpmh=args.rpmh,
                                marh=args.marh,
                                marv=args.marv,
                                smooth=args.smooth)
    else:
        PCT = PlacementCostTest(NETLIST_PATH=args.netlist,
                                width=args.width,
                                height=args.height,
                                column=args.col,
                                row=args.row,
                                rpmv=args.rpmv,
                                rpmh=args.rpmh,
                                marh=args.marh,
                                marv=args.marv,
                                smooth=args.smooth)

    """
    Uncomment any available tests
    """
    # PCT.test_metadata()
    # PCT.test_proxy_cost()
    # PCT.test_proxy_hpwl()
    # PCT.test_proxy_density()
    # PCT.test_proxy_congestion()
    # PCT.test_placement_util(keep_save_file=False)
    # PCT.test_place_node()
    # PCT.test_miscellaneous()
    # PCT.test_observation_extractor()
    # PCT.view_canvas()
    PCT.test_google_fd() # python3 -m Plc_client.plc_client_os_test --netlist ./Plc_client/test/1P1M2m/netlist.pb.txt --width 500 --height 500 --col 10 --row 10
    # PCT.test_environment()
    # PCT.test_fd_placement()


if __name__ == '__main__':
    app.run(main, flags_parser=parse_flags)
