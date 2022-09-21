set y [dbget top.fplan.box_sizey]
set y1 [expr $y*0.175]
set y2 [expr $y - $y1]
set layers [dbget [dbget head.layers.direction Horizontal -p ].name]
set layer1 [lindex $layers 1]
set layer2 [lindex $layers 2]

set pin_layer [list $layer1 $layer2]
set pt1 [list 0 $y1]
set pt2 [list 0 $y2]
set pin_list [dbget top.terms.name]
editPin -pin $pin_list -edge 0 -start $pt1 -end $pt2 -fixedPin -layer $pin_layer -spreadDirection clockwise -pattern fill_optimised
