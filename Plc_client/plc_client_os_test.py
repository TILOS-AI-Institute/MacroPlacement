import unittest
import os
from Plc_client import plc_client_os as plc_client

class CircuitDataBaseTest(unittest.TestCase):
    NETLIST_PATH = "./Plc_client/test/ariane/netlist.pb.txt"

    def test_HPWL(self):
        self.plc = plc_client.PlacementCost(netlist_file=self.NETLIST_PATH,
                                                macro_macro_x_spacing = 50,
                                                macro_macro_y_spacing = 50)
        assert(int(self.plc.get_wirelength()) == 834660)

if __name__ == '__main__':
    unittest.main()