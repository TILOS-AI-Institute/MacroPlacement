import os
import argparse
import time
import shutil
import sys
from math import floor

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


####################################################################################
#### TraverseFanout in BFS manner
####################################################################################
def TraverseFanout(vertices_list, hyperedges_list, vertex_hash, seed_id, root_id, K_out):
    # update the root vertex
    vertex_hash[root_id] = [seed_id, 0]

    visited = []
    wavefront = []

    wavefront.append(root_id)

    while (len(wavefront) > 0):
        vertex_id = wavefront.pop(0)
        visited.append(vertex_id)
        level_id = vertex_hash[vertex_id][1] + 1
        if (level_id <= K_out):
            for hyperedge_id in vertices_list[vertex_id]:
                hyperedge = hyperedges_list[hyperedge_id]
                # This hyperedge is driven by current edge
                if (hyperedge[0] == vertex_id):
                    for i in range(1, len(hyperedge)):
                        if hyperedge[i] in visited:
                            pass
                        else:
                            if (vertex_hash[hyperedge[i]][1] > level_id):
                                vertex_hash[hyperedge[i]] = [seed_id, level_id]
                                wavefront.append(hyperedge[i])
                            elif (vertex_hash[hyperedge[i]][1] == level_id and vertex_hash[hyperedge[i]][1] > seed_id):
                                vertex_hash[hyperedge[i]] = [seed_id, level_id]
                                wavefront.append(hyperedge[i])


####################################################################################
#### TraverseFanin in BFS manner
####################################################################################
def TraverseFanin(vertices_list, hyperedges_list, vertex_hash, seed_id, root_id, K_in):
    # update the root vertex
    vertex_hash[root_id] = [seed_id, 0]

    visited = []
    wavefront = []

    wavefront.append(root_id)

    while (len(wavefront) > 0):
        vertex_id = wavefront.pop(0)
        visited.append(vertex_id)
        level_id = vertex_hash[vertex_id][1] + 1
        if (level_id <= K_in):
            for hyperedge_id in vertices_list[vertex_id]:
                hyperedge = hyperedges_list[hyperedge_id]
                # This hyperedge is not driven by vertex_id
                if (hyperedge[0] != vertex_id):
                    driver_id = hyperedge[0]
                    if driver_id in visited:
                        pass
                    else:
                        if (vertex_hash[driver_id][1] > level_id):
                            vertex_hash[driver_id] = [seed_id, level_id]
                            wavefront.append(driver_id)
                        elif (vertex_hash[driver_id][1] == level_id and vertex_hash[driver_id][1] > seed_id):
                            vertex_hash[driver_id] = [seed_id, level_id]
                            wavefront.append(driver_id)


