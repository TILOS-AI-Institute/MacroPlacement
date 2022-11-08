import re
import os, sys
import math
import numpy as np
import logging
import matplotlib.pyplot as plt
import pandas as pd
from StatTest import util
# disable scientific notation
np.set_printoptions(suppress=True)
# print full array
np.set_printoptions(threshold=sys.maxsize)

"""Statistical Test docstrings.

    * Robustness
        *   Use EvalCT for fixed policy rollout on the same training 
            set but different initialization.
    * Stability
        *   Macro Movement Range 
    * Additional Note
        *   Loading weight back for training
"""


######################## META INFO ########################
# Directory that stores all plc file (must come from the same netlist)
PLC_DIR = "StatTest/test/flow2_68_1.3_ct"
PLC_PATH_COLLECTION = []
assert os.path.isdir(PLC_DIR)
# Top X% of largest movement range
TOP_X = 1

# List to store every plc coordinate
PLC_COORD = []

def init_method(plc_dir):
    """
    Scan through every .plc file
    """
    for __, __, files in os.walk(plc_dir):
        for plc_file in files:
            if plc_file.endswith((".plc")):
                plc_pth = os.path.join(plc_dir, plc_file)
                # plc path
                PLC_PATH_COLLECTION.append(plc_pth)
                print("#[INFO] Reading plc file {}".format(plc_pth))
                
                # store in numpy array for ease of computation
                temp_coord = np.empty((1,2), float)

                for cnt, line in enumerate(open(plc_pth, 'r')):
                    line_item = re.findall(r'[0-9A-Za-z\.\-]+', line)

                    # skip empty lines
                    if len(line_item) == 0:
                        continue

                    if all(re.match(r'[0-9FNEWS\.\-]+', it) for it in line_item)\
                        and len(line_item) == 5:
                        # extract pos
                        temp_coord = np.append(temp_coord, np.array([[float(line_item[1]),float(line_item[2])]]), axis=0)
            
                # remove header row
                temp_coord = temp_coord[1:, :]
                # make sure every plc is aligned
                if PLC_COORD:
                    assert PLC_COORD[-1].shape == temp_coord.shape

                PLC_COORD.append(temp_coord)
                # print(temp_coord)
                del temp_coord

def get_abs_dist():
    # store all pair-wise distance
    abs_dist_plc = np.empty((PLC_COORD[-1].shape[0],1), float)

    # pair-wise distance of all plc files
    for i in range(len(PLC_COORD)):
        for j in range(len(PLC_COORD)):
            if i == j:
                continue
            # find x/y position diff
            diff_coord = PLC_COORD[i] - PLC_COORD[j]
            # x_diff^2, y_diff^2
            diff_coord = np.power(diff_coord, 2)
            # sqrt(x_diff^2 + y_diff^2)
            abs_dist_coord = np.sqrt(diff_coord[:, 0] + diff_coord[:, 1])

            abs_dist_plc = np.append(abs_dist_plc, abs_dist_coord.reshape((-1, 1)), axis=1)

    # remove header col
    return abs_dist_plc[:, 1:]

