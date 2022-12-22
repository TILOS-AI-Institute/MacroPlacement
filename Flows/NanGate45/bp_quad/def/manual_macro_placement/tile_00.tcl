#############################################################################
# This script was written and developed by Dr. Jinwook Jung of IBM Research.
# However, the underlying commands and reports are copyrighted by Cadence. 
# We thank Cadence for granting permission to share our research to help 
# promote and foster the next generation of innovators.
#############################################################################
#-------------------------------------------------------------------------------
# Tile 00
#-------------------------------------------------------------------------------
set TILE y_0__x_0
set tile_orig_x [expr $fp_lly + $fp_x_offset]
set tile_orig_y [expr $fp_ury - $fp_y_offset]


#---------------------------------------
# L2 cache data
#---------------------------------------
#     00  01-10  11-20  21
#     30  31-40  41-50  51
#     60  61-70  71

set size_x [dbGet [dbGet head.libCells.name fakeram45_512x64 -p].size_x]
set size_y [dbGet [dbGet head.libCells.name fakeram45_512x64 -p].size_y]

set orig_x [expr $tile_orig_x]
set orig_y [expr $tile_orig_y - $size_y]

for {set i 0} {$i < 8} {incr i} {
    for {set j 0} {$j < 2} {incr j} {
        set row_idx [expr floor($i/3)]
        set col_idx [expr 2*($i%3) + $j]

        set name "*${TILE}*/l2s/cache/data_mem/macro_bmem/dbn_wb_${i}__db_${j}__bank/macro_mem"
        set x [expr $orig_x + $size_x*$col_idx + $spacing_x*floor(($col_idx+1)/2)]
        set y [expr $orig_y - $size_y*$row_idx - $spacing_y*floor($row_idx/2)]

        if {$j % 2 == 0} {
            placeInstance $name $x $y MY
        } else {
            placeInstance $name $x $y R0
        }
    }
}

set l2_data_lly $y


#---------------------------------------
# L2 cache tag
#---------------------------------------
set tag_size_x [dbGet [dbGet head.libCells.name fakeram45_128x116 -p].size_x]
set tag_size_y [dbGet [dbGet head.libCells.name fakeram45_128x116 -p].size_y]

set tag_x [expr $x + $size_x + $spacing_x]
set tag_y [expr $y + $size_y - $tag_size_y]


set name bp_processor/cc/${TILE}__tile_node/tile/l2s/cache/tag_mem/macro_bmem/db1_wb_0__bank/macro_mem
placeInstance $name $tag_x $tag_y R0
set name bp_processor/cc/${TILE}__tile_node/tile/l2s/cache/tag_mem/macro_bmem/db1_wb_1__bank/macro_mem
placeInstance $name $tag_x [expr $tag_y - $tag_size_y] R0



#---------------------------------------
# CCE Directory
#---------------------------------------
#  0  1-2  3
#  4  5-6  7

set size_x [dbGet [dbGet head.libCells.name fakeram45_64x62 -p].size_x]
set size_y [dbGet [dbGet head.libCells.name fakeram45_64x62 -p].size_y]

set orig_x [expr $tile_orig_x]
set orig_y [expr $l2_data_lly - $size_y - 2*$spacing_y]

for {set i 0} {$i < 8} {incr i} {
    set name "bp_processor/cc/${TILE}__tile_node/tile/cce/directory/directory/macro_bmem/db1_wb_${i}__bank/macro_mem"

    set row_idx [expr floor($i / 4)]
    set col_idx [expr $i % 4]

    set x [expr $orig_x + $size_x*$col_idx + $spacing_x*floor(($col_idx + 1)/2)]
    set y [expr $orig_y - $size_y*$row_idx - $spacing_y*floor($row_idx/2)]

    if {$col_idx == 3} {
        placeInstance $name $x $y MY
    } elseif {$col_idx % 2 == 0} {
        placeInstance $name $x $y MY
    } else {
        placeInstance $name $x $y R0
    }
}

