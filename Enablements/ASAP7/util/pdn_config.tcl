#################################################################
# This is the config file for power grid generation. Variables in
# this files are used by pdn_flow.tcl available in the Flows/util
# directory.
#################################################################
# minCh:    If channel width is less than minCh it will be filled 
#           with hard blockages.
# layers:   Name of the layers.
# width:    Width of the layer.
# pitch:    Distance b/w two vdd/vss set.
# spacing:  Spacing b/w the stripe of vdd and vss.
# ldir:     Layer direction. 0 is horizontal and 1 is vertical.
# isMacro:  If layer stripe is only above macro.
# isBM:     If layer is below the top layer of macro.
# isAM:     If layer is above the top layer of macro.
# isFP:     If layer is for follow pin.
# soffset:  Start offset of the stripe.
# addch:    Any requierment to add extra layer in the macro
#           channel.
#################################################################

set minCh 2
set offset [expr 1.44*2 - [expr 0.117 + [dbget top.fplan.coreBox_llx ]]]
set layers  "M1     M2      M3      M5      M6      M9"
set width   "0      0.018   0.234   0.312   0.416   0.544"
set pitch   "0      0       3.60    2.016   12.8    7.2"
set spacing "0      0       0.342   0.504   0.672   0.672"
set ldir    "0      0       1       1       0       1"
set isMacro "0      0       0       1       0       0"
set isBM    "1      1       1       0       0       0"
set isAM    "0      0       0       0       1       1"
set isFP    "1      1       0       0       0       0"
set soffset "0      0       $offset 0.254   0.416   0.544"
set addch   "0      0       1       0       1       0"
