// Copyright 2020 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>

`include "reqrsp_interface/assign.svh"

/// Testbench for `reqrsp_mux`. Random drivers on the slave and master ports
/// drive a random pattern. The monitors track all packets and the scoreboard
/// tries to generate a legit schedule. If the testbench terminates and no
/// schedule could be found the request and response routing of the arbiter is
/// wrong.
module reqrsp_mux_tb import reqrsp_pkg::*; #(
  parameter int unsigned AW = 32,
  parameter int unsigned DW = 32,
  parameter int unsigned NrPorts = 4,
  parameter int unsigned RespDepth = 2,
  parameter int unsigned RegisterReq = 1,
  parameter int unsigned NrRandomTransactions = 100
);
  localparam time ClkPeriod = 10ns;
  localparam time ApplTime =  2ns;
  localparam time TestTime =  8ns;

  logic  clk, rst_n;

  REQRSP_BUS #(
    .ADDR_WIDTH ( AW ),
    .DATA_WIDTH ( DW )
  ) master [NrPorts] ();

  REQRSP_BUS_DV #(
    .ADDR_WIDTH ( AW ),
    .DATA_WIDTH ( DW )
  ) master_dv [NrPorts] (clk);

  REQRSP_BUS #(
    .ADDR_WIDTH ( AW ),
    .DATA_WIDTH ( DW )
  ) slave ();

  REQRSP_BUS_DV #(
    .ADDR_WIDTH ( AW ),
    .DATA_WIDTH ( DW )
  ) slave_dv (clk);

  reqrsp_mux_intf #(
    .NrPorts (NrPorts),
    .AddrWidth (AW),
    .DataWidth (DW),
    .RespDepth (RespDepth),
    .RegisterReq (RegisterReq)
  ) dut (
    .clk_i (clk),
    .rst_ni (rst_n),
    .slv (master),
    .mst (slave)
  );

  `REQRSP_ASSIGN(slave_dv, slave)
  for (genvar i = 0; i < NrPorts; i++) begin : gen_if_assignment
    `REQRSP_ASSIGN(master[i], master_dv[i])
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

  reqrsp_monitor_t reqrsp_slv_monitor = new (slave_dv);
  // Reqrsp Monitor.
  initial begin
    @(posedge rst_n);
    reqrsp_slv_monitor.monitor();
  end

  reqrsp_monitor_t reqrsp_mst_monitor [NrPorts];
  for (genvar i = 0; i < NrPorts; i++) begin : gen_mst_mon
    initial begin
      reqrsp_mst_monitor[i] = new (master_dv[i]);
      @(posedge rst_n);
      reqrsp_mst_monitor[i].monitor();
    end
  end

  // ------
  // Driver
  // ------
  typedef reqrsp_test::rand_reqrsp_master #(
    // Reqrsp bus interface paramaters;
    .AW ( AW ),
    .DW ( DW ),
    // Stimuli application and test time
    .TA ( ApplTime ),
    .TT ( TestTime )
  ) reqrsp_rand_master_t;

  reqrsp_rand_master_t rand_reqrsp_master [NrPorts];
  for (genvar i = 0; i < NrPorts; i++) begin : gen_mst_driver
    initial begin
      rand_reqrsp_master[i] = new (master_dv[i]);
      rand_reqrsp_master[i].reset();
      @(posedge rst_n);
      rand_reqrsp_master[i].run(NrRandomTransactions);
    end
  end

  typedef reqrsp_test::rand_reqrsp_slave #(
    // Reqrsp bus interface paramaters;
    .AW ( AW ),
    .DW ( DW ),
    // Stimuli application and test time
    .TA ( ApplTime ),
    .TT ( TestTime )
  ) reqrsp_rand_slave_t;

  reqrsp_rand_slave_t rand_reqrsp_slave = new (slave_dv);

  // Reqrsp Slave.
  initial begin
    rand_reqrsp_slave.reset();
    @(posedge rst_n);
    rand_reqrsp_slave.run();
  end

  // ----------
  // Scoreboard
  // ----------
  // The arbiter is a bit more tricky to test as we do not, looking from
  // outside, know where the arbitration decision actually went (because two
  // exactly same requests can be issued and on the output port we have lost all
  // information on which port this request originated). This scoreboard
  // therefore takes a greedy approach. It tries to map each packet on the
  // output to a corresponding packet observed on a input port. The first port
  // that matches this will be assigned as the source and the monitor packets
  // from this port will be removed.
  // While the request does not necessarily must have come from that exact port,
  // the exact order doesn't matter as long as all packets have been removed and
  // all mailboxes are empty.
  initial begin
    automatic int unsigned nr_transactions = 0;
    forever begin
      automatic reqrsp_test::req_t req;
      automatic reqrsp_test::rsp_t rsp;
      automatic bit arb_found = 0;
      reqrsp_slv_monitor.req_mbx.get(req);
      reqrsp_slv_monitor.rsp_mbx.get(rsp);
      nr_transactions++;
      // Check that this transaction has been valid at one of the request
      // ports.
      for (int i = 0; i < NrPorts; i++) begin
        // Check that the request mailbox contains at least one value, otherwise
        // one early finishing port can stall the rest. Also, if the request is
        // observeable on the output the input must have handshaked, so this is
        // a safe operation.
        if (reqrsp_mst_monitor[i].req_mbx.num() != 0) begin
          automatic reqrsp_test::req_t req_inp;
          automatic reqrsp_test::rsp_t rsp_inp;
          reqrsp_mst_monitor[i].req_mbx.peek(req_inp);
          reqrsp_mst_monitor[i].rsp_mbx.peek(rsp_inp);
          if (req_inp.do_compare(req) && rsp_inp.do_compare(rsp)) begin
            reqrsp_mst_monitor[i].req_mbx.get(req_inp);
            reqrsp_mst_monitor[i].rsp_mbx.get(rsp_inp);
            arb_found |= 1;
            break;
          end
        end
      end

      assert(arb_found) else $error("No arbitration found.");
      if (nr_transactions == NrPorts * NrRandomTransactions) $finish;
    end
  end

  // Check that we have associated all transactions.
  final begin
    assert(reqrsp_slv_monitor.req_mbx.num() == 0);
    assert(reqrsp_slv_monitor.rsp_mbx.num() == 0);
    for (int i = 0; i < NrPorts; i++) begin
      assert(reqrsp_mst_monitor[i].req_mbx.num() == 0);
      assert(reqrsp_mst_monitor[i].rsp_mbx.num() == 0);
    end
    $display("Checked for non-empty mailboxes.");
  end
endmodule
