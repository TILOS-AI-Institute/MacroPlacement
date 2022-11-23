import os, sys
import pandas as pd
import numpy as np
import seaborn as sns
from Plc_client import plc_client_os
from Plc_client import placement_util_os as placement_util
import matplotlib.pyplot as plt
from skimage.metrics import structural_similarity

def heatmap(arr, title, show=True):
    """
    util function for generating heat map from numpy arrays
    """
    sns.set()
    ax = sns.heatmap(arr, vmin=0, vmax=1, cmap="YlGnBu")
    ax.set_title(title)
    ax.set_xlabel("Columns")
    ax.set_ylabel("Rows")
    if show:
        plt.show()
    else:
        plt.clf()

def extract_density_map(netlist_path, plc_path, ifshow=True):
    """
    wrapper function for extracting density map
    """
    plc_util_os = placement_util.create_placement_cost(
            plc_client=plc_client_os,
            netlist_file=netlist_path,
            init_placement=plc_path
        )

    grid_cols, grid_rows = plc_util_os.get_grid_num_columns_rows()

    dens_map = np.array(plc_util_os.get_grid_cells_density()).reshape(grid_rows, grid_cols)
    heatmap(dens_map, "Placement Density Heatmap", ifshow)

    return dens_map

def extract_congestion_map(netlist_path, plc_path, rpmh, rpmv, marh, marv, congestion_smooth_range, ifshow=True):
    """
    wrapper function for extracting congestion map
    """
    plc_util_os = placement_util.create_placement_cost(
            plc_client=plc_client_os,
            netlist_file=netlist_path,
            init_placement=plc_path
        )

    plc_util_os.set_routes_per_micron(rpmh, rpmv)
    plc_util_os.set_macro_routing_allocation(marh, marv)
    plc_util_os.set_congestion_smooth_range(congestion_smooth_range)

    grid_cols, grid_rows = plc_util_os.get_grid_num_columns_rows()

    # vertical routing congestion map
    vcong_map = np.array(plc_util_os.get_vertical_routing_congestion()).reshape(grid_rows, grid_cols)
    heatmap(vcong_map, "Placement Vertical Congestion Heatmap", ifshow)

    # horizontal routing congestion map
    hcong_map = np.array(plc_util_os.get_horizontal_routing_congestion()).reshape(grid_rows, grid_cols)
    heatmap(hcong_map, "Placement Horizontal Congestion Heatmap", ifshow)

    return vcong_map, hcong_map

def SSIM(a, b):
    return structural_similarity(a, b)

def l1_norm(a, b):
    return np.linalg.norm(normalize(a)-normalize(b), ord=1)

def normalize(a):
    return (a - np.min(a)) / (np.max(a) - np.min(a))