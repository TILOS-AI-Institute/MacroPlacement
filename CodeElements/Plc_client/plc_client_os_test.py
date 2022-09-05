import numpy as np
import sys,os,traceback
import argparse
import math,re
from absl import flags
from absl.flags import argparse_flags
from absl import app
from Plc_client import plc_client_os as plc_client_os
from Plc_client import placement_util_os as placement_util
from Plc_client import observation_extractor_os as observation_extractor
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
        
        $ python3 -m Plc_client.plc_client_os_test --netlist ./Plc_client/test/ariane133/netlist.pb.txt\
            --plc ./Plc_client/test/ariane133/initial.plc\
            --width 1599\
            --height 1600.06\
            --col 24\
            --row 21\
            --rpmh 10\
            --rpmv 10\
            --marh 5\
            --marv 5\
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
                                                macro_macro_x_spacing = 50,
                                                macro_macro_y_spacing = 50)

        # NOTE: must set canvas before restoring placement, otherwise OOB error
        self.plc.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc.set_placement_grid(self.GRID_COL, self.GRID_ROW)
        self.plc_os.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc_os.set_placement_grid(self.GRID_COL, self.GRID_ROW)

        if self.PLC_PATH:
            print("[PLC FILE FOUND] Loading info from .plc file")
            self.plc_os.set_canvas_boundary_check(False)
            self.plc_os.restore_placement(self.PLC_PATH,
                                            ifInital=True,
                                            ifValidate=True,
                                            ifReadComment=False)
            self.plc.set_canvas_boundary_check(False)
            self.plc.restore_placement(self.PLC_PATH)
        else:
            print("[PLC FILE MISSING] Using only netlist info")

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
            assert self.plc.get_congestion_smooth_range() == self.plc_os.get_congestion_smooth_range()

            self.plc.set_macro_routing_allocation(3.0, 4.0)
            self.plc_os.set_macro_routing_allocation(3.0, 4.0)
            assert self.plc.get_macro_routing_allocation() == self.plc_os.get_macro_routing_allocation()
        except Exception as e:
            _, _, tb = sys.exc_info()
            traceback.print_tb(tb)
            tb_info = traceback.extract_tb(tb)
            _, line, _, text = tb_info[-1]
            print('[METADATA ERROR] at line {} in statement {}'\
                .format(line, text))
            exit(1)
        
        # test get_macro_adjacency
        plc_macroadj = self.plc.get_macro_adjacency()
        plc_macroadj = np.array(plc_macroadj).reshape(int(math.sqrt(len(plc_macroadj))),\
             int(math.sqrt(len(plc_macroadj))))

        plcos_macroadj = self.plc_os.get_macro_adjacency()
        plcos_macroadj = np.array(plcos_macroadj).reshape(int(math.sqrt(len(plcos_macroadj))),\
             int(math.sqrt(len(plcos_macroadj))))

        try:
            assert(np.sum(np.nonzero(plc_macroadj - plcos_macroadj)) == 0)
        except Exception as e:
            print("[MACRO ADJ ERROR] Mismatched found -- {}".format(str(e)))
            exit(1)
        
        # test get_macro_and_clustered_port_adjacency
        plc_clusteradj, plc_cell = self.plc.get_macro_and_clustered_port_adjacency()
        plc_clusteradj = np.array(plc_clusteradj).reshape(int(math.sqrt(len(plc_clusteradj))),\
             int(math.sqrt(len(plc_clusteradj))))

        plcos_clusteradj, plcos_cell = self.plc_os.get_macro_and_clustered_port_adjacency()
        plcos_clusteradj = np.array(plcos_clusteradj).reshape(int(math.sqrt(len(plcos_clusteradj))),\
             int(math.sqrt(len(plcos_clusteradj))))

        try:
            for plc_adj, plcos_adj in zip(plc_clusteradj, plcos_clusteradj):
                assert(np.sum(np.nonzero(plc_adj - plcos_adj)) == 0)
        except Exception as e:
            print("[MACRO AND CLUSTERED PORT ADJ ERROR] Mismatched found -- {}".format(str(e)))
            exit(1)
        
        print("                  +++++++++++++++++++++++++++")
        print("                  +++ TEST METADATA: PASS +++")
        print("                  +++++++++++++++++++++++++++")
    
    def view_canvas(self):
        print("############################ VIEW CANVAS ############################")
        self.plc_os = plc_client_os.PlacementCost(netlist_file=self.NETLIST_PATH,
                                                macro_macro_x_spacing = 50,
                                                macro_macro_y_spacing = 50)
        self.plc.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc.set_placement_grid(self.GRID_COL, self.GRID_ROW)
        self.plc_os.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc_os.set_placement_grid(self.GRID_COL, self.GRID_ROW)
        # show canvas
        self.plc_os.display_canvas()

    def test_proxy_cost(self):
        print("############################ TEST PROXY COST ############################")
        # Google's Binary Executable
        self.plc = plc_client.PlacementCost(self.NETLIST_PATH)
        
        # Open-sourced Implementation
        self.plc_os = plc_client_os.PlacementCost(netlist_file=self.NETLIST_PATH,
                                                macro_macro_x_spacing = 50,
                                                macro_macro_y_spacing = 50)

        self.plc.get_overlap_threshold()
        print("overlap_threshold default", self.plc.get_overlap_threshold())
        
        if self.PLC_PATH:
            print("[PLC FILE FOUND] Loading info from .plc file")
            self.plc_os.set_canvas_boundary_check(False)
            self.plc_os.restore_placement(self.PLC_PATH,
                                            ifInital=True,
                                            ifValidate=True,
                                            ifReadComment=False)
            self.plc.set_canvas_boundary_check(False)
            # self.plc.restore_placement(self.PLC_PATH)
        else:
            print("[PLC FILE MISSING] Using only netlist info")

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

        # TODO: [IGNORE] create_blockage must be defined BEFORE set_canvas_size and set_placement_grid in order to be considered on the canvas
        if False:
            self.plc.create_blockage(0.0, 100.0, 300.0, 300.0, 1.0)
            self.plc.create_blockage(300,0,500,200,1)
            print(self.plc.get_blockages())
            print(self.plc.make_soft_macros_square())
            print(self.plc.set_use_incremental_cost(True))
            print(self.plc_os.get_soft_macros_count())

        # HPWL
        try:
            assert int(self.plc_os.get_wirelength()) == int(self.plc.get_wirelength())
            assert abs(self.plc.get_cost() - self.plc_os.get_cost()) <= 1e-3
        except Exception as e:
            print("[WIRELENGTH ERROR] Discrepancies found when computing wirelength -- {}, {}".format(str(self.plc.get_cost()), self.plc_os.get_cost()))
            exit(1)

        # Density
        try:
            print(self.plc_os.get_density_cost())
            assert int(sum(self.plc_os.get_grid_cells_density())) == int(sum(self.plc.get_grid_cells_density()))
            print(self.plc_os.get_density_cost())
            assert int(self.plc_os.get_density_cost()) == int(self.plc.get_density_cost())
        except Exception as e:
            print("[DENSITY ERROR] Discrepancies found when computing density -- {}, {}".format(str(self.plc.get_density_cost()), self.plc_os.get_density_cost()))
            exit(1)

        # Congestion
        try:
            print(self.plc_os.get_congestion_cost())
            assert abs(sum(self.plc_os.get_horizontal_routing_congestion()) - sum(self.plc.get_horizontal_routing_congestion())) < 1e-3
            assert abs(sum(self.plc_os.get_vertical_routing_congestion()) - sum(self.plc.get_vertical_routing_congestion())) < 1e-3
            print(self.plc_os.get_congestion_cost())
            assert abs(self.plc.get_congestion_cost() - self.plc_os.get_congestion_cost()) < 1e-3
        except Exception as e:
            print("[CONGESTION ERROR] Discrepancies found when computing congestion -- {}".format(str(e)))
            exit(1)

        print("                  +++++++++++++++++++++++++++++")
        print("                  +++ TEST PROXY COST: PASS +++")
        print("                  +++++++++++++++++++++++++++++")

    def test_miscellaneous(self):
        # Google's Binary Executable
        self.plc = plc_client.PlacementCost(self.NETLIST_PATH)
        self.plc_os = plc_client_os.PlacementCost(netlist_file=self.NETLIST_PATH,
                                                macro_macro_x_spacing = 50,
                                                macro_macro_y_spacing = 50)
        print("****************** miscellaneous ******************")
        self.plc.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc.set_placement_grid(self.GRID_COL, self.GRID_ROW)
        self.plc_os.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc_os.set_placement_grid(self.GRID_COL, self.GRID_ROW)
        NODE_IDX = 22853
        print("get_macro_indices", self.plc.get_macro_indices())
        print("get_node_name", self.plc.get_node_name(NODE_IDX))
        print("get_node_type", self.plc.get_node_type(NODE_IDX))
        print("get_node_location", self.plc.get_node_location(NODE_IDX))
        print("get_grid_cell_of_node", self.plc.get_grid_cell_of_node(NODE_IDX))
        print("get_macro_orientation", self.plc.get_macro_orientation(NODE_IDX))
        print("is_node_placed", self.plc.is_node_placed(NODE_IDX))
        print("get_source_filename", self.plc.get_source_filename())
        print("get_blockages", self.plc.get_blockages())
        print("get_ref_node_id", self.plc.get_ref_node_id(NODE_IDX), self.plc.get_ref_node_id(NODE_IDX))
        # print("get_node_mask\n", np.array(self.plc.get_node_mask(NODE_IDX)).reshape((4,4)))
        # print("can_place_node", self.plc.can_place_node(0, 1))
        print("***************************************************")
    
    def test_proxy_congestion(self):
        # Google's API
        self.plc = plc_client.PlacementCost(self.NETLIST_PATH)
        self.plc_os = plc_client_os.PlacementCost(self.NETLIST_PATH)

        # set rpm
        self.plc.set_routes_per_micron(10, 10)
        self.plc_os.set_routes_per_micron(10, 10)

        self.plc.set_macro_routing_allocation(10, 10)
        self.plc_os.set_macro_routing_allocation(10, 10)

        self.plc.set_congestion_smooth_range(0.0)
        self.plc_os.set_congestion_smooth_range(0.0)

        self.plc.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc.set_placement_grid(self.GRID_COL, self.GRID_ROW)
        self.plc_os.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc_os.set_placement_grid(self.GRID_COL, self.GRID_ROW)


        temp_gl_h = np.array(self.plc.get_horizontal_routing_congestion())
        temp_os_h =  np.array(self.plc_os.get_horizontal_routing_congestion())
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

        ###################################################################### EXTRACT ROUTING CONGESTION
        self.plc.set_macro_routing_allocation(0, 0)
        self.plc_os.set_macro_routing_allocation(0, 0)

        temp_gl_h_rt = np.array(self.plc.get_horizontal_routing_congestion())
        temp_os_h_rt =  np.array(self.plc_os.get_horizontal_routing_congestion())

        temp_gl_v_rt = np.array(self.plc.get_vertical_routing_congestion())
        temp_os_v_rt = np.array(self.plc_os.get_vertical_routing_congestion())

        temp_gl_h_mc = (temp_gl_h - temp_gl_h_rt).reshape(self.GRID_COL, self.GRID_ROW)
        temp_os_h_mc = (temp_os_h - temp_os_h_rt).reshape(self.GRID_COL, self.GRID_ROW)

        temp_gl_v_mc = (temp_gl_v - temp_gl_v_rt).reshape(self.GRID_COL, self.GRID_ROW)
        temp_os_v_mc = (temp_os_v - temp_os_v_rt).reshape(self.GRID_COL, self.GRID_ROW)

        # print("GL H MACRO Congestion", (temp_gl_h_mc).reshape(self.GRID_COL, self.GRID_ROW))
        # print("OS H MACRO Congestion", (temp_os_h_mc).reshape(self.GRID_COL, self.GRID_ROW))
        print("H MACRO Congestion DIFF", np.where(abs(temp_gl_h_mc - temp_os_h_mc) > 1e-5))

        # print("GL V MACRO Congestion", (temp_gl_v_mc).reshape(self.GRID_COL, self.GRID_ROW))
        # print("OS V MACRO Congestion", (temp_os_v_mc).reshape(self.GRID_COL, self.GRID_ROW))
        print("V MACRO Congestion DIFF", np.where(abs(temp_gl_v_mc - temp_os_v_mc) > 1e-5))

        ####################################################################### BY ENTRY
        print("**************BY ENTRY DIFF")
        print(temp_gl_h_mc[0][6], temp_os_h_mc[0][6])

    def test_placement_util(self, keep_save_file=False):
        """
            * Read same input, perturb placement and orientation, write to new .plc
        """
        print("############################ TEST PLACEMENT UTIL ############################")
        try:
            assert self.PLC_PATH
        except AssertionError:
            print("[ERROR PLACEMENT UTIL TEST] Facilitate required .plc file")
        
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
        # ********************** plc_client_os ********************** 
        # node_xy_coordinates
        # NODE_XY_DICT = {}
        # for i in placement_util.nodes_of_types(self.plc_util_os, ['MACRO', 'STDCELL', 'PORT']):
        #     NODE_XY_DICT[i] = (100, 100)
        
        # placement_util.restore_node_xy_coordinates(self.plc_util_os, NODE_XY_DICT)

        # macro_orientation
        MACRO_ORIENTATION = {}
        for i in placement_util.nodes_of_types(self.plc_util_os, ['MACRO']):
            MACRO_ORIENTATION[i] = "S"

        placement_util.restore_macro_orientations(self.plc_util_os, MACRO_ORIENTATION)

        # fix ports
        placement_util.fix_port_coordinates(self.plc_util_os)

        # write out new plc
        placement_util.save_placement(self.plc_util_os, "save_test_os.plc", 'this is a comment')

        # ********************** plc_client ********************** 
        # # node_xy_coordinates
        # NODE_XY_DICT = {}
        # for i in placement_util.nodes_of_types(self.plc_util, ['MACRO', 'STDCELL', 'PORT']):
        #     NODE_XY_DICT[i] = (100, 100)
        
        # placement_util.restore_node_xy_coordinates(self.plc_util, NODE_XY_DICT)

        # macro_orientation
        MACRO_ORIENTATION = {}
        for i in placement_util.nodes_of_types(self.plc_util, ['MACRO']):
            MACRO_ORIENTATION[i] = "S"

        placement_util.restore_macro_orientations(self.plc_util, MACRO_ORIENTATION)

        # fix ports
        placement_util.fix_port_coordinates(self.plc_util)

        # write out new plc
        placement_util.save_placement(self.plc_util, "save_test_gl.plc", 'this is a comment')

        print("                  +++++++++++++++++++++++++++++++++")
        print("                  +++ TEST PLACEMENT UTIL: PASS +++")
        print("                  +++++++++++++++++++++++++++++++++")

        # This is only for node information, line-by-line test
        try:
            with open('save_test_gl.plc') as f1, open('save_test_os.plc') as f2:
                for idx, (line1, line2) in enumerate(zip(f1, f2)):
                    if line1.strip() != line2.strip():
                        if not re.match(r"(# )\w+", line1.strip()):
                            print("PLC MISMATCH (GL, OS)\n", line1.strip(), "\n", line2.strip())
                            raise AssertionError ("false")
        except AssertionError:
            print("[ERROR PLACEMENT UTIL] Saved PLC Discrepency found at line {}".format(str(idx)))

        # if keep plc file for detailed comparison
        if not keep_save_file:
            os.remove('save_test_gl.plc')
            os.remove('save_test_os.plc')

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
        try:
            assert self.PLC_PATH
        except AssertionError:
            print("[ERROR OBSERVATION EXTRACTOR TEST] Facilitate required .plc file")

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

        # Static features that are invariant across training steps
        static_feature_gl = self.extractor._extract_static_features()
        static_feature_os = self.extractor_os._extract_static_features()
        for feature_gl, feature_os in zip(static_feature_gl, static_feature_os):
            assert (static_feature_gl[feature_gl] == static_feature_os[feature_os]).all()

        print("                  ++++++++++++++++++++++++++++++++++++++++")
        print("                  +++ TEST OBSERVATION EXTRACTOR: PASS +++")
        print("                  ++++++++++++++++++++++++++++++++++++++++")

    def test_place_node(self):
        pass

    def test_environment(self):
        pass

def parse_flags(argv):
    parser = argparse_flags.ArgumentParser(description='An argparse + app.run example')
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
    
    # PCT.test_metadata()
    PCT.test_proxy_cost()
    # PCT.test_placement_util()
    # PCT.test_miscellaneous()
    PCT.test_observation_extractor()

if __name__ == '__main__':
    app.run(main, flags_parser=parse_flags)