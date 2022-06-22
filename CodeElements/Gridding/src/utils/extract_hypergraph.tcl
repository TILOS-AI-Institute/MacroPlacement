#######################################################################
### Author:  Zhiang, May, 2022
### Uses OpenROAD API to convert the netlist to a hypergraph (in hemtis format)
### This file cannot be used directly.  It will be called by
### generate_cluster.py
### All the parameters set here are meaningless.  
### !!! Please don't touch this file !!!
########################################################################

read_def  $def_file

#Generate the hypergraph
partition_design -max_num_inst 2000000 -min_num_inst 40000 \
                 -max_num_macro 12 -min_num_macro 4 \
                 -net_threshold 20  -virtual_weight 50 \
                 -num_hop 0 -timing_weight 1000 \
                 -report_file ${top_design}.hgr
exit
