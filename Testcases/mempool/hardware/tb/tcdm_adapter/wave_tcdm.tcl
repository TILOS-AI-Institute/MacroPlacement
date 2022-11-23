# Copyright 2021 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -group DUT /tcdm_adapter_tb/*

add wave -noupdate -group TCDMAdapter /tcdm_adapter_tb/dut/*

add wave -noupdate -group MEMBANK /tcdm_adapter_tb/mem_bank/*

add wave -noupdate -group FALLTHROUGH /tcdm_adapter_tb/dut/i_rdata_register/*

add wave -noupdate -group RDATA_FIFO /tcdm_adapter_tb/dut/i_rdata_register/i_fifo/*

run -a
