########################## Details to use this script ##########################
# Author: Sayak Kundu    email: sakundu@ucsd.edu
# Date: 11-22-2022
# This script converts LEF / DEF format to Protobuf format using OpenROAD.
# Follow the below steps to generate protobuf netlist from LEF / DEF in the
# OpenROAD shell:
#   1. read_lef <tech lef>
#   2. read_lef <standard cell and macro lef one by one>
#   3. read_def <design def file>
#   4. source <This script file>
#   5. gen_pb_netlist <path of the output protobuf netlist>
################################################################################
#### Print the design header ####
proc print_header { fp } {
  set design [[ord::get_db_block] getName]
  set user [exec whoami]
  set date [exec date]
  set run_dir [exec pwd]
  set canvas_width [ord::dbu_to_microns [[[ord::get_db_block] getCoreArea] dx]]
  set canvas_height [ord::dbu_to_microns [[[ord::get_db_block] getCoreArea] dy]]

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
  foreach bterm [$net_ptr getBTerms] {
    set type [$bterm getIoType]
    if { $type == "OUTPUT" } {
      set btermName [$bterm getName]
      puts $fp "  input: \"${btermName}\""
    }
  }
  
  ### For each inst pins ###
  foreach iterm [$net_ptr getITerms] {
    if { [$iterm isInputSignal] } {
      set inst [ $iterm getInst ]
      set isBlock [ $inst isBlock]
      set instName [$inst getName]
      if { $isBlock } {
        set pinName [[$iterm getMTerm] getName]
        puts $fp "  input: \"${instName}\/${pinName}\""
      } else {
        puts $fp "  input: \"${instName}\""
      }
    }
  }
}

### Procedure Find Side ###
proc find_bterm_side { pt_x pt_y dx dy} {
  set cond1 [expr $pt_x - $pt_y]
  set cond2 [expr ($pt_x/$dx) + ($pt_y/$dy) - 1]
  if { $cond1 > 0 } {
    if { $cond2 > 0 } {
      return "right"
    } else {
      return "bottom"
    }
  } else {
    if { $cond2 > 0 } {
      return "top"
    } else {
      return "left"
    }
  }
}

### Procedure Find Mid Point ###
proc find_mid_point { rect } {
  set xmin [$rect xMin]
  set ymin [$rect yMin]
  set dx [$rect dx]
  set dy [$rect dy]
  set pt_x [expr $xmin + $dx/2]
  set pt_y [expr $ymin + $dy/2]
  return [list $pt_x $pt_y]
}

proc find_mid_point_bbox { rect } {
  set xmin [$rect xMin]
  set ymin [$rect yMin]
  set dx [$rect getDX]
  set dy [$rect getDY]
  set pt_x [expr $xmin + $dx/2]
  set pt_y [expr $ymin + $dy/2]
  return [list $pt_x $pt_y]
}

#### Procedure to write Ports ####
proc write_node_port { port_ptr fp } {
  puts $fp "node {"
  
  set name [$port_ptr getName]
  puts $fp "  name: \"${name}\""
 
  if { [$port_ptr getIoType] == "INPUT" } {
    set net_ptr [$port_ptr getNet]
    print_net $net_ptr $fp
  }

  ### Attribute: type ###
  print_placeholder $fp "type" "port"

  ### Adjusting Core and Die ###
  set term_box [$port_ptr getBBox]
  set mid_pts [find_mid_point $term_box]
  set X [ord::dbu_to_microns [lindex $mid_pts 0]]
  set Y [ord::dbu_to_microns [lindex $mid_pts 1]]
  set dx [ord::dbu_to_microns [[[ord::get_db_block] getDieArea] dx]]
  set dy [ord::dbu_to_microns [[[ord::get_db_block] getDieArea] dy]]
  set die_llx [ord::dbu_to_microns [[[ord::get_db_block] getDieArea] xMin]]
  set die_lly [ord::dbu_to_microns [[[ord::get_db_block] getDieArea] yMin]]
  set side [find_bterm_side [expr $X - $die_llx] [expr $Y - $die_lly]\
            $dx $dy]
  
  ### Attribute: X, Y and Side ###
  print_placeholder $fp "side" $side

  set origin_x [ord::dbu_to_microns [[[ord::get_db_block] getCoreArea] xMin]]
  set origin_y [ord::dbu_to_microns [[[ord::get_db_block] getCoreArea] yMin]]
  ### Attribute: X ###
  if {$side == "top" || $side == "bottom"} {
    set X [expr $X - $origin_x]
  } elseif { $side == "right" } {
    set X [expr $X - 2*$origin_x]
  }
  
  print_float $fp "x" $X

  ### Attribute: Y ###
  if {$side == "left" || $side == "right"} {
    set Y [expr $Y - $origin_y]
  } elseif { $side == "top" } {
    set Y [expr $Y - 2*$origin_y]
  }

  print_float $fp "y" $Y
  
  puts $fp "}"
}

