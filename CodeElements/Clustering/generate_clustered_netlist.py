import os
import igraph as ig
import leidenalg as la
from igraph import *
import argparse
import time
import shutil
import sys
sys.path.append('./utils')

#################################################################
### Partitioning the hypergraph using hmetis
#################################################################
def hMetisPartitioner(hmetis_exe, hypergraph_file, Nparts):
    # The parameter configuration is the same as Google Brain paper
    # UBfactor = 5
    # Nruns    = 10
    # CType    = 5
    # RType    = 3
    # Vcycle   = 3
    # The random seed is 0 by default (in our implementation)
    # We use the hMetis C++ API to implement hMetis
    cmd = hmetis_exe + " " + hypergraph_file + " " + str(Nparts) + " 5 10 5 3 3 0 0"
    os.system(cmd)


#################################################################
### Partitioning the hypergraph using Leiden algorithm
#################################################################
def LeidenPartitioner(hypergraph_file, solution_file):
    with open(hypergraph_file) as f:
        content = f.read().splitlines()
    f.close()

    items = content[0].split()
    num_hyperedges = int(items[0])
    num_vertices = int(items[1])

    edge_list = [0 for i in range(num_vertices)]
    for i in range(num_vertices):
        edge_list[i] = {  }

    # Clique model
    for i in range(1, len(content)):
        items = content[i].split()
        hyperedge = [int(item) - 1 for item in items]
        if(len(hyperedge) > 20):
            continue
        hyperedge.sort()
        weight = 1.0 / (len(hyperedge) - 1)
        for i in range(len(hyperedge) - 1):
            for j in range(i + 1, len(hyperedge)):
                src = hyperedge[i]
                target = hyperedge[j]
                if target in edge_list[src]:
                    edge_list[src][target] += weight
                else:
                    edge_list[src][target] = weight

    tuple_edge_list = []
    weights = []

    for i in range(len(edge_list)):
        for key, value in edge_list[i].items():
            tuple_edge_list.append((i, key))
            weights.append(value)


    g = Graph(directed = False)
    g.add_vertices(num_vertices)
    g.add_edges(tuple_edge_list)
    g.es["weight"]  = weights
    partition = la.find_partition(g, la.ModularityVertexPartition)
    solution_vector = partition.membership
    num_clusters = max(solution_vector) + 1
    print("[INFO] number of clusters :  ", num_clusters)

    solution_file = hypergraph_file + ".cluster"
    f = open(solution_file, "w")
    for solution in solution_vector:
        f.write(str(solution) + "\n")
    f.close()


#################################################################
### Create cluster commands for Innovus
#################################################################
def CreateInvsCluster(solution_file, io_name_file, instance_name_file, cluster_file):
    solution_vector = []
    with open(solution_file) as f:
        content = f.read().splitlines()
    f.close()

    for line in content:
        solution_vector.append(int(line))

    num_clusters = max(solution_vector) + 1

    with open(io_name_file) as f:
        content = f.read().splitlines()
    f.close()
    num_ios = len(content)


    with open(instance_name_file) as f:
        content = f.read().splitlines()
    f.close()


    f = open(cluster_file, "w")
    for i in range(num_clusters):
        f.write("createInstGroup cluster" + str(i) + "\n")

    for i in range(len(content)):
        instance_name = content[i]
        cluster_id = solution_vector[num_ios + i]
        line = "addInstToInstGroup cluster" + str(cluster_id) + " " + instance_name + "\n"
        f.write(line)
    f.close()


########################################################################
### Create clustered netlist (in def format) Based on OpenROAD API
########################################################################
def CreateDef(solution_file, io_name_file, instance_name_file, \
              cluster_lef_file, cluster_def_file, \
              setup_file, create_clustered_netlist_def_file, \
              openroad_exe):
    # read solution vector
    solution_vector = []
    with open(solution_file) as f:
        content = f.read().splitlines()
    f.close()
    for line in content:
        solution_vector.append(int(line))

    # read io and instance files
    with open(io_name_file) as f:
        content = f.read().splitlines()
    f.close()
    num_ios = len(content)

    with open(instance_name_file) as f:
        content = f.read().splitlines()
    f.close()


    ###  Create the related openroad tcl file
    file_name = os.getcwd() + "/create_def.tcl"
    cmd = "cp " + setup_file + " " + file_name
    os.system(cmd)

    f = open(file_name, "a")
    f.write("\n")
    f.write("\n")
    f.write("read_verilog $netlist\n")
    f.write("link_design $top_design\n")
    f.write("read_sdc $sdc\n")
    #f.write("read_def  $def_file\n")
    f.write("read_def  $def_file -floorplan_initialize\n")
    f.write("\n")
    f.write("set db [ord::get_db]\n")
    f.write("set block [[$db getChip] getBlock]\n")
    f.write("set cluster_lef_file " + cluster_lef_file + "\n")
    f.write("set cluster_def_file " + cluster_def_file + "\n")
    f.write("\n")
    f.write("\n")
    for i in range(len(content)):
        instance_name = content[i]
        cluster_id = solution_vector[num_ios + i]
        line = "set inst [$block findInst " + instance_name +  " ]\n"
        f.write(line)
        f.write("set cluster_id " + str(cluster_id) + "\n")
        f.write('set newProperty [odb::dbStringProperty_create $inst "cluster_id" $cluster_id]\n')
    f.close()


    with open(create_clustered_netlist_def_file) as f:
        content = f.read().splitlines()
    f.close()

    f = open(file_name, "a")
    f.write("\n")
    for line in content:
        f.write(line + "\n")
    f.close()

    cmd = openroad_exe + " " + file_name
    os.system(cmd)

    cmd = "rm " + file_name
    os.system(cmd)

    # Due to some bugs in OpenROAD, we have to manually remove the RESISTANCE section for all the via layers
    with open(cluster_lef_file) as f:
        content = f.read().splitlines()
    f.close()

    f = open(cluster_lef_file, "w")
    i = 0
    while(i < len(content)):
        items = content[i].split()
        if(len(items) == 2 and items[0] == "LAYER" and items[1][0:-1] == "via"):
            while((len(items) == 2 and items[0] == "END") == False):
                if(items[0] != "RESISTANCE"):
                    f.write(content[i] + "\n")
                i = i + 1
                items = content[i].split()
            f.write(content[i] + "\n")
            i = i + 1
        else:
            f.write(content[i] + "\n")
            i = i  + 1
    f.close()


