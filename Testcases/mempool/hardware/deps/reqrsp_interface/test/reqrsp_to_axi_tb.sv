// Copyright 2020 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>

`include "reqrsp_interface/assign.svh"
`include "axi/assign.svh"

/// Testbench for the request/response TB
module reqrsp_to_axi_tb import reqrsp_pkg::*; #(
  parameter int unsigned AW = 32,
  parameter int unsigned DW = 32,
  parameter int unsigned IW = 2,
  parameter int unsigned UW = 2,
  parameter int unsigned NrDirectedReads = 2000,
  parameter int unsigned NrDirectedWrites = 2000,
  parameter int unsigned NrRandomTransactions = 4000
);
  localparam time ClkPeriod = 10ns;
  localparam time ApplTime =  2ns;
  localparam time TestTime =  8ns;

  logic  clk, rst_n;

  typedef logic [AW-1:0] addr_t;
  typedef logic [DW-1:0] data_t;
  typedef logic [DW/8-1:0] strb_t;
  typedef logic [IW-1:0] id_t;
  typedef logic [UW-1:0] user_t;

  // interfaces
  REQRSP_BUS #(
    .ADDR_WIDTH ( AW ),
    .DATA_WIDTH ( DW )
  ) master ();

  REQRSP_BUS_DV #(
    .ADDR_WIDTH ( AW ),
    .DATA_WIDTH ( DW )
  ) master_dv (clk);

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AW ),
    .AXI_DATA_WIDTH ( DW ),
    .AXI_ID_WIDTH   ( IW  ),
    .AXI_USER_WIDTH ( UW )
  ) slave ();

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( AW ),
    .AXI_DATA_WIDTH ( DW ),
    .AXI_ID_WIDTH   ( IW  ),
    .AXI_USER_WIDTH ( UW )
  ) slave_dv (clk);

  reqrsp_to_axi_intf #(
    .AxiIdWidth (IW),
    .AddrWidth (AW),
    .DataWidth (DW),
    .AxiUserWidth (UW)
  ) i_reqrsp_to_axi (
    .clk_i (clk),
    .rst_ni (rst_n),
    .reqrsp (master),
    .axi (slave)
  );

  `REQRSP_ASSIGN(master, master_dv)
  `AXI_ASSIGN(slave_dv, slave)
  // ----------------
  // Clock generation
  // ----------------
  initial begin
    rst_n = 0;
    repeat (3) begin
      #(ClkPeriod/2) clk = 0;
      #(ClkPeriod/2) clk = 1;
    end
    rst_n = 1;
    forever begin
      #(ClkPeriod/2) clk = 0;
      #(ClkPeriod/2) clk = 1;
    end
  end

  // -------
  // Monitor
  // -------
  typedef reqrsp_test::reqrsp_monitor #(
    // Reqrsp bus interface paramaters;
    .AW ( AW ),
    .DW ( DW ),
    // Stimuli application and test time
    .TA ( ApplTime ),
    .TT ( TestTime )
  ) reqrsp_monitor_t;

  reqrsp_monitor_t reqrsp_monitor = new (master_dv);
  // Reqrsp Monitor.
  initial begin
    @(posedge rst_n);
    reqrsp_monitor.monitor();
  end

  // AXI Monitor
  typedef axi_test::axi_monitor #(
    // AXI interface parameters
    .AW ( AW ),
    .DW ( DW ),
    .IW ( IW ),
    .UW ( UW ),
    // Stimuli application and test time
    .TT ( TestTime )
  ) axi_monitor_t;

  axi_monitor_t axi_monitor = new (slave_dv);
  initial begin
    @(posedge rst_n);
    axi_monitor.monitor();
  end

  // ----------
  // Scoreboard
  // ----------
  initial begin
    forever begin
      automatic reqrsp_test::req_t req;
      automatic reqrsp_test::rsp_t rsp;
      automatic axi_monitor_t::ax_beat_t ax;
      automatic axi_monitor_t::b_beat_t b;
      automatic axi_monitor_t::r_beat_t r;
      automatic axi_monitor_t::w_beat_t w;
      reqrsp_monitor.req_mbx.get(req);
      // check fields match
      // Writes and atomics.
      // For each write the reqrsp bus we want to see a `aw` beat.
      if (req.write) begin
        axi_monitor.aw_mbx.get(ax);
        axi_monitor.w_mbx.get(w);

        if (req.amo != AMOAnd) begin
          assert(w.w_data == req.data)
            else $error("[Data Check] Expecting `%b` got `%b`", w.w_data, req.data);
        end else begin
          assert(w.w_data == (~req.data))
            else $error("[AMOAnd] Expecting `%b` got `%b`", w.w_data, req.data);
        end
        // Check byte strobe.
        assert(w.w_strb == req.strb);
        // Check exclusive access.
        assert(req.amo != AMOSC || ax.ax_lock == 1);
        axi_monitor.b_mbx.get(b);
        reqrsp_monitor.rsp_mbx.get(rsp);

        // Check error flag.
        assert(rsp.error == b.b_resp[1])
          else $error("[Write Resp] Expecting `%h` got `%h`.", b.b_resp[1], rsp.error);
        // Check whether we are expecting an additional R response.
        if (is_amo(req.amo)) begin
          // Check that AMOs were correctly translated.
          assert(ax.ax_atop == to_axi_amo(req.amo))
            else $error("Expecting `%b` got `%b`", to_axi_amo(req.amo), ax.ax_atop);
          axi_monitor.r_mbx.get(r);
          assert(rsp.data == r.r_data)
            else $error("[Write Amo] Expecting `%h` got `%h`.", r.r_data, rsp.data);
        end
      // Reads
      end else begin
        axi_monitor.ar_mbx.get(ax);
        axi_monitor.r_mbx.get(r);

        // Check exclusive access.
        assert(req.amo != AMOLR || ax.ax_lock == 1);
        reqrsp_monitor.rsp_mbx.get(rsp);

        // Check read data access.
        assert(rsp.data == r.r_data)
          else $error("Expecting `%h` got `%h` on read data.", r.r_data, rsp.data);
        // Check error flag.
        assert(rsp.error == r.r_resp[1])
          else $error("[Read Response] Expecting `%h` got `%h`.", r.r_resp[1], rsp.error);
      end
      assert(ax.ax_len == 0)
        else $fatal("Testbench does not support bursts.");
      assert(ax.ax_size == req.size);
      assert(req.addr == ax.ax_addr)
        else $error("Address does noit match. Expected `%h` got `%h`.", req.addr, ax.ax_addr);
    end
  end

  // Check that all transcations ceased.
  final begin
    assert(axi_monitor.aw_mbx.num() == 0);
    assert(axi_monitor.w_mbx.num() == 0);
    assert(axi_monitor.b_mbx.num() == 0);
    assert(axi_monitor.ar_mbx.num() == 0);
    assert(axi_monitor.r_mbx.num() == 0);
  end

  // ------
  // Driver
  // ------
  // AXI Driver
  typedef axi_test::axi_rand_slave #(
    // AXI interface parameters
    .AW ( AW ),
    .DW ( DW ),
    .IW ( IW ),
    .UW ( UW ),
    // Stimuli application and test time
    .TA ( ApplTime ),
    .TT ( TestTime ),
    .RAND_RESP (1),
    .AX_MIN_WAIT_CYCLES (0),
    .AX_MAX_WAIT_CYCLES (20)
  ) rand_axi_slave_t;

  rand_axi_slave_t axi_rand_slave = new (slave_dv);

  typedef reqrsp_test::rand_reqrsp_master #(
    // Reqrsp bus interface paramaters;
    .AW ( AW ),
    .DW ( DW ),
    // Stimuli application and test time
    .TA ( ApplTime ),
    .TT ( TestTime )
  ) reqrsp_driver_t;

  reqrsp_driver_t rand_reqrsp_master = new (master_dv);

  // AXI side.
  initial begin
    axi_rand_slave.reset();
    @(posedge rst_n);
    axi_rand_slave.run();
  end

  // Reqrsp master side.
  initial begin
    rand_reqrsp_master.reset();
    @(posedge rst_n);
    // Directed testing.
    // 1. Directed testing (read).
    fork
      repeat(NrDirectedReads) begin
        automatic reqrsp_test::req_t req = new;
        assert(req.randomize() with { amo == AMONone; write == 0;});
        rand_reqrsp_master.drv.send_req(req);
      end
      repeat (NrDirectedReads) begin
        automatic reqrsp_test::rsp_t rsp;
        rand_reqrsp_master.drv.recv_rsp(rsp);
      end
    join
    // 2. Directed testing (write).
    fork
      repeat(NrDirectedWrites) begin
        automatic reqrsp_test::req_t req = new;
        assert(req.randomize() with { amo == AMONone; write == 1;});
        rand_reqrsp_master.drv.send_req(req);
      end
      repeat (NrDirectedWrites) begin
        automatic reqrsp_test::rsp_t rsp;
        rand_reqrsp_master.drv.recv_rsp(rsp);
      end
    join
    // 3. Random testing.
    rand_reqrsp_master.run(NrRandomTransactions);
    $info("Rand reqrsp master finished. Waiting for completion.");
    // Wait until req/rsp mailboxes are empty.
    while (reqrsp_monitor.req_mbx.num() > 0 || reqrsp_monitor.rsp_mbx.num() > 0) begin
      @(posedge clk);
    end
    $info("Finished Testing %d vectors", NrRandomTransactions + NrDirectedReads + NrDirectedWrites);
    $finish;
  end

endmodule
