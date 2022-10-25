// Copyright 2020 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>

`include "reqrsp_interface/typedef.svh"
`include "common_cells/assertions.svh"

module reqrsp_demux #(
    /// Number of input ports.
    parameter int unsigned NrPorts     = 2,
    /// Request type.
    parameter type req_t               = logic,
    /// Response type.
    parameter type rsp_t               = logic,
    /// Amount of outstanding responses. Determines the FIFO size.
    parameter int unsigned RespDepth   = 8,
    // Dependent parameters, DO NOT OVERRIDE!
    parameter int unsigned SelectWidth = cf_math_pkg::idx_width(NrPorts),
    parameter type         select_t    = logic [SelectWidth-1:0]
) (
    input  logic               clk_i,
    input  logic               rst_ni,
    input  select_t            slv_select_i,
    input  req_t               slv_req_i,
    output rsp_t               slv_rsp_o,
    output req_t [NrPorts-1:0] mst_req_o,
    input  rsp_t [NrPorts-1:0] mst_rsp_i
);

  logic [NrPorts-1:0] fwd;
  logic req_ready, req_valid;
  logic fifo_full, fifo_empty;
  logic [NrPorts-1:0] fifo_data;
  logic push_id_fifo, pop_id_fifo;

  // we need space in the return id fifo, silence if no space is available
  assign req_valid = ~fifo_full & slv_req_i.q_valid;
  assign slv_rsp_o.q_ready = ~fifo_full & req_ready;

  // Stream demux (unwrapped because of struct issues)
  always_comb begin
    for (int i = 0; i < NrPorts; i++) begin
      mst_req_o[i].q_valid = '0;
      mst_req_o[i].q = slv_req_i.q;
      mst_req_o[i].p_ready = fwd[i] ? slv_req_i.p_ready : 1'b0;
    end
    mst_req_o[slv_select_i].q_valid = req_valid;
  end
  assign req_ready = mst_rsp_i[slv_select_i].q_ready;

  assign push_id_fifo = req_valid & slv_rsp_o.q_ready;
  assign pop_id_fifo = slv_rsp_o.p_valid & slv_req_i.p_ready;

  for (genvar i = 0; i < NrPorts; i++) begin : gen_fifo_data
    assign fifo_data[i] = mst_rsp_i[i].q_ready & mst_req_o[i].q_valid;
  end

  // Remember selected master for correct forwarding of read data/acknowledge.
  fifo_v3 #(
    .DATA_WIDTH ( NrPorts ),
    .DEPTH ( RespDepth )
  ) i_id_fifo (
    .clk_i,
    .rst_ni,
    .flush_i (1'b0),
    .testmode_i (1'b0),
    .full_o (fifo_full),
    .empty_o (fifo_empty),
    .usage_o ( ),
    // Onehot mask.
    .data_i (fifo_data),
    .push_i (push_id_fifo),
    .data_o (fwd),
    .pop_i (pop_id_fifo)
  );

  // Response data routing.
  always_comb begin
    slv_rsp_o.p  = '0;
    slv_rsp_o.p_valid = '0;
    for (int i = 0; i < NrPorts; i++) begin
      if (fwd[i]) begin
        slv_rsp_o.p  = mst_rsp_i[i].p;
        slv_rsp_o.p_valid = mst_rsp_i[i].p_valid;
      end
    end
  end

  `ASSERT(SelectStable, slv_req_i.q_valid && !slv_rsp_o.q_ready |=> $stable(slv_select_i))
  `ASSERT(SelectInBounds, slv_req_i.q_valid |-> (slv_select_i <= NrPorts))

endmodule

`include "reqrsp_interface/typedef.svh"
`include "reqrsp_interface/assign.svh"

/// Reqrsp demux interface version.
module reqrsp_demux_intf #(
    /// Number of input ports.
    parameter int unsigned NrPorts   = 2,
    /// Address width of the interface.
    parameter int unsigned AddrWidth    = 0,
    /// Data width of the interface.
    parameter int unsigned DataWidth    = 0,
    /// Amount of outstanding responses. Determines the FIFO size.
    parameter int unsigned RespDepth    = 8,
    // Dependent parameters, DO NOT OVERRIDE!
    parameter int unsigned SelectWidth    = cf_math_pkg::idx_width(NrPorts),
    parameter type         select_t       = logic [SelectWidth-1:0]
) (
    input  logic    clk_i,
    input  logic    rst_ni,
    input  select_t slv_select_i,
    REQRSP_BUS      slv,
    REQRSP_BUS      mst [NrPorts]
);

  typedef logic [AddrWidth-1:0] addr_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [DataWidth/8-1:0] strb_t;

  `REQRSP_TYPEDEF_ALL(reqrsp, addr_t, data_t, strb_t)

  reqrsp_req_t reqrsp_slv_req;
  reqrsp_rsp_t reqrsp_slv_rsp;

  reqrsp_req_t [NrPorts-1:0] reqrsp_mst_req;
  reqrsp_rsp_t [NrPorts-1:0] reqrsp_mst_rsp;

  reqrsp_demux #(
    .NrPorts (NrPorts),
    .req_t (reqrsp_req_t),
    .rsp_t (reqrsp_rsp_t),
    .RespDepth (RespDepth)
  ) i_reqrsp_demux (
    .clk_i,
    .rst_ni,
    .slv_select_i (slv_select_i),
    .slv_req_i (reqrsp_slv_req),
    .slv_rsp_o (reqrsp_slv_rsp),
    .mst_req_o (reqrsp_mst_req),
    .mst_rsp_i (reqrsp_mst_rsp)
  );

  `REQRSP_ASSIGN_TO_REQ(reqrsp_slv_req, slv)
  `REQRSP_ASSIGN_FROM_RESP(slv, reqrsp_slv_rsp)

  for (genvar i = 0; i < NrPorts; i++) begin : gen_interface_assignment
    `REQRSP_ASSIGN_FROM_REQ(mst[i], reqrsp_mst_req[i])
    `REQRSP_ASSIGN_TO_RESP(reqrsp_mst_rsp[i], mst[i])
  end

endmodule
