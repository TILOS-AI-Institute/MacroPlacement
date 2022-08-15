import unittest
import os
from Plc_client import plc_client_os as plc_client_os
from Plc_client import plc_client as plc_client


class CircuitDataBaseTest(unittest.TestCase):
    # NETLIST_PATH = "./Plc_client/test/ariane_hard2soft/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/ariane_soft2hard/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/ariane_port2soft/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/sample_clustered_nomacro/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/sample_clustered_macroxy/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/ariane/netlist.pb.txt"
    # NETLIST_PATH = "./Plc_client/test/ariane133/netlist.pb.txt"

    def test_proxy_cost(self):
        # Google's Binary Executable
        self.plc = plc_client_os.PlacementCost(self.NETLIST_PATH)
        # Open-sourced Implementation
        self.plc_os = plc_client_os.PlacementCost(netlist_file=self.NETLIST_PATH,
                                                macro_macro_x_spacing = 50,
                                                macro_macro_y_spacing = 50)
        # Google's Ariane
        CANVAS_HEIGHT = 
        CANVAS_WIDTH = 
        GRID_COL = 35
        GRID_ROW = 33

        # Ariane133
        CANVAS_HEIGHT = 
        CANVAS_WIDTH = 
        GRID_COL = 35
        GRID_ROW = 33


        print(self.plc.set_canvas_size(CANVAS_WIDTH, CANVAS_HEIGHT))
        print(self.plc.set_placement_grid(GRID_COL, GRID_ROW))

        assert int(self.plc_os.get_wirelength()) == int(self.plc.get_wirelength())
        assert int(self.plc_os.get_density_cost()) == int(self.plc.get_density_cost())
    
    def test_metadata(self):
        # Google's Binary Executable
        self.plc = plc_client_os.PlacementCost(self.NETLIST_PATH)
        # Open-sourced Implementation
        self.plc_os = plc_client_os.PlacementCost(netlist_file=self.NETLIST_PATH,
                                                macro_macro_x_spacing = 50,
                                                macro_macro_y_spacing = 50)

        assert self.plc_os.get_block_name() == self.plc_os.get_block_name()
        assert self.plc_os.get_project_name() == self.plc_os.get_project_name()
        assert int(self.plc_os.get_area()) == int(self.plc_os.get_area())
        
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
        
        assert self.plc.get_macro_adjacency() == self.plc_os.get_macro_adjacency()
    
    def test_miscellaneous(self):
        # Google's Binary Executable
        self.plc = plc_client_os.PlacementCost(self.NETLIST_PATH)
        # Open-sourced Implementation
        self.plc_os = plc_client_os.PlacementCost(netlist_file=self.NETLIST_PATH,
                                                macro_macro_x_spacing = 50,
                                                macro_macro_y_spacing = 50)
        

if __name__ == '__main__':
    unittest.main()