# Copyright 2021 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Create an nWave window
wvCreateWindow

# Add a vector of the core's wfi signal to quickly see which cores are active
wvAddGroup wfi
wvAddSignal -group {wfi {mempool_tb/wfi}}

# Add min function (DVE does not support TCL8.5)
proc min args {
    set minval [lindex args 0]
    foreach arg $args {
        if { $arg < $minval } {
            set minval $arg
        }
    }
    return $minval
}

# Add all cores from group 0 tile 0
set group 0
set tile 0
for {set core 0}  {$core < [min 4 [get -radix dec mempool_pkg::NumCoresPerTile]]} {incr core} {
    source ../scripts/vcs/wave_core.tcl
}

# Add specific cores from different tiles
set group 1
set tile 0
set core 0
source ../scripts/vcs/wave_core.tcl

# Add groups
for {set group 0} {$group < [get -radix dec mempool_pkg::NumGroups]} {incr group} {
    # Create the group
    wvAddGroup group\[$group\]

    # Add tiles
    for {set tile 0} {$tile < [min 2 [get -radix dec mempool_pkg::NumTilesPerGroup]]} {incr tile} {
        source ../scripts/vcs/wave_tile.tcl
    }

    # Interconnects
    for {set tgtgroup 0} {$tgtgroup < [get -radix dec mempool_pkg::NumGroups]} {incr tgtgroup} {
        if {$tgtgroup != $group} {
            set interco_idx [expr $group ^ $tgtgroup]
            wvSelectGroup group\[$group\]
            wvAddSubGroup interconnect_to_group\[$tgtgroup\]
            wvSetPosition [subst {(group\[$group\]/interconnect_to_group\[$tgtgroup\] last)}]

            wvAddSignal mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/clk_i \
                        mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/rst_ni \
                        mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/req_valid_i \
                        mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/req_ready_o \
                        mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/req_tgt_addr_i \
                        mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/req_wen_i \
                        mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/req_wdata_i \
                        mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/req_be_i \
                        mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/resp_valid_o \
                        mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/resp_ready_i \
                        mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/resp_rdata_o \
                        mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/req_valid_o \
                        mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/req_ready_i \
                        mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/req_ini_addr_o \
                        mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/req_tgt_addr_o \
                        mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/req_wen_o \
                        mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/req_wdata_o \
                        mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/req_be_o \
                        mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/resp_valid_i \
                        mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/resp_ready_o \
                        mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/resp_ini_addr_i \
                        mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_remote_interco\[$interco_idx\]/i_remote_interco/resp_rdata_i
        }
    }

    wvSelectGroup group\[$group\]
    wvAddSubGroup local_interconnect
    wvSetPosition [subst {(group\[$group\]/local_interconnect last)}]

    wvAddSignal mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/clk_i \
                mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/rst_ni \
                mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/req_valid_i \
                mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/req_ready_o \
                mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/req_tgt_addr_i \
                mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/req_wen_i \
                mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/req_wdata_i \
                mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/req_be_i \
                mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/resp_valid_o \
                mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/resp_ready_i \
                mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/resp_rdata_o \
                mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/req_valid_o \
                mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/req_ready_i \
                mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/req_ini_addr_o \
                mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/req_tgt_addr_o \
                mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/req_wen_o \
                mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/req_wdata_o \
                mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/req_be_o \
                mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/resp_valid_i \
                mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/resp_ready_o \
                mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/resp_ini_addr_i \
                mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/i_local_interco/resp_rdata_i
}

wvAddGroup Control_Registers
wvSetPosition {(Control_Registers last)}
wvAddSignal mempool_tb/dut/i_ctrl_registers/clk_i \
            mempool_tb/dut/i_ctrl_registers/rst_ni \
            mempool_tb/dut/i_ctrl_registers/axi_lite_slave_req_i \
            mempool_tb/dut/i_ctrl_registers/axi_lite_slave_resp_o \
            mempool_tb/dut/i_ctrl_registers/eoc_o \
            mempool_tb/dut/i_ctrl_registers/eoc_valid_o \
            mempool_tb/dut/i_ctrl_registers/wake_up_o \
            mempool_tb/dut/i_ctrl_registers/tcdm_start_address_o \
            mempool_tb/dut/i_ctrl_registers/tcdm_end_address_o \
            mempool_tb/dut/i_ctrl_registers/num_cores_o
