from absl import flags
from absl import app
from Plc_client import plc_client_os as plc_client_os
from Plc_client import plc_client as plc_client
import numpy as np
import sys
np.set_printoptions(threshold=sys.maxsize)
FLAGS = flags.FLAGS

class CircuitDataBaseTest():
    # NETLIST_PATH = "./Plc_client/test/ariane_hard2soft/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/ariane_soft2hard/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/ariane_port2soft/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/sample_clustered_nomacro/netlist.pb.txt"
    NETLIST_PATH = "./Plc_client/test/sample_clustered_macroxy/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/ariane/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/ariane133/netlist.pb.txt"

    def test_proxy_cost(self):
        # Google's Binary Executable
        self.plc = plc_client.PlacementCost(self.NETLIST_PATH)
        print(self.plc.get_canvas_width_height())
        # Open-sourced Implementation
        self.plc_os = plc_client_os.PlacementCost(netlist_file=self.NETLIST_PATH,
                                                macro_macro_x_spacing = 50,
                                                macro_macro_y_spacing = 50)
        # Google's Ariane
        CANVAS_WIDTH = 356.592
        CANVAS_HEIGHT = 356.640
        GRID_COL = 35
        GRID_ROW = 33

        # Ariane133
        # CANVAS_WIDTH = 1599.99
        # CANVAS_HEIGHT = 1598.8
        # GRID_COL = 50
        # GRID_ROW = 50

        # Sample clustered
        CANVAS_WIDTH = 80
        CANVAS_HEIGHT = 80
        GRID_COL = 5
        GRID_ROW = 5

        self.plc.set_canvas_size(CANVAS_WIDTH, CANVAS_HEIGHT)
        self.plc.set_placement_grid(GRID_COL, GRID_ROW)
        self.plc_os.set_canvas_size(CANVAS_WIDTH, CANVAS_HEIGHT)
        self.plc_os.set_placement_grid(GRID_COL, GRID_ROW)

        assert int(self.plc_os.get_wirelength()) == int(self.plc.get_wirelength())
        assert int(sum(self.plc_os.get_grid_cells_density())) == int(sum(self.plc.get_grid_cells_density()))
        assert int(self.plc_os.get_density_cost()) == int(self.plc.get_density_cost())
    
    def test_metadata(self):
        # Google's Binary Executable
        self.plc = plc_client.PlacementCost(self.NETLIST_PATH)
        # Open-sourced Implementation
        self.plc_os = plc_client_os.PlacementCost(netlist_file=self.NETLIST_PATH,
                                                macro_macro_x_spacing = 50,
                                                macro_macro_y_spacing = 50)


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
        
        assert sum(self.plc.get_macro_adjacency()) == sum(self.plc_os.get_macro_adjacency())
    
    def test_miscellaneous(self):
        # Google's Binary Executable
        self.plc = plc_client_os.PlacementCost(self.NETLIST_PATH)
        # Open-sourced Implementation
        self.plc_os = plc_client_os.PlacementCost(netlist_file=self.NETLIST_PATH,
                                                macro_macro_x_spacing = 50,
                                                macro_macro_y_spacing = 50)
        
def main(argv):
    temp = CircuitDataBaseTest()
    temp.test_proxy_cost()
    temp.test_metadata()
    temp.test_miscellaneous()

if __name__ == "__main__":
  app.run(main)