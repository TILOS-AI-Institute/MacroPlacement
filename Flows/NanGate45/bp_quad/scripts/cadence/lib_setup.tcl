# This script was written and developed by ABKGroup students at UCSD. However, the underlying commands and reports are copyrighted by Cadence. 
# We thank Cadence for granting permission to share our research to help promote and foster the next generation of innovators.
# lib and lef, RC setup

set platformdir "../../../../../Enablements/NanGate45/"

set libdir "${platformdir}/lib"
set lefdir "${platformdir}/lef"
set qrcdir "${platformdir}/qrc"

set_db init_lib_search_path { \
    ${libdir} \
    ${lefdir} \
}


set libworst "  
    ${libdir}/NangateOpenCellLibrary_typical.lib \
    ${libdir}/fakeram45_32x32.lib \
    ${libdir}/fakeram45_128x116.lib \
    ${libdir}/fakeram45_256x48.lib \
    ${libdir}/fakeram45_512x64.lib \
    ${libdir}/fakeram45_64x62.lib \
    ${libdir}/fakeram45_64x124.lib \
    "


set libbest " 
    ${libdir}/NangateOpenCellLibrary_typical.lib \
    ${libdir}/fakeram45_32x32.lib \
    ${libdir}/fakeram45_128x116.lib \
    ${libdir}/fakeram45_256x48.lib \
    ${libdir}/fakeram45_512x64.lib \
    ${libdir}/fakeram45_64x62.lib \
    ${libdir}/fakeram45_64x124.lib \
    "

set lefs "
    ${lefdir}/NangateOpenCellLibrary.tech.lef \
    ${lefdir}/NangateOpenCellLibrary.macro.mod.lef \
    ${lefdir}/fakeram45_32x32.lef \
    ${lefdir}/fakeram45_128x116.lef \
    ${lefdir}/fakeram45_256x48.lef \
    ${lefdir}/fakeram45_512x64.lef \
    ${lefdir}/fakeram45_64x62.lef \
    ${lefdir}/fakeram45_64x124.lef \
    "

set qrc_max "${qrcdir}/NG45.tch"
set qrc_min "${qrcdir}/NG45.tch"
#
# Ensures proper and consistent library handling between Genus and Innovus
#set_db library_setup_ispatial true
setDesignMode -process 45 
