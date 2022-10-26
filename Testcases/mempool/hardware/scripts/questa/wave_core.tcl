# Copyright 2021 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Create group for core $3 from group $1 tile $2 (core_id=NUM_CORES_PER_group*$1+NUM_CORES_PER_TILE*$2+$3)

add wave -noupdate -group core[$1][$2][$3] -group Params /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/BootAddr
add wave -noupdate -group core[$1][$2][$3] -group Params /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/MTVEC
add wave -noupdate -group core[$1][$2][$3] -group Params /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/RVE
add wave -noupdate -group core[$1][$2][$3] -group Params /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/RVM
add wave -noupdate -group core[$1][$2][$3] -group Params /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/RegisterOffloadReq
add wave -noupdate -group core[$1][$2][$3] -group Params /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/RegisterOffloadResp
add wave -noupdate -group core[$1][$2][$3] -group Params /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/RegisterTCDMReq
add wave -noupdate -group core[$1][$2][$3] -group Params /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/RegisterTCDMResp
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/clk_i
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/rst_i
add wave -noupdate -group core[$1][$2][$3] -radix unsigned /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/hart_id_i

add wave -noupdate -group core[$1][$2][$3] -divider Instructions
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/inst_addr_o
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/inst_data_i
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/inst_valid_o
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/inst_ready_i

add wave -noupdate -group core[$1][$2][$3] -divider Load/Store
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/data_qaddr_o
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/data_qwrite_o
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/data_qamo_o
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/data_qdata_o
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/data_qstrb_o
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/data_qvalid_o
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/data_qready_i
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/data_pdata_i
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/data_perror_i
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/data_pvalid_i
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/data_pready_o

add wave -noupdate -group core[$1][$2][$3] -divider Accelerator
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/acc_qaddr_o
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/acc_qid_o
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/acc_qdata_op_o
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/acc_qdata_arga_o
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/acc_qdata_argb_o
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/acc_qdata_argc_o
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/acc_qvalid_o
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/acc_qready_i
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/acc_pdata_i
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/acc_pid_i
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/acc_perror_i
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/acc_pvalid_i
add wave -noupdate -group core[$1][$2][$3] /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/acc_pready_o

add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/illegal_inst
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/stall
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/lsu_stall
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/acc_stall
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/zero_lsb
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/pc_d
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/pc_q
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/wfi_d
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/wfi_q
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/wake_up_sync_i
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/wake_up_d
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/wake_up_q
add wave -noupdate -group core[$1][$2][$3] -group Internal -divider LSU
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/ls_size
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/ls_amo
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/ld_result
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/lsu_qready
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/lsu_qvalid
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/lsu_pvalid
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/lsu_pready
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/lsu_rd
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/retire_load
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/retire_i
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/retire_acc
add wave -noupdate -group core[$1][$2][$3] -group Internal -divider Register
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/i_snitch_regfile/raddr_i
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/i_snitch_regfile/waddr_i
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/i_snitch_regfile/wdata_i
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/i_snitch_regfile/we_i
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/i_snitch_regfile/rdata_o
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/i_snitch_regfile/mem
add wave -noupdate -group core[$1][$2][$3] -group Internal -divider ALU
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/opa
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/opb
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/iimm
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/uimm
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/jimm
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/bimm
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/simm
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/adder_result
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/alu_result
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/rd
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/rs1
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/rs2
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/gpr_raddr
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/gpr_rdata
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/gpr_waddr
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/gpr_wdata
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/gpr_we
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/consec_pc
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/sb_d
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/sb_q
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/is_load
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/is_store
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/is_signed
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/is_fp_load
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/is_fp_store
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/ls_misaligned
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/ld_addr_misaligned
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/st_addr_misaligned
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/valid_instr
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/exception
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/alu_op
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/opa_select
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/opb_select
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/write_rd
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/uses_rd
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/next_pc
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/rd_select
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/rd_bypass
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/is_branch
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/csr_rvalue
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/csr_en
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/cycle_q
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/instret_q
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/acc_register_rd
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/operands_ready
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/dst_ready
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/opa_ready
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/opb_ready
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/shift_opa
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/shift_opa_reversed
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/shift_right_result
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/shift_left_result
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/shift_opa_ext
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/shift_right_result_ext
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/shift_left
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/shift_arithmetic
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/alu_opa
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/alu_opb
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/alu_writeback
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/csr_trace_q
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/csr_trace_en
add wave -noupdate -group core[$1][$2][$3] -group Internal /mempool_tb/dut/i_mempool_cluster/gen_groups[$1]/i_group/gen_tiles[$2]/i_tile/gen_cores[$3]/gen_mempool_cc/riscv_core/i_snitch/core_events_o
