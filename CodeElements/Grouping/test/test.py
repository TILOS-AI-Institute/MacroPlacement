import os
import sys
import argparse
# Load the src files
sys.path.append('../src')
from grouping import Grouping


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("--design", help = "design name", type = str, default = "ariane")
    parser.add_argument("--n_rows", help = "number of rows", type = int, default = "23")
    parser.add_argument("--n_cols", help = "number of cols", type = int, default = "27")
    parser.add_argument("--K_in", help = "K_in", type = int, default = "1")
    parser.add_argument("--K_out", help = "K_out", type = int, default = "1")
    parser.add_argument("--setup_file", help = "setup file for openroad (default = setup.tcl)", type =     str, default  = "setup.tcl")
    parser.add_argument("--global_net_threshold", help = "global net threshold", type = int, default  = 500)

    args = parser.parse_args()

    design = args.design
    n_rows = args.n_rows
    n_cols = args.n_cols
    K_in   = args.K_in
    K_out  = args.K_out
    setup_file = args.setup_file
    global_net_threshold = args.global_net_threshold

    # To use the grouping function, you need to specify the directory of src file
    src_dir = "../src"
    openroad_exe = "./openroad"  # You need to specify your openroad exe

    Grouping(design, n_rows, n_cols, K_in, K_out, setup_file, global_net_threshold, src_dir, openroad_exe)










