'''
This script can be used to evaluate proxy cost of clustered netlist.
Author: Sayak Kundu             email:sakundu@ucsd.edu

Requirements:
This code utilizes Google Circuit Training (CT)
(https://github.com/google-research/circuit_training) code and the plc_wrapper_main
(https://storage.googleapis.com/rl-infra-public/circuit-training/placement_cost/plc_wrapper_main)
binary to evaluate the proxy cost of the clustered netlist.
For more details please look into the README file in CT repo.

Steps to run this script:
1. First install CT
2. export PYTHONPATH=$PYTHONPATH:<CT Path>
3. python evaluate_clustered_netlist.py <pb_netlist> <plc_file> <output_dir/design>

Output:
This will print the initial proxy cost, final proxy cost (cost after FD repel).
It will save the following files:
    1. initial placement image <output_dir/design>_init.png
    2. final plc_file in as <output_dir/design>_post_repel.plc
    3. final placement image (after FD repel) <output_dir/design>_final.png

If you do not provide <output_dir/design> it will only print the initial and
post FD repel proxy cost.
'''
import sys
import os
sys.path.append(os.path.dirname(__file__))
from extract_net import pb_design
from circuit_training.environment import plc_client
from circuit_training.environment import placement_util
import matplotlib.pyplot as plt


def get_plc(plc_file, pb_netlist):
    plc = plc_client.PlacementCost(pb_netlist)
    design = pb_design('block', pb_netlist)
    design.read_netlist()
    design.read_plc(plc_file)
    plc.make_soft_macros_square()
    plc.set_canvas_size(design.plc_info.width, design.plc_info.height)
    plc.set_placement_grid(design.plc_info.columns, design.plc_info.rows)
    plc.set_routes_per_micron(design.plc_info.route_hor, design.plc_info.route_ver)
    plc.set_macro_routing_allocation(design.plc_info.macro_route_hor, design.plc_info.macro_route_ver)
    plc.set_congestion_smooth_range(design.plc_info.sm_factor)
    plc.set_overlap_threshold(design.plc_info.ovrlp_thrshld)
    plc.set_canvas_boundary_check(True)
    plc.restore_placement(plc_file)
    return plc

def plot_from_plc(plc, png_file = None):
    plt.figure(constrained_layout=True,figsize=(8,5),dpi=600)
    canvas_width, canvas_height = plc.get_canvas_width_height()
    for idx in plc.get_macro_indices():
        color = 'blue'
        if plc.is_node_soft_macro(idx):
            color = 'red'
        width, height = plc.get_node_width_height(idx)
        cx, cy = plc.get_node_location(idx)
        lx, ly = cx - width/2.0, cy - height/2
        rectangle = plt.Rectangle((lx, ly), width, height, fc = color, ec = "black")
        plt.gca().add_patch(rectangle)

    lx, ly, lw = 0.0, 0.0, 1.0
    ux, uy = lx + canvas_width, ly + canvas_height
    x, y = [lx, ux], [ly, ly]
    plt.plot(x,y, '-k', lw = lw)

    x, y = [lx, ux], [uy, uy]
    plt.plot(x,y, '-k', lw = lw)

    x, y = [lx, lx], [ly, uy]
    plt.plot(x,y, '-k', lw = lw)

    x, y = [ux, ux], [ly, uy]
    plt.plot(x,y, '-k', lw = lw)

    plt.xlim(lx, ux)
    plt.ylim(ly, uy)
    plt.axis("scaled")
    if png_file != None:
        plt.savefig(png_file)
    plt.show()
    return

def get_cost(plc, isPrint = True):
    wl_cost = plc.get_cost()
    den_cost = plc.get_density_cost()
    cong_cost = plc.get_congestion_cost()
    proxy_cost = wl_cost + 0.5*den_cost + 0.5*cong_cost

    if isPrint:
        print(f'WL Cost:{wl_cost}\nCongestion Cost:{cong_cost}\nDensity Cost:{den_cost}')
        print(f"Proxy Cost:{proxy_cost}")
    return proxy_cost

## Run Placement schedule only with repeal and plot it again ##
def fix_all_hard_macros(plc):
    for idx in plc.get_macro_indices():
        if plc.is_node_soft_macro(idx):
            plc.unfix_node_coord(idx)
        else:
            plc.fix_node_coord(idx)
    return

def fix_all_ports(plc):
    i = 0
    while True:
        node_type = plc.get_node_type(i)
        if node_type == '':
            break
        elif node_type == 'PORT':
            plc.fix_node_coord(i)
        i += 1
    return

def update_soft_macros_using_repeal(plc, isComplete = False):
    if isComplete:
        num_steps = (100, 100, 100)
        move_distance_factors = (1.0, 1.0, 1.0)
        attract_factor = (100, 1.0e-3, 1.0e-5)
        repel_factor = (0.0, 1.0e6, 1.0e7)
        use_current_loc = False
    else:
        num_steps = (100, 100)
        move_distance_factors = (1.0, 1.0)
        attract_factor = (1.0e-3, 1.0e-5)
        repel_factor = (1.0e6, 1.0e7)
        use_current_loc = True

    io_factor = 1.0
    move_macros = False

    canvas_size = max(plc.get_canvas_width_height())
    max_move_distance = [
        f * canvas_size / s for s, f in zip(num_steps, move_distance_factors)
    ]

    move_stdcells = True
    log_scale_conns = False
    use_sizes = False
    plc.optimize_stdcells(use_current_loc, move_stdcells, move_macros,
                            log_scale_conns, use_sizes, io_factor, num_steps,
                            max_move_distance, attract_factor, repel_factor)

if __name__ == '__main__':
    pb_netlist = sys.argv[1]
    plc_netlist = sys.argv[2]
    png_file = None
    png_file_init_path = None
    png_file_final_path = None
    plc_file_final_path = None
    if len(sys.argv) == 4:
        png_file = sys.argv[3]
        png_file_init_path = f"{png_file}_init.png"
        png_file_final_path = f"{png_file}_final.png"
        plc_file_final_path = f"{png_file}_post_repel.plc"

    plc = get_plc(plc_netlist, pb_netlist)
    print("Initial Proxy cost:")
    _ = get_cost(plc)

    plot_from_plc(plc, png_file_init_path)
    fix_all_hard_macros(plc)
    fix_all_ports(plc)
    update_soft_macros_using_repeal(plc)
    print("Final Proxy cost (After FD Repel):")
    _ = get_cost(plc)
    plot_from_plc(plc, png_file_final_path)
    if plc_file_final_path:
        placement_util.save_placement(plc, plc_file_final_path, 'Post FD repel placement')