def main():
    init_method(PLC_DIR)
    abs_dist_plc = get_abs_dist()

    TOP_N =  int(math.floor(abs_dist_plc.shape[0] * (TOP_X/100.0)))
    print("[INFO] Using TOP {}% Largest Macro Movement --- {} Macros in total.".format(TOP_X, TOP_N))

    ############ MACRO placement range maximum distance + visual ###############
    # across all the plc diff, the max distance [row wise]
    max_dist = np.amax(abs_dist_plc, axis=1)

    # top-n max distance
    topn_max_dist_idx = np.argpartition(max_dist, -TOP_N)[-TOP_N:]
    topn_max_dist_val = np.take(max_dist, topn_max_dist_idx)

    x = range(topn_max_dist_val.shape[0])
    y = topn_max_dist_val
    n = topn_max_dist_idx
    fig, ax = plt.subplots()
    ax.set_title("Top {}% Maximum Placement Range".format(TOP_X))
    ax.scatter(x, y, c = 'b')
    ax.set_xlabel("module index")
    ax.set_ylabel("distance")
    for i, txt in enumerate(n):
        ax.annotate(txt, (x[i], y[i]))
    plt.show()

    ######################## MACRO placement range box plot visual #############
    abs_dist_plc_df = pd.DataFrame(data=abs_dist_plc)
    topn_max_dist_df = abs_dist_plc_df.iloc[topn_max_dist_idx, :]
    topn_max_dist_df.T.boxplot()
    plt.title("Top {}% Placement Range".format(TOP_X))
    plt.xlabel("module index")
    plt.ylabel("distance")
    plt.show()

    ######################## Density Heatmap ########################
    util.extract_density_map(
                            os.path.join(PLC_DIR, "netlist.pb.txt"), 
                            PLC_PATH_COLLECTION[0],
                            ifshow=True
                            )

    ######################## Congestion Heatmap #####################
    util.extract_congestion_map(
                                os.path.join(PLC_DIR, "netlist.pb.txt"),
                                PLC_PATH_COLLECTION[0],
                                marh=7.143,
                                marv=8.339,
                                rpmh=11.285,
                                rpmv=12.605,
                                congestion_smooth_range=2,
                                ifshow=True
                                )
    
    ######################## L1 Norm & SSIM #####################
    # pair-wise distance of all plc files
    DENS_SMI = []
    DENS_L1 = []
    VCONG_SMI = []
    VCONG_L1 = []
    HCONG_SMI = []
    HCONG_L1 = []

    for i in range(len(PLC_PATH_COLLECTION)):
        for j in range(len(PLC_PATH_COLLECTION)):
            if i == j:
                continue
            
            print("####### Heat Map Comparison between {} and {} #######".format(os.path.basename(PLC_PATH_COLLECTION[i])
                                                                                    ,os.path.basename(PLC_PATH_COLLECTION[j])))
            dens_i = util.extract_density_map(os.path.join(PLC_DIR, "netlist.pb.txt"),
                                    PLC_PATH_COLLECTION[i],
                                    ifshow=False)
            dens_j = util.extract_density_map(os.path.join(PLC_DIR, "netlist.pb.txt"),
                                    PLC_PATH_COLLECTION[j],
                                    ifshow=False)

            print("#[INFO] Density map SMI: {}".format(util.SSIM(dens_i, dens_j)))
            print("#[INFO] Density map L1 Dist: {}".format(util.l1_norm(dens_i, dens_j)))

            DENS_SMI.append(util.SSIM(dens_i, dens_j))
            DENS_L1.append(util.l1_norm(dens_i, dens_j))
            
            vcong_i, hcong_i = util.extract_congestion_map(
                                                            os.path.join(PLC_DIR, "netlist.pb.txt"),
                                                            PLC_PATH_COLLECTION[i],
                                                            marh=7.143,
                                                            marv=8.339,
                                                            rpmh=11.285,
                                                            rpmv=12.605,
                                                            congestion_smooth_range=2,
                                                            ifshow=False
                                                            )

            vcong_j, hcong_j = util.extract_congestion_map(
                                                            os.path.join(PLC_DIR, "netlist.pb.txt"),
                                                            PLC_PATH_COLLECTION[j],
                                                            marh=7.143,
                                                            marv=8.339,
                                                            rpmh=11.285,
                                                            rpmv=12.605,
                                                            congestion_smooth_range=2,
                                                            ifshow=False
                                                            )
            
            print("#[INFO] V Congestion map SMI: {}".format(util.SSIM(vcong_i, vcong_j)))
            print("#[INFO] V Congestion map L1 Dist: {}".format(util.l1_norm(vcong_i, vcong_j)))
            print("#[INFO] H Congestion map SMI: {}".format(util.SSIM(hcong_i, hcong_j)))
            print("#[INFO] H Congestion map L1 Dist: {}".format(util.l1_norm(hcong_i, hcong_j)))

            VCONG_SMI.append(util.SSIM(vcong_i, vcong_j))
            VCONG_L1.append(util.l1_norm(vcong_i, vcong_j))
            HCONG_SMI.append(util.SSIM(hcong_i,hcong_j))
            HCONG_L1.append(util.l1_norm(hcong_i, hcong_j))

    print("DENS_SMI Range ({} ~ {})".format(min(DENS_SMI), max(DENS_SMI)))
    print("DENS_L1 Range ({} ~ {})".format(min(DENS_L1), max(DENS_L1)))
    print("VCONG_SMI Range ({} ~ {})".format(min(VCONG_SMI), max(VCONG_SMI)))
    print("VCONG_L1 Range ({} ~ {})".format(min(VCONG_L1), max(VCONG_L1)))
    print("HCONG_SMI Range ({} ~ {})".format(min(HCONG_SMI), max(HCONG_SMI)))
    print("HCONG_L1 Range ({} ~ {})".format(min(HCONG_L1), max(HCONG_L1)))

if __name__ == "__main__":
    main()