import os
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"
os.environ["TF_ENABLE_ONEDNN_OPTS"] = "0"
import re
import sys
import glob


## Provide the pat to the circuit_training
sys.path.append('/home/tool/anaconda/envs/circuit_training')
from circuit_training.environment import placement_util


from absl import flags
FLAGS = flags.FLAGS
flags.FLAGS([''])  # Parse flags with an empty argument list

def parse_initial_plc(filename):
    hor, ver, smooth = None, None, None
    used_hor, used_ver = None, None
    
    routes_pattern = re.compile(r".*Routes per micron, hor : (\S+)  ver : (\S+).*")
    used_routes_pattern = re.compile(r".*Routes used by macros, hor : (\S+)  ver : (\S+).*")
    smooth_pattern = re.compile(r".*Smoothing factor : (\S+).*")
    
    with open(filename, "r") as f:
        for line in f:
            match_routes = routes_pattern.match(line)
            if match_routes:
                hor, ver = match_routes.groups()
            match_used = used_routes_pattern.match(line)
            if match_used:
                used_hor, used_ver = match_used.groups()
            match_smooth = smooth_pattern.match(line)
            if match_smooth:
                smooth = match_smooth.group(1)
                
    return hor, ver, used_hor, used_ver, smooth

def get_cost(plc, print_details=False):
    hard_macro_indices = [(m, plc.get_node_location(m),
                           plc.get_grid_cell_of_node(m)) 
                           for m in plc.get_macro_indices() 
                          if not plc.is_node_soft_macro(m)]
    wirelength = plc.get_cost()
    congestion = plc.get_congestion_cost()
    density = plc.get_density_cost()
    total_cost = wirelength + 0.5 * congestion + 0.5 * density
    ## Print init cost
    init_details = f"Initial Wirelength: {wirelength}, Congestion: {congestion}, Density: {density} Total Cost: {total_cost}"
    print(f"{init_details}")
    plc.unplace_all_nodes()
    for m, _, grid_loc in hard_macro_indices:
        plc.place_node(m, grid_loc)
        
    ## Place soft macros
    placement_util.fd_placement_schedule(plc)
    wirelength = plc.get_cost()
    congestion = plc.get_congestion_cost()
    density = plc.get_density_cost()
    total_cost = wirelength + 0.5 * congestion + 0.5 * density
    if print_details:
        print(f"Wirelength: {wirelength}, Congestion: {congestion}, Density: {density} Total Cost: {total_cost}")
        
    
    return round(wirelength,3), round(congestion,3), round(density,3), round(total_cost,3), init_details

def get_details_only(design, netlist, plc_file):
    # get details from the plc file
    hor_val, ver_val, used_hor_val, used_ver_val, smooth_val = parse_initial_plc(plc_file)
    plc = placement_util.create_placement_cost(netlist, plc_file, horizontal_routes_per_micron = float(hor_val),
    vertical_routes_per_micron = float(ver_val), congestion_smooth_range = int(smooth_val),
    macro_horizontal_routing_allocation = float(used_hor_val),
    macro_vertical_routing_allocation = float(used_ver_val),
    macro_macro_x_spacing = 0.0, macro_macro_y_spacing = 0.0)
    plc.set_block_name(design)
    output_plc_file = plc_file.replace(".plc", "_fixed.plc")
    placement_util.save_placement(plc, output_plc_file)
    return

def get_details(run_dir, design, netlist, plc_file):
    # get details from the plc file
    hor_val, ver_val, used_hor_val, used_ver_val, smooth_val = parse_initial_plc(plc_file)
    ## Create a placement object
    plc = placement_util.create_placement_cost(netlist, plc_file, horizontal_routes_per_micron = float(hor_val),
    vertical_routes_per_micron = float(ver_val), congestion_smooth_range = int(smooth_val),
    macro_horizontal_routing_allocation = float(used_hor_val),
    macro_vertical_routing_allocation = float(used_ver_val),
    macro_macro_x_spacing = 0.0, macro_macro_y_spacing = 0.0)
    # , legacy_congestion_grid = True
    plc.set_block_name(design)
    wirelength, congestion, density, total_cost, init_details = get_cost(plc, print_details=True)
    
    # Save the updated plc file and tcl script placement in the run dir
    plc_file_name = f"{run_dir}/{design}_{wirelength}_{density}_{congestion}_{total_cost}.plc"
    user_comment = f"Input PLC: {plc_file} \n{init_details}"

    placement_util.save_placement(plc, plc_file_name, f"{user_comment}")
    
    ## Save the placement in tcl format
    tcl_file_name = f"{run_dir}/{design}_{wirelength}_{density}_{congestion}_{total_cost}.tcl"
    plc.save_placement_pnr(tcl_file_name, '', '', 'innovus', 'circuit_training')
    return wirelength, congestion, density, total_cost, plc

if __name__ == '__main__':
    # Inputs are netlist plc and run dir
    design = sys.argv[1]
    netlist = sys.argv[2]
    plc_files = sys.argv[3]
    run_dir = sys.argv[4]
    for plc_file in glob.glob(plc_files):
        print(f"PLC File: {plc_file}")
        get_details(run_dir, design, netlist, plc_file)