#### Procedure to write Macros ####
proc write_node_macro { macro_ptr fp } {
  puts $fp "node {"

  set name [$macro_ptr getName]
  puts $fp "  name: \"${name}\""

  ### Attribute: ref_name ###
  set master_ptr [$macro_ptr getMaster]
  set ref_name [$master_ptr getName]
  print_placeholder $fp "ref_name" ${ref_name}

  ### Attribute: Width ###
  set width [ord::dbu_to_microns [$master_ptr getWidth]]
  print_float $fp "width" $width

  ### Attribute: Height ###
  set height [ord::dbu_to_microns [$master_ptr getHeight]]
  print_float $fp "height" $height

  ### Attribute: type ###
  print_placeholder $fp "type" "macro"

  set inst_box [$macro_ptr getBBox]
  set pts [find_mid_point_bbox $inst_box]
  set origin_x [ord::dbu_to_microns [[[ord::get_db_block] getCoreArea] xMin]]
  set origin_y [ord::dbu_to_microns [[[ord::get_db_block] getCoreArea] yMin]]

  ### Attribute: X ###
  set X [ord::dbu_to_microns [lindex $pts 0]]
  set X [expr $X - $origin_x]
  print_float $fp "x" $X

  ### Attribute: Y ###
  set Y [ord::dbu_to_microns [lindex $pts 1]]
  set Y [expr $Y - $origin_y]
  print_float $fp "y" $Y
  
  ### Attribute: Orient ###
  set tmp_orient [${macro_ptr} getOrient]
  set orient [get_orient $tmp_orient]
  print_placeholder $fp "orientation" $orient

  puts $fp "}"
}

#### Procedure to Write Macro Pins ####
proc write_node_macro_pin { macro_pin_ptr fp } {
  puts $fp "node {"

  set macro_ptr [ ${macro_pin_ptr} getInst]
  set macro_name [ ${macro_ptr} getName ]
  set pin_name [ [${macro_pin_ptr} getMTerm] getName ]
  set name "${macro_name}\/${pin_name}"
  puts $fp "  name: \"${name}\""

  ### Print all the sinks ###
  if { [${macro_pin_ptr} isOutputSignal] } {
    set net_ptr [${macro_pin_ptr} getNet]
    print_net $net_ptr $fp
  }

  ### Attribute: Macro Name ###
  print_placeholder $fp "macro_name" $macro_name

  ### Attribute: type ###
  print_placeholder $fp "type" "macro_pin"
  
  set origin_x [ord::dbu_to_microns [[[ord::get_db_block] getCoreArea] xMin]]
  set origin_y [ord::dbu_to_microns [[[ord::get_db_block] getCoreArea] yMin]]

  set macro_master [${macro_ptr} getMaster]
  set cell_height [${macro_master} getHeight]
  set cell_width [ ${macro_master} getWidth]
  set mterm_ptr [${macro_pin_ptr} getMTerm]
  set pin_box [${mterm_ptr} getBBox]
  set pts [find_mid_point $pin_box]
  set x_offset [expr [lindex $pts 0] - $cell_width/2]
  set y_offset [expr [lindex $pts 1] - $cell_height/2]
  ### Attribute: x_offset ###
  set x_offset [ord::dbu_to_microns $x_offset]
  print_float $fp "x_offset" $x_offset
  
  ### Attribute: y_offset ###
  set y_offset [ord::dbu_to_microns $y_offset]
  print_float $fp "y_offset" $y_offset

  set pin_box [${macro_pin_ptr} getBBox]
  set pts [find_mid_point $pin_box]
  ### Attribute: X ###
  set X [ord::dbu_to_microns [lindex $pts 0]]
  set X [expr $X - $origin_x]
  print_float $fp "x" $X
  
  ### Attribute: Y ###
  set Y [ord::dbu_to_microns [lindex $pts 1]]
  set Y [expr $Y - $origin_y]
  print_float $fp "y" $Y
  
  puts $fp "}"
}

