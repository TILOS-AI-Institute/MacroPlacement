// Copyright 2020 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
// - Florian Zaruba <zarubaf@iis.ee.ethz.ch>
// - Andreas Kurth <akurth@iis.ee.ethz.ch>
// - Wolfgang Roenninger <wroennin@iis.ee.ethz.ch>

`include "common_cells/registers.svh"
`include "common_cells/assertions.svh"

/// AXI4+ATOP slave module which translates AXI bursts to reqrsp. This module
/// fully supports the Atomic + LR/SC semantic of the reqrsp interface.
///
/// ## Complexity
///
/// The complexity of the module increases lineraly with `BufDepth` as all
/// requests need to be saved for proper response routing and error condition
/// generation.
///
/// ## Note
///
/// > This work is largely (99.5%) based on `axi_to_mem` found in the AXI
/// > repository. Eventually these two modules can be merged (translating from AXI
/// > to reqrsp to mem).
module axi_to_reqrsp #(
  /// AXI4+ATOP request type. See `include/axi/typedef.svh`.
  parameter type         axi_req_t  = logic,
  /// AXI4+ATOP response type. See `include/axi/typedef.svh`.
  parameter type         axi_rsp_t = logic,
  /// Address width, has to be less or equal than the width off the AXI address
  /// field. Determines the width of `mem_addr_o`. Has to be wide enough to emit
  /// the memory region which should be accessible.
  parameter int unsigned AddrWidth  = 0,
  parameter int unsigned DataWidth  = 0,
  /// AXI4+ATOP ID width.
  parameter int unsigned IdWidth    = 0,
  /// Depth of memory response buffer. This should be equal to the downstream
  /// response latency.
  parameter int unsigned BufDepth   = 1,
  /// Reqrsp request channel type.
  parameter type         reqrsp_req_t = logic,
  /// Reqrsp response channel type.
  parameter type         reqrsp_rsp_t = logic
) (
  /// Clock input.
  input  logic                           clk_i,
  /// Asynchronous reset, active low.
  input  logic                           rst_ni,
  /// The unit is busy handling an AXI4+ATOP request.
  output logic                           busy_o,
  /// AXI4+ATOP slave port, request input.
  input  axi_req_t                       axi_req_i,
  /// AXI4+ATOP slave port, response output.
  output axi_rsp_t                       axi_rsp_o,
  /// Reqrsp request channel.
  output reqrsp_req_t                    reqrsp_req_o,
  /// Reqrsp respone channel.
  input  reqrsp_rsp_t                    reqrsp_rsp_i
);

  localparam int unsigned StrbWidth = DataWidth/8;

  typedef logic [AddrWidth-1:0]   addr_t;
  typedef logic [DataWidth-1:0]   data_t;
  typedef logic [IdWidth-1:0]     axi_id_t;

  typedef struct packed {
    addr_t          addr;
    axi_pkg::atop_t atop;
    axi_id_t        id;
    logic           last;
    axi_pkg::qos_t  qos;
    axi_pkg::size_t size;
    logic           write;
    logic           lock;
  } meta_t;

  reqrsp_pkg::amo_op_e amo;
  data_t data;
  axi_pkg::resp_t resp;
  axi_pkg::len_t  r_cnt_d,        r_cnt_q,
                  w_cnt_d,        w_cnt_q;
  logic           arb_valid,      arb_ready,
                  rd_valid,       rd_ready,
                  wr_valid,       wr_ready,
                  sel_b,          sel_buf_b,
                  sel_r,          sel_buf_r,
                  sel_valid,      sel_ready,
                  sel_buf_valid,  sel_buf_ready,
                  sel_lock_d,     sel_lock_q,
                  meta_valid,     meta_ready,
                  meta_buf_valid, meta_buf_ready,
                  meta_sel_d,     meta_sel_q;
  meta_t          rd_meta,
                  rd_meta_d,      rd_meta_q,
                  wr_meta,
                  wr_meta_d,      wr_meta_q,
                  meta,           meta_buf;

  assign busy_o = axi_req_i.aw_valid | axi_req_i.ar_valid | axi_req_i.w_valid |
                    axi_rsp_o.b_valid | axi_rsp_o.r_valid |
                    (r_cnt_q > 0) | (w_cnt_q > 0);

  // Handle reads.
  always_comb begin
    // Default assignments
    axi_rsp_o.ar_ready = 1'b0;
    rd_meta_d           = rd_meta_q;
    rd_meta             = '{default: '0};
    rd_valid            = 1'b0;
    r_cnt_d             = r_cnt_q;
    // Handle R burst in progress.
    if (r_cnt_q > '0) begin
      rd_meta_d.last = (r_cnt_q == 8'd1);
      rd_meta        = rd_meta_d;
      rd_meta.addr   = rd_meta_q.addr + axi_pkg::num_bytes(rd_meta_q.size);
      rd_valid       = 1'b1;
      if (rd_ready) begin
        r_cnt_d--;
        rd_meta_d.addr = rd_meta.addr;
      end
    // Handle new AR if there is one.
    end else if (axi_req_i.ar_valid) begin
      rd_meta_d = '{
        addr:  addr_t'(axi_pkg::aligned_addr(axi_req_i.ar.addr, axi_req_i.ar.size)),
        atop:  '0,
        id:    axi_req_i.ar.id,
        last:  (axi_req_i.ar.len == '0),
        qos:   axi_req_i.ar.qos,
        size:  axi_req_i.ar.size,
        write: 1'b0,
        lock: axi_req_i.ar.lock
      };
      rd_meta      = rd_meta_d;
      rd_meta.addr = addr_t'(axi_req_i.ar.addr);
      rd_valid     = 1'b1;
      if (rd_ready) begin
        r_cnt_d             = axi_req_i.ar.len;
        axi_rsp_o.ar_ready = 1'b1;
      end
    end
  end

  // Handle writes.
  always_comb begin
    // Default assignments
    axi_rsp_o.aw_ready = 1'b0;
    axi_rsp_o.w_ready  = 1'b0;
    wr_meta_d           = wr_meta_q;
    wr_meta             = '{default: '0};
    wr_valid            = 1'b0;
    w_cnt_d             = w_cnt_q;
    // Handle W bursts in progress.
    if (w_cnt_q > '0) begin
      wr_meta_d.last = (w_cnt_q == 8'd1);
      wr_meta        = wr_meta_d;
      wr_meta.addr   = wr_meta_q.addr + axi_pkg::num_bytes(wr_meta_q.size);
      if (axi_req_i.w_valid) begin
        wr_valid = 1'b1;
        if (wr_ready) begin
          axi_rsp_o.w_ready = 1'b1;
          w_cnt_d--;
          wr_meta_d.addr = wr_meta.addr;
        end
      end
    // Handle new AW if there is one.
    end else if (axi_req_i.aw_valid && axi_req_i.w_valid) begin
      wr_meta_d = '{
        addr:   addr_t'(axi_pkg::aligned_addr(axi_req_i.aw.addr, axi_req_i.aw.size)),
        atop:   axi_req_i.aw.atop,
        id:     axi_req_i.aw.id,
        last:   (axi_req_i.aw.len == '0),
        qos:    axi_req_i.aw.qos,
        size:   axi_req_i.aw.size,
        write:  1'b1,
        lock:   axi_req_i.aw.lock
      };
      wr_meta = wr_meta_d;
      wr_meta.addr = addr_t'(axi_req_i.aw.addr);
      wr_valid = 1'b1;
      if (wr_ready) begin
        w_cnt_d = axi_req_i.aw.len;
        axi_rsp_o.aw_ready = 1'b1;
        axi_rsp_o.w_ready = 1'b1;
      end
    end
  end

  // Arbitrate between reads and writes.
  stream_mux #(
    .DATA_T ( meta_t ),
    .N_INP  ( 32'd2  )
  ) i_ax_mux (
    .inp_data_i   ({wr_meta,  rd_meta }),
    .inp_valid_i  ({wr_valid, rd_valid}),
    .inp_ready_o  ({wr_ready, rd_ready}),
    .inp_sel_i    ( meta_sel_d         ),
    .oup_data_o   ( meta               ),
    .oup_valid_o  ( arb_valid          ),
    .oup_ready_i  ( arb_ready          )
  );
  always_comb begin
    meta_sel_d = meta_sel_q;
    sel_lock_d = sel_lock_q;
    if (sel_lock_q) begin
      meta_sel_d = meta_sel_q;
      if (arb_valid && arb_ready) begin
        sel_lock_d = 1'b0;
      end
    end else begin
      if (wr_valid ^ rd_valid) begin
        // If either write or read is valid but not both, select the valid one.
        meta_sel_d = wr_valid;
      end else if (wr_valid && rd_valid) begin
        // If both write and read are valid, decide according to QoS then burst properties.
        // Prioritize higher QoS.
        if (wr_meta.qos > rd_meta.qos) begin
          meta_sel_d = 1'b1;
        end else if (rd_meta.qos > wr_meta.qos) begin
          meta_sel_d = 1'b0;
        // Decide requests with identical QoS.
        end else if (wr_meta.qos == rd_meta.qos) begin
          // 1. Prioritize individual writes over read bursts.
          // Rationale: Read bursts can be interleaved on AXI but write bursts cannot.
          if (wr_meta.last && !rd_meta.last) begin
            meta_sel_d = 1'b1;
          // 2. Prioritize ongoing burst.
          // Rationale: Stalled bursts create back-pressure or require costly buffers.
          end else if (w_cnt_q > '0) begin
            meta_sel_d = 1'b1;
          end else if (r_cnt_q > '0) begin
            meta_sel_d = 1'b0;
          // 3. Otherwise arbitrate round robin to prevent starvation.
          end else begin
            meta_sel_d = ~meta_sel_q;
          end
        end
      end
      // Lock arbitration if valid but not yet ready.
      if (arb_valid && !arb_ready) begin
        sel_lock_d = 1'b1;
      end
    end
  end

  // Fork arbitrated stream to meta data, memory requests, and R/B channel selection.
  stream_fork #(
    .N_OUP ( 32'd3 )
  ) i_fork (
    .clk_i,
    .rst_ni,
    .valid_i ( arb_valid                            ),
    .ready_o ( arb_ready                            ),
    .valid_o ({sel_valid, meta_valid, reqrsp_req_o.q_valid}),
    .ready_i ({sel_ready, meta_ready, reqrsp_rsp_i.q_ready})
  );

  assign sel_b = meta.write & meta.last;
  assign sel_r = ~meta.write | meta.atop[5];

  stream_fifo #(
    .FALL_THROUGH ( 1'b1             ),
    .DEPTH        ( 32'd1 + BufDepth ),
    .T            ( logic[1:0]       )
  ) i_sel_buf (
    .clk_i,
    .rst_ni,
    .flush_i    ( 1'b0                    ),
    .testmode_i ( 1'b0                    ),
    .data_i     ({sel_b,        sel_r    }),
    .valid_i    ( sel_valid               ),
    .ready_o    ( sel_ready               ),
    .data_o     ({sel_buf_b,    sel_buf_r}),
    .valid_o    ( sel_buf_valid           ),
    .ready_i    ( sel_buf_ready           ),
    .usage_o    ( /* unused */            )
  );

  stream_fifo #(
    .FALL_THROUGH ( 1'b1             ),
    .DEPTH        ( 32'd1 + BufDepth ),
    .T            ( meta_t           )
  ) i_meta_buf (
    .clk_i,
    .rst_ni,
    .flush_i    ( 1'b0           ),
    .testmode_i ( 1'b0           ),
    .data_i     ( meta           ),
    .valid_i    ( meta_valid     ),
    .ready_o    ( meta_ready     ),
    .data_o     ( meta_buf       ),
    .valid_o    ( meta_buf_valid ),
    .ready_i    ( meta_buf_ready ),
    .usage_o    ( /* unused */   )
  );

  assign reqrsp_req_o.q = '{
    addr: meta.addr,
    write: meta.write & (amo == reqrsp_pkg::AMONone),
    amo: amo,
    // Silence those channels in case of a read.
    data: data & {DataWidth{meta.write}},
    strb: axi_req_i.w.strb & {StrbWidth{meta.write}},
    size: meta.size
  };

  always_comb begin
    amo = reqrsp_pkg::from_axi_amo(meta.atop);
    data = axi_req_i.w.data;
    // The `AMOAnd` has a slightly different semantic to the AXI `Set`.
    if (amo == reqrsp_pkg::AMOAnd) data = ~axi_req_i.w.data;
    // Check wether this meant to be an exclusive access.
    if (meta.lock) begin
      if (meta.write) amo = reqrsp_pkg::AMOSC;
      else amo = reqrsp_pkg::AMOLR;
    end
  end

  // Join memory read data and meta data stream.
  logic mem_join_valid, mem_join_ready;
  stream_join #(
    .N_INP ( 32'd2 )
  ) i_join (
    .inp_valid_i  ({reqrsp_rsp_i.p_valid, meta_buf_valid}),
    .inp_ready_o  ({reqrsp_req_o.p_ready, meta_buf_ready}),
    .oup_valid_o  ( mem_join_valid                 ),
    .oup_ready_i  ( mem_join_ready                 )
  );

  // Dynamically fork the joined stream to B and R channels.
  stream_fork_dynamic #(
    .N_OUP ( 32'd2 )
  ) i_fork_dynamic (
    .clk_i,
    .rst_ni,
    .valid_i      ( mem_join_valid                         ),
    .ready_o      ( mem_join_ready                         ),
    .sel_i        ({sel_buf_b,          sel_buf_r         }),
    .sel_valid_i  ( sel_buf_valid                          ),
    .sel_ready_o  ( sel_buf_ready                          ),
    .valid_o      ({axi_rsp_o.b_valid, axi_rsp_o.r_valid}),
    .ready_i      ({axi_req_i.b_ready,  axi_req_i.r_ready })
  );

  // Compose error flag.
  always_comb begin
    resp = axi_pkg::RESP_OKAY;
    resp[1] = reqrsp_rsp_i.p.error;
    // The success is encoded in the LSB.
    if (meta_buf.lock) begin
      resp[0] = reqrsp_rsp_i.p.data[0];
    end
  end

  // Compose B responses.
  assign axi_rsp_o.b = '{
    id:   meta_buf.id,
    resp: resp,
    user: '0
  };

  // Compose R responses.
  assign axi_rsp_o.r = '{
    data: reqrsp_rsp_i.p.data,
    id:   meta_buf.id,
    last: meta_buf.last,
    resp: resp,
    user: '0
  };

  // Registers
  `FFARN(meta_sel_q, meta_sel_d, 1'b0, clk_i, rst_ni)
  `FFARN(sel_lock_q, sel_lock_d, 1'b0, clk_i, rst_ni)
  `FFARN(rd_meta_q, rd_meta_d, meta_t'{default: '0}, clk_i, rst_ni)
  `FFARN(wr_meta_q, wr_meta_d, meta_t'{default: '0}, clk_i, rst_ni)
  `FFARN(r_cnt_q, r_cnt_d, '0, clk_i, rst_ni)
  `FFARN(w_cnt_q, w_cnt_d, '0, clk_i, rst_ni)

  // Assertions
  // Make sure that write is never set for AMOs.
  `ASSERT(AMOWriteEnable, reqrsp_req_o.q_valid &&
    (reqrsp_req_o.q.amo != reqrsp_pkg::AMONone) |-> !reqrsp_req_o.q.write)
  // pragma translate_off
  `ifndef VERILATOR
  default disable iff (!rst_ni);
  assume property (@(posedge clk_i)
      axi_req_i.ar_valid && !axi_rsp_o.ar_ready |=> $stable(axi_req_i.ar))
    else $error("AR must remain stable until handshake has happened!");
  assert property (@(posedge clk_i)
      axi_rsp_o.r_valid && !axi_req_i.r_ready |=> $stable(axi_rsp_o.r))
    else $error("R must remain stable until handshake has happened!");
  assume property (@(posedge clk_i)
      axi_req_i.aw_valid && !axi_rsp_o.aw_ready |=> $stable(axi_req_i.aw))
    else $error("AW must remain stable until handshake has happened!");
  assume property (@(posedge clk_i)
      axi_req_i.w_valid && !axi_rsp_o.w_ready |=> $stable(axi_req_i.w))
    else $error("W must remain stable until handshake has happened!");
  assert property (@(posedge clk_i)
      axi_rsp_o.b_valid && !axi_req_i.b_ready |=> $stable(axi_rsp_o.b))
    else $error("B must remain stable until handshake has happened!");
  assert property (@(posedge clk_i) axi_req_i.ar_valid && axi_req_i.ar.len > 0 |->
      axi_req_i.ar.burst == axi_pkg::BURST_INCR)
    else $error("Non-incrementing bursts are not supported!");
  assert property (@(posedge clk_i) axi_req_i.aw_valid && axi_req_i.aw.len > 0 |->
      axi_req_i.aw.burst == axi_pkg::BURST_INCR)
    else $error("Non-incrementing bursts are not supported!");
  assert property (@(posedge clk_i) meta_valid && meta.atop != '0 |-> meta.write)
    else $warning("Unexpected atomic operation on read.");
  `endif
  // pragma translate_on
endmodule

`include "reqrsp_interface/typedef.svh"
`include "reqrsp_interface/assign.svh"
`include "axi/typedef.svh"
`include "axi/assign.svh"

/// Interface Wrapper
module axi_to_reqrsp_intf #(
  /// AXI addr width.
  parameter int unsigned AddrWidth  = 0,
  /// AXI data width.
  parameter int unsigned DataWidth  = 0,
  /// AXI id width.
  parameter int unsigned IdWidth    = 0,
  /// AXI user wdith.
  parameter int unsigned UserWidth  = 0,
  /// Depth of memory response buffer. This should be equal to the downstream
  /// response latency.
  parameter int unsigned BufDepth   = 1
) (
  /// Clock input.
  input  logic   clk_i,
  /// Asynchronous reset, active low.
  input  logic   rst_ni,
  /// The unit is busy handling an AXI4+ATOP request.
  output logic   busy_o,
  REQRSP_BUS     reqrsp,
  AXI_BUS        axi
);

  typedef logic [AddrWidth-1:0] addr_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [DataWidth/8-1:0] strb_t;
  typedef logic [IdWidth-1:0] id_t;
  typedef logic [UserWidth-1:0] user_t;

  `REQRSP_TYPEDEF_ALL(reqrsp, addr_t, data_t, strb_t)

  `AXI_TYPEDEF_AW_CHAN_T(aw_chan_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(b_chan_t, id_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(ar_chan_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(r_chan_t, data_t, id_t, user_t)

  `AXI_TYPEDEF_REQ_T(axi_req_t, aw_chan_t, w_chan_t, ar_chan_t)
  `AXI_TYPEDEF_RESP_T(axi_rsp_t, b_chan_t, r_chan_t)

  reqrsp_req_t reqrsp_req;
  reqrsp_rsp_t reqrsp_rsp;

  axi_req_t axi_req;
  axi_rsp_t axi_rsp;

  axi_to_reqrsp #(
    .axi_req_t (axi_req_t),
    .axi_rsp_t (axi_rsp_t),
    .AddrWidth (AddrWidth),
    .DataWidth (DataWidth),
    .IdWidth (IdWidth),
    .BufDepth (BufDepth),
    .reqrsp_req_t (reqrsp_req_t),
    .reqrsp_rsp_t (reqrsp_rsp_t )
  ) i_dut (
    .clk_i,
    .rst_ni,
    .busy_o,
    .axi_req_i (axi_req),
    .axi_rsp_o (axi_rsp),
    .reqrsp_req_o (reqrsp_req),
    .reqrsp_rsp_i (reqrsp_rsp)
  );

  `REQRSP_ASSIGN_FROM_REQ(reqrsp, reqrsp_req)
  `REQRSP_ASSIGN_TO_RESP(reqrsp_rsp, reqrsp)

  `AXI_ASSIGN_TO_REQ(axi_req, axi)
  `AXI_ASSIGN_FROM_RESP(axi, axi_rsp)

endmodule
