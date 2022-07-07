# This script was written and developed by ABKGroup students at UCSD. However, the underlying commands and reports are copyrighted by Cadence. 
# We thank Cadence for granting permission to share our research to help promote and foster the next generation of innovators.
source lib_setup.tcl
source design_setup.tcl
source mmmc_setup.tcl

setMultiCpuUsage -localCpu 16
set util 0.3

set netlist "../../netlist/$DESIGN.v"
set sdc "../../constraints/$DESIGN.sdc"
#set netlist "./syn_handoff/$DESIGN.v"
#set sdc "./syn_handoff/$DESIGN.sdc"

set site "FreePDK45_38x28_10R_NP_162NW_34O"

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
#floorPlan -r 1.0 $util 10 10 10 10
defIn $floorplan_def 

## Macro Placement ##
#redirect mp_config.tcl {source gen_mp_config.tcl}
#proto_design -constraints mp_config.tcl 
addHaloToBlock -allMacro 5 5 5 5
place_design -concurrent_macros
refine_macro_place
saveDesign ${encDir}/${DESIGN}_floorplan.enc

## Creating Pin Blcokage for lower and upper pin layers ##
createPinBlkg -name Layer_1 -layer {metal2 metal3 metal9 metal10} -edge 0
createPinBlkg -name side_top -edge 1
createPinBlkg -name side_right -edge 2
createPinBlkg -name side_bottom -edge 3


setPlaceMode -place_detail_legalization_inst_gap 1
setFillerMode -fitGap true
setNanoRouteMode -routeTopRoutingLayer 10
setNanoRouteMode -routeBottomRoutingLayer 2
setNanoRouteMode -drouteVerboseViolationSummary 1
setNanoRouteMode -routeWithSiDriven true
setNanoRouteMode -routeWithTimingDriven true
setNanoRouteMode -routeExpUseAutoVia true
#setPlaceMode -placeIoPins true

place_opt_design -out_dir $rptDir -prefix place
saveDesign $encDir/${DESIGN}_placed.enc

## Creating Pin Blcokage for lower and upper pin layers ##
createPinBlkg -name Layer_1 -layer {metal2 metal3 metal9 metal10} -edge 0
createPinBlkg -name Layer_2 -edge 1
createPinBlkg -name Layer_3 -edge 2
createPinBlkg -name Layer_4 -edge 3

setPlaceMode -place_detail_legalization_inst_gap 1
setFillerMode -fitGap true
setNanoRouteMode -routeTopRoutingLayer 10
setNanoRouteMode -routeBottomRoutingLayer 2
setNanoRouteMode -drouteVerboseViolationSummary 1
setNanoRouteMode -routeWithSiDriven true
setNanoRouteMode -routeWithTimingDriven true
setNanoRouteMode -routeExpUseAutoVia true
setPlaceMode -placeIoPins true

place_opt_design -out_dir $rptDir -prefix place
saveDesign $encDir/${DESIGN}_placed.enc
defOut -netlist -floorplan ${DESIGN}_placed.def

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
setNanoRouteMode -routeTopRoutingLayer 10
setNanoRouteMode -routeBottomRoutingLayer 2
setNanoRouteMode -drouteVerboseViolationSummary 1
setNanoRouteMode -routeWithSiDriven true
setNanoRouteMode -routeWithTimingDriven true
setNanoRouteMode -routeExpUseAutoVia true

##Recommended by lib owners
# Prevent router modifying M1 pins shapes
setNanoRouteMode -routeWithViaInPin "1:1"
setNanoRouteMode -routeWithViaOnlyForStandardCellPin "1:1"

## limit VIAs to ongrid only for VIA1 (S1)
setNanoRouteMode -drouteOnGridOnly "via 1:1"
setNanoRouteMode -dbCheckRule true
setNanoRouteMode -drouteAutoStop false
setNanoRouteMode -drouteExpAdvancedMarFix true
setNanoRouteMode -routeExpAdvancedTechnology true

#SM suggestion for solving long extraction runtime during GR
setNanoRouteMode -grouteExpWithTimingDriven false


routeDesign
saveDesign ${encDir}/${DESIGN}_route.enc
defOut -netlist -floorplan -routing ${DESIGN}_route.def

setDelayCalMode -reset 
setDelayCalMode -SIAware true
setExtractRCMode -engine postRoute -coupled true -tQuantusForPostRoute false
setAnalysisMode -analysisType onChipVariation -cppr both

# routeOpt
#optDesign -postRoute -setup -hold -prefix postRoute -expandedViews

#extractRC
deselectAll
selectNet -clock
reportSelect  > summaryReport/clock_net_length.post_route
deselectAll
summaryReport -noHtml -outfile summaryReport/post_route.sum
saveDesign ${encDir}/${DESIGN}.enc
defOut -netlist -floorplan -routing ${DESIGN}.def

exit
