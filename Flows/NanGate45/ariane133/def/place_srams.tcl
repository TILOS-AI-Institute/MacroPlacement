# This script was written and developed by ABKGroup students at UCSD. However, the underlying commands and reports are copyrighted by Cadence. 
# We thank Cadence for granting permission to share our research to help promote and foster the next generation of innovators.
# We thank Dr. Jinwook Jung for sharing the Human Macro Placement of Ariane-133 design.
# Disclaimer from Dr. Jung: I don’t have any prior knowledge about the design, and just did the placement based on the SRAM instance names as well as “aesthetic.”

unplaceAllBlocks

set sram_name fakeram45_256x16
set sram_size_x [dbGet [dbGet head.libCells.name $sram_name -p].size_x]
set sram_size_y [dbGet [dbGet head.libCells.name $sram_name -p].size_y]
set sram_size_hx [expr $sram_size_x / 2]
set sram_size_hy [expr $sram_size_y / 2]

set halo_size_x 5
set halo_size_y 5

set fp_llx [dbGet top.fPlan.coreBox_llx]
set fp_lly [dbGet top.fPlan.coreBox_lly]
set fp_urx [dbGet top.fPlan.coreBox_urx]
set fp_ury [dbGet top.fPlan.coreBox_ury]
set fp_cx [expr [dbGet top.fPlan.coreBox_urx]/2]
set fp_cy [expr [dbGet top.fPlan.coreBox_ury]/2]

set site_width [dbGet head.sites.size_x]  ;# 0.19
set fp_spacing_urx [expr 260*$site_width]
set fp_spacing_ury [expr 260*$site_width]




#-------------------------------------------------------------------------------
# i_icache/tag
#-------------------------------------------------------------------------------
set begin_llx [expr $fp_urx - $fp_spacing_urx - $sram_size_x]
set begin_lly [expr $fp_cy  - $sram_size_hy]
set WAY 4
set NUM_SRAMS_PER_WAY 3
for {set i 0} {$i < $WAY} {incr i} {
    for {set j 0} {$j < $NUM_SRAMS_PER_WAY} {incr j} {
        set sram_inst [dbGet top.insts.name *i_icache/sram_block[$i].tag*/macro_mem[$j]*]
        puts $sram_inst

        set row_idx [expr $i]
        set col_idx [expr $NUM_SRAMS_PER_WAY*$i + $j]
        set x [expr $begin_llx - ($col_idx > 0)*$sram_size_x]
        set y [expr $begin_lly]

        if {$col_idx % 2 == 0} {
            placeInstance $sram_inst $x $y R0
        } else {
            # Add additional spacing
            set x [expr $x - 4*$halo_size_x]

            # Mirror the pin side
            placeInstance $sram_inst $x $y MY
        }

        set begin_llx $x
    }
}




#-------------------------------------------------------------------------------
# i_icache/data
#    I'll place the first two ways on the top of the tag arrays.
#    The other two ways below the tag arrays.
#-------------------------------------------------------------------------------

## First half

set ref_tag_sram i_cache_subsystem/i_icache/sram_block[0].tag_sram/macro_mem[0].i_ram
set begin_llx [dbGet [dbGet top.insts.name $ref_tag_sram -p].pt_x]
set begin_lly [dbGet [dbGet top.insts.name $ref_tag_sram -p].pt_y]

# Add additional spacing
set begin_lly [expr $begin_lly + 2*$sram_size_y + 4*$halo_size_y]

set WAY 2
set NUM_SRAMS_PER_WAY 8
for {set i 0} {$i < $WAY} {incr i} {
    for {set j 0} {$j < $NUM_SRAMS_PER_WAY} {incr j} {
        set sram_inst [dbGet top.insts.name *i_icache/sram_block[$i].data*/macro_mem[$j]*]
        puts $sram_inst

        set row_idx [expr $i]
        set col_idx [expr $j]
        set x [expr $begin_llx - ($col_idx > 0)*$sram_size_x]
        set y [expr $begin_lly - $row_idx*$sram_size_y]

        if {$col_idx % 2 == 0} {
            placeInstance $sram_inst $x $y R0
        } else {
            # Add additional spacing
            set x [expr $x - 4*$halo_size_x]

            if {$col_idx == $NUM_SRAMS_PER_WAY - 1} {
                # Don't mirror the last column.
                placeInstance $sram_inst $x $y R0
            } else {
                # Mirror the pin side
                placeInstance $sram_inst $x $y MY
            }
        }

        set begin_llx $x
    }
    set begin_llx [dbGet [dbGet top.insts.name $ref_tag_sram -p].pt_x]
}


