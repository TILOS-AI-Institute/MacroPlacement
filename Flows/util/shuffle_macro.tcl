proc shuffle1 {list} {
    set n [llength $list]
    for {set i 0} {$i < $n} {incr i} {
        set j [expr {int(rand() * $n)}]
        set temp [lindex $list $j]
        set list [lreplace $list $j $j [lindex $list $i]]
        set list [lreplace $list $i $i $temp]
    }
    return $list
}

proc shuffle_macros {} {
  foreach macro_ref [dbget [dbget top.insts.cell.subClass block -p ].name -u] {
    set macro_list [dbget [dbget top.insts.cell.name $macro_ref -p2 ].name]
    set pt_x_list [dbget [dbget top.insts.cell.name $macro_ref -p2 ].pt_x]
    set pt_y_list [dbget [dbget top.insts.cell.name $macro_ref -p2 ].pt_y]
    set orient_list [dbget [dbget top.insts.cell.name $macro_ref -p2 ].orient]

    set number_macros [llength $macro_list]
    set shuffle_macros [shuffle1 $macro_list]

    ## Unplace all macros ##
    dbset [dbget top.insts.cell.name $macro_ref -p2 ].pStatus unplaced
    set i 0
    set k 0
    foreach macro $shuffle_macros {
      set pt_x [lindex $pt_x_list $i]
      set pt_y [lindex $pt_y_list $i]
      set orient [lindex $orient_list $i]
      placeInstance $macro $pt_x $pt_y $orient -fixed
      incr i
      if {[lindex $macro_list $i] != $macro} {
        incr k
      }
    }
    puts "$k macros (ref name: ${macro_ref}) are shuffled"
  }
}