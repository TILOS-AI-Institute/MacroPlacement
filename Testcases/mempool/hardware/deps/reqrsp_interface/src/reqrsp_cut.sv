// Copyright 2021 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

`include "reqrsp_interface/typedef.svh"

// Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>

/// Cut all combinatorial paths through the `reqrsp` interface.
module reqrsp_cut #(
    /// Address width of the interface.
    parameter int unsigned AddrWidth = 0,
    /// Data width of the interface.
    parameter int unsigned DataWidth = 0,
    /// Request type.
    parameter type req_t             = logic,
    /// Response type.
    parameter type rsp_t             = logic,
    /// Bypass request channel.
    parameter bit  BypassReq         = 0,
    /// Bypass Response channel.
    parameter bit  BypassRsp         = 0
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  req_t slv_req_i,
    output rsp_t slv_rsp_o,
    output req_t mst_req_o,
    input  rsp_t mst_rsp_i
);

  typedef logic [AddrWidth-1:0] addr_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [DataWidth/8-1:0] strb_t;

  `REQRSP_TYPEDEF_ALL(reqrsp, addr_t, data_t, strb_t)

  spill_register #(
    .T (reqrsp_req_chan_t),
    .Bypass ( BypassReq )
  ) i_spill_register_q (
    .clk_i,
    .rst_ni,
    .valid_i (slv_req_i.q_valid) ,
    .ready_o (slv_rsp_o.q_ready) ,
    .data_i (slv_req_i.q),
    .valid_o (mst_req_o.q_valid),
    .ready_i (mst_rsp_i.q_ready),
    .data_o (mst_req_o.q)
  );

  spill_register #(
    .T (reqrsp_rsp_chan_t),
    .Bypass ( BypassRsp )
  ) i_spill_register_p (
    .clk_i,
    .rst_ni,
    .valid_i (mst_rsp_i.p_valid) ,
    .ready_o (mst_req_o.p_ready) ,
    .data_i (mst_rsp_i.p),
    .valid_o (slv_rsp_o.p_valid),
    .ready_i (slv_req_i.p_ready),
    .data_o (slv_rsp_o.p)
  );

endmodule


`include "reqrsp_interface/typedef.svh"
`include "reqrsp_interface/assign.svh"

module reqrsp_cut_intf #(
    /// Address width of the interface.
    parameter int unsigned AddrWidth = 0,
    /// Data width of the interface.
    parameter int unsigned DataWidth = 0,
    /// Bypass request channel.
    parameter bit  BypassReq         = 0,
    /// Bypass Response channel.
    parameter bit  BypassRsp         = 0
) (
    input logic clk_i,
    input logic rst_ni,
    REQRSP_BUS  slv,
    REQRSP_BUS  mst
);

  typedef logic [AddrWidth-1:0] addr_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [DataWidth/8-1:0] strb_t;

  `REQRSP_TYPEDEF_ALL(reqrsp, addr_t, data_t, strb_t)

  reqrsp_req_t reqrsp_slv_req, reqrsp_mst_req;
  reqrsp_rsp_t reqrsp_slv_rsp, reqrsp_mst_rsp;

  reqrsp_cut #(
    .AddrWidth (AddrWidth),
    .DataWidth (DataWidth),
    .req_t (reqrsp_req_t),
    .rsp_t (reqrsp_rsp_t),
    .BypassReq (BypassReq),
    .BypassRsp (BypassRsp)
  ) i_reqrsp_cut (
    .clk_i,
    .rst_ni,
    .slv_req_i (reqrsp_slv_req),
    .slv_rsp_o (reqrsp_slv_rsp),
    .mst_req_o (reqrsp_mst_req),
    .mst_rsp_i (reqrsp_mst_rsp)
  );

  `REQRSP_ASSIGN_TO_REQ(reqrsp_slv_req, slv)
  `REQRSP_ASSIGN_FROM_RESP(slv, reqrsp_slv_rsp)

  `REQRSP_ASSIGN_FROM_REQ(mst, reqrsp_mst_req)
  `REQRSP_ASSIGN_TO_RESP(reqrsp_mst_rsp, mst)

endmodule
