# Copyright 2021 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Create cache for core $3 from group $1 tile $2 (core_id=NUM_CORES_PER_group*$1+NUM_CORES_PER_TILE*$2+$3)

add_wave -group core\[$1\]\[$2\]\[$3\] -divider Parameters
add_wave -group cache\[$1\]\[$2\]\[$3\] /mempool_tb/dut/i_mempool_cluster/gen_groups\[$1\]/i_group/gen_tiles\[$2\]/i_tile/gen_caches\[$3\]/i_snitch_icache/NR_FETCH_PORTS
add_wave -group cache\[$1\]\[$2\]\[$3\] /mempool_tb/dut/i_mempool_cluster/gen_groups\[$1\]/i_group/gen_tiles\[$2\]/i_tile/gen_caches\[$3\]/i_snitch_icache/L0_LINE_COUNT
add_wave -group cache\[$1\]\[$2\]\[$3\] /mempool_tb/dut/i_mempool_cluster/gen_groups\[$1\]/i_group/gen_tiles\[$2\]/i_tile/gen_caches\[$3\]/i_snitch_icache/LINE_WIDTH
add_wave -group cache\[$1\]\[$2\]\[$3\] /mempool_tb/dut/i_mempool_cluster/gen_groups\[$1\]/i_group/gen_tiles\[$2\]/i_tile/gen_caches\[$3\]/i_snitch_icache/LINE_COUNT
add_wave -group cache\[$1\]\[$2\]\[$3\] /mempool_tb/dut/i_mempool_cluster/gen_groups\[$1\]/i_group/gen_tiles\[$2\]/i_tile/gen_caches\[$3\]/i_snitch_icache/SET_COUNT
add_wave -group cache\[$1\]\[$2\]\[$3\] /mempool_tb/dut/i_mempool_cluster/gen_groups\[$1\]/i_group/gen_tiles\[$2\]/i_tile/gen_caches\[$3\]/i_snitch_icache/FETCH_DW
add_wave -group cache\[$1\]\[$2\]\[$3\] /mempool_tb/dut/i_mempool_cluster/gen_groups\[$1\]/i_group/gen_tiles\[$2\]/i_tile/gen_caches\[$3\]/i_snitch_icache/FILL_AW
add_wave -group cache\[$1\]\[$2\]\[$3\] /mempool_tb/dut/i_mempool_cluster/gen_groups\[$1\]/i_group/gen_tiles\[$2\]/i_tile/gen_caches\[$3\]/i_snitch_icache/FILL_DW
add_wave -group cache\[$1\]\[$2\]\[$3\] /mempool_tb/dut/i_mempool_cluster/gen_groups\[$1\]/i_group/gen_tiles\[$2\]/i_tile/gen_caches\[$3\]/i_snitch_icache/EARLY_LATCH
add_wave -group cache\[$1\]\[$2\]\[$3\] /mempool_tb/dut/i_mempool_cluster/gen_groups\[$1\]/i_group/gen_tiles\[$2\]/i_tile/gen_caches\[$3\]/i_snitch_icache/L0_EARLY_TAG_WIDTH
add_wave -group cache\[$1\]\[$2\]\[$3\] /mempool_tb/dut/i_mempool_cluster/gen_groups\[$1\]/i_group/gen_tiles\[$2\]/i_tile/gen_caches\[$3\]/i_snitch_icache/ISO_CROSSING
add_wave -group core\[$1\]\[$2\]\[$3\] -divider Signals
add_wave -group cache\[$1\]\[$2\]\[$3\] /mempool_tb/dut/i_mempool_cluster/gen_groups\[$1\]/i_group/gen_tiles\[$2\]/i_tile/gen_caches\[$3\]/i_snitch_icache/*

for {set i 0} {$i < [get -radix dec /mempool_tb/dut/i_mempool_cluster/gen_groups\[$1\]/i_group/gen_tiles\[$2\]/i_tile/gen_caches\[$3\]/i_snitch_icache/NR_FETCH_PORTS]} {incr i} {
  add_wave -group cache\[$1\]\[$2\]\[$3\]|refill[$i] /mempool_tb/dut/i_mempool_cluster/gen_groups\[$1\]/i_group/gen_tiles\[$2\]/i_tile/gen_caches\[$3\]/i_snitch_icache/gen_prefetcher[$i]/i_snitch_icache_l0/*
}

add_wave -group cache\[$1\]\[$2\]\[$3\]|lookup  /mempool_tb/dut/i_mempool_cluster/gen_groups\[$1\]/i_group/gen_tiles\[$2\]/i_tile/gen_caches\[$3\]/i_snitch_icache/i_lookup/*
add_wave -group cache\[$1\]\[$2\]\[$3\]|handler /mempool_tb/dut/i_mempool_cluster/gen_groups\[$1\]/i_group/gen_tiles\[$2\]/i_tile/gen_caches\[$3\]/i_snitch_icache/i_handler/*
add_wave -group cache\[$1\]\[$2\]\[$3\]|refill  /mempool_tb/dut/i_mempool_cluster/gen_groups\[$1\]/i_group/gen_tiles\[$2\]/i_tile/gen_caches\[$3\]/i_snitch_icache/i_refill/*
