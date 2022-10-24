# Copyright 2021 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Create group for core $core from group $group tile $tile (core_id=NUM_CORES_PER_group*$group+NUM_CORES_PER_TILE*$tile+$core)

wvAddGroup core\[$group\]\[$tile\]\[$core\]
wvSetPosition [subst {(core\[$group\]\[$tile\]\[$core\] last)}]

add_wave -divider Clock
wvAddSignal mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/clk_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/rst_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/hart_id_i

add_wave -divider Instructions
wvAddSignal mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/inst_addr_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/inst_data_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/inst_valid_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/inst_ready_i

add_wave -divider "Load and Store"
wvAddSignal mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/data_qaddr_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/data_qwrite_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/data_qamo_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/data_qdata_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/data_qstrb_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/data_qvalid_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/data_qready_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/data_pdata_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/data_perror_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/data_pvalid_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/data_pready_o

add_wave -divider Accelerator
wvAddSignal mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/acc_qaddr_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/acc_qid_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/acc_qdata_op_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/acc_qdata_arga_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/acc_qdata_argb_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/acc_qdata_argc_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/acc_qvalid_o \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/acc_qready_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/acc_pdata_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/acc_pid_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/acc_perror_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/acc_pvalid_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/acc_pready_o

wvSelectGroup core\[$group\]\[$tile\]\[$core\]
wvAddSubGroup Internal
wvAddSignal mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/clk_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/rst_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/illegal_inst \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/stall \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/lsu_stall \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/acc_stall \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/zero_lsb \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/pc_d \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/pc_q \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/wfi_d \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/wfi_q \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/wake_up_sync_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/wake_up_d \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/wake_up_q
add_wave -divider LSU
wvAddSignal mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/ls_size \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/ls_amo \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/ld_result \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/lsu_qready \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/lsu_qvalid \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/lsu_pvalid \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/lsu_pready \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/lsu_rd \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/retire_load \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/retire_i \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/retire_acc
add_wave -divider ALU
wvAddSignal mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/opa \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/opb \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/iimm \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/uimm \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/jimm \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/bimm \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/simm \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/adder_result \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/alu_result \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/rd \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/rs1 \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/rs2 \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/gpr_raddr \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/gpr_rdata \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/gpr_waddr \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/gpr_wdata \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/gpr_we \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/consec_pc \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/sb_d \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/sb_q \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/is_load \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/is_store \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/is_signed \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/is_fp_load \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/is_fp_store \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/ls_misaligned \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/ld_addr_misaligned \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/st_addr_misaligned \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/valid_instr \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/exception \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/alu_op \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/opa_select \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/opb_select \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/write_rd \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/uses_rd \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/next_pc \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/rd_select \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/rd_bypass \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/is_branch \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/csr_rvalue \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/csr_en \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/cycle_q \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/instret_q \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/acc_register_rd \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/operands_ready \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/dst_ready \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/opa_ready \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/opb_ready \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/shift_opa \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/shift_opa_reversed \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/shift_right_result \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/shift_left_result \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/shift_opa_ext \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/shift_right_result_ext \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/shift_left \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/shift_arithmetic \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/alu_opa \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/alu_opb \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/alu_writeback \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/csr_trace_q \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/csr_trace_en \
            mempool_tb/dut/i_mempool_cluster/gen_groups\[$group\]/i_group/gen_tiles\[$tile\]/i_tile/gen_cores\[$core\]/gen_mempool_cc/riscv_core/i_snitch/core_events_o

wvCollapseAllGroups
