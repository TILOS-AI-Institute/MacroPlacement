import re
import os, sys
import math
import numpy as np
import logging
import matplotlib.pyplot as plt
import pandas as pd

from torch import argmax
# disable scientific notation
np.set_printoptions(suppress=True)
# print full array
np.set_printoptions(threshold=sys.maxsize)

'''
META INFO
'''
# Directory that stores all plc file (must come from the same netlist)
PLC_DIR = "Plc_client/test/ariane"
assert os.path.isdir(PLC_DIR)
# Top X% of largest movement range
TOP_X = 1

# List to store every plc coordinate
PLC_COORD = []

# scan through every .plc file
for __, __, files in os.walk(PLC_DIR):
    for plc_file in files:
        if plc_file.endswith((".plc")):
            plc_pth = os.path.join(PLC_DIR, plc_file)
            print("[INFO] Reading plc file {}".format(plc_pth))
            
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
            print(temp_coord)
            del temp_coord

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
abs_dist_plc = abs_dist_plc[:, 1:]

TOP_N =  int(math.floor(abs_dist_plc.shape[0] * (TOP_X/100.0)))
print(TOP_N)

'''
MACRO placement maximum distance + visual
'''
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

'''
MACRO placement box plot visual
'''
abs_dist_plc_df = pd.DataFrame(data=abs_dist_plc)
topn_max_dist_df = abs_dist_plc_df.iloc[topn_max_dist_idx, :]
topn_max_dist_df.T.boxplot()
plt.title("Top {}% Placement Range".format(TOP_X))
plt.xlabel("module index")
plt.ylabel("distance")
plt.show()
'''
MACRO placement variane test
'''

'''
MACRO placement std dev test
'''