## Second half

set ref_tag_sram i_cache_subsystem/i_icache/sram_block[0].tag_sram/macro_mem[0].i_ram
set begin_llx [dbGet [dbGet top.insts.name $ref_tag_sram -p].pt_x]
set begin_lly [dbGet [dbGet top.insts.name $ref_tag_sram -p].pt_y]

# Add additional spacing
set begin_lly [expr $begin_lly - $sram_size_y - 4*$halo_size_y]

set WAY 4
set NUM_SRAMS_PER_WAY 8
for {set i 2} {$i < $WAY} {incr i} {
    for {set j 0} {$j < $NUM_SRAMS_PER_WAY} {incr j} {
        set sram_inst [dbGet top.insts.name *i_icache/sram_block[$i].data*/macro_mem[$j]*]
        puts $sram_inst

        set row_idx [expr $i - 2]
        set col_idx [expr $j]
        set x [expr $begin_llx - ($col_idx > 0)*$sram_size_x]
        set y [expr $begin_lly - $row_idx*$sram_size_y]

        if {$col_idx % 2 == 0} {
            placeInstance $sram_inst $x $y R0
        } else {
            # Add additional spacing
            set x [expr $x - 4*$halo_size_x]

            if {$col_idx == $NUM_SRAMS_PER_WAY - 1} {
                # Don't mirror the last column.
                placeInstance $sram_inst $x $y R0
            } else {
                # Mirror the pin side
                placeInstance $sram_inst $x $y MY
            }
        }

        set begin_llx $x
    }
    set begin_llx [dbGet [dbGet top.insts.name $ref_tag_sram -p].pt_x]
}




#-------------------------------------------------------------------------------
# i_nbdcache/tag: First 4 ways near the top-left corner of the core area.
#-------------------------------------------------------------------------------

set begin_llx [expr $fp_llx]
set begin_lly [expr $fp_ury - $sram_size_y]

set num_ways 8
set num_srams_per_way 3

for {set i 0} {$i < $num_ways/2} {incr i} {
    for {set j 0} {$j < $num_srams_per_way} {incr j} {
        set sram_inst [dbGet top.insts.name *i_nbdcache/sram_block[$i].tag*/macro_mem[$j]*]
        puts $sram_inst

        set row_idx [expr $i]
        set col_idx [expr $j]
        set x [expr $begin_llx + ($col_idx > 0)*$sram_size_x]
        set y [expr $begin_lly - $row_idx*$sram_size_y]

        if {$col_idx % 2 == 0} {
            placeInstance $sram_inst $x $y MY
        } else {
            # Add additional spacing
            set x [expr $x + 4*$halo_size_x]

            # Mirror 
            placeInstance $sram_inst $x $y R0
        }

        set begin_llx $x
    }

    set begin_llx [expr $fp_llx]
}




#-------------------------------------------------------------------------------
# i_nbdcache/tag: Second 4 ways near the top-left corner of the core area.
#-------------------------------------------------------------------------------

set begin_llx [expr $fp_llx]
set begin_lly [expr $fp_lly]

set num_ways 8
set num_srams_per_way 3

for {set i 4} {$i < $num_ways} {incr i} {
    puts "HEY"
    for {set j 0} {$j < $num_srams_per_way} {incr j} {
        set sram_inst [dbGet top.insts.name *i_nbdcache/sram_block[$i].tag*/macro_mem[$j]*]
        puts $sram_inst

        set row_idx [expr $i - $num_ways/2]
        set col_idx [expr $j]
        set x [expr $begin_llx + ($col_idx > 0)*$sram_size_x]
        set y [expr $begin_lly + $row_idx*$sram_size_y]

        if {$col_idx % 2 == 0} {
            placeInstance $sram_inst $x $y MY
        } else {
            # Add additional spacing
            set x [expr $x + 4*$halo_size_x]

            # Mirror 
            placeInstance $sram_inst $x $y R0
        }

        set begin_llx $x
    }

    set begin_llx [expr $fp_llx]
}




