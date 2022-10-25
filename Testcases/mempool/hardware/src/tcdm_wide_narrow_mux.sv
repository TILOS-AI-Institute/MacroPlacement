// Copyright 2020 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Samuel Riedel <sriedel@iis.ee.ethz.ch>

// This module multiplexes many narrow ports and one wide port onto many narrow
// ports. The wide port is prioritized.
module tcdm_wide_narrow_mux #(
  // Width of narrow data.
  parameter int unsigned NarrowDataWidth = 0,
  // Width of wide data.
  parameter int unsigned WideDataWidth   = 0,
  // Request type of narrow inputs.
  parameter type narrow_req_t        = logic,
  // Response type of narrow inputs.
  parameter type narrow_rsp_t        = logic,
  // Request type of wide inputs.
  parameter type wide_req_t          = logic,
  // Response type of wide inputs.
  parameter type wide_rsp_t          = logic,
  // Derived. *Do not override*
  // Number of narrow inputs.
  parameter int unsigned NrPorts = WideDataWidth / NarrowDataWidth
) (
  input  logic                          clk_i,
  input  logic                          rst_ni,
  // Narrow inputs
  input  narrow_req_t [NrPorts-1:0] slv_narrow_req_i,
  input  logic        [NrPorts-1:0] slv_narrow_req_valid_i,
  output logic        [NrPorts-1:0] slv_narrow_req_ready_o,
  output narrow_rsp_t [NrPorts-1:0] slv_narrow_rsp_o,
  output logic        [NrPorts-1:0] slv_narrow_rsp_valid_o,
  input  logic        [NrPorts-1:0] slv_narrow_rsp_ready_i,
  // Wide input
  input  wide_req_t                 slv_wide_req_i,
  input  logic                      slv_wide_req_valid_i,
  output logic                      slv_wide_req_ready_o,
  output wide_rsp_t                 slv_wide_rsp_o,
  output logic                      slv_wide_rsp_valid_o,
  input  logic                      slv_wide_rsp_ready_i,
  // Multiplexed outputs
  output narrow_req_t [NrPorts-1:0] mst_req_o,
  output logic        [NrPorts-1:0] mst_req_wide_o,
  output logic        [NrPorts-1:0] mst_req_valid_o,
  input  logic        [NrPorts-1:0] mst_req_ready_i,
  input  narrow_rsp_t [NrPorts-1:0] mst_rsp_i,
  input  logic        [NrPorts-1:0] mst_rsp_wide_i,
  input  logic        [NrPorts-1:0] mst_rsp_valid_i,
  output logic        [NrPorts-1:0] mst_rsp_ready_o
);

  localparam int unsigned NarrowBeWidth = NarrowDataWidth/8;

  // Request path
  logic [NrPorts-1:0] forked_wide_req_valid;
  logic [NrPorts-1:0] forked_wide_req_ready;

  // Fork the wide request into multiple narrow ones
  stream_fork #(
    .N_OUP (NrPorts)
  ) i_wide_stream_fork (
    .clk_i  (clk_i                ),
    .rst_ni (rst_ni               ),
    .valid_i(slv_wide_req_valid_i ),
    .ready_o(slv_wide_req_ready_o ),
    .valid_o(forked_wide_req_valid),
    .ready_i(forked_wide_req_ready)
  );

  always_comb begin
    // Feed-through narrow ports by default
    mst_req_valid_o = slv_narrow_req_valid_i;
    slv_narrow_req_ready_o = mst_req_ready_i;
    mst_req_wide_o = '0;
    mst_req_o = slv_narrow_req_i;
    // Block wide by default
    forked_wide_req_ready = '0;

    for (int i = 0; i < NrPorts; i++) begin
      if (forked_wide_req_valid[i]) begin
        // Select the wide port
        mst_req_valid_o[i] = forked_wide_req_valid[i];
        forked_wide_req_ready[i] = mst_req_ready_i[i];
        mst_req_wide_o[i] = 1'b1;
        mst_req_o[i] = '{
          wdata: slv_wide_req_i.wdata[i*NarrowDataWidth+:NarrowDataWidth],
          wen: slv_wide_req_i.wen,
          be: slv_wide_req_i.be[i*NarrowBeWidth+:NarrowBeWidth],
          tgt_addr: slv_wide_req_i.tgt_addr,
          ini_addr: '0
        };
        // Block access from narrow ports.
        slv_narrow_req_ready_o[i] = 1'b0;
      end
    end
  end

  // Response path
  logic [NrPorts-1:0] forked_wide_rsp_valid;
  logic [NrPorts-1:0] forked_wide_rsp_ready;

  // Join the multiple narrow requests into one wide one
  stream_join #(
    .N_INP (NrPorts)
  ) i_wide_stream_join (
    .inp_valid_i(forked_wide_rsp_valid),
    .inp_ready_o(forked_wide_rsp_ready),
    .oup_valid_o(slv_wide_rsp_valid_o ),
    .oup_ready_i(slv_wide_rsp_ready_i )
  );

  always_comb begin
    // Broadcast data
    slv_narrow_rsp_o = mst_rsp_i;
    // Tie off both interfaces by default
    slv_narrow_rsp_valid_o = '0;
    forked_wide_rsp_valid = '0;
    mst_rsp_ready_o = '0;
    for (int i = 0; i < NrPorts; i++) begin
      // Broadcast data from all banks.
      slv_wide_rsp_o.rdata[i*NarrowDataWidth+:NarrowDataWidth] = mst_rsp_i[i].rdata;
      // Connect handshake based on selection
      if (mst_rsp_wide_i[i]) begin
        forked_wide_rsp_valid[i] = mst_rsp_valid_i[i];
        mst_rsp_ready_o[i] = forked_wide_rsp_ready[i];
      end else begin
        slv_narrow_rsp_valid_o[i] = mst_rsp_valid_i[i];
        mst_rsp_ready_o[i] = slv_narrow_rsp_ready_i[i];
      end
    end
  end

  // Check parameters
  if (NrPorts*NarrowDataWidth != WideDataWidth) begin
    $error("[tcdm_wide_narrow_mux] WideDataWidth must be divisible by NarrowDataWidth.");
  end
endmodule
