import os
import argparse
import time
import shutil
import sys
from math import floor
sys.path.append('./utils')

####################################################################################
#### Extract hypergraph, instance, IO ports and outline from netlist
####################################################################################
def GenerateHypergraph(openroad_exe, setup_file, extract_hypergraph_file):
    temp_file = os.getcwd() + "/extract_hypergraph.tcl"
    cmd = "cp " + setup_file + " " + temp_file
    os.system(cmd)

    with open(extract_hypergraph_file) as f:
        content = f.read().splitlines()
    f.close()

    f = open(temp_file, "a")
    f.write("\n")
    for line in content:
        f.write(line + "\n")
    f.close()

    cmd = openroad_exe + " " + temp_file
    os.system(cmd)

    cmd = "rm " + temp_file
    os.system(cmd)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("design", help = "design name", type = str)
    parser.add_argument("n_rows", help = "number of rows", type = int)
    parser.add_argument("n_cols", help = "number of cols", type = int)
    parser.add_argument("--setup_file", help = "setup file for openroad (default = setup.tcl)", type = str, default  = "setup.tcl")
    args = parser.parse_args()

    design = args.design
    n_rows = args.n_rows
    n_cols = args.n_cols
    setup_file = args.setup_file

    pwd = os.getcwd()
    # Specify the location of hmetis exe and openroad exe
    openroad_exe = pwd + "/utils/openroad"
    extract_hypergraph_file  = pwd + "/utils/extract_hypergraph.tcl"

    # Generate Hypergraph file
    rpt_dir = pwd + "/rtl_mp"
    hypergraph_file = rpt_dir + "/" + design + ".hgr"
    io_name_file = hypergraph_file + ".io"
    instance_name_file = hypergraph_file + ".instance"
    outline_file = hypergraph_file + ".outline"
    GenerateHypergraph(openroad_exe, setup_file, extract_hypergraph_file)


    # Generate fix file
    fix_file = design + ".fix"
    print("[INFO] Generated fix file : ", fix_file)

    # Step 1: Grouping bundled IOs based on n_rows and n_cols
    with open(outline_file) as f:
        content = f.read().splitlines()
    f.close()

    items = content[0].split()
    floorplan_lx = float(items[0])
    floorplan_ly = float(items[1])
    floorplan_ux = float(items[2])
    floorplan_uy = float(items[3])

    width = (floorplan_ux - floorplan_lx) / n_cols
    height = (floorplan_uy - floorplan_ly) / n_rows

    group_map = {  }
    io_inst_map = {  }
    vertex_list = []

    grid_row_max = 100000000
    with open(io_name_file) as f:
        content = f.read().splitlines()
    f.close()

    for line in content:
        items = line.split()
        io_name = items[0]
        vertex_list.append(io_name)
        x = (float(items[1]) + float(items[3])) / 2.0
        y = (float(items[2]) + float(items[4])) / 2.0
        hash_id = floor(y / height) * grid_row_max + floor(x / width)
        io_inst_map[io_name] = hash_id
        if hash_id not in group_map:
            group_map[hash_id] = [io_name]
        else:
            group_map[hash_id].append(io_name)

    hash_id = max(group_map.keys()) + 1
    with open(instance_name_file) as f:
        content = f.read().splitlines()
    f.close()

    for line in content:
        items = line.split()
        inst_name = items[0]
        vertex_list.append(inst_name)
        if (int(items[1]) == 1):
            group_map[hash_id] = [inst_name]
            io_inst_map[inst_name] = hash_id
            hash_id += 1


    glue_inst = {  }
    with open(hypergraph_file) as f:
        content = f.read().splitlines()
    f.close()

    for i in range(1, len(content)):
        items = [vertex_list[int(item) -1] for item in content[i].split()]
        if(len(items) > 100):
            continue

        group_list = []
        flag = False
        for item in items:
            if item in io_inst_map:
                flag = True
                group_list.append(item)

        if (flag == True):
            for item in items:
                if item not in group_list:
                    for inst in group_list:
                        group_map[io_inst_map[inst]].append(item)
                        if item not in glue_inst:
                            glue_inst[item] = [inst]
                        else:
                            glue_inst[item].append(inst)



    for key, value in glue_inst.items():
        if(len(value) > 1):
            print(value)

    group_id = 0
    f = open(fix_file, "w")
    for key, value in group_map.items():
        line = "group_" + str(group_id) + ": "
        group_id += 1
        for io in value:
            line += io + " "
        line += "\n"
        f.write(line)
    f.close()



















