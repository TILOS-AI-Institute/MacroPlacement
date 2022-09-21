set design "ariane"
set top_design "ariane"
set netlist "/home/zf4_projects/DREAMPlace/sakundu/ABK_MP/07222022_flow_scripts/MacroPlacement/Flows/SKY130HD/ariane136/run-20220731-023129/flow2/def/ariane.v"
set def_file "/home/zf4_projects/DREAMPlace/sakundu/ABK_MP/07222022_flow_scripts/MacroPlacement/Flows/SKY130HD/ariane136/run-20220731-023129/flow2/def/ariane.def"
set ALL_LEFS "
    ../../../../../Enablements/SKY130HD/lef/9M_li_2Ma_2Mb_2Mc_2Md_1Me.tlef
    ../../../../../Enablements/SKY130HD/lef/sky130_fd_sc_hd_merged.lef
    ../../../../../Enablements/SKY130HD/lef/fakeram130_256x16.lef
"
set LIB_BC "
    ../../../../../Enablements/SKY130HD/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
    ../../../../../Enablements/SKY130HD/lib/fakeram130_256x16.lib
"
set site "unithd"
foreach lef_file ${ALL_LEFS} {
    read_lef $lef_file
}
foreach lib_file ${LIB_BC} {
    read_liberty $lib_file
}