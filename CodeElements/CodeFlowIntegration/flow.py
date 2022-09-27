import os
import argparse
import time
import shutil
import sys
from math import sqrt
sys.path.append('../Clustering/src')
sys.path.append('../Gridding/src')
sys.path.append('../Grouping/src')
sys.path.append('../FormatTranslators/src')


from clustering import Clustering
from gridding import GriddingLefDefInterface
from grouping import Grouping


setup_file = "setup.tcl"
design = "ariane"
macro_lefs = ["./lefs/fakeram45_256x16.lef"]
openroad_exe = "./openroad"  # You need to specify your own openroad exe


##############################################
### Call Gridding Function
##############################################
gridding_src_dir = '../Gridding/src'
tolerance = 0.05
halo_width = 0.05
gridding = GriddingLefDefInterface(gridding_src_dir, design, setup_file, tolerance, halo_width, openroad_exe)
num_rows = gridding.GetNumRows()
num_cols = gridding.GetNumCols()

##############################################
### Call Grouping Function
##############################################
grouping_src_dir = '../Grouping/src'
grouping_rpt_dir = 'grouping_rpt'
K_in = 1
K_out = 1
global_net_threshold = 300
grouping = Grouping(design, num_rows, num_cols, K_in, K_out, setup_file, global_net_threshold, grouping_src_dir, openroad_exe)

# clean the rpt_dir
if not os.path.exists(grouping_rpt_dir):
    os.mkdir(grouping_rpt_dir)

cmd = "mv " + design + ".fix " + grouping_rpt_dir
os.system(cmd)

fixed_file = grouping_rpt_dir + "/" + design + ".fix"

##############################################
### Call Clustering Function
##############################################
clustering_src_dir = '../Clustering/src'
Nparts = 500
clustering = Clustering(design, clustering_src_dir, fixed_file, num_cols,
                        num_rows,  global_net_threshold, Nparts, setup_file, openroad_exe)
