#############################################################################
# This script was written and developed by Dr. Jinwook Jung of IBM Research.
# However, the underlying commands and reports are copyrighted by Cadence. 
# We thank Cadence for granting permission to share our research to help 
# promote and foster the next generation of innovators.
#############################################################################
unplaceAllBlocks

set script_dir [file dirname [file normalize [info script]]]

source $script_dir/globals.tcl

puts "Tile 00"
source $script_dir/tile_00.tcl

puts "Tile 01"
source $script_dir/tile_01.tcl

puts "Tile 10"
source $script_dir/tile_10.tcl

puts "Tile 11"
source $script_dir/tile_11.tcl

verify_drc -limit -1
