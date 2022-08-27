### Helper to convert Orientation format ###
proc get_orient { tmp_orient } {
  set orient "N"
  if { $tmp_orient == "N"} {
    set orient "R0"
  } elseif { $tmp_orient == "S" } {
    set orient "R180"
  } elseif { $tmp_orient == "W" } {
    set orient "R90"
  } elseif { $tmp_orient == "E" } {
    set orient "R270"
  } elseif { $tmp_orient == "FN" } {
    set oreint "MY"
  } elseif { $tmp_orient == "FS" } {
    set oreint "MX"
  } elseif { $tmp_orient == "FW" } {
    set orient "MX90" 
  } elseif { $tmp_orient == "FE" } {
    set orient "MY90"
  }
  return $orient
}

proc place_macro_from_pl {file_path} {
  set dbu 100
  set fp [open $file_path r]
  while { [gets $fp line] >= 0} {
    if {[llength $line] == 7} {
      set inst_name [lindex $line 0]
      puts "$inst_name"
      set pt_x [expr [lindex $line 1]/$dbu]
      set pt_y [expr [lindex $line 2]/$dbu]
      set tmp_orient [expr [lindex $line 5]]
      set orient [get_orient $tmp_orient]
      if {[dbget top.insts.name $inst_name -e] == ""} {
        puts "\[ERROR\] $inst_name does not exists."
      } else {
        placeInstance $inst_name $pt_x $pt_y $orient -fixed
      }
    }
  }
}