########################################################################
### Run RePlace on the clustered netlist
########################################################################
def RunRePlace(cluster_lef_file, cluster_def_file, blob_def_file, setup_file,  placement_density,  openroad_exe, GUI):
    ###  Create the related openroad tcl file
    file_name = os.getcwd() + "/run_replace.tcl"
    cmd = "cp " + setup_file + " " + file_name
    os.system(cmd)
    f = open(file_name, "a")
    line = "read_lef " + cluster_lef_file + "\n"
    line += "read_def " + cluster_def_file + "\n"
    line += "set global_place_density " + str(placement_density) + "\n"
    line += "set global_place_density_penalty 8e-5\n"
    line += "global_placement -disable_routability_driven  -density $global_place_density -init_density_penalty $global_place_density_penalty\n"
    line += "write_def " + blob_def_file + "\n"
    f.write(line)
    if (GUI == False):
        f.write("exit\n")
    f.close()


    cmd = openroad_exe + " -gui " + file_name
    if (GUI == False):
        cmd = openroad_exe + "  " + file_name
    os.system(cmd)

    cmd = "rm " + file_name
    os.system(cmd)

####################################################################################
#### Extract hypergraph from netlist
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
    parser.add_argument("design", help="design_name: ariane, MegaBoom_x2 ", type = str)
    parser.add_argument("partitioner", help="hmetis, leiden", type = str)
    parser.add_argument("--Nparts",  help = "number of clusters (only for hmetis, default  = 500)", type = int, default = 500)
    parser.add_argument("--setup_file", help = "setup file for openroad (default = setup.tcl)", type = str, default = "setup.tcl")
    parser.add_argument("--RePlace", help = "Run RePlace for blob placement (default = True)", type = bool, default = True)
    parser.add_argument("--placement_density", help = "Placement density for RePlace (default = 0.7)", type = float, default = 0.7)
    parser.add_argument("--GUI", help = "Run OpenROAD in GUI Mode (default = True)", type = bool, default = True)
    args = parser.parse_args()

    design = args.design
    partitioner = args.partitioner
    Nparts = args.Nparts
    setup_file = args.setup_file
    RePlace  = args.RePlace
    placement_density = args.placement_density
    GUI = args.GUI

    pwd = os.getcwd()
    # Specify the location of hmetis exe and openroad exe
    hmetis_exe = pwd + "/utils/hmetis"
    openroad_exe = pwd + "/utils/openroad"
    extract_hypergraph_file  = pwd + "/utils/extract_hypergraph.tcl"
    create_clustered_netlist_def_file = pwd + "/utils/create_clustered_netlist_def.tcl"

    print("[INFO] Design : ", design)
    print("[INFO] Partitioner : ", partitioner)
    print("[INFO] Nparts : ", Nparts)


    # Generate Hypergraph file
    rpt_dir = pwd + "/rtl_mp"
    hypergraph_file = rpt_dir + "/" + design + ".hgr"
    io_name_file = hypergraph_file + ".io"
    instance_name_file = hypergraph_file + ".instance"
    GenerateHypergraph(openroad_exe, setup_file, extract_hypergraph_file)

    # Partition the hypergraph
    cluster_file = rpt_dir + "/" + design + "_cluster_" + partitioner  +  ".tcl"  # for innovus command
    solution_file = hypergraph_file + ".cluster"
    if partitioner == "leiden":
       LeidenPartitioner(hypergraph_file, solution_file)
    elif partitioner == "hmetis":
        cluster_file = rpt_dir + "/" + design + "_cluster_" + partitioner + "_" + str(Nparts) +  ".tcl"  # for innovus command
        solution_file = hypergraph_file + ".part." + str(Nparts) # defined by hemtis automatically
        hMetisPartitioner(hmetis_exe, hypergraph_file, Nparts)
    else:
        print("[ERROR] The partitioner is not defined!")
        exit()

    # Generate Innovus Clustering Commands
    CreateInvsCluster(solution_file, io_name_file, instance_name_file, cluster_file)

    # Generate clustered lef and def file
    cluster_lef_file  = rpt_dir + "/clusters.lef"
    cluster_def_file  = rpt_dir + "/clustered_netlist.def"
    CreateDef(solution_file, io_name_file, instance_name_file, cluster_lef_file, cluster_def_file, \
              setup_file, create_clustered_netlist_def_file, openroad_exe)

    # Generate blob placemment
    blob_def_file     = rpt_dir + "/blob.def"
    if (RePlace == True):
        RunRePlace(cluster_lef_file, cluster_def_file, blob_def_file, setup_file,  placement_density,  openroad_exe, GUI)



