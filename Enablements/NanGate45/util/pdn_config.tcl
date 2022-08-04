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
set layers  "metal1 metal4  metal5  metal6  metal7  metal10"
set width   "0      0.84    0.84    0.84    2.4     3.20"
set pitch   "0      20.16   10.08   10.08   40      32"
set spacing "0      0.56    0.56    0.56    1.6     1.6"
set ldir    "0      1       0       1       0       1"
set isMacro "0      0       1       1       0       0"
set isBM    "1      1       0       0       0       0"
set isAM    "0      0       1       1       1       1"
set isFP    "1      0       0       0       0       0"
set soffset "0      2       2       2       2       2"
set addch   "0      1       0       0       0       0"
