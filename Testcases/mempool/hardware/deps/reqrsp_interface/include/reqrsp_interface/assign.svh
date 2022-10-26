// Copyright 2020 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>
// Author: Fabian Schuiki <fschuiki@iis.ee.ethz.ch>

// Macros to assign reqrsp Interfaces and Structs

`ifndef REQRSP_ASSIGN_SVH_
`define REQRSP_ASSIGN_SVH_

// Assign an reqrsp handshake.
`define REQRSP_ASSIGN_VALID(__opt_as, __dst, __src, __chan) \
  __opt_as ``__dst``.``__chan``_valid   = ``__src``.``__chan``_valid;
`define REQRSP_ASSIGN_READY(__opt_as, __dst, __src, __chan) \
  __opt_as ``__dst``.``__chan``_ready   = ``__src``.``__chan``_ready;

`define REQRSP_ASSIGN_HANDSHAKE(__opt_as, __dst, __src, __chan) \
  `REQRSP_ASSIGN_VALID(__opt_as, __dst, __src, __chan)          \
  `REQRSP_ASSIGN_READY(__opt_as, __src, __dst, __chan)

////////////////////////////////////////////////////////////////////////////////////////////////////
// Assigning one REQRSP interface to another, as if you would do `assign slv =
// mst;`
//
// The channel assignments `REQRSP_ASSIGN_XX(dst, src)` assign all payload and
// the valid signal of the `XX` channel from the `src` to the `dst` interface
// and they assign the ready signal from the `src` to the `dst` interface. The
// interface assignment `REQRSP_ASSIGN(dst, src)` assigns all channels including
// handshakes as if `src` was the master of `dst`.
//
// Usage Example: `REQRSP_ASSIGN(slv, mst) `REQRSP_ASSIGN_Q(dst, src, aw)
// `REQRSP_ASSIGN_P(dst, src)
`define REQRSP_ASSIGN_Q_CHAN(__opt_as, dst, src, __sep_dst, __sep_src) \
  __opt_as dst.q``__sep_dst``addr  = src.q``__sep_src``addr;           \
  __opt_as dst.q``__sep_dst``write = src.q``__sep_src``write;          \
  __opt_as dst.q``__sep_dst``amo   = src.q``__sep_src``amo;            \
  __opt_as dst.q``__sep_dst``data  = src.q``__sep_src``data;           \
  __opt_as dst.q``__sep_dst``strb  = src.q``__sep_src``strb;           \
  __opt_as dst.q``__sep_dst``size  = src.q``__sep_src``size;
`define REQRSP_ASSIGN_P_CHAN(__opt_as, dst, src, __sep_dst, __sep_src) \
  __opt_as dst.p``__sep_dst``data   = src.p``__sep_src``data;          \
  __opt_as dst.p``__sep_dst``error   = src.p``__sep_src``error;
`define REQRSP_ASSIGN(slv, mst)                 \
  `REQRSP_ASSIGN_Q_CHAN(assign, slv, mst, _, _) \
  `REQRSP_ASSIGN_HANDSHAKE(assign, slv, mst, q) \
  `REQRSP_ASSIGN_P_CHAN(assign, mst, slv, _, _) \
  `REQRSP_ASSIGN_HANDSHAKE(assign, mst, slv, p)
////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////
// Assigning an interface from channel or request/response structs outside a
// process.
//
// The request macro `REQRSP_ASSIGN_FROM_REQ(reqrsp_if, req_struct)` assigns the
// request channel and the request-side handshake signals of the `reqrsp_if`
// interface from the signals in `req_struct`. The response macro
// `REQRSP_ASSIGN_FROM_RESP(reqrsp_if, resp_struct)` assigns the response
// channel and the response-side handshake signals of the `reqrsp_if` interface
// from the signals in `resp_struct`.
//
// Usage Example:
// `REQRSP_ASSIGN_FROM_REQ(my_if, my_req_struct)
`define REQRSP_ASSIGN_FROM_REQ(reqrsp_if, req_struct)        \
  `REQRSP_ASSIGN_VALID(assign, reqrsp_if, req_struct, q)     \
  `REQRSP_ASSIGN_Q_CHAN(assign, reqrsp_if, req_struct, _, .) \
  `REQRSP_ASSIGN_READY(assign, reqrsp_if, req_struct, p)

`define REQRSP_ASSIGN_FROM_RESP(reqrsp_if, resp_struct)       \
  `REQRSP_ASSIGN_READY(assign, reqrsp_if, resp_struct, q)     \
  `REQRSP_ASSIGN_P_CHAN(assign, reqrsp_if, resp_struct, _, .) \
  `REQRSP_ASSIGN_VALID(assign, reqrsp_if, resp_struct, p)

////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////////////////////
// Assigning channel or request/response structs from an interface outside a
// process.
//
// The request macro `REQRSP_ASSIGN_TO_REQ(reqrsp_if, req_struct)` assigns all
// signals of `req_struct` payload and request-side handshake signals to the
// signals in the `reqrsp_if` interface. The response macro
// `REQRSP_ASSIGN_TO_RESP(reqrsp_if, resp_struct)` assigns all signals of
// `resp_struct` payload and response-side handshake signals to the signals in
// the `reqrsp_if` interface.
//
// Usage Example:
// `REQRSP_ASSIGN_TO_REQ(my_req_struct, my_if)
`define REQRSP_ASSIGN_TO_REQ(req_struct, reqrsp_if)          \
  `REQRSP_ASSIGN_VALID(assign, req_struct, reqrsp_if, q)     \
  `REQRSP_ASSIGN_Q_CHAN(assign, req_struct, reqrsp_if, ., _) \
  `REQRSP_ASSIGN_READY(assign, req_struct, reqrsp_if, p)

`define REQRSP_ASSIGN_TO_RESP(resp_struct, reqrsp_if)         \
  `REQRSP_ASSIGN_READY(assign, resp_struct, reqrsp_if, q)     \
  `REQRSP_ASSIGN_P_CHAN(assign, resp_struct, reqrsp_if, ., _) \
  `REQRSP_ASSIGN_VALID(assign, resp_struct, reqrsp_if, p)
////////////////////////////////////////////////////////////////////////////////////////////////////

`endif
