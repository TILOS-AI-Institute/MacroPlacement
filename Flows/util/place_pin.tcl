proc place_pins { {side 0} {pin_list ""} {perc 0.6}} {
  if { $pin_list == "" } {
    set pin_list [dbget top.terms.name]
  }

  if { $perc > 1 || $perc < 0 } {
    set perc 0.6
  }

  set height [dbget top.fplan.box_sizey]
  set width [dbget top.fplan.box_sizex]

  set x1 0
  set x2 $width
  set y1 0
  set y2 $height

  if { $side == 0 } {
    set x2 $x1
    set y1 [expr $height*(1- $perc)/2]
    set y2 [expr $height - $y1]  
  } elseif { $side == 1 } {
    set y1 $y2
    set x1 [expr $width*(1 - $perc)/2]
    set x2 [expr $width - $x1]
  } elseif { $side == 2 } {
    set x1 $x2
    set y2 [expr $height*(1- $perc)/2]
    set y1 [expr $height - $y2]
  } elseif { $side == 3 } {
    set y2 $y1
    set x2 [expr $width*(1 - $perc)/2]
    set x1 [expr $width - $x2]
  } else {
    puts "Side is not correct"
    return
  }

  if { $side == 0 || $side == 2 } {
    set layers [dbget [dbget head.layers.direction Horizontal -p ].name]
  } else {
    set layers [dbget [dbget head.layers.direction Vertical -p ].name]
  }

  set layer1 [lindex $layers 1]
  set layer2 [lindex $layers 2]
  set pin_layer [list $layer1 $layer2]

  set pt1 [list $x1 $y1]
  set pt2 [list $x2 $y2]

  editPin -pin $pin_list -edge $side -start $pt1 -end $pt2 -fixedPin -layer $pin_layer -spreadDirection clockwise -pattern fill_optimised  
}