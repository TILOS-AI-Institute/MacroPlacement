# Copyright 2021 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

onerror {resume}
quietly WaveActivateNextPane {} 0

# Add a vector of the core's wfi signal to quickly see which cores are active
add wave /mempool_tb/wfi

# Add all cores from group 0 tile 0
for {set core 0}  {$core < [examine -radix dec mempool_pkg::NumCoresPerTile]} {incr core} {
    do ../scripts/questa/wave_core.tcl 0 0 $core
}

# Add specific cores from different tiles
do ../scripts/questa/wave_core.tcl 1 0 0

# Add groups
for {set group 0} {$group < [examine -radix dec /mempool_pkg::NumGroups]} {incr group} {
    # Add tiles
    for {set tile 0} {$tile < [expr min(4,[examine -radix dec /mempool_pkg::NumTilesPerGroup])]} {incr tile} {
        do ../scripts/questa/wave_tile.tcl $group $tile
    }

    # Interconnects
    for {set tgtgroup 0} {$tgtgroup < [examine -radix dec /mempool_pkg::NumGroups]} {incr tgtgroup} {
        if {$tgtgroup != $group} {
            set interco_idx [expr $group ^ $tgtgroup]
            add wave -group group_[$group] -group interconnect_to_group[$tgtgroup] /mempool_tb/dut/i_mempool_cluster/gen_groups[$group]/i_group/gen_remote_interco[$interco_idx]/i_remote_interco/*
        }
    }
    add wave -group group_[$group] -group interconnect_local /mempool_tb/dut/i_mempool_cluster/gen_groups[$group]/i_group/i_local_interco/*
}

# Add cluster
do ../scripts/questa/wave_cluster.tcl

add wave -Group Control_Registers /mempool_tb/dut/i_ctrl_registers/*

add wave -Group DMA /mempool_tb/dut/i_mempool_dma/*
add wave -Group DMA -Group Reg /mempool_tb/dut/i_mempool_dma/i_mempool_dma_frontend_reg_top/*
for {set group 0} {$group < [examine -radix dec /mempool_pkg::NumGroups]} {incr group} {
  add wave -Group DMA_midend_${group} /mempool_tb/dut/i_mempool_cluster/gen_groups[$group]/i_group/i_idma_distributed_midend/NoMstPorts
  add wave -Group DMA_midend_${group} /mempool_tb/dut/i_mempool_cluster/gen_groups[$group]/i_group/i_idma_distributed_midend/DmaRegionWidth
  add wave -Group DMA_midend_${group} /mempool_tb/dut/i_mempool_cluster/gen_groups[$group]/i_group/i_idma_distributed_midend/DmaRegionStart
  add wave -Group DMA_midend_${group} /mempool_tb/dut/i_mempool_cluster/gen_groups[$group]/i_group/i_idma_distributed_midend/DmaRegionEnd
  add wave -Group DMA_midend_${group} /mempool_tb/dut/i_mempool_cluster/gen_groups[$group]/i_group/i_idma_distributed_midend/DmaRegionAddressBits
  add wave -Group DMA_midend_${group} /mempool_tb/dut/i_mempool_cluster/gen_groups[$group]/i_group/i_idma_distributed_midend/FullRegionAddressBits
  add wave -Group DMA_midend_${group} /mempool_tb/dut/i_mempool_cluster/gen_groups[$group]/i_group/i_idma_distributed_midend/*
  for {set dma 0} {$dma < [examine -radix dec /mempool_pkg::NumDmasPerGroup]} {incr dma} {
    add wave -Group DMA_${group}_${dma} /mempool_tb/dut/i_mempool_cluster/gen_groups[$group]/i_group/gen_dmas[$dma]/i_axi_dma_backend/*
  }
}

add wave -Group DMA_midend_cluster /mempool_tb/dut/i_mempool_cluster/i_idma_distributed_midend/NoMstPorts
add wave -Group DMA_midend_cluster /mempool_tb/dut/i_mempool_cluster/i_idma_distributed_midend/DmaRegionWidth
add wave -Group DMA_midend_cluster /mempool_tb/dut/i_mempool_cluster/i_idma_distributed_midend/DmaRegionStart
add wave -Group DMA_midend_cluster /mempool_tb/dut/i_mempool_cluster/i_idma_distributed_midend/DmaRegionEnd
add wave -Group DMA_midend_cluster /mempool_tb/dut/i_mempool_cluster/i_idma_distributed_midend/DmaRegionAddressBits
add wave -Group DMA_midend_cluster /mempool_tb/dut/i_mempool_cluster/i_idma_distributed_midend/FullRegionAddressBits
add wave -Group DMA_midend_cluster /mempool_tb/dut/i_mempool_cluster/i_idma_distributed_midend/*


add wave -Group DMA_split /mempool_tb/dut/i_mempool_cluster/i_idma_split_midend/*

do ../scripts/questa/wave_cache.tcl 0 0 0
