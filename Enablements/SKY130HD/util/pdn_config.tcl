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

set minCh 5
set layers  "met1   met4    met5    met6    met7    met8    met9"
set width   "0      1.38    1.36    1.36    2.76    2.76    3.40"
set pitch   "0      20.24   10.2    10.2    30.36   30.36   34.0"
set spacing "0      0.23    0.34    0.34    0.46    0.46    1.70"
set ldir    "0      1       0       1       0       1       0"
set isMacro "0      0       1       1       0       0       0"
set isBM    "1      1       0       0       0       0       0"
set isAM    "0      0       1       1       1       1       1"
set isFP    "1      0       0       0       0       0       0"
set soffset "0      2       2       2       2       2       2"
set addch   "0      1       0       0       0       0       0"