set design "ariane"
set top_design "ariane"
set netlist "/home/zf4_projects/DREAMPlace/sakundu/ABK_MP/07222022_flow_scripts/MacroPlacement/Flows/ASAP7/ariane136/run-20220731-023129/flow2/def/ariane.v"
set def_file "/home/zf4_projects/DREAMPlace/sakundu/ABK_MP/07222022_flow_scripts/MacroPlacement/Flows/ASAP7/ariane136/run-20220731-023129/flow2/def/ariane.def"
set ALL_LEFS "
    ../../../../../Enablements/ASAP7/lef/asap7_tech_1x_201209.lef
    ../../../../../Enablements/ASAP7/lef/asap7sc7p5t_27_R_1x_201211.lef
    ../../../../../Enablements/ASAP7/lef/sram_asap7_16x256_1rw.lef
"
set LIB_BC "
    ../../../../../Enablements/ASAP7/lib/asap7sc7p5t_SEQ_RVT_FF_nldm_201020.lib
    ../../../../../Enablements/ASAP7/lib/sram_asap7_64x64_1rw.lib
    ../../../../../Enablements/ASAP7/lib/asap7sc7p5t_OA_RVT_FF_nldm_201020.lib
    ../../../../../Enablements/ASAP7/lib/asap7sc7p5t_AO_RVT_FF_nldm_201020.lib
    ../../../../../Enablements/ASAP7/lib/asap7sc7p5t_INVBUF_RVT_FF_nldm_201020.lib
    ../../../../../Enablements/ASAP7/lib/sram_asap7_64x256_1rw.lib
    ../../../../../Enablements/ASAP7/lib/sram_asap7_16x256_1rw.lib
    ../../../../../Enablements/ASAP7/lib/asap7sc7p5t_SIMPLE_RVT_FF_nldm_201020.lib
    ../../../../../Enablements/ASAP7/lib/sram_asap7_32x256_1rw.lib
"
set site "asap7sc7p5t"
foreach lef_file ${ALL_LEFS} {
    read_lef $lef_file
}
foreach lib_file ${LIB_BC} {
    read_liberty $lib_file
}