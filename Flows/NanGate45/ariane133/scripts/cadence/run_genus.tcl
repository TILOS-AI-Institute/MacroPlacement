## This script was written and developed by UCSD ABKGroup, 
## however, the underlying commands and reports are copyrighted
## by Cadence. We thank Cadence for granting permission to share
## our research to help promote and foster the next generation of
## innovators.

set top_module ariane 
set_db max_cpus_per_server 16
set_db super_thread_servers "localhost"
set libdir "../../../../../Enablements/NanGate45/lib/"

set libworst "
    ${libdir}/NangateOpenCellLibrary_typical.lib \
    ${libdir}/fakeram45_256x16.lib \
    ${libdir}/fakeram45_256x64.lib \
    "

set list_lib "$libworst"

# Target library
set link_library $list_lib
set target_library $list_lib

# set path
set_db init_lib_search_path $libdir
set_db init_hdl_search_path "../../designs/${top_module}/"

set_db library $list_lib

# Start
if {[file exists template]} {
	exec rm -rf template
}

exec mkdir template
if {![file exists gate]} {
	exec mkdir gate
}

if {![file exists rpt]} {
	exec mkdir rpt
}

# read RTL
source rtl_list.tcl

foreach rtl_file $rtl_all {
    if {$top_module == "jpeg_encoder"} {
        read_hdl -sv $rtl_file
    } else {
        read_hdl -sv $rtl_file
    }
}

elaborate $top_module 


# Default SDC Constraints
read_sdc ./${top_module}.sdc

syn_generic
syn_map

write_sdc > gate/${top_module}.sdc
write_hdl > gate/${top_module}.v
write_script > constraints.g

# Write Reports
redirect [format "%s%s%s" rpt/ $top_module _area.rep] { report_area }
redirect [format "%s%s%s" rpt/ $top_module _cell.rep] { report_gates }
redirect [format "%s%s%s" rpt/ $top_module _timing.rep] { report_timing }

exit
