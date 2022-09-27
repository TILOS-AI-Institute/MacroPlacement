import os
import argparse
import time
import shutil
import sys
from math import floor

class Vertex:
    def __init__(self, vertex_id, name, type, x, y):
        self.vertex_id = vertex_id
        self.name = name
        self.type = type
        self.x = x
        self.y = y
        self.group_id = -1

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
#### TraverseFanout or TraverseFanin in DFS manner
####################################################################################
def TraverseFanout(vertices_list, hyperedges_list, vertices, root_vertex, K_out, level_id):
    if (level_id >= K_out):
        return

    for hyperedge_id in vertices_list[root_vertex.vertex_id]:
        hyperedge = hyperedges_list[hyperedge_id]
        # Check if this hyperedge is driven by root_vertex
        if (hyperedge[0] != root_vertex.vertex_id):
            continue

        for i in range(1, len(hyperedge)):
            vertex = vertices[hyperedge[i]]
            if (vertex.group_id != -1):
                continue

            vertices[hyperedge[i]].group_id = root_vertex.group_id
            TraverseFanout(vertices_list, hyperedges_list, vertices, vertices[hyperedge[i]], K_out, level_id + 1)



def TraverseFanin(vertices_list, hyperedges_list, vertices, root_vertex, K_in, level_id):
    if (level_id >= K_in):
        return

    for hyperedge_id in vertices_list[root_vertex.vertex_id]:
        hyperedge = hyperedges_list[hyperedge_id]
        # Check if this hyperedge is driven by root_vertex
        if (hyperedge[0] == root_vertex.vertex_id):
            continue

        # check the driver status
        vertex = vertices[hyperedge[0]]
        if (vertex.group_id != -1):
            continue

        vertices[hyperedge[0]].group_id = root_vertex.group_id
        TraverseFanin(vertices_list, hyperedges_list, vertices, vertices[hyperedge[0]], K_in, level_id + 1)

def GetValue(vertex, direction):
    if (direction == "x"):
        return vertex.x
    elif (direction == "y"):
        return vertex.y
    else:
        print("Error")
        return 0.0

def SortIOPorts(io_list, group_id, distance, direction = "y"):
    if (len(io_list) == 0):
        return group_id

    i = 1
    group_id += 1
    if (direction == "x"):
        io_list.sort(key = lambda vertex : vertex.x)
    elif (direction == "y"):
        io_list.sort(key = lambda vertex : vertex.y)
    last_record = GetValue(io_list[0], direction)
    for vertex in io_list:
        if (GetValue(vertex, direction) - last_record > distance):
            group_id += 1
            last_record = GetValue(vertex, direction)
        vertex.group_id = group_id
        i = i + 1
    return group_id


def Grouping(design, n_rows, n_cols, K_in, K_out, setup_file, global_net_threshold, src_dir, openroad_exe):
    pwd = os.getcwd()
    extract_hypergraph_file  = src_dir + "/utils/extract_hypergraph.tcl"

    # Generate Hypergraph file
    rpt_dir = pwd + "/rtl_mp"
    hypergraph_file = rpt_dir + "/" + design + ".hgr"
    instance_name_file = hypergraph_file + ".vertex"
    outline_file = hypergraph_file + ".outline"
    fix_file = pwd + "/" + design  + ".fix"
    new_hypergraph_file = pwd + "/" + design + ".hgr"
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
        if (len(items) > global_net_threshold or len(items) == 1):
            continue
        hyperedge = [int(item) - 1 for item in items]
        hyperedges_list.append(hyperedge)
        for vertex in hyperedge:
            vertices_list[vertex].append(hyperedge_id)
        hyperedge_id += 1

    # read vertices
    vertices = []
    with open(instance_name_file) as f:
        content = f.read().splitlines()
    f.close()

    for i in range(len(content)):
        items = content[i].split()
        vertices.append(Vertex(i, items[0], items[1], float(items[2]), float(items[3])))

    f = open(new_hypergraph_file, "w")
    f.write(str(len(hyperedges_list)) + " " + str(len(vertices)) + "\n")
    for hyperedge in hyperedges_list:
        line = ""
        for vertex in hyperedge:
            line += str(vertex + 1) + " "
        f.write(line + "\n")
    f.close()

    ###
    fixed_groups = []
    macros = {  }
    group_id = -1
    # Put each macro's pins into a seperate group
    for vertex in vertices:
        if (vertex.type == "macro_pin"):
            name = vertex.name.split('/')
            macro_name = ""
            for i in range(len(name) - 1):
                macro_name += name[i]
            if macro_name not in macros:
                group_id += 1
                macros[macro_name] = group_id
            vertex.group_id = macros[macro_name]

    # Put IOs that are within close proximity of each other
    # get the bounding box
    die_lx = 1e9
    die_ly = 1e9
    die_ux = 0.0
    die_uy = 0.0
    for vertex in vertices:
        x = vertex.x
        y = vertex.y
        die_lx = min(x, die_lx)
        die_ux = max(x, die_ux)
        die_ly = min(y, die_ly)
        die_uy = max(y, die_uy)

    with open(outline_file) as f:
        content = f.read().splitlines()
    f.close()

    items = content[0].split()
    floorplan_lx = float(items[0])
    floorplan_ly = float(items[1])
    floorplan_ux = float(items[2])
    floorplan_uy = float(items[3])

    canvas_width = floorplan_ux - floorplan_lx
    canvas_height = floorplan_uy - floorplan_ly
    canvas_height = 1600.06

    # get the vertical distance and horizontal distance
    width = canvas_width / n_cols
    height = canvas_height / n_rows
    print("n_cols = ", n_cols)
    print("n_rows = ", n_rows)

    die_lx = round(die_lx, 3)
    die_ly = round(die_ly, 3)
    die_ux = round(die_ux, 3)
    die_uy = round(die_uy, 3)

    print("die_lx = ", die_lx)
    print("die_ly = ", die_ly)
    print("die_ux = ", die_ux)
    print("die_uy = ", die_uy)

    # put ports into different sides : L, T, R, B
    ports = { }
    ports["L"] = []
    ports["T"] = []
    ports["R"] = []
    ports["B"] = []
    for vertex in vertices:
        if (vertex.type == "port"):
            vertex.x = round(vertex.x, 3)
            vertex.y = round(vertex.y, 3)
            if (vertex.x == die_lx):
                ports["L"].append(vertex)
            elif (vertex.x == die_ux):
                ports["R"].append(vertex)
            elif (vertex.y == die_ly):
                ports["B"].append(vertex)
            else:
                ports["T"].append(vertex)

    # sort all the pins
    for key, value in ports.items():
        if (key == "L" or key == "R"):
            group_id = SortIOPorts(value, group_id, height, "y")
        else:
            group_id = SortIOPorts(value, group_id, width, "x")

    # update the vertices
    for key, value in ports.items():
        for vertex in value:
            vertices[vertex.vertex_id].group_id = vertex.group_id

    for vertex in vertices:
        if (vertex.type == "port" or vertex.type == "macro_pin"):
            TraverseFanout(vertices_list, hyperedges_list, vertices, vertex, K_out, 0)
            TraverseFanin(vertices_list, hyperedges_list, vertices, vertex, K_in, 0)

    f = open(fix_file, "w")
    for vertex in vertices:
        f.write(str(vertex.group_id) + "\n")
    f.close()

    #shutil.rmtree(rpt_dir)
