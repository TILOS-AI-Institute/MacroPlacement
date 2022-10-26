// Copyright 2020 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>

`include "reqrsp_interface/assign.svh"

/// Testbench for all idempotent modules i.e., module which do not alter data
/// but only the handshaking.
module reqrsp_idempotent_tb import reqrsp_pkg::*; #(
  parameter int unsigned AW = 32,
  parameter int unsigned DW = 32,
  parameter int unsigned NrRandomTransactions = 1000,
  /// Test Isochronous spill register.
  parameter bit Iso = 1,
  /// Test normal spill register.
  parameter bit Cut = 0
);
  localparam time ClkPeriod = 10ns;
  localparam time ApplTime =  2ns;
  localparam time TestTime =  8ns;

  logic  clk, rst_n;

  REQRSP_BUS #(
    .ADDR_WIDTH ( AW ),
    .DATA_WIDTH ( DW )
  ) master ();

  REQRSP_BUS_DV #(
    .ADDR_WIDTH ( AW ),
    .DATA_WIDTH ( DW )
  ) master_dv (clk);

  REQRSP_BUS #(
    .ADDR_WIDTH ( AW ),
    .DATA_WIDTH ( DW )
  ) slave ();

  REQRSP_BUS_DV #(
    .ADDR_WIDTH ( AW ),
    .DATA_WIDTH ( DW )
  ) slave_dv (clk);

  // Isochronous crossing.
  if (Iso) begin : gen_iso_dut
  // We only want to test that the module is properly wired up so we can put it
  // in bypass which makes this testbench significantly easier as we do not need
  // to generate a isochronous clock. The iso feature is tested in a separate
  // testbench in the common_cells repository.
  reqrsp_iso_intf #(
    .AddrWidth (AW),
    .DataWidth (DW),
    .BypassReq (1),
    .BypassRsp (1)
  ) i_dut (
    .src_clk_i (clk),
    .src_rst_ni (rst_n),
    .src (master),
    .dst_clk_i (clk),
    .dst_rst_ni (rst_n),
    .dst (slave)
  );
  // Plain synchronous cuts.
  end else if (Cut) begin : gen_cut_dut
    reqrsp_cut_intf #(
      .AddrWidth (AW),
      .DataWidth (DW),
      .BypassReq (0),
      .BypassRsp (0)
    ) i_dut (
      .clk_i (clk),
      .rst_ni (rst_n),
      .slv (master),
      .mst (slave)
    );
  end

  `REQRSP_ASSIGN(master, master_dv)
  `REQRSP_ASSIGN(slave_dv, slave)

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

  reqrsp_monitor_t reqrsp_mst_monitor = new (master_dv);
  // Reqrsp Monitor.
  initial begin
    @(posedge rst_n);
    reqrsp_mst_monitor.monitor();
  end

  reqrsp_monitor_t reqrsp_slv_monitor = new (slave_dv);
  // Reqrsp Monitor.
  initial begin
    @(posedge rst_n);
    reqrsp_slv_monitor.monitor();
  end

  // ------
  // Driver
  // ------
  typedef reqrsp_test::rand_reqrsp_slave #(
    // Reqrsp bus interface paramaters;
    .AW ( AW ),
    .DW ( DW ),
    // Stimuli application and test time
    .TA ( ApplTime ),
    .TT ( TestTime )
  ) reqrsp_rand_slave_t;

  reqrsp_rand_slave_t rand_reqrsp_slave = new (slave_dv);
  initial begin
    rand_reqrsp_slave.reset();
    @(posedge rst_n);
    rand_reqrsp_slave.run();
  end

  typedef reqrsp_test::rand_reqrsp_master #(
    // Reqrsp bus interface paramaters;
    .AW ( AW ),
    .DW ( DW ),
    // Stimuli application and test time
    .TA ( ApplTime ),
    .TT ( TestTime )
  ) reqrsp_rand_master_t;

  reqrsp_rand_master_t rand_reqrsp_master = new (master_dv);

  // Reqrsp master.
  initial begin
    rand_reqrsp_master.reset();
    @(posedge rst_n);
    rand_reqrsp_master.run(NrRandomTransactions);
    // Wait until all transactions have ceased.
    repeat(1000) @(posedge clk);
    $finish;
  end

  // ----------
  // Scoreboard
  // ----------
  initial begin
    forever begin
        automatic reqrsp_test::req_t req;
        automatic reqrsp_test::req_t req_slv;
        automatic reqrsp_test::rsp_t rsp;
        automatic reqrsp_test::rsp_t rsp_slv;
        reqrsp_mst_monitor.req_mbx.get(req);
        reqrsp_mst_monitor.rsp_mbx.get(rsp);
        reqrsp_slv_monitor.req_mbx.get(req_slv);
        reqrsp_slv_monitor.rsp_mbx.get(rsp_slv);
        assert(req_slv.do_compare(req));
        assert(rsp_slv.do_compare(rsp));
    end
  end

  // Check that we have associated all transactions.
  final begin
    assert(reqrsp_mst_monitor.req_mbx.num() == 0);
    assert(reqrsp_mst_monitor.rsp_mbx.num() == 0);
    assert(reqrsp_slv_monitor.req_mbx.num() == 0);
    assert(reqrsp_slv_monitor.rsp_mbx.num() == 0);
    $display("Checked for non-empty mailboxes.");
  end

endmodule