#### Procedure to Write Std-cell ###
proc write_node_stdcell { inst_ptr fp } {
  puts $fp "node {"

  set name [${inst_ptr} getName]
  puts $fp "  name: \"${name}\""

  ### Print all the sinks ###
  foreach iterm_ptr [${inst_ptr} getITerms] {
    if { [${iterm_ptr} isOutputSignal] } {
      set net_ptr [${iterm_ptr} getNet]
      print_net $net_ptr $fp
    }
  }

  ### Attribute: ref_name ###
  set master_ptr [${inst_ptr} getMaster]
  set ref_name [${master_ptr} getName]
  print_placeholder $fp "ref_name" $ref_name

  ### Attribute: Width ###
  set width [ord::dbu_to_microns [${master_ptr} getWidth]]
  print_float $fp "width" $width

  ### Attribute: Height ###
  set height [ord::dbu_to_microns [${master_ptr} getHeight]]
  print_float $fp "height" $height

  ### Attribute: type ###
  print_placeholder $fp "type" "stdcell"

  set inst_box [$inst_ptr getBBox]
  set pts [find_mid_point_bbox $inst_box]
  set origin_x [ord::dbu_to_microns [[[ord::get_db_block] getCoreArea] xMin]]
  set origin_y [ord::dbu_to_microns [[[ord::get_db_block] getCoreArea] yMin]]

  ### Attribute: X ###
  set X [ord::dbu_to_microns [lindex $pts 0]]
  set X [expr $X - $origin_x]
  print_float $fp "x" $X

  ### Attribute: Y ###
  set Y [ord::dbu_to_microns [lindex $pts 1]]
  set Y [expr $Y - $origin_y]
  print_float $fp "y" $Y
  
  puts $fp "}"
}

#### Generate protobuff format netlist ####
proc gen_pb_netlist { {file_name ""} } {
  set block [ord::get_db_block]
  set design [$block getName]
  
  if { $file_name != "" } {
    set out_file ${file_name}
  } else {
    set out_file "${design}.pb.txt"
  }
  
  set fp [open $out_file w+]

  print_header $fp

  foreach port_ptr [$block getBTerms] {  
    write_node_port $port_ptr $fp
  }

  foreach inst_ptr [$block getInsts] {
    ### Macro ###
    if { [${inst_ptr} isBlock] } {
      write_node_macro $inst_ptr $fp
      foreach macro_pin_ptr [${inst_ptr} getITerms] {
        if {[${macro_pin_ptr} isInputSignal] || [${macro_pin_ptr} isOutputSignal]} {
          write_node_macro_pin $macro_pin_ptr $fp
        }
      }
    } elseif { [${inst_ptr} isCore] } {
      ### Standard Cells ###
      write_node_stdcell $inst_ptr $fp
    }
  }
  close $fp
  exec sed -i {s@\\@@g} $out_file
  puts "Output netlist: $out_file"
}
