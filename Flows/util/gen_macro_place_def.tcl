# This script was written and developed by ABKGroup students at UCSD. However, the underlying commands and reports are copyrighted by Cadence. 
# We thank Cadence for granting permission to share our research to help promote and foster the next generation of innovators.
source lib_setup.tcl
source design_setup.tcl
set handoff_dir $::env(SYN_HANDOFF)

set netlist ${handoff_dir}/${DESIGN}.v
set sdc ${handoff_dir}/${DESIGN}.sdc 
source mmmc_setup.tcl

setMultiCpuUsage -localCpu 16
set util 0.3

# default settings
set init_pwr_net VDD
set init_gnd_net VSS

# default settings
set init_verilog "$netlist"
set init_design_netlisttype "Verilog"
set init_design_settop 1
set init_top_cell "$DESIGN"
set init_lef_file "$lefs"

# MCMM setup
init_design -setup {WC_VIEW} -hold {BC_VIEW}
set_power_analysis_mode -leakage_power_view WC_VIEW -dynamic_power_view WC_VIEW

set_interactive_constraint_modes {CON}
setAnalysisMode -reset
setAnalysisMode -analysisType onChipVariation -cppr both

clearGlobalNets
globalNetConnect VDD -type pgpin -pin VDD -inst * -override
globalNetConnect VSS -type pgpin -pin VSS -inst * -override
globalNetConnect VDD -type tiehi -inst * -override
globalNetConnect VSS -type tielo -inst * -override


setOptMode -powerEffort low -leakageToDynamicRatio 0.5
setGenerateViaMode -auto true
generateVias

# basic path groups
createBasicPathGroups -expanded

## Generate the floorplan ##
defIn $floorplan_def
set origin_x [dbget top.fPlan.coreBox_llx]
set origin_y [dbget top.fPlan.coreBox_lly]

if {[info exist ::env(pb_netlist)] &&
    [info exist ::env(plc_file)] &&
    [file exist $::env(pb_netlist)] &&
    [file exist $::env(plc_file)]} {
        exec /home/sakundu/.conda/envs/py-tf/bin/python3.8 \
            ../../../../util/plc_pb_to_placement_tcl.py $::env(plc_file) $::env(pb_netlist) \
                               "macro_place.tcl" $origin_x $origin_y 
        source macro_place.tcl
} elseif { [info exist ::env(pl_file)] && [file exist $::env(pl_file)] } {
        source ../../../../util/place_from_pl.tcl
        place_macro_from_pl $::env(pl_file)
}


if { [info exist ::env(run_refine_macro_place)] && $::env(run_refine_macro_place) == 1 } {
    dbset [dbget top.insts.cell.subClass block -p2 ].pStatus placed
    refine_macro_place
}

addHaloToBlock -allMacro $HALO_WIDTH $HALO_WIDTH $HALO_WIDTH $HALO_WIDTH
dbset [dbget top.insts.cell.subClass block -p2 ].pStatus fixed

defOut -floorplan ./${DESIGN}_fp_new_placed_macros.def

exit
