// Copyright 2021 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>

`include "reqrsp_interface/typedef.svh"

/// Multiplex multiple `reqrsp` ports onto one, based on arbitration.
module reqrsp_mux #(
    /// Number of input ports.
    parameter int unsigned               NrPorts      = 2,
    /// Address width of the interface.
    parameter int unsigned               AddrWidth    = 0,
    /// Data width of the interface.
    parameter int unsigned               DataWidth    = 0,
    /// Request type.
    parameter type                       req_t        = logic,
    /// Response type.
    parameter type                       rsp_t        = logic,
    /// Amount of outstanding responses. Determines the FIFO size.
    parameter int unsigned               RespDepth    = 8,
    /// Cut timing paths on the request path. Incurs a cycle additional latency.
    /// Registers are inserted at the slave side.
    parameter bit          [NrPorts-1:0] RegisterReq  = '0
) (
    input  logic               clk_i,
    input  logic               rst_ni,
    input  req_t [NrPorts-1:0] slv_req_i,
    output rsp_t [NrPorts-1:0] slv_rsp_o,
    output req_t               mst_req_o,
    input  rsp_t               mst_rsp_i
);

  typedef logic [AddrWidth-1:0] addr_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [DataWidth/8-1:0] strb_t;

  `REQRSP_TYPEDEF_REQ_CHAN_T(req_chan_t, addr_t, data_t, strb_t)

  localparam int unsigned LogNrPorts = cf_math_pkg::idx_width(NrPorts);

  logic [NrPorts-1:0] req_valid_masked, req_ready_masked;
  logic [LogNrPorts-1:0] idx, idx_rsp;
  logic full;

  req_chan_t [NrPorts-1:0] req_payload_q;
  logic [NrPorts-1:0] req_valid_q, req_ready_q;

  // Unforunately we need this signal otherwise the simulator complains about
  // multiple driven signals, because some other signals are driven from an
  // `always_comb` block.
  logic [NrPorts-1:0] slv_rsp_q_ready;

  // Optionially cut the incoming path
  for (genvar i = 0; i < NrPorts; i++) begin : gen_cuts
    spill_register #(
      .T (req_chan_t),
      .Bypass (!RegisterReq[i])
    ) i_spill_register_req (
      .clk_i,
      .rst_ni,
      .valid_i (slv_req_i[i].q_valid),
      .ready_o (slv_rsp_q_ready[i]),
      .data_i (slv_req_i[i].q),
      .valid_o (req_valid_q[i]),
      .ready_i (req_ready_masked[i]),
      .data_o (req_payload_q[i])
    );
  end

  // We need to silence the handshake in case the fifo is full and we can't
  // accept more transactions.
  for (genvar i = 0; i < NrPorts; i++) begin : gen_req_valid_masked
    assign req_valid_masked[i] = req_valid_q[i] & ~full;
    assign req_ready_masked[i] = req_ready_q[i] & ~full;
  end

  /// Arbitrate on instruction request port
  rr_arb_tree #(
    .NumIn (NrPorts),
    .DataType (req_chan_t),
    .AxiVldRdy (1'b1),
    .LockIn (1'b1)
  ) i_q_mux (
    .clk_i,
    .rst_ni,
    .flush_i (1'b0),
    .rr_i  ('0),
    .req_i (req_valid_masked),
    .gnt_o (req_ready_q),
    .data_i (req_payload_q),
    .gnt_i (mst_rsp_i.q_ready),
    .req_o (mst_req_o.q_valid),
    .data_o (mst_req_o.q),
    .idx_o ()
  );

  // De-generate version does not need a fifo. We always know where to route
  // back the responses.
  if (NrPorts == 1) begin : gen_single_port
    assign idx_rsp = 0;
    assign full = 1'b0;
  end else begin : gen_multi_port
    // For the "normal" case we need to safe the arbitration decision. We so by
    // converting the handshake into a binary signal which we save for response
    // routing.
    onehot_to_bin #(
      .ONEHOT_WIDTH (NrPorts)
    ) i_onehot_to_bin (
      .onehot (req_valid_q & req_ready_q),
      .bin    (idx)
    );
    // Safe the arbitration decision.
    fifo_v3 #(
      .DATA_WIDTH (LogNrPorts),
      .DEPTH (RespDepth)
    ) i_resp_fifo (
      .clk_i,
      .rst_ni,
      .flush_i (1'b0),
      .testmode_i (1'b0),
      .full_o (full),
      .empty_o (),
      .usage_o (),
      .data_i (idx),
      .push_i (mst_req_o.q_valid & mst_rsp_i.q_ready),
      .data_o (idx_rsp),
      .pop_i (mst_req_o.p_ready & mst_rsp_i.p_valid)
    );
  end

  // Output Mux
  always_comb begin
    for (int i = 0; i < NrPorts; i++) begin
      slv_rsp_o[i].p_valid = '0;
      slv_rsp_o[i].q_ready = slv_rsp_q_ready[i];
      slv_rsp_o[i].p = mst_rsp_i.p;
    end
    slv_rsp_o[idx_rsp].p_valid = mst_rsp_i.p_valid;
  end

  assign mst_req_o.p_ready = slv_req_i[idx_rsp].p_ready;

endmodule

`include "reqrsp_interface/typedef.svh"
`include "reqrsp_interface/assign.svh"

/// Interface wrapper.
module reqrsp_mux_intf #(
    /// Number of input ports.
    parameter int unsigned      NrPorts      = 2,
    /// Address width of the interface.
    parameter int unsigned      AddrWidth    = 0,
    /// Data width of the interface.
    parameter int unsigned      DataWidth    = 0,
    /// Amount of outstanding responses. Determines the FIFO size.
    parameter int unsigned      RespDepth    = 8,
    /// Cut timing paths on the request path. Incurs a cycle additional latency.
    /// Registers are inserted at the slave side.
    parameter bit [NrPorts-1:0] RegisterReq  = '0
) (
    input  logic clk_i,
    input  logic rst_ni,
    REQRSP_BUS   slv [NrPorts],
    REQRSP_BUS   mst
);

  typedef logic [AddrWidth-1:0] addr_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [DataWidth/8-1:0] strb_t;

  `REQRSP_TYPEDEF_ALL(reqrsp, addr_t, data_t, strb_t)

  reqrsp_req_t [NrPorts-1:0] reqrsp_slv_req;
  reqrsp_rsp_t [NrPorts-1:0] reqrsp_slv_rsp;

  reqrsp_req_t reqrsp_mst_req;
  reqrsp_rsp_t reqrsp_mst_rsp;

  reqrsp_mux #(
    .NrPorts (NrPorts),
    .AddrWidth (AddrWidth),
    .DataWidth (DataWidth),
    .req_t (reqrsp_req_t),
    .rsp_t (reqrsp_rsp_t),
    .RespDepth (RespDepth),
    .RegisterReq (RegisterReq)
  ) i_reqrsp_mux (
    .clk_i,
    .rst_ni,
    .slv_req_i (reqrsp_slv_req),
    .slv_rsp_o (reqrsp_slv_rsp),
    .mst_req_o (reqrsp_mst_req),
    .mst_rsp_i (reqrsp_mst_rsp)
  );

  for (genvar i = 0; i < NrPorts; i++) begin : gen_interface_assignment
    `REQRSP_ASSIGN_TO_REQ(reqrsp_slv_req[i], slv[i])
    `REQRSP_ASSIGN_FROM_RESP(slv[i], reqrsp_slv_rsp[i])
  end

  `REQRSP_ASSIGN_FROM_REQ(mst, reqrsp_mst_req)
  `REQRSP_ASSIGN_TO_RESP(reqrsp_mst_rsp, mst)

endmodule
