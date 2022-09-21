# ===================================================================
# File: syn/cons/NV_NVDLA_partition_c.sdc
# NVDLA Open Source Project
#
# Copyright (c) 2016 – 2017 NVIDIA Corporation. Licensed under the
# NVDLA Open Hardware License; see the "LICENSE.txt" file that came
# with this distribution for more information.
# ===================================================================

set clk_period 900
if { [info exists ::env(CLK_PERIOD)] } {
  set clk_period   $::env(CLK_PERIOD)
}

#set_max_area 0
set_ideal_network [get_ports direct_reset_]
set_ideal_network [get_ports dla_reset_rstn]
set_ideal_network -no_propagate [get_nets nvdla_core_rstn]
set_ideal_network [get_ports test_mode]
create_clock [get_ports nvdla_core_clk]  -period $clk_period  -waveform {0 [expr $clk_period / 2.0]}
set_clock_transition -max -rise 50 [get_clocks nvdla_core_clk]
set_clock_transition -max -fall 50 [get_clocks nvdla_core_clk]
set_clock_transition -min -rise 50 [get_clocks nvdla_core_clk]
set_clock_transition -min -fall 50 [get_clocks nvdla_core_clk]
set_false_path   -from [get_ports direct_reset_]
set_false_path   -from [get_ports dla_reset_rstn]
set_false_path   -from [get_ports test_mode]
set_false_path   -from [get_ports pwrbus_ram_pd*]
set_false_path   -from [get_ports tmc2slcg_disable_clock_gating]
set_false_path   -from [get_ports global_clk_ovr_on]
set_false_path   -from [get_ports nvdla_clk_ovr_on]
