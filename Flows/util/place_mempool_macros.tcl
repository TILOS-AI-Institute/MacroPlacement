#############################################################################
# This script was written and developed by ABKGroup students at UCSD.
# However, the underlying commands and reports are copyrighted by Cadence. 
# We thank Cadence for granting permission to share our research to help 
# promote and foster the next generation of innovators.
# Author: Sayak Kundu (sakundu@ucsd.edu), ABKGroup, UCSD. 
# Thanks to Matheus Cavalcante, ETH Zürich and Jiantao Liu (jil313@ucsd.edu) 
# for providing the tile configuration.
#
# Usage: This script places macros for MemPool Group NG45 design. First source
# the script in the Innovus terminal and then use the following command:
#   mempool_group_macro_placement
#############################################################################

# Y Flip
# RO --> MX      MY --> R180
# It do not validate if there is enough space to create the macro stack
# For the boundary macros of the cluster always have pin facing towards outside
# Stack size indicates the number of macros will be stacked
# Also it considers all the macro size in the macro list is same
proc place_macro_mem_stack {macro_list stack_size ch_space origin_x origin_y\
                            isFlip} {
  
  if {$isFlip == 0} {
    set orient [list "R0" "MY"]
    set stack_dir 1
  } else {
    set orient [list "MX" "R180"]
    set stack_dir -1
  }

  # Extract macro informations
  set macro_width [dbget [dbget top.insts.name [lindex $macro_list 0] -p ].box_sizex]
  set macro_height [dbget [dbget top.insts.name [lindex $macro_list 0] -p ].box_sizey]

  # i indicates the row number and j indicates the column number
  set i 0
  set j 0
  set llx $origin_x
  set lly $origin_y
  foreach macro $macro_list {
    # For each column all the macros have same orientation
    set orientation [lindex $orient [expr $j%2]]
    placeInstance $macro $llx $lly $orientation -placed

    incr i
    if { $i == $stack_size } {
      set i 0
      incr j
      set lly $origin_y
      set llx [expr $origin_x + ($j/2)*$ch_space + $j*$macro_width]
    } else {
      set lly [expr $origin_y + ${stack_dir}*($i*$macro_height)]
    }
  }
}

proc place_macro_mem_stack_in {macro_list stack_size ch_space origin_x origin_y\
                            isFlip} {
  if {$isFlip == 0} {
    set orient [list "R0" "MY"]
    set stack_dir 1
  } else {
    set orient [list "MX" "R180"]
    set stack_dir -1
  }

  # Extract macro informations
  set macro_width [dbget [dbget top.insts.name [lindex $macro_list 0] -p ].box_sizex]
  set macro_height [dbget [dbget top.insts.name [lindex $macro_list 0] -p ].box_sizey]

  # i indicates the row number and j indicates the column number
  set i 0
  set j 1
  set llx $origin_x
  set lly $origin_y
  foreach macro $macro_list {
    # For each column all the macros have same orientation
    set orientation [lindex $orient [expr $j%2]]
    placeInstance $macro $llx $lly $orientation -placed

    incr i
    if { $i == $stack_size } {
      set i 0
      incr j
      set lly $origin_y
      set llx [expr $origin_x + ($j/2)*$ch_space + ($j-1)*$macro_width]
    } else {
      set lly [expr $origin_y + ${stack_dir}*($i*$macro_height)]
    }
  }
}

# Tile origin is always the lower left coordinate of the tile bbox
proc place_tiles {tile_id tile_origin_x tile_origin_y tile_width tile_height \
                  isFlip {halo_wdith 5} {stack_size 2} } {
  # ICACHE
  set icache_rams [dbget [dbget top.insts.cell.subClass block -p2\
                  ].name gen_tiles[${tile_id}]*i_tile*i_lookup*i_data*]
  set icache_width [dbget [dbget top.insts.name [lindex $icache_rams 0] -p \
                  ].cell.size_x]
  set icache_height [dbget [dbget top.insts.name [lindex $icache_rams 0] -p \
                  ].cell.size_y]

  set ch_space [expr $halo_wdith*4]
  
  ## Place the ICACHE memories on the left boundary
  ## Stack two memories together
  set icache_llx [expr $tile_origin_x + $ch_space]
  if { $isFlip == 0 } {
    set icache_lly [expr $tile_origin_y + $ch_space]
  } else {
    set icache_lly [expr $tile_origin_y + $tile_height - $icache_height - $ch_space]
  }
  
  place_macro_mem_stack $icache_rams 2 $ch_space $icache_llx $icache_lly $isFlip

  # Place the TCDM memories on the right of the boundary
  # Stack 4 memories together
  # Ensure 
  set tcdm_rams [dbget [dbget top.insts.cell.subClass block -p2 ].name \
              gen_tiles*[${tile_id}]*i_tile*mem_bank*]
  set tcdm_width [dbget [dbget top.insts.name [lindex $tcdm_rams 0] -p \
                  ].cell.size_x]
  set tcdm_height [dbget [dbget top.insts.name [lindex $tcdm_rams 0] -p \
                  ].cell.size_y]
    
  if { $stack_size == 2 } {
    set tcdm_llx [expr $tile_origin_x + $tile_width - 4*$ch_space - 8*$tcdm_width]
  } elseif { $stack_size == 4 } {
    set tcdm_llx [expr $tile_origin_x + $tile_width - 2*$ch_space - 4*$tcdm_width]
  }
  if { $isFlip == 0 } {
    set tcdm_lly [expr $tile_origin_y + $ch_space]
  } else {
    set tcdm_lly [expr $tile_origin_y + $tile_height - $ch_space - $tcdm_height]
  }

  place_macro_mem_stack $tcdm_rams $stack_size $ch_space $tcdm_llx $tcdm_lly $isFlip
}

proc mempool_group_macro_placement { {halo_width 10} {stack_size 2} } {
  set core_llx [dbget top.fplan.coreBox_llx]
  set core_lly [dbget top.fplan.coreBox_lly]
  set core_width [dbget top.fplan.coreBox_sizex]
  set core_height [dbget top.fplan.coreBox_sizey]
  set tile_height [expr $core_height/4.0]
  set tile_width [expr $core_width/4.0]

  #set halo_width 10

  # Scramble tiles
  set toffsets [list \
              [list  0  1  4  5]\
              [list  2  3  6  7]\
              [list  8  9 12 13]\
              [list 10 11 14 15]]
  # i is row and j is coloum
  set isFlip 0
  for { set i 0 } { $i < 4 } { incr i } {
    if { $i > 1 } {
      set isFlip 1
    }
    set tile_ly [expr $core_lly + $i*$tile_height]
    
    for { set j 0 } { $j < 4 } { incr j } {
      set tile_lx [expr $core_llx + $j*$tile_width]
      set tile_id [lindex $toffsets $i $j]
      puts "Placing Tile:$tile_id Tile lx:$tile_lx ly:$tile_ly Height:$tile_height Width:$tile_width"
      place_tiles $tile_id $tile_lx $tile_ly $tile_width $tile_height $isFlip $halo_width $stack_size
    }
  }
}
