setMultiCpuUsage -localCpu 16
set design ariane 
set util 0.3

set dir "../../../../platforms/nangate45"
set netlist "./gate/$design.v"
set sdc "./gate/$design.sdc"
set lef "${dir}/lef/NangateOpenCellLibrary.tech.lef \
        ${dir}/lef/NangateOpenCellLibrary.macro.mod.lef \
        ${dir}/lef/fakeram45_256x16.lef \
        ${dir}/lef/fakeram45_256x64.lef"

set wc_lib_list [list $dir/lib/NangateOpenCellLibrary_typical.lib $dir/lib/fakeram45_256x16.lib $dir/lib/fakeram45_256x64.lib]
set bc_lib_list [list $dir/lib/NangateOpenCellLibrary_typical.lib $dir/lib/fakeram45_256x16.lib $dir/lib/fakeram45_256x64.lib]

create_library_set -name WC_LIB -timing $wc_lib_list
create_library_set -name BC_LIB -timing $bc_lib_list
	
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

create_rc_corner -name Cmax
create_rc_corner -name Cmin
create_delay_corner -name WC -library_set WC_LIB -rc_corner Cmax
create_delay_corner -name BC -library_set BC_LIB -rc_corner Cmin

create_constraint_mode -name CON -sdc_file [list $sdc]

create_analysis_view -name WC_VIEW -delay_corner WC -constraint_mode CON
create_analysis_view -name BC_VIEW -delay_corner BC -constraint_mode CON

# default settings
set init_verilog "$netlist"
set init_design_netlisttype "Verilog"
set init_design_settop 1
set init_top_cell "$design"
set init_lef_file "$lef"

# MCMM setup
init_design -setup {WC_VIEW} -hold {BC_VIEW}
set_power_analysis_mode -leakage_power_view WC_VIEW -dynamic_power_view WC_VIEW

set_interactive_constraint_modes {CON}
setDesignMode -process 45

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
floorPlan -r 1.0 $util 10 10 10 10

## Macro Placement ##
planDesign
refinePlace

## Creating Pin Blcokage for lower and upper pin layers ##
createPinBlkg -name Layer_1 -layer {metal2 metal3 metal9 metal10} -edge 0
createPinBlkg -name Layer_2 -layer {metal2 metal3 metal9 metal10} -edge 1
createPinBlkg -name Layer_3 -layer {metal2 metal3 metal9 metal10} -edge 2
createPinBlkg -name Layer_4 -layer {metal2 metal3 metal9 metal10} -edge 3

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
saveDesign $encDir/${design}_placed.enc
defOut -netlist -floorplan ${design}_placed.def

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
saveDesign ${encDir}/${design}_route.enc
defOut -netlist -floorplan -routing ${design}_route.def

setDelayCalMode -reset 
setDelayCalMode -SIAware true
setExtractRCMode -engine postRoute -coupled true -tQuantusForPostRoute false
setAnalysisMode -analysisType onChipVariation -cppr both

# routeOpt
optDesign -postRoute -setup -hold -prefix postRoute -expandedViews

extractRC
deselectAll
selectNet -clock
reportSelect  > summaryReport/clock_net_length.post_route
deselectAll
summaryReport -noHtml -outfile summaryReport/post_route.sum
saveDesign ${encDir}/${design}.enc
defOut -netlist -floorplan -routing ${design}.def

exit
