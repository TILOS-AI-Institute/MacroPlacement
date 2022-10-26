# Copyright 2021 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Create group for group $group tile $tile

wvSelectGroup group\[$group\]
wvAddSubGroup tile\[$tile\]

wvSetPosition [subst {(group\[$group\]/tile\[$tile\] last)}]

add_wave -divider Clock
wvAddSignal mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/clk_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/rst_ni \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/tile_id_i \

add_wave -divider TCDM
wvAddSignal mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/tcdm_master_req_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/tcdm_master_req_valid_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/tcdm_master_req_ready_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/tcdm_master_resp_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/tcdm_master_resp_valid_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/tcdm_master_resp_ready_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/tcdm_slave_req_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/tcdm_slave_req_valid_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/tcdm_slave_req_ready_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/tcdm_slave_resp_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/tcdm_slave_resp_valid_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/tcdm_slave_resp_ready_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/axi_mst_req_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/axi_mst_resp_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/snitch_inst_addr \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/snitch_inst_data \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/snitch_inst_valid \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/snitch_inst_ready \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/snitch_data_qaddr \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/snitch_data_qwrite \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/snitch_data_qamo \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/snitch_data_qdata \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/snitch_data_qstrb \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/snitch_data_qid \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/snitch_data_qvalid \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/snitch_data_qready \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/snitch_data_pdata \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/snitch_data_perror \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/snitch_data_pid \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/snitch_data_pvalid \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/snitch_data_pready \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/mask_map \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/soc_req_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/soc_resp_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/soc_qvalid \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/soc_qready \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/soc_pvalid \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/soc_pready

wvCollapseAllGroups
