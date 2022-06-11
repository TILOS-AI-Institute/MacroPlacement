set design "ariane"
set top_design "ariane"
set netlist "./design/1_synth.v"
set sdc     "./design/1_synth.sdc"
# If the netlist is post-synthesis, the def_file is the floorplan_def with placed pins
set def_file "./design/2_floorplan.def"

set ALL_LEFS "
    ./lefs/NangateOpenCellLibrary.tech.lef 
    ./lefs/NangateOpenCellLibrary.macro.mod.lef 
    ./lefs/fakeram45_256x16.lef
    "

set LIB_BC "
    ./libs/NangateOpenCellLibrary_typical.lib 
    ./libs/fakeram45_256x16.lib
    "

set site "FreePDK45_38x28_10R_NP_162NW_34O"

foreach lef_file ${ALL_LEFS} {
	read_lef $lef_file
}

foreach lib_file ${LIB_BC} {
	read_liberty $lib_file
}