set directory_urx [expr $x + $size_x]
set directory_ury [expr $y + 2*$size_y]


#---------------------------------------
# cce_inst_ram
#---------------------------------------
set ref_ram_name bp_processor/cc/${TILE}__tile_node/tile/cce/directory/directory/macro_bmem/db1_wb_3__bank/macro_mem
set ref_ram [dbGet top.insts.name $ref_ram_name -p]
set ref_ram_llx [dbGet ${ref_ram}.box_llx]
set ref_ram_lly [dbGet ${ref_ram}.box_lly]
set ref_ram_urx [dbGet ${ref_ram}.box_urx]
set ref_ram_ury [dbGet ${ref_ram}.box_ury]

set size_x [dbGet [dbGet head.libCells.name fakeram45_256x48 -p].size_x]
set size_y [dbGet [dbGet head.libCells.name fakeram45_256x48 -p].size_y]

set x [expr $ref_ram_urx + $spacing_x]
set y [expr $ref_ram_ury - $size_y]
set name bp_processor/cc/${TILE}__tile_node/tile/cce/inst_ram/cce_inst_ram/macro_mem
placeInstance $name $x $y MY


set cce_inst_ram_lly $y




#---------------------------------------
# DCache data
#---------------------------------------
#    0  1-2
#    3  4-5
#    6  7
set size_x [dbGet [dbGet head.libCells.name fakeram45_512x64 -p].size_x]
set size_y [dbGet [dbGet head.libCells.name fakeram45_512x64 -p].size_y]

set orig_x [expr $tile_orig_x]
set orig_y [expr $cce_inst_ram_lly - $size_y - 4*$spacing_y]

for {set i 0} {$i < 8} {incr i} {
    set name "*${TILE}*/core/be/be_mem/dcache/data_mem_${i}__data_mem*/macro_mem"

    set row_idx [expr floor($i / 3)]
    set col_idx [expr $i % 3]

    set x [expr $orig_x + $size_x*$col_idx + $spacing_x*floor(($col_idx + 1)/2)]
    set y [expr $orig_y - $size_y*$row_idx - $spacing_y*floor($row_idx/2)]

    if {$i == 7} {
        placeInstance $name $x $y MY
    } elseif {$col_idx % 2 == 0} {
        placeInstance $name $x $y MY
    } else {
        placeInstance $name $x $y R0
    }
}

set l1_dcache_data_llx $x
set l1_dcache_data_lly $y
set l1_dcache_data_urx [expr $x + 2*$size_x]


# Tags
set tag_size_x [dbGet [dbGet head.libCells.name fakeram45_64x124 -p].size_x]
set tag_size_y [dbGet [dbGet head.libCells.name fakeram45_64x124 -p].size_y]

set tag_x [expr $x + 2*$size_x - $tag_size_x]
set tag_y [expr $y + $size_y - $tag_size_y]

set name bp_processor/cc/${TILE}__tile_node/tile/core/be/be_mem/dcache/tag_mem/macro_bmem/db1_wb_0__bank/macro_mem
placeInstance $name $tag_x $tag_y MY
set name bp_processor/cc/${TILE}__tile_node/tile/core/be/be_mem/dcache/tag_mem/macro_bmem/db1_wb_1__bank/macro_mem
placeInstance $name $tag_x [expr $tag_y - $tag_size_y] MY


#---------------------------------------
# ICache
#---------------------------------------
#    6  7
#    3  4-5
#    0  1-2
set size_x [dbGet [dbGet head.libCells.name fakeram45_512x64 -p].size_x]
set size_y [dbGet [dbGet head.libCells.name fakeram45_512x64 -p].size_y]

set orig_x [expr $tile_orig_x]
set orig_y [expr $l1_dcache_data_lly - 3*$size_y - 6*$spacing_y]

