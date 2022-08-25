from absl import flags
from absl import app
from Plc_client import plc_client_os as plc_client_os
from Plc_client import plc_client as plc_client
import numpy as np
import sys
import time
import math
np.set_printoptions(threshold=sys.maxsize)
FLAGS = flags.FLAGS

class CircuitDataBaseTest():
    # NETLIST_PATH = "./Plc_client/test/sample_clustered_uniform_two_soft/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/ariane_hard2soft/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/ariane_soft2hard/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/ariane_port2soft/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/sample_clustered_nomacro/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/sample_clustered_macroxy/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/ariane/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/ariane133/netlist.pb.txt"
    NETLIST_PATH = "./Plc_client/test/testcases/TC1_MP1_0_0_P2_0_1.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/testcases/TC24_MP1_0_0_MP2_4_4.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/0P1M1m/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/0P2M0m/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/0P3M0m/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/0P4M0m/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/testcases_xm/TC_MP1_4_1_MP2_2_2_MP3_3_4_MP4_0_0.pb.txt"

    # Google's Ariane
    CANVAS_WIDTH = 356.592
    CANVAS_HEIGHT = 356.640
    GRID_COL = 35
    GRID_ROW = 33

    # Ariane133
    # CANVAS_WIDTH = 1599.99
    # CANVAS_HEIGHT = 1600.06
    # GRID_COL = 24
    # GRID_ROW = 21

    # Sample clustered
    # CANVAS_WIDTH = 400
    # CANVAS_HEIGHT = 400
    # GRID_COL = 4
    # GRID_ROW = 4

    # PMm
    # CANVAS_WIDTH = 100
    # CANVAS_HEIGHT = 100
    # GRID_COL = 20
    # GRID_ROW = 20

    def __init__(self, NETLIST_PATH) -> None:
        self.NETLIST_PATH = NETLIST_PATH

    def test_proxy_congestion(self):
        # Google's Binary Executable
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

        print("Name: ", self.plc.get_source_filename().rsplit("/", 1)[1])

        # self.plc_os.display_canvas()

        # start = time.time()
        temp_gl_h = self.plc.get_horizontal_routing_congestion()
        temp_os_h = self.plc_os.get_horizontal_routing_congestion()
        # print(np.array(temp_gl_h).reshape(self.GRID_COL, self.GRID_ROW))
        # print(np.array(temp_os_h).reshape(self.GRID_COL, self.GRID_ROW))

        print("GL H Congestion: ", temp_gl_h)
        print("OS H Congestion: ", temp_os_h)

        temp_gl_v = self.plc.get_vertical_routing_congestion()
        temp_os_v = self.plc_os.get_vertical_routing_congestion()
        
        # print(np.array(temp_gl_v).reshape(self.GRID_COL, self.GRID_ROW))
        # print(np.array(temp_os_v).reshape(self.GRID_COL, self.GRID_ROW))

        print("GL V Congestion: ", self.plc.get_vertical_routing_congestion())
        print("OS V Congestion: ", self.plc_os.get_vertical_routing_congestion())
        # end = time.time()
        # print("time elapsed:", end - start)

        # for idx in range(len(temp_gl_h)):
        #     print("gl, os:", temp_gl_h[idx], temp_os_h[idx], temp_gl_v[idx], temp_os_v[idx])

        # print("congestion summation gl os", sum(temp_gl_h), sum(temp_os_h), sum(temp_gl_v), sum(temp_os_v))
        print("congestion GL: ", self.plc.get_congestion_cost())
        print("congestion OS: ", self.plc_os.get_congestion_cost())

    def test_proxy_cost(self):
        # Google's Binary Executable
        self.plc = plc_client.PlacementCost(self.NETLIST_PATH)
        
        # Open-sourced Implementation
        self.plc_os = plc_client_os.PlacementCost(netlist_file=self.NETLIST_PATH,
                                                macro_macro_x_spacing = 50,
                                                macro_macro_y_spacing = 50)

        self.plc.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc.set_placement_grid(self.GRID_COL, self.GRID_ROW)
        self.plc_os.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc_os.set_placement_grid(self.GRID_COL, self.GRID_ROW)

        # print(self.plc_os.display_canvas())
        
        print(self.plc_os.get_wirelength(), self.plc.get_wirelength())

        # assert int(self.plc_os.get_wirelength()) == int(self.plc.get_wirelength())
        print("os wl cost", self.plc_os.get_cost())
        print("gl wl cost", self.plc.get_cost())
        assert abs(self.plc.get_cost() - self.plc_os.get_cost()) <= 10e-3
        print("gl density\n", np.array(self.plc.get_grid_cells_density()).reshape(self.GRID_COL, self.GRID_ROW))
        print("os density\n", np.array(self.plc_os.get_grid_cells_density()).reshape(self.GRID_COL, self.GRID_ROW))

        assert int(sum(self.plc_os.get_grid_cells_density())) == int(sum(self.plc.get_grid_cells_density()))
        assert int(self.plc_os.get_density_cost()) == int(self.plc.get_density_cost())
        print("os density cost", self.plc_os.get_density_cost())
        print("gl density cost", self.plc.get_density_cost())
    
    def test_metadata(self):
        # Google's Binary Executable
        self.plc = plc_client.PlacementCost(self.NETLIST_PATH)
        # Open-sourced Implementation
        self.plc_os = plc_client_os.PlacementCost(netlist_file=self.NETLIST_PATH,
                                                macro_macro_x_spacing = 50,
                                                macro_macro_y_spacing = 50)
        
        self.plc.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc.set_placement_grid(self.GRID_COL, self.GRID_ROW)
        self.plc_os.set_canvas_size(self.CANVAS_WIDTH, self.CANVAS_HEIGHT)
        self.plc_os.set_placement_grid(self.GRID_COL, self.GRID_ROW)

        self.plc_os.get_grid_cells_density()

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
        
        # test get_macro_adjacency
        plc_macroadj = self.plc.get_macro_adjacency()
        plc_macroadj = np.array(plc_macroadj).reshape(int(math.sqrt(len(plc_macroadj))),\
             int(math.sqrt(len(plc_macroadj))))

        plcos_macroadj = self.plc_os.get_macro_adjacency()
        plcos_macroadj = np.array(plcos_macroadj).reshape(int(math.sqrt(len(plcos_macroadj))),\
             int(math.sqrt(len(plcos_macroadj))))

        assert(np.sum(np.nonzero(plc_macroadj - plcos_macroadj)) == 0)
        
        # test get_macro_and_clustered_port_adjacency
        plc_clusteradj, plc_cell = self.plc.get_macro_and_clustered_port_adjacency()
        plc_clusteradj = np.array(plc_clusteradj).reshape(int(math.sqrt(len(plc_clusteradj))),\
             int(math.sqrt(len(plc_clusteradj))))

        plcos_clusteradj, plcos_cell = self.plc_os.get_macro_and_clustered_port_adjacency()
        plcos_clusteradj = np.array(plcos_clusteradj).reshape(int(math.sqrt(len(plcos_clusteradj))),\
             int(math.sqrt(len(plcos_clusteradj))))

        assert(plc_cell == plcos_cell)

        for plc_adj, plcos_adj in zip(plc_clusteradj, plcos_clusteradj):
            assert(np.sum(np.nonzero(plc_adj - plcos_adj)) == 0)

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
        NODE_IDX = 0
        print("get_macro_indices", self.plc.get_macro_indices(), self.plc_os.get_macro_indices())
        print("get_node_name", self.plc.get_node_name(NODE_IDX))
        print("get_node_location", self.plc.get_node_location(NODE_IDX))
        print("get_grid_cell_of_node", self.plc.get_grid_cell_of_node(NODE_IDX))
        print("get_node_location", self.plc.get_node_location(NODE_IDX))
        print("get_macro_orientation", self.plc.get_macro_orientation(NODE_IDX))
        print("is_node_placed", self.plc.is_node_placed(NODE_IDX))
        print("get_source_filename", self.plc.get_source_filename())
        print("get_blockages", self.plc.get_blockages())
        print("get_ref_node_id", self.plc.get_ref_node_id(NODE_IDX), self.plc.get_ref_node_id(NODE_IDX))
        print("get_node_mask\n", np.array(self.plc.get_node_mask(NODE_IDX)).reshape((4,4)))
        print("can_place_node", self.plc.can_place_node(0, 1))
        print("***************************************************")

        
def main(argv):
    args = sys.argv[1:]
    temp = CircuitDataBaseTest(args[0])
    temp.test_proxy_congestion()
    # temp.test_proxy_cost()
    # temp.test_metadata()
    # temp.test_miscellaneous()

if __name__ == "__main__":
  app.run(main)