## Make sure all the Macro has HALO ##
deselectAll
set top_module [dbget top.name]

if {[dbget top.terms.pStatus -v -e fixed] != "" } {
    source ../../../../util/place_pin.tcl
}

exec mkdir -p def
### Remove Halo as OR do not support ###
deleteHaloFromBlock -allBlock

#### Below files can be used in the Code element to generate clustered netlist ####
defOut -netlist ./def/${top_module}.def
saveNetlist -removePowerGround ./def/${top_module}.v
saveNetlist -flat -removePowerGround ./def/${top_module}_flat.v


### Add halo ###
addHaloToBlock -allMacro $HALO_WIDTH $HALO_WIDTH $HALO_WIDTH $HALO_WIDTH

#### Unplace the standard cells ###
dbset [dbget top.insts.cell.subClass core -p2 ].pStatus unplaced

#### Write out Macro Placed def ####
dbset [dbget top.insts.cell.subClass block -p2 ].pStatus placed
defOut -floorplan ./def/${top_module}_fp_placed_macros.def

#### Unplace the macros ###
dbset [dbget top.insts.cell.subClass block -p2 ].pStatus unplaced

### Remove Halo as OR do not support ###
deleteHaloFromBlock -allBlock

### Write out Pin Placed def only ###
defOut -floorplan ./def/${top_module}_fp.def


### Read the Macro Def ###
defIn ./def/${top_module}_fp_placed_macros.def

### Fix macros ###
dbset [dbget top.insts.cell.subClass block -p2 ].pStatus fixed

### run global place during place opt ###
setPlaceMode -place_opt_run_global_place full
