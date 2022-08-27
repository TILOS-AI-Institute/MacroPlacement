set design "mempool_tile_wrap"
set top_design "mempool_tile_wrap"
set netlist "/home/zf4_projects/DREAMPlace/sakundu/ABK_MP/07222022_flow_scripts/MacroPlacement/Flows/SKY130HD/mempool_tile/run-20220731-023129/flow2/def/mempool_tile_wrap.v"
set def_file "/home/zf4_projects/DREAMPlace/sakundu/ABK_MP/07222022_flow_scripts/MacroPlacement/Flows/SKY130HD/mempool_tile/run-20220731-023129/flow2/def/mempool_tile_wrap.def"
set ALL_LEFS "
    ../../../../../Enablements/SKY130HD/lef/9M_li_2Ma_2Mb_2Mc_2Md_1Me.tlef
    ../../../../../Enablements/SKY130HD/lef/sky130_fd_sc_hd_merged.lef
    ../../../../../Enablements/SKY130HD/lef/fakeram130_256x32.lef
    ../../../../../Enablements/SKY130HD/lef/fakeram130_64x64.lef
"
set LIB_BC "
    ../../../../../Enablements/SKY130HD/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
    ../../../../../Enablements/SKY130HD/lib/fakeram130_256x32.lib
    ../../../../../Enablements/SKY130HD/lib/fakeram130_64x64.lib
"
set site "unithd"
foreach lef_file ${ALL_LEFS} {
    read_lef $lef_file
}
foreach lib_file ${LIB_BC} {
    read_liberty $lib_file
}