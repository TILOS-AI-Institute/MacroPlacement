// Copyright 2020 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>
// Description: Variable Register File
module snitch_regfile #(
  parameter DATA_WIDTH     = 32,
  parameter NR_READ_PORTS  = 2,
  parameter NR_WRITE_PORTS = 1,
  parameter ZERO_REG_ZERO  = 1,
  parameter ADDR_WIDTH     = 4
) (
  // clock and reset
  input  logic                                      clk_i,
  // read port
  input  logic [NR_READ_PORTS-1:0][ADDR_WIDTH-1:0]  raddr_i,
  output logic [NR_READ_PORTS-1:0][DATA_WIDTH-1:0]  rdata_o,
  // write port
  input  logic [NR_WRITE_PORTS-1:0][ADDR_WIDTH-1:0] waddr_i,
  input  logic [NR_WRITE_PORTS-1:0][DATA_WIDTH-1:0] wdata_i,
  input  logic [NR_WRITE_PORTS-1:0]                 we_i
);

  localparam NUM_WORDS  = 2**ADDR_WIDTH;

  logic clk;
  logic [NUM_WORDS-1:0] mem_clocks;

  logic [NUM_WORDS-1:0][DATA_WIDTH-1:0]      mem;

  logic [NR_WRITE_PORTS-1:0][DATA_WIDTH-1:0] wdata_q;
  logic [NR_WRITE_PORTS-1:0][NUM_WORDS-1:0]  waddr_onehot;
  logic [NUM_WORDS-1:0][NR_WRITE_PORTS-1:0]  waddr_onehot_trans; // transposed index version

  for (genvar i = 0; i < NR_WRITE_PORTS; i++) begin
    for (genvar j = 0; j < NUM_WORDS; j++) begin
      assign waddr_onehot_trans[j][i] = waddr_onehot[i][j];
    end
  end

  tc_clk_gating i_regfile_cg (
    .clk_i,
    .en_i      ( |we_i  ),
    .test_en_i ( 1'b0   ),
    .clk_o     ( clk    )
  );

  // Sample Input Data
  for (genvar i = 0; i < NR_WRITE_PORTS; i++) begin
    always_ff @(posedge clk) wdata_q[i] <= wdata_i[i];

    for (genvar j = ZERO_REG_ZERO; j < NUM_WORDS; j++) begin
      always_comb begin
        if (we_i[i] && waddr_i[i] == j) waddr_onehot[i][j] = 1'b1;
        else waddr_onehot[i][j] = 1'b0;
      end
    end
  end

  for (genvar i = 0; i <  NUM_WORDS; i++) begin
    tc_clk_gating i_regfile_cg (
      .clk_i     ( clk                    ),
      .en_i      ( |waddr_onehot_trans[i] ),
      .test_en_i ( 1'b0                   ),
      .clk_o     ( mem_clocks[i]          )
    );
  end

  always_latch begin
    if (ZERO_REG_ZERO) mem[0] = '0;

    for (int unsigned i = ZERO_REG_ZERO; i < NUM_WORDS; i++) begin
      for (int unsigned j = 0; j < NR_WRITE_PORTS; j++) begin
        if (mem_clocks[i]) begin
          // TODO(zarubaf) generalize to more than 1 read port
          mem[i] = wdata_q[j];
        end
      end
    end
  end

  for (genvar i = 0; i < NR_READ_PORTS; i++) assign rdata_o[i] = mem[raddr_i[i][ADDR_WIDTH-1:0]];

endmodule
