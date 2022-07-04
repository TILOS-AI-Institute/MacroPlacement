# This script was written and developed by ABKGroup students at UCSD. However, the underlying commands and reports are copyrighted by Cadence. 
# We thank Cadence for granting permission to share our research to help promote and foster the next generation of innovators.
# lib and lef, RC setup

set libdir "../../../../../Enablements/NanGate45/lib"
set lefdir "../../../../../Enablements/NanGate45/lef"
set qrcdir "../../../../../Enablements/NanGate45/qrc"

set_db init_lib_search_path { \
    ${libdir} \
    ${lefdir} \
}

set libworst "  
    ${libdir}/NangateOpenCellLibrary_typical.lib \
    ${libdir}/fakeram45_256x32.lib \
    ${libdir}/fakeram45_64x64.lib \
    "


set libbest " 
    ${libdir}/NangateOpenCellLibrary_typical.lib \
    ${libdir}/fakeram45_256x32.lib \
    ${libdir}/fakeram45_64x64.lib \
    "

set lefs "  
    ${lefdir}/NangateOpenCellLibrary.tech.lef \
    ${lefdir}/NangateOpenCellLibrary.macro.mod.lef \
    ${lefdir}/fakeram45_256x32.lef \
    ${lefdir}/fakeram45_64x64.lef \
    "
#
# Ensures proper and consistent library handling between Genus and Innovus
#set_db library_setup_ispatial true

set qrc_max "${qrcdir}/NG45.tch"
set qrc_min "${qrcdir}/NG45.tch"
