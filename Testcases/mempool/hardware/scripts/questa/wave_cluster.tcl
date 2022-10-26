# Copyright 2021 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Create cache for core $3 from group $1 tile $2 (core_id=NUM_CORES_PER_group*$1+NUM_CORES_PER_TILE*$2+$3)

add wave -noupdate -group cluster -divider Parameters
add wave -noupdate -group cluster mempool_tb/dut/i_mempool_cluster/TCDMBaseAddr
add wave -noupdate -group cluster mempool_tb/dut/i_mempool_cluster/BootAddr
add wave -noupdate -group cluster mempool_tb/dut/i_mempool_cluster/NumDMAReq
add wave -noupdate -group cluster mempool_tb/dut/i_mempool_cluster/NumAXIMasters
add wave -noupdate -group cluster -divider Signals
add wave -noupdate -group cluster mempool_tb/dut/i_mempool_cluster/clk_i
add wave -noupdate -group cluster mempool_tb/dut/i_mempool_cluster/rst_ni
add wave -noupdate -group cluster mempool_tb/dut/i_mempool_cluster/axi_mst_req_o
add wave -noupdate -group cluster mempool_tb/dut/i_mempool_cluster/axi_mst_resp_i
add wave -noupdate -group cluster mempool_tb/dut/i_mempool_cluster/ro_cache_ctrl_i
add wave -noupdate -group cluster mempool_tb/dut/i_mempool_cluster/dma_*
