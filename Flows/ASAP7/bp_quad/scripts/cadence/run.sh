# This script was written and developed by ABKGroup students at UCSD. However, the underlying commands and reports are copyrighted by Cadence. 
# We thank Cadence for granting permission to share our research to help promote and foster the next generation of innovators.
#!/bin/tcsh
module unload genus
module load genus/21.1
module unload innovus
module load innovus/21.1

#
# To run the Physical Synthesis (iSpatial) flow - flow2
export PHY_SYNTH=0
export clk_period=850

mkdir log -p
genus -overwrite -log log/genus.log -no_gui -files run_genus_hybrid.tcl
innovus -64 -overwrite -log log/innovus.log -files run_invs.tcl
