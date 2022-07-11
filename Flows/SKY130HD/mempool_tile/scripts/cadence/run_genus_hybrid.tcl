# This script was written and developed by ABKGroup students at UCSD. However, the underlying commands and reports are copyrighted by Cadence. 
# We thank Cadence for granting permission to share our research to help promote and foster the next generation of innovators.
source lib_setup.tcl
source design_setup.tcl

if {[info exist ::env(PHY_SYNTH)] && $::env(PHY_SYNTH) == 1} {
    read_mmmc mmmc_iSpatial_setup.tcl
}

# set the output directories
set OUTPUTS_PATH  syn_output
set REPORTS_PATH  syn_rpt
set HANDOFF_PATH  syn_handoff

if {![file exists ${OUTPUTS_PATH}]} {
  file mkdir ${OUTPUTS_PATH}
}

if {![file exists ${REPORTS_PATH}]} {
  file mkdir ${REPORTS_PATH}
}

if {![file exists ${HANDOFF_PATH}]} {
  file mkdir ${HANDOFF_PATH}
}
#
# set threads
set_db max_cpus_per_server 16
set_db super_thread_servers "localhost"
#
set list_lib "$libworst"


if {[info exist ::env(PHY_SYNTH)] && $::env(PHY_SYNTH) == 1} {
    set_db invs_temp_dir ${OUTPUTS_PATH}/invs_tmp_dir
    read_physical -lefs $lefs
}

# Target library
set link_library $list_lib
set target_library $list_lib

# set pathi
set_db hdl_flatten_complex_port true
set_db hdl_record_naming_style  %s_%s
set_db auto_ungroup none


if {![info exist ::env(PHY_SYNTH)] || $::env(PHY_SYNTH) == 0} {
    set_db library $list_lib
}

#################################################
# Load Design and Initialize
#################################################
set_db init_hdl_search_path $rtldir 
source rtl_list.tcl

foreach rtl_file $rtl_all {
    #read_hdl -sv $rtl_file
    read_hdl -language sv -define TARGET_SYNTHESIS -define XPULPIMG=1 $rtl_file
}

elaborate $DESIGN
time_info Elaboration

if {![info exist ::env(PHY_SYNTH)] || $::env(PHY_SYNTH) == 0} {
    #read_sdc $sdc
    source $sdc
}

init_design

check_design -unresolved

check_timing_intent
# reports the physical layout estimation report from lef and QRC tech file
report_ple > ${REPORTS_PATH}/ple.rpt 

###############################################
# Read DEF
###############################################
if {[info exist ::env(PHY_SYNTH)] && $::env(PHY_SYNTH) == 1} {
    read_def $floorplan_def
    check_floorplan -detailed
}

# keep hierarchy during synthesis
set_db auto_ungroup none

if {[info exist ::env(PHY_SYNTH)] && $::env(PHY_SYNTH) == 1} {
    syn_generic -physical
} else {
    syn_generic
}
time_info GENERIC

# generate a summary for the current stage of synthesis
write_reports -directory ${REPORTS_PATH} -tag generic
write_db  ${OUTPUTS_PATH}/${DESIGN}_generic.db

 
if {[info exist ::env(PHY_SYNTH)] && $::env(PHY_SYNTH) == 1} {
    syn_map -physical
} else {
    syn_map
}
time_info MAPPED

# generate a summary for the current stage of synthesis
write_reports -directory ${REPORTS_PATH} -tag map
write_db  ${OUTPUTS_PATH}/${DESIGN}_map.db

if {[info exist ::env(PHY_SYNTH)] && $::env(PHY_SYNTH) == 1} {
    syn_opt -spatial
} else {
    syn_opt
}

time_info OPT 
write_db ${OUTPUTS_PATH}/${DESIGN}_opt.db

##############################################################################
# Write reports
##############################################################################

# summarizes the information, warnings and errors
report_messages > ${REPORTS_PATH}/${DESIGN}_messages.rpt

# generate PPA reports
report_gates > ${REPORTS_PATH}/${DESIGN}_gates.rpt
report_power > ${REPORTS_PATH}/${DESIGN}_power.rpt
report_area > ${REPORTS_PATH}/${DESIGN}_power.rpt
write_reports -directory ${REPORTS_PATH} -tag final 


if {[info exist ::env(PHY_SYNTH)] && $::env(PHY_SYNTH) == 1} {
    write_design -innovus -base_name ${HANDOFF_PATH}/${DESIGN}
} else {
    write_sdc >${HANDOFF_PATH}/${DESIGN}.sdc
    write_hdl > ${HANDOFF_PATH}/${DESIGN}.v
}

exit