def Grouping(design, n_rows, n_cols, K_in, K_out, setup_file, global_net_threshold, src_dir):
    pwd = os.getcwd()
    # Specify the location of hmetis exe and openroad exe
    openroad_exe = src_dir + "/utils/openroad"
    extract_hypergraph_file  = src_dir + "/utils/extract_hypergraph.tcl"

    # Generate Hypergraph file
    rpt_dir = pwd + "/rtl_mp"
    hypergraph_file = rpt_dir + "/" + design + ".hgr"
    io_name_file = hypergraph_file + ".io"
    instance_name_file = hypergraph_file + ".instance"
    outline_file = hypergraph_file + ".outline"
    fix_file = pwd + "/" + design  + ".fix"
    original_fix_file = pwd + "/" + design + ".fix.old"
    GenerateHypergraph(openroad_exe, setup_file, extract_hypergraph_file)

    # read hypergraph
    # Each vertex corresponds to the hyperedge_id incident to it
    # Each hyperedge corresponds to the vertices in it
    with open (hypergraph_file) as f:
        content = f.read().splitlines()
    f.close()

    items = content[0].split()
    num_hyperedges = int(items[0])
    num_vertices   = int(items[1])

    vertices_list = [[] for i in range(num_vertices)]
    hyperedges_list = []
    hyperedge_id = 0

    for i in range(num_hyperedges):
        items = content[i+1].split()
        # ignore all the global nets
        if (len(items) > global_net_threshold):
            pass
        hyperedge = [int(item) - 1 for item in items]
        hyperedges_list.append(hyperedge)
        for vertex in hyperedge:
            vertices_list[vertex].append(hyperedge_id)
        hyperedge_id += 1

    # sort all the macros and IOs based on lexicographically smallest macro name
    # get all the IOs and macros as seeds
    seed_list = []
    vertex_map = {  }
    vertex_name_list = []

    # read all the IOs
    io_pos_map = {  }
    with open(io_name_file) as f:
        content = f.read().splitlines()
    f.close()


    vertex_id = 0
    for line in content:
        items = line.split()
        io_name = items[0]
        x = (float(items[1]) + float(items[3])) / 2.0
        y = (float(items[2]) + float(items[4])) / 2.0
        io_pos_map[io_name] = (x, y)
        seed_list.append(io_name)
        vertex_map[io_name] = vertex_id
        vertex_name_list.append(io_name)
        vertex_id += 1


    # read all the instances (including macros)
    with open(instance_name_file) as f:
        content = f.read().splitlines()
    f.close()

    for line in content:
        items = line.split()
        inst_name = items[0]
        vertex_map[inst_name] = vertex_id
        vertex_name_list.append(inst_name)
        vertex_id += 1
        if (int(items[1]) == 1):
            seed_list.append(inst_name)

    # sort the seed
    seed_list.sort()

    # grouping all the directly K_in fanins and K_out fanouts respect to
    # ios and instances.
    vertex_hash = [[len(seed_list), max(K_in, K_out) + 1] for i in range(len(vertex_map))]
    for i in range(len(seed_list)):
        TraverseFanout(vertices_list, hyperedges_list, vertex_hash, i, vertex_map[seed_list[i]], K_out)
        TraverseFanin(vertices_list, hyperedges_list, vertex_hash, i,  vertex_map[seed_list[i]], K_in)


    # group IOs to bundled pins based on their position
    with open(outline_file) as f:
        content = f.read().splitlines()
    f.close()

    items = content[0].split()
    floorplan_lx = float(items[0])
    floorplan_ly = float(items[1])
    floorplan_ux = float(items[2])
    floorplan_uy = float(items[3])

    # get the vertical distance and horizontal distance
    width = (floorplan_ux - floorplan_lx) / n_cols
    height = (floorplan_uy - floorplan_ly) / n_rows


    initial_group_map = {  }
    grid_row_max = 100000000
    for io_name, pos in io_pos_map.items():
        hash_id = floor( pos[1] / height) * grid_row_max + floor( pos[0] / width)
        if hash_id not in initial_group_map:
            initial_group_map[hash_id] = [io_name]
        else:
            initial_group_map[hash_id].append(io_name)

    # final group list
    group_list = [  ]
    for hash_id, ios in initial_group_map.items():
        group_list.append(ios)

    for seed in seed_list:
        if seed not in io_pos_map:
            group_list.append([seed])

    group_id_map = {  }
    for i in range(len(group_list)):
        for vertex in group_list[i]:
            group_id_map[vertex] = i


    for i in range(len(vertex_hash)):
        seed_id = vertex_hash[i][0]
        if (seed_id < len(seed_list)):
            vertex_name = vertex_name_list[i]
            seed_name = seed_list[seed_id]
            if vertex_name not in group_list[group_id_map[seed_name]]:
                group_list[group_id_map[seed_name]].append(vertex_name)


    f = open(original_fix_file, "w")
    for group in group_list:
        line = ""
        for vertex in group:
            line += vertex + ","
        line = line[0:-1]
        f.write(line + '\n')
    f.close()

    f = open(fix_file, "w")
    for group in group_list:
        line = ""
        for vertex in group:
            if vertex not in seed_list:
                line += vertex + ","
        if (len(line) > 0):
            line = line[0:-1]
        f.write(line + '\n')
    f.close()


    shutil.rmtree(rpt_dir)


























