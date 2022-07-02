# This script was written and developed by ABKGroup students at UCSD. However, the underlying commands and reports are copyrighted by Cadence. 
# We thank Cadence for granting permission to share our research to help promote and foster the next generation of innovators.
# lib and lef, RC setup

set libdir "../../../../../Enablements/SKY130HD/lib"
set lefdir "../../../../../Enablements/SKY130HD/lef"
set qrcdir "../../../../../Enablements/SKY130HD/qrc"

set_db init_lib_search_path { \
    ${libdir} \
    ${lefdir} \
}

set libworst "  
    ${libdir}/sky130_fd_sc_hd__tt_025C_1v80.lib \
    ${libdir}/fakeram130_256x64.lib \
    "


set libbest " 
    ${libdir}/sky130_fd_sc_hd__tt_025C_1v80.lib \
    ${libdir}/fakeram130_256x64.lib \
    "

set lefs "  
    ${lefdir}/9M_li_2Ma_2Mb_2Mc_2Md_1Me.tlef \
    ${lefdir}/sky130_fd_sc_hd_merged.lef \
    ${lefdir}/fakeram130_256x64.lef \
    "

#set qrc_max "${qrcdir}/NG45.tch"
#set qrc_min "${qrcdir}/NG45.tch"
#
# Ensures proper and consistent library handling between Genus and Innovus
#set_db library_setup_ispatial true