#-------------------------------------------------------------------------------
# i_nbdcache/data: first 4 ways near the top edge of the core area.
#-------------------------------------------------------------------------------

set begin_llx [expr $fp_urx - $fp_spacing_urx - $sram_size_x]
set begin_lly [expr $fp_ury - $sram_size_y]

set num_ways 8
set num_srams_per_way 8

for {set i 0} {$i < $num_ways/2} {incr i} {
    for {set j 0} {$j < $num_srams_per_way} {incr j} {
        set sram_inst [dbGet top.insts.name *i_nbdcache/sram_block[$i].data*/macro_mem[$j]*]
        puts $sram_inst

        set row_idx [expr int(floor($i/2))]
        set col_idx [expr $j + ($i%2) * $num_srams_per_way]
        set x [expr $begin_llx - ($col_idx > 0)*$sram_size_x]
        set y [expr $begin_lly - $row_idx*$sram_size_y]

        if {$col_idx % 2 == 0} {
            placeInstance $sram_inst $x $y R0
        } else {
            # Add additional spacing
            set x [expr $x - 4*$halo_size_x]

            # Mirror the pin side
            placeInstance $sram_inst $x $y MY
        }

        set begin_llx $x
    }

    if {$i == 1} {
        set begin_llx [expr $fp_urx - $fp_spacing_urx - $sram_size_x]
    }
}


#-------------------------------------------------------------------------------
# i_nbdcache/data: second 4 ways near the bottom edge of the core area.
#-------------------------------------------------------------------------------

set begin_llx [expr $fp_urx - $fp_spacing_urx - $sram_size_x]
set begin_lly [expr $fp_lly]

set num_ways 8
set num_srams_per_way 8

for {set i 4} {$i < $num_ways} {incr i} {
    for {set j 0} {$j < $num_srams_per_way} {incr j} {
        set sram_inst [dbGet top.insts.name *i_nbdcache/sram_block[$i].data*/macro_mem[$j]*]
        puts $sram_inst

        set row_idx [expr int(floor(($i - 4)/2))]
        set col_idx [expr $j + ($i%2) * $num_srams_per_way]
        set x [expr $begin_llx - ($col_idx > 0)*$sram_size_x]
        set y [expr $begin_lly + $row_idx*$sram_size_y]

        if {$col_idx % 2 == 0} {
            placeInstance $sram_inst $x $y R0
        } else {
            # Add additional spacing
            set x [expr $x - 4*$halo_size_x]

            # Mirror the pin side
            placeInstance $sram_inst $x $y MY
        }

        set begin_llx $x
    }

    if {$i == 5} {
        set begin_llx [expr $fp_urx - $fp_spacing_urx - $sram_size_x]
    }
}




##-------------------------------------------------------------------------------
## Manual refinement
##-------------------------------------------------------------------------------
placeInstance i_cache_subsystem/i_icache/sram_block[3].tag_sram/macro_mem[2].i_ram  704.7 895.42 R0
placeInstance i_cache_subsystem/i_icache/sram_block[3].tag_sram/macro_mem[1].i_ram  704.7 762.42 R0
placeInstance i_cache_subsystem/i_icache/sram_block[2].tag_sram/macro_mem[2].i_ram  704.7 456.42 R0
placeInstance i_cache_subsystem/i_icache/sram_block[3].tag_sram/macro_mem[0].i_ram  704.7 323.42 R0
placeInstance i_cache_subsystem/i_nbdcache/valid_dirty_sram/macro_mem[0].i_ram      704.7 609.42 R0

placeInstance i_cache_subsystem/i_icache/sram_block[0].data_sram/macro_mem[7].i_ram 762.27 895.42 MY
placeInstance i_cache_subsystem/i_icache/sram_block[1].data_sram/macro_mem[7].i_ram 762.27 762.42 MY
placeInstance i_cache_subsystem/i_icache/sram_block[2].data_sram/macro_mem[7].i_ram 762.27 456.42 MY
placeInstance i_cache_subsystem/i_icache/sram_block[3].data_sram/macro_mem[7].i_ram 762.27 323.42 MY

verify_drc -limit -1
