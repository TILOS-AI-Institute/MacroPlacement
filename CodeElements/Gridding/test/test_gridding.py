import os
import argparse
import time
import shutil
import sys
sys.path.append('../src')
from gridding import GriddingLefDefInterface


if __name__ == '__main__':
    design = "ariane"
    src_dir = "../src"
    setup_file = "setup.tcl"
    tolerance = 0.1
    GriddingLefDefInterface(src_dir, design, setup_file, tolerance)

