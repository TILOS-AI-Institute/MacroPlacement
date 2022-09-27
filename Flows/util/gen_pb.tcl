#############################################################################
# This script was written and developed by ABKGroup students at UCSD.
# However, the underlying commands and reports are copyrighted by Cadence. 
# We thank Cadence for granting permission to share our research to help 
# promote and foster the next generation of innovators.
# Author: Sayak Kundu, ABKGroup, UCSD
#
# Usage: First source the script in Innovus shell. then use gen_pb_netlist
# command to write out the netlist. The protobuf netlist will be available
# as <design name>.pb.txt.
#############################################################################

#### Print the design header ####
proc print_header { fp } {
  set design [dbget top.name]
  set user [exec whoami]
  set date [exec date]
  set run_dir [exec pwd]
  set canvas_width [dbget top.fplan.coreBox_sizex]
  set canvas_height [dbget top.fplan.coreBox_sizey]

  puts $fp "# User: $user"
  puts $fp "# Date: $date"
  puts $fp "# Run area: $run_dir"
  puts $fp "# Block : $design"
  puts $fp "# FP bbox: {0.0 0.0} {$canvas_width $canvas_height}"
  ## Add dummy Column and Row info ##
  puts $fp "# Columns : 10  Rows : 10"
}

#### Print helper ####
proc print_placeholder { fp key value } {
  puts $fp "  attr {"
  puts $fp "    key: \"$key\""
  puts $fp "    value {"
  puts $fp "      placeholder: \"$value\""
  puts $fp "    }"
  puts $fp "  }"
}

proc print_float { fp key value } {
  puts $fp "  attr {"
  puts $fp "    key: \"$key\""
  puts $fp "    value {"
  puts $fp "      f: $value"
  puts $fp "    }"
  puts $fp "  }"
}

### Helper to convert Orientation format ###
proc get_orient { tmp_orient } {
  set orient "N"
  if { $tmp_orient == "R0"} {
    set orient "N"
  } elseif { $tmp_orient == "R180" } {
    set orient "S"
  } elseif { $tmp_orient == "R90" } {
    set orient "W"
  } elseif { $tmp_orient == "R270" } {
    set orient "E"
  } elseif { $tmp_orient == "MY" } {
    set oreint "FN"
  } elseif { $tmp_orient == "MX" } {
    set oreint "FS"
  } elseif { $tmp_orient == "MX90" } {
    set orient "FW" 
  } elseif { $tmp_orient == "MY90" } {
    set orient "FE"
  }

  return $orient
}

#### Procedure to print the sinks ####
proc print_net { net_ptr fp } {
  ### Print Terms ###
  foreach term [dbget [dbget ${net_ptr}.terms.isOutput 1 -p ].name -e] {
    puts $fp "  input: \"${term}\""
  }
  
  ### Print Macro Pins ###
  foreach macro_pin [dbget [dbget [dbget ${net_ptr}.instTerms.isInput 1 -p \
                    ].inst.cell.subClass block -p3 ].name -e] {
    puts $fp "  input: \"${macro_pin}\""
  }
  
  ### Print Stdcells ###
  foreach inst [dbget [dbget [dbget ${net_ptr}.instTerms.isInput 1 -p \
                    ].inst.cell.subClass core -p2 ].name -e] {
    puts $fp "  input: \"${inst}\""
  }
}

#### Procedure to write Ports ####
proc write_node_port { port_ptr fp {origin_x 0} {origin_y 0} } {
  puts $fp "node {"
  
  set name [lindex [dbget ${port_ptr}.name] 0]
  puts $fp "  name: \"${name}\""
 
  if { [dbget ${port_ptr}.isInput] == 1 } {
    set net_ptr [dbget ${port_ptr}.net]
    print_net $net_ptr $fp
  }

  ### Attribute: type ###
  print_placeholder $fp "type" "port"

  ### Attribute: Side ###
  set tmp_side [dbget ${port_ptr}.side]
  set side ""
  if {$tmp_side == "West"} {
    set side "left"
  } elseif {$tmp_side == "East"} {
    set side "right"
  } elseif {$tmp_side == "North"} {
    set side "top"
  } elseif {$tmp_side == "South"} {
    set side "bottom"
  } else {
    puts "Error: Wrong Direction. Port Name: $name"
  }
  print_placeholder $fp "side" $side

  ### Attribute: X ###
  set X1 [lindex [dbget ${port_ptr}.pinShapes.rect] 0 0]
  set X2 [lindex [dbget ${port_ptr}.pinShapes.rect] 0 2]
  set X [expr ($X1 + $X2)/2]
  
  if {$side == "top" || $side == "bottom"} {
    set X [expr $X - $origin_x]
  }
  
  print_float $fp "x" $X

  ### Attribute: Y ###
  set Y1 [lindex [dbget ${port_ptr}.pinShapes.rect] 0 1]
  set Y2 [lindex [dbget ${port_ptr}.pinShapes.rect] 0 3]
  set Y [expr ($Y1 + $Y2)/2]
  if {$side == "left" || $side == "right"} {
    set Y [expr $Y - $origin_y]
  }
  print_float $fp "y" $Y
  
  puts $fp "}"
}

