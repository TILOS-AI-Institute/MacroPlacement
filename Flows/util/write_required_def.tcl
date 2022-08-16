## Make sure all the Macro has HALO ##
addHaloToBlock -allMacro $HALO_WIDTH $HALO_WIDTH $HALO_WIDTH $HALO_WIDTH
deselectAll
set top_module [dbget top.name]

if {[dbget top.terms.pStatus -v -e fixed] == "" } {
    source ../../../../util/place_pin.tcl
}

exec mkdir -p def
select_obj [dbget top.terms ]
defOut -selected -floorplan ./def/${top_module}_fp.def

dbset [dbget top.insts.isHaloBlock 1 -p ].pStatus placed
selectInst [dbget [dbget top.insts.isHaloBlock 1 -p ].name]

defOut -selected -floorplan ./def/${top_module}_fp_macro_placed.def
dbset [dbget top.insts.isHaloBlock 1 -p ].pStatus fixed
deselectAll

### Remove Halo as OR do not support ###
deleteHaloFromBlock -allBlock

#### Below files can be used in the Code element to generate clustered netlist ####
defOut -netlist ./def/${top_module}.def
saveNetlist -removePowerGround ./def/${top_module}.v
saveNetlist -flat -removePowerGround ./def/${top_module}_flat.v

### Add halo again ###
addHaloToBlock -allMacro $HALO_WIDTH $HALO_WIDTH $HALO_WIDTH $HALO_WIDTH
