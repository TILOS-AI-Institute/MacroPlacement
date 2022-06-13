import os
import time
import shutil
import sys
sys.path.append('./utils')

#################################################################
### Partitioning the hypergraph using hmetis
#################################################################
def hMetisPartitioner(hmetis_exe, hypergraph_file, Nparts, fixed_file):
    # The parameter configuration is the same as Google Brain paper
    # UBfactor = 5
    # Nruns    = 10
    # CType    = 5
    # RType    = 3
    # Vcycle   = 3
    # The random seed is 0 by default (in our implementation)
    # We use the hMetis C++ API to implement hMetis
    cmd = hmetis_exe + " " + hypergraph_file + " " + fixed_file + " "  + str(Nparts) + " 5 10 5 3 3 0 0"
    os.system(cmd)


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
    line =  "# This script was written and developed by ABKGroup students at UCSD.\n"
    line += "# However, the underlying commands and reports are copyrighted by Cadence.\n"
    line += "# We thank Cadence for granting permission to share our research to help \n"
    line += "# promote and foster the next generation of innovators.\n"
    line += "\n"
    f.write(line)

    for i in range(num_clusters):
        f.write("createInstGroup cluster" + str(i) + "\n")

    for i in range(len(content)):
        items = content[i].split()
        instance_name = items[0]
        # ignore all the macros
        is_macro = int(items[1])
        if (is_macro == 1):
            continue

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
        items = content[i].split()
        instance_name = items[0]
        # just consider standard cells
        is_macro = int(items[1])
        if (is_macro == 1):
            continue

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

####################################################################################
#### Remove large nets from the hypergraph
####################################################################################
def RemoveLargetNet(hypergraph_file, net_size_threshold):
    with open(hypergraph_file) as f:
        content = f.read().splitlines()
    f.close()

    items = content[0].split()
    num_hyperedges = int(items[0])
    num_vertices = int(items[1])

    hyperedges_list = []
    for i in range(1, len(content)):
        items = content[i].split()
        if (len(items) < net_size_threshold):
            hyperedges_list.append(content[i])

    f = open(hypergraph_file, "w")
    line = str(len(hyperedges_list)) + " " + str(num_vertices) + "\n"
    f.write(line)
    for hyperedge in hyperedges_list:
        f.write(hyperedge + "\n")
    f.close()



####################################################################################
#### Convert the grouping information to fix file which can used by hMetis
####################################################################################
def ConvertFixFile(fixed_file, hypergraph_fix_file, io_name_file, instance_name_file):
    vertex_id = 0
    vertex_map = {  }
    with open(io_name_file) as f:
        content = f.read().splitlines()
    f.close()

    for line in content:
        io_name = line.split()[0]
        vertex_map[io_name] = vertex_id
        vertex_id += 1

    with open(instance_name_file) as f:
        content = f.read().splitlines()
    f.close()

    for line in content:
        instance_name = line.split()[0]
        vertex_map[instance_name] = vertex_id
        vertex_id += 1

    fixed_part = [-1 for i in range(vertex_id)]

    with open(fixed_file) as f:
        content = f.read().splitlines()
    f.close()

    for i in range(len(content)):
        items = content[i].split(',')
        for item in items:
            fixed_part[vertex_map[item]] = i

    f = open(hypergraph_fix_file, "w")
    for part in fixed_part:
        f.write(str(part) + "\n")
    f.close()

def Clustering(design, src_dir, fixed_file, net_size_threshold = 300, Nparts = 500, setup_file = "setup.tcl", RePlace = True, placement_density = 0.7, GUI = True):
    """
    parameter: design,  help="design_name: ariane, MegaBoom_x2 ", type = str
    parameter: src_dir, help="directory for source codes", type = str
    parameter: fixed_file, help="fixed file generated by grouping"
    parameter: net_size_threshold, help="large net threshold", type = int
    parameter: Nparts,  help = "number of clusters (only for hmetis, default  = 500)", type = int
    parameter: setup_file, help = "setup file for openroad (default = setup.tcl)", type = str
    parameter: RePlace, help = "Run RePlace for blob placement (default = True)", type = bool
    parameter: placement_density, help = "Placement density for RePlace (default = 0.7)", type = float
    parameter: GUI, help = "Run OpenROAD in GUI Mode (default = True)", type = bool
    """

    pwd = os.getcwd()
    # Specify the location of hmetis exe and openroad exe
    hmetis_exe = src_dir + "/utils/hmetis"
    openroad_exe = src_dir + "/utils/openroad"
    extract_hypergraph_file  = src_dir + "/utils/extract_hypergraph.tcl"
    create_clustered_netlist_def_file = src_dir + "/utils/create_clustered_netlist_def.tcl"

    print("[INFO] Design : ", design)
    print("[INFO] Nparts : ", Nparts)

    result_dir = "./results"
    if not os.path.exists(result_dir):
        os.mkdir(result_dir)

    cadence_result_dir = result_dir + "/Cadence"
    if not os.path.exists(cadence_result_dir):
        os.mkdir(cadence_result_dir)

    openroad_result_dir = result_dir + "/OpenROAD"
    if not os.path.exists(openroad_result_dir):
        os.mkdir(openroad_result_dir)


    # Generate Hypergraph file
    rpt_dir = pwd + "/rtl_mp"
    hypergraph_file = rpt_dir + "/" + design + ".hgr"
    io_name_file = hypergraph_file + ".io"
    instance_name_file = hypergraph_file + ".instance"
    hypergraph_fix_file = hypergraph_file + ".fix"
    GenerateHypergraph(openroad_exe, setup_file, extract_hypergraph_file)

    # Remove large nets
    RemoveLargetNet(hypergraph_file, net_size_threshold)

    # Convert fixed file
    ConvertFixFile(fixed_file, hypergraph_fix_file, io_name_file, instance_name_file)

    # Partition the hypergraph
    cluster_file = cadence_result_dir + "/" + design + "_cluster_"  + str(Nparts) +  ".tcl"  # for innovus command
    solution_file = hypergraph_file + ".part." + str(Nparts) # defined by hemtis automatically
    hMetisPartitioner(hmetis_exe, hypergraph_file, Nparts, hypergraph_fix_file)

    # Generate Innovus Clustering Commands
    CreateInvsCluster(solution_file, io_name_file, instance_name_file, cluster_file)

    # Generate clustered lef and def file
    cluster_lef_file  = openroad_result_dir + "/clusters.lef"
    cluster_def_file  = openroad_result_dir + "/clustered_netlist.def"
    CreateDef(solution_file, io_name_file, instance_name_file, cluster_lef_file, cluster_def_file, \
              setup_file, create_clustered_netlist_def_file, openroad_exe)

    # Generate blob placemment
    blob_def_file = openroad_result_dir + "/blob.def"
    if (RePlace == True):
        RunRePlace(cluster_lef_file, cluster_def_file, blob_def_file, setup_file,  placement_density,  openroad_exe, GUI)

    shutil.rmtree(rpt_dir)



