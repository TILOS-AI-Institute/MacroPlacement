set design "ariane"
set top_design "ariane"
set netlist "/home/zf4_projects/DREAMPlace/sakundu/ABK_MP/07222022_flow_scripts/MacroPlacement/Flows/NanGate45/ariane133/run-20220731-023129/flow2/def/ariane.v"
set def_file "/home/zf4_projects/DREAMPlace/sakundu/ABK_MP/07222022_flow_scripts/MacroPlacement/Flows/NanGate45/ariane133/run-20220731-023129/flow2/def/ariane.def"
set ALL_LEFS "
    ../../../../../Enablements/NanGate45/lef/NangateOpenCellLibrary.tech.lef
    ../../../../../Enablements/NanGate45/lef/NangateOpenCellLibrary.macro.mod.lef
    ../../../../../Enablements/NanGate45/lef/fakeram45_256x16.lef
    ../../../../../Enablements/NanGate45/lef/fakeram45_256x64.lef
"
set LIB_BC "
    ../../../../../Enablements/NanGate45/lib/NangateOpenCellLibrary_typical.lib
    ../../../../../Enablements/NanGate45/lib/fakeram45_256x16.lib
    ../../../../../Enablements/NanGate45/lib/fakeram45_256x64.lib
"
set site "FreePDK45_38x28_10R_NP_162NW_34O"
foreach lef_file ${ALL_LEFS} {
    read_lef $lef_file
}
foreach lib_file ${LIB_BC} {
    read_liberty $lib_file
}