#### Procedure to write Macros ####
proc write_node_macro { macro_ptr fp {origin_x 0} {origin_y 0}} {
  puts $fp "node {"

  set name [lindex [dbget ${macro_ptr}.name] 0]
  puts $fp "  name: \"${name}\""

  ### Attribute: ref_name ###
  set ref_name [dbget ${macro_ptr}.cell.name]
  print_placeholder $fp "ref_name" ${ref_name}

  ### Attribute: Width ###
  set width [dbget ${macro_ptr}.box_sizex]
  print_float $fp "width" $width

  ### Attribute: Height ###
  set height [dbget ${macro_ptr}.box_sizey]
  print_float $fp "height" $height

  ### Attribute: type ###
  print_placeholder $fp "type" "macro"

  ### Attribute: X ###
  set X1 [lindex [dbget ${macro_ptr}.box] 0 0]
  set X2 [lindex [dbget ${macro_ptr}.box] 0 2]
  set X [expr ($X1 + $X2)/2 - $origin_x]
  print_float $fp "x" $X

  ### Attribute: Y ###
  set Y1 [lindex [dbget ${macro_ptr}.box] 0 1]
  set Y2 [lindex [dbget ${macro_ptr}.box] 0 3]
  set Y [expr ($Y1 + $Y2)/2 - $origin_y]
  print_float $fp "y" $Y
  
  ### Attribute: Y ###
  set tmp_orient [dbget ${macro_ptr}.orient]
  set orient [get_orient $tmp_orient]
  print_placeholder $fp "orientation" $orient

  puts $fp "}"
}

#### Procedure to Write Macro Pins ####
proc write_node_macro_pin { macro_pin_ptr fp {origin_x 0} {origin_y 0}} {
  puts $fp "node {"

  set name [lindex [dbget ${macro_pin_ptr}.name] 0]
  puts $fp "  name: \"${name}\""

  ### Print all the sinks ###
  if { [dbget ${macro_pin_ptr}.isOutput] == 1} {
    set net_ptr [dbget ${macro_pin_ptr}.net]
    print_net $net_ptr $fp
  }

  ### Attribute: Macro Name ###
  set macro_name [lindex [dbget ${macro_pin_ptr}.inst.name] 0]
  print_placeholder $fp "macro_name" $macro_name

  ### Attribute: type ###
  print_placeholder $fp "type" "macro_pin"
  
  set X [expr [dbget ${macro_pin_ptr}.pt_x] - $origin_x]
  set Y [expr [dbget ${macro_pin_ptr}.pt_y] - $origin_y]
  set cell_height [dbget ${macro_pin_ptr}.cellTerm.cell.size_y]
  set cell_width [dbget ${macro_pin_ptr}.cellTerm.cell.size_x]
  set pin_x [dbget ${macro_pin_ptr}.cellTerm.pt_x]
  set pin_y [dbget ${macro_pin_ptr}.cellTerm.pt_y]
  set x_offset [expr $pin_x - $cell_width/2]
  set y_offset [expr $pin_y - $cell_height/2]

  ### Attribute: x_offset ###
  print_float $fp "x_offset" $x_offset
  
  ### Attribute: y_offset ###
  print_float $fp "y_offset" $y_offset

  ### Attribute: X ###
  print_float $fp "x" $X
  
  ### Attribute: Y ###
  print_float $fp "y" $Y
  
  puts $fp "}"
}

#### Procedure to Write Std-cell ###
proc write_node_stdcell { inst_ptr fp {origin_x 0} {origin_y 0}} {
  puts $fp "node {"

  set name [lindex [dbget ${inst_ptr}.name] 0]
  puts $fp "  name: \"${name}\""

  ### Print all the sinks ###
  foreach net_ptr [dbget [dbget ${inst_ptr}.instTerms.isOutput 1 -p ].net -e ] {
    print_net $net_ptr $fp
  }

  ### Attribute: ref_name ###
  set ref_name [dbget ${inst_ptr}.cell.name]
  print_placeholder $fp "ref_name" $ref_name

  ### Attribute: Width ###
  set width [dbget ${inst_ptr}.box_sizex]
  print_float $fp "width" $width

  ### Attribute: Height ###
  set height [dbget ${inst_ptr}.box_sizey]
  print_float $fp "height" $height

  ### Attribute: type ###
  print_placeholder $fp "type" "stdcell"

  ### Attribute: X ###
  set X1 [lindex [dbget ${inst_ptr}.box] 0 0]
  set X2 [lindex [dbget ${inst_ptr}.box] 0 2]
  set X [expr ($X1 + $X2)/2 - $origin_x]
  print_float $fp "x" $X

  ### Attribute: Y ###
  set Y1 [lindex [dbget ${inst_ptr}.box] 0 1]
  set Y2 [lindex [dbget ${inst_ptr}.box] 0 3]
  set Y [expr ($Y1 + $Y2)/2 - $origin_y]
  print_float $fp "y" $Y
  
  puts $fp "}"
}

#### Generate protobuff format netlist ####
proc gen_pb_netlist { } {
  set design [dbget top.name]
  set out_file "${design}.pb.txt"
  set fp [open $out_file w+]

  print_header $fp
  set origin_x [dbget top.fplan.coreBox_llx]
  set origin_y [dbget top.fplan.coreBox_lly]

  foreach port_ptr [dbget top.terms] {  
    write_node_port $port_ptr $fp $origin_x $origin_y
  }

  foreach macro_ptr [dbget top.insts.cell.subClass block -p2] {
    write_node_macro $macro_ptr $fp $origin_x $origin_y
    foreach macro_pin_ptr [dbget ${macro_ptr}.instTerms] {
      write_node_macro_pin $macro_pin_ptr $fp $origin_x $origin_y
    }
  }

  foreach inst_ptr [dbget top.insts.cell.subClass core -p2] {
    write_node_stdcell $inst_ptr $fp $origin_x $origin_y
  }

  close $fp
  puts "Output netlist: $out_file"
}
