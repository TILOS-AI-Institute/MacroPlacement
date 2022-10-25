// Copyright 2020 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>

`include "reqrsp_interface/assign.svh"

/// Testbench for `reqrsp_demux`. Random drivers on the slave and master ports
/// drive a random pattern. The monitors track all packets and the scoreboard
/// checks the integrity of the schedule and data. We test the demux on a fixed,
/// address-based routing scheme. That makes it deterministic which port should
/// have received the corresponding datum and we can use the scoreboard to track
/// this.
module reqrsp_demux_tb import reqrsp_pkg::*; #(
  parameter int unsigned AW = 32,
  parameter int unsigned DW = 32,
  parameter int unsigned NrPorts = 4,
  parameter int unsigned RespDepth = 2,
  parameter int unsigned NrRandomTransactions = 1000
);
  localparam time ClkPeriod = 10ns;
  localparam time ApplTime =  2ns;
  localparam time TestTime =  8ns;
  localparam int unsigned SelectWidth = cf_math_pkg::idx_width(NrPorts);
  typedef logic [SelectWidth-1:0] select_t;
  logic  clk, rst_n;
  select_t slv_select;

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
  ) slave [NrPorts]();

  REQRSP_BUS_DV #(
    .ADDR_WIDTH ( AW ),
    .DATA_WIDTH ( DW )
  ) slave_dv [NrPorts] (clk);

  reqrsp_demux_intf #(
    .NrPorts (NrPorts),
    .AddrWidth (AW),
    .DataWidth (DW),
    .RespDepth (RespDepth)
  ) dut (
    .clk_i (clk),
    .rst_ni (rst_n),
    .slv_select_i (slv_select),
    .slv (master),
    .mst (slave)
  );

  assign slv_select = master.q_addr % NrPorts;

  `REQRSP_ASSIGN(master, master_dv)
  for (genvar i = 0; i < NrPorts; i++) begin : gen_if_assignment
    `REQRSP_ASSIGN(slave_dv[i], slave[i])
  end

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

  reqrsp_monitor_t reqrsp_slv_monitor [NrPorts];
  for (genvar i = 0; i < NrPorts; i++) begin : gen_mst_mon
    initial begin
      reqrsp_slv_monitor[i] = new (slave_dv[i]);
      @(posedge rst_n);
      reqrsp_slv_monitor[i].monitor();
    end
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

  reqrsp_rand_slave_t rand_reqrsp_slave [NrPorts];
  for (genvar i = 0; i < NrPorts; i++) begin : gen_slv_driver
    initial begin
      rand_reqrsp_slave[i] = new (slave_dv[i]);
      rand_reqrsp_slave[i].reset();
      @(posedge rst_n);
      rand_reqrsp_slave[i].run();
    end
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
        automatic select_t select;
        reqrsp_mst_monitor.req_mbx.get(req);
        reqrsp_mst_monitor.rsp_mbx.get(rsp);
        // Check that for each master transaction we see a slave transaction on
        // the right port.
        // The slave select in the testbench is steered based on the
        // (randomized) address.
        select = req.addr % NrPorts;
        reqrsp_slv_monitor[select].req_mbx.get(req_slv);
        reqrsp_slv_monitor[select].rsp_mbx.get(rsp_slv);
        assert(req_slv.do_compare(req));
        assert(rsp_slv.do_compare(rsp));
    end
  end

  // Check that we have associated all transactions.
  final begin
    assert(reqrsp_mst_monitor.req_mbx.num() == 0);
    assert(reqrsp_mst_monitor.rsp_mbx.num() == 0);
    for (int i = 0; i < NrPorts; i++) begin
      assert(reqrsp_slv_monitor[i].req_mbx.num() == 0);
      assert(reqrsp_slv_monitor[i].rsp_mbx.num() == 0);
    end
    $display("Checked for non-empty mailboxes.");
  end

endmodule
