# This script was written and developed by ABKGroup students at UCSD. However, the underlying commands and reports are copyrighted by Cadence. 
# We thank Cadence for granting permission to share our research to help promote and foster the next generation of innovators.
set DESIGN mempool_group
set rtl_dir "../../../../../Testcases/mempool/hardware"
set sdc  "../../constraints/${DESIGN}.sdc"
set rtldir ". ${rtl_dir} \
           ${rtl_dir}/deps/axi \
           ${rtl_dir}/deps/snitch \ 
           ${rtl_dir}/deps/axi/include \
           ${rtl_dir}/deps/common_cells \
           ${rtl_dir}/include \
           ${rtl_dir}/deps/register_interface/include \
           ${rtl_dir}/deps/common_cells/include \
           ${rtl_dir}/deps/reqrsp_interface/include"

# def file with die size and placed IO pins
if {[info exist ::env(PHY_SYNTH)] && $::env(PHY_SYNTH) == 1} {
    set floorplan_def "../../def/mempool_group_fp_placed_macros.def"
} else {
    set floorplan_def "../../def/mempool_group_fp.def"
}
#
# Effort level during optimization in syn_generic -physical (or called generic) stage
# possible values are : high, medium or low
set GEN_EFF medium

# Effort level during optimization in syn_map -physical (or called mapping) stage
# possible values are : high, medium or low
set MAP_EFF high
#
set SITE "asap7sc7p5t"
set HALO_WIDTH 1 
set TOP_ROUTING_LAYER 9
