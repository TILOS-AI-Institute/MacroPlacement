// Copyright 2021 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Description: Automatically generated bootrom
//
// Generated by hardware/scripts/generate_bootrom.py

module bootrom #(
  /* Automatically generated. DO NOT CHANGE! */
  parameter int unsigned DataWidth = 256,
  parameter int unsigned AddrWidth = 32
) (
  input  logic                 clk_i,
  input  logic                 req_i,
  input  logic [AddrWidth-1:0] addr_i,
  output logic [DataWidth-1:0] rdata_o
);
  localparam int RomSize = 1;
  localparam int AddrBits = RomSize > 1 ? $clog2(RomSize) : 1;

  const logic [RomSize-1:0][DataWidth-1:0] mem = {
    256'h00000000_00000000_00000000_00000000_00050067_10500073_00050513_e0000517
  };

  logic [AddrBits-1:0] addr_q;

  always_ff @(posedge clk_i) begin
    if (req_i) begin
      addr_q <= addr_i[AddrBits-1+5:5];
    end
  end

  // this prevents spurious Xes from propagating into
  // the speculative fetch stage of the core
  assign rdata_o = (addr_q < RomSize) ? mem[addr_q] : '0;
endmodule