for {set i 0} {$i < 8} {incr i} {
    set name "*${TILE}*/core/fe/mem/icache/data_mems_${i}__data_mem*/macro_mem"

    set row_idx [expr floor($i / 3)]
    set col_idx [expr $i % 3]

#    # FIXME
#    if {$i > 5} {
#        set col_idx [expr $col_idx + 1]
#    }


    set x [expr $orig_x + $size_x*$col_idx + $spacing_x*floor(($col_idx+1) / 2)]
    set y [expr $orig_y + $size_y*$row_idx + $spacing_y*floor($row_idx / 2)]

    if {$i == 7} {
        placeInstance $name $x $y MY
    } elseif {$col_idx % 2 == 0} {
        placeInstance $name $x $y MY
    } else {
        placeInstance $name $x $y R0
    }
}


set l1_icache_data_lly $orig_y

# Tags
set tag_size_x [dbGet [dbGet head.libCells.name fakeram45_64x124 -p].size_x]
set tag_size_y [dbGet [dbGet head.libCells.name fakeram45_64x124 -p].size_y]

set tag_x [expr $x + 2*$size_x - $tag_size_x]
set tag_y [expr $y]

set name bp_processor/cc/${TILE}__tile_node/tile/core/fe/mem/icache/tag_mem/macro_bmem/db1_wb_0__bank/macro_mem
placeInstance $name $tag_x $tag_y MY
set name bp_processor/cc/${TILE}__tile_node/tile/core/fe/mem/icache/tag_mem/macro_bmem/db1_wb_1__bank/macro_mem
placeInstance $name $tag_x [expr $tag_y + $tag_size_y] MY




#---------------------------------------
# int_regfile
#---------------------------------------
set size_x [dbGet [dbGet head.libCells.name fakeram45_32x32 -p].size_x]
set size_y [dbGet [dbGet head.libCells.name fakeram45_32x32 -p].size_y]

set rmod "a b"
for {set i 0} {$i < 2} {incr i} {
    if {$i == 1} {
        set ref_ram_name bp_processor/cc/${TILE}__tile_node/tile/core/fe/mem/icache/tag_mem/macro_bmem/db1_wb_1__bank/macro_mem
        set ref_ram [dbGet top.insts.name $ref_ram_name -p]
        set ref_ram_llx [dbGet ${ref_ram}.box_llx]
        set ref_ram_lly [dbGet ${ref_ram}.box_lly]
        set ref_ram_urx [dbGet ${ref_ram}.box_urx]
        set ref_ram_ury [dbGet ${ref_ram}.box_ury]

        set orig_x [expr $ref_ram_urx + $spacing_x]
        set orig_y [expr $ref_ram_ury - $size_y]
    } else {
        set ref_ram_name bp_processor/cc/${TILE}__tile_node/tile/core/be/be_mem/dcache/tag_mem/macro_bmem/db1_wb_1__bank/macro_mem
        set ref_ram [dbGet top.insts.name $ref_ram_name -p]
        set ref_ram_llx [dbGet ${ref_ram}.box_llx]
        set ref_ram_lly [dbGet ${ref_ram}.box_lly]
        set ref_ram_urx [dbGet ${ref_ram}.box_urx]
        set ref_ram_ury [dbGet ${ref_ram}.box_ury]

        set orig_x [expr $ref_ram_urx + $spacing_x]
        set orig_y [expr $ref_ram_lly + 3*($size_y + $spacing_y)]
    }

    for {set j 0} {$j < 2} {incr j} {
        for {set k 0} {$k < 2} {incr k} {
            set x [expr $orig_x]
            set y [expr $orig_y - ($size_y + $spacing_y)*(2*$j + $k)]

            set name "bp_processor/cc/${TILE}__tile_node/tile/core/be/be_checker/scheduler/int_regfile/rf/macro_mem${i}${j}/rmod_[lindex $rmod $k]"
            placeInstance $name $x $y MY
        }
    }
}


