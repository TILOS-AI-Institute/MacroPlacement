#############################################################################
# This script was written and developed by ABKGroup students at UCSD.
# However, the underlying commands and reports are copyrighted by Cadence. 
# We thank Cadence for granting permission to share our research to help 
# promote and foster the next generation of innovators.
# Author: Sayak Kundu (sakundu@ucsd.edu), ABKGroup, UCSD. 
# Thanks to Matheus Cavalcante, ETH Zürich and Jiantao Liu (jil313@ucsd.edu) 
# for providing the pin configuration.
#
# Usage: First source the script in Innovus shell. then use gen_pb_netlist
# command to write out the netlist. The protobuf netlist will be available
# as <design name>.pb.txt.
#############################################################################

setPinAssignMode -pinEditInBatch true
set group_width [dbget top.fplan.box_sizex]
set group_height [dbget top.fplan.box_sizey]
set NUM_GROUPS 4
set NUM_TILES 16

proc place_tcdm_top_bus {bus direction index width start end layers} {
    global NUM_TILES
    global group_height

    # Number of ports per tile
    set ports_per_tile [expr $width / $NUM_TILES]

    # Which ports are we placing?
    set ports []

    # Shuffle the tiles to have the ports organized from left to right
    set tile_shuffle [list 0 1 8 9 2 3 10 11 4 5 12 13 6 7 14 15]

    if {$direction == "in"} {
        for {set tile 0} {$tile < $NUM_TILES} {incr tile} {
            set tile_sh [lindex $tile_shuffle $tile]

            for {set idx 0} {$idx < $ports_per_tile} {incr idx} {
				set act_idx [expr $index*$width + $ports_per_tile*$tile_sh + $ports_per_tile - 1 - $idx]
				set port_name [lindex [dbget top.terms.name ${bus}_i[$act_idx] -e] 0]
				if { $port_name != "" } {
					lappend ports $port_name
				}
			}
			
            foreach_in_collection port [get_ports ${bus}_valid_i[[expr $tile_sh + $index*$NUM_TILES]]] {
                lappend ports [get_object_name $port]
            }
            foreach_in_collection port [get_ports ${bus}_ready_o[[expr $tile_sh + $index*$NUM_TILES]]] {
                lappend ports [get_object_name $port]
            }
        }
    } else {
        for {set tile 0} {$tile < $NUM_TILES} {incr tile} {
            set tile_sh [lindex $tile_shuffle $tile]

            for {set idx 0} {$idx < $ports_per_tile} {incr idx} {
				set act_idx [expr $index*$width + $ports_per_tile*$tile_sh + $ports_per_tile - 1 - $idx]
				set port_name [lindex [dbget top.terms.name ${bus}_o[$act_idx] -e] 0]
				if { $port_name != "" } {
					lappend ports $port_name
				}
			}
			
            foreach_in_collection port [get_ports ${bus}_valid_o[[expr $tile_sh + $index*$NUM_TILES]]] {
                lappend ports [get_object_name $port]
            }
            foreach_in_collection port [get_ports ${bus}_ready_i[[expr $tile_sh + $index*$NUM_TILES]]] {
                lappend ports [get_object_name $port]
            }
        }
    }

    set num_ports [llength $ports]
    set offset    [expr ($end - $start)/$num_ports]
	
	set y [dbget top.fplan.box_ury]
	set pt1 [list $start $y]
	set pt2 [list $end $y]
	
	editPin -pin $ports -edge 1 -start $pt1 -end $pt2 -fixedPin -layer $layers -spreadDirection clockwise -pattern fill_optimised
    
}

proc place_tcdm_left_bus {bus direction index width start end layers} {
    global NUM_TILES
    global group_height

    # Number of ports per tile
    set ports_per_tile [expr $width / $NUM_TILES]

    # Shuffle the tiles to have the ports organized from top to bottom
    set tile_shuffle [list 8 9 12 13 10 11 14 15 2 3 6 7 0 1 4 5]

    # Which ports are we placing?
    set ports []
    if {$direction == "in"} {
        for {set tile 0} {$tile < $NUM_TILES} {incr tile} {
            set tile_sh [lindex $tile_shuffle $tile]

            for {set idx 0} {$idx < $ports_per_tile} {incr idx} {
				set act_idx [expr $index*$width + $ports_per_tile*$tile_sh + $ports_per_tile - 1 - $idx]
				set port_name [lindex [dbget top.terms.name ${bus}_i[$act_idx] -e] 0]
				if { $port_name != "" } {
					lappend ports $port_name
				}
			}
			
            foreach_in_collection port [get_ports ${bus}_valid_i[[expr $tile_sh + $index*$NUM_TILES]]] {
                lappend ports [get_object_name $port]
            }
            foreach_in_collection port [get_ports ${bus}_ready_o[[expr $tile_sh + $index*$NUM_TILES]]] {
                lappend ports [get_object_name $port]
            }
        }
    } else {
        for {set tile 0} {$tile < $NUM_TILES} {incr tile} {
            set tile_sh [lindex $tile_shuffle $tile]

            for {set idx 0} {$idx < $ports_per_tile} {incr idx} {
				set act_idx [expr $index*$width + $ports_per_tile*$tile_sh + $ports_per_tile - 1 - $idx]
				set port_name [lindex [dbget top.terms.name ${bus}_o[$act_idx] -e] 0]
				if { $port_name != "" } {
					lappend ports $port_name
				}
			}
			
            foreach_in_collection port [get_ports ${bus}_valid_o[[expr $tile_sh + $index*$NUM_TILES]]] {
                lappend ports [get_object_name $port]
            }
            foreach_in_collection port [get_ports ${bus}_ready_i[[expr $tile_sh + $index*$NUM_TILES]]] {
                lappend ports [get_object_name $port]
            }
        }
    }

    set num_ports [llength $ports]
    set offset    [expr ($end - $start)/$num_ports]
    
	set x [dbget top.fplan.box_urx]
	set pt1 [list $x $start]
	set pt2 [list $x $end]
	
	editPin -pin $ports -edge 2 -start $pt1 -end $pt2 -fixedPin -layer $layers -spreadDirection counterclockwise -pattern fill_optimised
}



