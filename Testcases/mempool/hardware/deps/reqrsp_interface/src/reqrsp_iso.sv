// Copyright 2021 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

`include "reqrsp_interface/typedef.svh"

// Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>

/// Decouple `src` and `dst` side using an isochronous clock-domain crossing.
/// See `common_cells/isochronous_spill_register` for further detail on the
/// clock requirements.
module reqrsp_iso #(
    /// Address width of the interface.
    parameter int unsigned AddrWidth = 0,
    /// Data width of the interface.
    parameter int unsigned DataWidth = 0,
    /// Request type.
    parameter type req_t             = logic,
    /// Response type.
    parameter type rsp_t             = logic,
    /// Bypass.
    parameter bit  BypassReq         = 0,
    parameter bit  BypassRsp         = 0
) (
    /// Clock of source clock domain.
    input  logic src_clk_i,
    /// Active low async reset in source domain.
    input  logic src_rst_ni,
    /// Source request data.
    input  req_t src_req_i,
    /// Source response data.
    output rsp_t src_rsp_o,
    /// Clock of destination clock domain.
    input  logic dst_clk_i,
    /// Active low async reset in destination domain.
    input  logic dst_rst_ni,
    /// Destination request data.
    output req_t dst_req_o,
    /// Destination response data.
    input  rsp_t dst_rsp_i
);

  typedef logic [AddrWidth-1:0] addr_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [DataWidth/8-1:0] strb_t;

  `REQRSP_TYPEDEF_ALL(reqrsp, addr_t, data_t, strb_t)

  isochronous_spill_register #(
    .T (reqrsp_req_chan_t),
    .Bypass (BypassReq)
  ) i_isochronous_spill_register_q (
    .src_clk_i (src_clk_i),
    .src_rst_ni (src_rst_ni),
    .src_valid_i (src_req_i.q_valid) ,
    .src_ready_o (src_rsp_o.q_ready) ,
    .src_data_i (src_req_i.q),
    .dst_clk_i (dst_clk_i),
    .dst_rst_ni (dst_rst_ni),
    .dst_valid_o (dst_req_o.q_valid),
    .dst_ready_i (dst_rsp_i.q_ready),
    .dst_data_o (dst_req_o.q)
  );

  isochronous_spill_register #(
    .T (reqrsp_rsp_chan_t),
    .Bypass (BypassRsp)
  ) i_isochronous_spill_register_p (
    .src_clk_i (dst_clk_i),
    .src_rst_ni (dst_rst_ni),
    .src_valid_i (dst_rsp_i.p_valid) ,
    .src_ready_o (dst_req_o.p_ready) ,
    .src_data_i (dst_rsp_i.p),
    .dst_clk_i (src_clk_i),
    .dst_rst_ni (src_rst_ni),
    .dst_valid_o (src_rsp_o.p_valid),
    .dst_ready_i (src_req_i.p_ready),
    .dst_data_o (src_rsp_o.p)
  );

endmodule

`include "reqrsp_interface/typedef.svh"
`include "reqrsp_interface/assign.svh"

/// Interface wrapper for `reqrsp_iso`.
module reqrsp_iso_intf #(
    /// Address width of the interface.
    parameter int unsigned AddrWidth = 0,
    /// Data width of the interface.
    parameter int unsigned DataWidth = 0,
    /// Bypass.
    parameter bit  BypassReq         = 0,
    parameter bit  BypassRsp         = 0
) (
    /// Clock of source clock domain.
    input  logic src_clk_i,
    /// Active low async reset in source domain.
    input  logic src_rst_ni,
    /// Source interface.
    REQRSP_BUS   src,
    /// Clock of destination clock domain.
    input  logic dst_clk_i,
    /// Active low async reset in destination domain.
    input  logic dst_rst_ni,
    /// Destination interface.
    REQRSP_BUS   dst
);

  typedef logic [AddrWidth-1:0] addr_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [DataWidth/8-1:0] strb_t;

  `REQRSP_TYPEDEF_ALL(reqrsp, addr_t, data_t, strb_t)

  reqrsp_req_t reqrsp_src_req, reqrsp_dst_req;
  reqrsp_rsp_t reqrsp_src_rsp, reqrsp_dst_rsp;

  reqrsp_iso #(
    .AddrWidth (AddrWidth),
    .DataWidth (DataWidth),
    .req_t     (reqrsp_req_t),
    .rsp_t     (reqrsp_rsp_t),
    .BypassReq (BypassReq),
    .BypassRsp (BypassRsp)
  ) i_reqrsp_iso (
    .src_clk_i,
    .src_rst_ni,
    .src_req_i (reqrsp_src_req),
    .src_rsp_o (reqrsp_src_rsp),
    .dst_clk_i,
    .dst_rst_ni,
    .dst_req_o (reqrsp_dst_req),
    .dst_rsp_i (reqrsp_dst_rsp)
  );

  `REQRSP_ASSIGN_TO_REQ(reqrsp_src_req, src)
  `REQRSP_ASSIGN_FROM_RESP(src, reqrsp_src_rsp)

  `REQRSP_ASSIGN_FROM_REQ(dst, reqrsp_dst_req)
  `REQRSP_ASSIGN_TO_RESP(reqrsp_dst_rsp, dst)

endmodule
