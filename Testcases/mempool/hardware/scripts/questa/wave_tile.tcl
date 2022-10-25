# Copyright 2021 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Create group for group $1 tile $2

add wave -noupdate -group group_[$1] -group Tile_[$2] -group Params /mempool_pkg::NumBanksPerTile
add wave -noupdate -group group_[$1] -group Tile_[$2] -group Params /mempool_pkg::NumTiles
add wave -noupdate -group group_[$1] -group Tile_[$2] -group Params /mempool_pkg::NumBanks
add wave -noupdate -group group_[$1] -group Tile_[$2] -group Params /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/TCDMBaseAddr
add wave -noupdate -group group_[$1] -group Tile_[$2] -group Params /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/BootAddr
add wave -noupdate -group group_[$1] -group Tile_[$2] -group Params /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_caches[0].i_snitch_icache.LINE_WIDTH
add wave -noupdate -group group_[$1] -group Tile_[$2] -group Params /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_caches[0].i_snitch_icache.LINE_COUNT
add wave -noupdate -group group_[$1] -group Tile_[$2] -group Params /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_caches[0].i_snitch_icache.SET_COUNT
add wave -noupdate -group group_[$1] -group Tile_[$2] -group Params /mempool_pkg::ICacheLineWidth
add wave -noupdate -group group_[$1] -group Tile_[$2] -group Params /mempool_pkg::ICacheSizeByte
add wave -noupdate -group group_[$1] -group Tile_[$2] -group Params /mempool_pkg::ICacheSets
add wave -noupdate -group group_[$1] -group Tile_[$2] -group Params /mempool_pkg::NumCores
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/clk_i
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/rst_ni
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/scan_enable_i
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/scan_data_i
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/scan_data_o
add wave -noupdate -group group_[$1] -group Tile_[$2] -radix unsigned /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/tile_id_i

add wave -noupdate -group group_[$1] -group Tile_[$2] -divider TCDM
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/tcdm_master_*
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/tcdm_slave_*
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/axi_*
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/snitch_inst_*
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/snitch_data_*
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/bank_req_*
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/bank_resp_*
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/postreg_tcdm_slave_req_*
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/prereg_tcdm_slave_resp_*
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/prereg_tcdm_master_req_*
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/postreg_tcdm_master_resp_*
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/remote_req_*
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/remote_resp_*
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/local_req_*
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/local_resp_*
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/soc_data_*
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/mask_map
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/soc_req_o
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/soc_resp_i
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/soc_qvalid
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/soc_qready
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/soc_pvalid
add wave -noupdate -group group_[$1] -group Tile_[$2] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/soc_pready

for {set i 0} {$i < 16} {incr i} {
	add wave -noupdate -group group_[$1] -group Tile_[$2] -group tcdm_adapter[$i] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_banks[$i]/i_tcdm_adapter/*
}