set master_req_bus_length  [expr [llength [get_object_name [get_ports tcdm_master_req_o*]]] / ($NUM_GROUPS - 1)]
set master_resp_bus_length [expr [llength [get_object_name [get_ports tcdm_master_resp_i*]]] / ($NUM_GROUPS - 1)]
set slave_req_bus_length   [expr [llength [get_object_name [get_ports tcdm_slave_req_i*]]] / ($NUM_GROUPS - 1)]
set slave_resp_bus_length  [expr [llength [get_object_name [get_ports tcdm_slave_resp_o*]]] / ($NUM_GROUPS - 1)]

# North
place_tcdm_top_bus tcdm_master_req            out 1 $master_req_bus_length  [expr 0.35*$group_width] [expr 0.51*$group_width] [list metal4 metal6]
place_tcdm_top_bus tcdm_slave_req             in  1 $slave_req_bus_length   [expr 0.35*$group_width] [expr 0.51*$group_width] [list metal6 metal8]
place_tcdm_top_bus tcdm_slave_resp            out 1 $slave_resp_bus_length  [expr 0.51*$group_width] [expr 0.67*$group_width] [list metal6 metal8]
place_tcdm_top_bus tcdm_master_resp           in  1 $master_resp_bus_length [expr 0.51*$group_width] [expr 0.67*$group_width] [list metal4 metal6]

# Northeast
place_tcdm_top_bus tcdm_slave_req             in  2 $slave_req_bus_length   [expr 0.67*$group_width] [expr 0.83*$group_width] [list metal4 metal6]
place_tcdm_top_bus tcdm_master_resp           in  2 $master_resp_bus_length [expr 0.67*$group_width] [expr 0.83*$group_width] [list metal6 metal8]

# set ports []
# lappend ports [get_object_name [get_ports clk_i* ]]
# lappend ports [get_object_name [get_ports rst_ni*]]
# set ports [list $ports [get_object_name [get_ports scan*]]]
# lappend ports [get_object_name [get_ports testmode*]]
# puts "Ports are $ports"

set ports {clk_i rst_ni scan_enable_i scan_data_i scan_data_o testmode_i dma_meta_o[0] dma_meta_o[1] group_id_i[0] group_id_i[1]}
set y [dbget top.fplan.box_ury]
set x1 [expr 0.45*$group_width]
set x2 [expr 0.55*$group_width]
set pt1 [list $x1 $y]
set pt2 [list $x2 $y]

editPin -pin $ports -edge 1 -start $pt1 -end $pt2 -fixedPin -layer [list metal4 metal6] -spreadDirection clockwise -pattern fill_optimised

# Northeast
place_tcdm_left_bus tcdm_master_req           out 2 $master_req_bus_length [expr 0.17*$group_height] [expr 0.33*$group_height] [list metal3 metal5]
place_tcdm_left_bus tcdm_slave_resp           out 2 $slave_resp_bus_length [expr 0.17*$group_height] [expr 0.33*$group_height] [list metal5 metal7]
# East
place_tcdm_left_bus tcdm_master_req           out 0 $master_req_bus_length  [expr 0.33*$group_height] [expr 0.49*$group_height] [list metal3 metal5]
place_tcdm_left_bus tcdm_slave_req            in  0 $slave_req_bus_length   [expr 0.33*$group_height] [expr 0.49*$group_height] [list metal5 metal7]
place_tcdm_left_bus tcdm_master_resp          in  0 $master_resp_bus_length [expr 0.49*$group_height] [expr 0.65*$group_height] [list metal3 metal5]
place_tcdm_left_bus tcdm_slave_resp           out 0 $slave_resp_bus_length  [expr 0.49*$group_height] [expr 0.65*$group_height] [list metal5 metal7]

set ports [dbget top.terms.name  *dma_req*]
set x [dbget top.fplan.box_urx]
set y1 [expr 0.66*$group_height]
set y2 [expr 0.80*$group_height]
set pt1 [list $x $y1]
set pt2 [list $x $y2]
editPin -pin $ports -edge 2 -start $pt1 -end $pt2 -fixedPin -layer [list metal3 metal5] -spreadDirection counterclockwise -pattern fill_optimised

set ports [dbget top.terms.name  *wake_up*]
set x [dbget top.fplan.box_llx]
set y1 [expr 0.17*$group_height]
set y2 [expr 0.32*$group_height]
set pt1 [list $x $y1]
set pt2 [list $x $y2]
editPin -pin $ports -edge 0 -start $pt1 -end $pt2 -fixedPin -layer [list metal3 metal5] -spreadDirection clockwise -pattern fill_optimised

set ports [dbget top.terms.name -regexp ".*axi.*|.*ro_cache.*"]
set x [dbget top.fplan.box_llx]
set y1 [expr 0.33*$group_height]
set y2 [expr 0.67*$group_height]
set pt1 [list $x $y1]
set pt2 [list $x $y2]
editPin -pin $ports -edge 0 -start $pt1 -end $pt2 -fixedPin -layer [list metal3 metal5] -spreadDirection clockwise -pattern fill_optimised

setPinAssignMode -pinEditInBatch false
