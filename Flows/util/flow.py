import os
import argparse
import time
import shutil
import sys
from math import sqrt
from gen_setup import gen_setup

run_dir = sys.argv[1]
output_dir = sys.argv[2]

run_dir = os.path.abspath(run_dir)
output_dir = os.path.abspath(output_dir)

## gen_setup create the setup.tcl file which is
## used in the later part of the code
design, halo_width, work_dir, setup_file = gen_setup(run_dir, output_dir)

tmp_dir = os.getcwd()
os.chdir(run_dir)
sys.path.append(f'{work_dir}/CodeElements/Clustering/src')
sys.path.append(f'{work_dir}/CodeElements/Gridding/src')
sys.path.append(f'{work_dir}/CodeElements/Grouping/src')
sys.path.append(f'{work_dir}/CodeElements/FormatTranslators/src')

from clustering import Clustering
from gridding import GriddingLefDefInterface
from grouping import Grouping
from FormatTranslators import LefDef2ProBufFormat
# setup_file = "setup.tcl"
# design = "ariane"
# macro_lefs = ["./lefs/fakeram45_256x16.lef"]

##############################################
### Call Gridding Function
##############################################
gridding_src_dir = f'{work_dir}/CodeElements/Gridding/src'
tolerance = 0.01
min_n_rows = 10
min_n_cols = 10
max_n_rows = 50
max_n_cols = 50
max_rows_times_cols = 3000
# halo_width = 5

gridding = GriddingLefDefInterface(gridding_src_dir, design, setup_file, tolerance, halo_width,
                                   min_n_rows, min_n_cols, max_n_rows, max_n_cols,
                                   max_rows_times_cols)
num_rows = gridding.GetNumRows()
num_cols = gridding.GetNumCols()

##############################################
### Call Grouping Function
##############################################
grouping_src_dir = f'{work_dir}/CodeElements/Grouping/src'
grouping_rpt_dir = f'{output_dir}/grouping_rpt'
K_in = 1
K_out = 1
global_net_threshold = 300
grouping = Grouping(design, num_rows, num_cols, K_in, K_out, setup_file, global_net_threshold, grouping_src_dir)

# clean the rpt_dir
if not os.path.exists(grouping_rpt_dir):
    os.mkdir(grouping_rpt_dir)

cmd = "mv " + design + ".fix " + grouping_rpt_dir
os.system(cmd)

cmd = "mv " + design + ".fix.old " + grouping_rpt_dir
os.system(cmd)

fixed_file = grouping_rpt_dir + "/" + design + ".fix.old"

##############################################
### Call Clustering Function
##############################################
clustering_src_dir = f'{work_dir}/CodeElements/Clustering/src'
chip_width = gridding.GetChipWidth()
chip_height = gridding.GetChipHeight()
num_std_cells = gridding.GetNumStdCells()
grid_width = chip_width / num_cols
Nparts = 500

# Based on the description of circuit training, [see line 180 at grouper.py]
# we set the following thresholds
step_threshold = sqrt(chip_width * chip_height) / 4.0
distance = step_threshold / 2.0
max_num_vertices = num_std_cells / Nparts / 4
Replace = False
print("[INFO] step_threshold : ", step_threshold)
print("[INFO] distance : ", distance)
print("[INFO] max_num_vertices : ", max_num_vertices)


clustering = Clustering(design, clustering_src_dir, fixed_file, step_threshold, distance,
             grid_width, max_num_vertices, global_net_threshold, Nparts, setup_file,
             output_dir, Replace)

cluster_def = f"{output_dir}/OpenROAD/clustered_netlist.def"
cluster_lef = f"{output_dir}/OpenROAD/clusters.lef"

os.chdir(tmp_dir)
