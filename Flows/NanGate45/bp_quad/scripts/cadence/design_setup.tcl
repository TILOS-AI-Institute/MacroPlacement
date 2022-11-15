# This script was written and developed by ABKGroup students at UCSD. However, the underlying commands and reports are copyrighted by Cadence. 
# We thank Cadence for granting permission to share our research to help promote and foster the next generation of innovators.

set DESIGN bsg_chip
set sdc  ../../constraints/bsg_chip.sdc
set rtldir ./rtl

#
# DEF file for floorplan initialization
#
if {[info exist ::env(PHY_SYNTH)] && $::env(PHY_SYNTH) == 1} {
    set floorplan_def ../../def/bsg_chip_fp_placed_macros.def
} else {
    set floorplan_def ../../def/bsg_chip_fp.def
}
#
# Effort level during optimization in syn_generic -physical (or called generic) stage
# possible values are : high, medium or low
set GEN_EFF medium

# Effort level during optimization in syn_map -physical (or called mapping) stage
# possible values are : high, medium or low
set MAP_EFF high
#
set SITE "FreePDK45_38x28_10R_NP_162NW_34O"
set HALO_WIDTH 5
set TOP_ROUTING_LAYER 10
