# This script was written and developed by ABKGroup students at UCSD. However, the underlying commands and reports are copyrighted by Cadence. 
# We thank Cadence for granting permission to share our research to help promote and foster the next generation of innovators.
source lib_setup.tcl
source design_setup.tcl
source mmmc_setup.tcl

setMultiCpuUsage -localCpu 16
set util 0.3

set handoff_dir  "./syn_handoff"

set netlist ${handoff_dir}/${DESIGN}.v
set sdc ${handoff_dir}/${DESIGN}.sdc 

set rptDir summaryReport/ 
set encDir enc/

if {![file exists $rptDir/]} {
    exec mkdir $rptDir/
}

if {![file exists $encDir/]} {
    exec mkdir $encDir/
}

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
setDesignMode -process 7

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
setFPlanMode -snapBlockGrid LayerTrack
if {[info exist ::env(PHY_SYNTH)] && $::env(PHY_SYNTH) == 1} {
    defIn ${handoff_dir}/${DESIGN}.def
} else {
    defIn $floorplan_def
    addHaloToBlock -allMacro $HALO_WIDTH $HALO_WIDTH $HALO_WIDTH $HALO_WIDTH
    place_design -concurrent_macros
    refine_macro_place
    snapFPlan -pin
}

saveDesign ${encDir}/${DESIGN}_floorplan.enc

setPlaceMode -place_detail_legalization_inst_gap 1
setFillerMode -fitGap true
setDesignMode -topRoutingLayer $TOP_ROUTING_LAYER
setDesignMode -bottomRoutingLayer 2 

place_opt_design -out_dir $rptDir -prefix place
saveDesign $encDir/${DESIGN}_placed.enc

set_ccopt_property post_conditioning_enable_routing_eco 1
set_ccopt_property -cts_def_lock_clock_sinks_after_routing true
setOptMode -unfixClkInstForOpt false

create_ccopt_clock_tree_spec
ccopt_design

set_interactive_constraint_modes [all_constraint_modes -active]
set_propagated_clock [all_clocks]
set_clock_propagation propagated

# ------------------------------------------------------------------------------
# Routing
# ------------------------------------------------------------------------------
setNanoRouteMode -drouteVerboseViolationSummary 1
setNanoRouteMode -routeWithSiDriven true
setNanoRouteMode -routeWithTimingDriven true
setNanoRouteMode -routeUseAutoVia true

##Recommended by lib owners
# Prevent router modifying M1 pins shapes
setNanoRouteMode -routeWithViaInPin "1:1"
setNanoRouteMode -routeWithViaOnlyForStandardCellPin "1:1"

## limit VIAs to ongrid only for VIA1 (S1)
setNanoRouteMode -drouteOnGridOnly "via 1:1"
setNanoRouteMode -drouteAutoStop false
setNanoRouteMode -drouteExpAdvancedMarFix true
setNanoRouteMode -routeExpAdvancedTechnology true

#SM suggestion for solving long extraction runtime during GR
setNanoRouteMode -grouteExpWithTimingDriven false

routeDesign
#route_opt_design
saveDesign ${encDir}/${DESIGN}_route.enc
defOut -netlist -floorplan -routing ${DESIGN}_route.def

summaryReport -noHtml -outfile summaryReport/post_route.sum
saveDesign ${encDir}/${DESIGN}.enc
defOut -netlist -floorplan -routing ${DESIGN}.def

exit
