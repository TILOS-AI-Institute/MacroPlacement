#!/bin/tcsh

## Set to 1 to run refine_macro_place ##
setenv run_refine_macro_place 0

setenv SYN_HANDOFF $argv[1]

if ($#argv == 3) then
    setenv pb_netlist $argv[2]
    setenv plc_file $argv[3]
else if ($#argv == 2) then
    setenv pl_file $argv[2]
else
    echo "Required clustered netlist and plc file to generate macro placed defs"
endif

module unload innovus
module load innovus/21.1

innovus -64 -overwrite -log log/macro_placement_generation_innovus.log -files ../../../../util/gen_macro_place_def.tcl

## Edit the design file to make sure flow2 reads the new macro placed def instead of the default one
set def_file=`ls *_fp_new_placed_macros.def | head -n1`
sed -i "s@\S*_fp_placed_macros.def@${def_file}@" design_setup.tcl

