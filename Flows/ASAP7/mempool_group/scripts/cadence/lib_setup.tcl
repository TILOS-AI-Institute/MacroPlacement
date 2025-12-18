# This script was written and developed by ABKGroup students at UCSD. However, the underlying commands and reports are copyrighted by Cadence. 
# We thank Cadence for granting permission to share our research to help promote and foster the next generation of innovators.
# lib and lef, RC setup

set libdir "../../../../../Enablements/ASAP7/lib"
set lefdir "../../../../../Enablements/ASAP7/lef"
set qrcdir "../../../../../Enablements/ASAP7/qrc"

set_db init_lib_search_path { \
    ${libdir} \
    ${lefdir} \
}

set libworst "
    ${libdir}/asap7sc7p5t_AO_RVT_FF_nldm_201020.lib \
    ${libdir}/asap7sc7p5t_INVBUF_RVT_FF_nldm_201020.lib \
    ${libdir}/asap7sc7p5t_OA_RVT_FF_nldm_201020.lib \
    ${libdir}/asap7sc7p5t_SEQ_RVT_FF_nldm_201020.lib \
    ${libdir}/asap7sc7p5t_SIMPLE_RVT_FF_nldm_201020.lib \
    ${libdir}/sram_asap7_32x256_1rw.lib \
    ${libdir}/sram_asap7_64x64_1rw.lib \
    ${libdir}/sram_asap7_256x128_1rw.lib \
    ${libdir}/sram_asap7_32x128_1rw.lib \
    "

set libbest $libworst

set lefs "
    ${lefdir}/asap7_tech_1x_201209.lef \
    ${lefdir}/asap7sc7p5t_27_R_1x_201211.lef \
    ${lefdir}/sram_asap7_32x256_1rw.lef \
    ${lefdir}/sram_asap7_64x64_1rw.lef \
    ${lefdir}/sram_asap7_256x128_1rw.lef \
    ${lefdir}/sram_asap7_32x128_1rw.lef \
    "

set qrc_max "${qrcdir}/ASAP7.tch"
set qrc_min "${qrcdir}/ASAP7.tch"
#
# Ensures proper and consistent library handling between Genus and Innovus
#set_db library_setup_ispatial true
setDesignMode -process 7
