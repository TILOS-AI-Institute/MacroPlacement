// Copyright 2020 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>

`include "reqrsp_interface/typedef.svh"
`include "reqrsp_interface/assign.svh"
`include "axi/typedef.svh"
`include "axi/assign.svh"

module axi_to_reqrsp_tb import reqrsp_pkg::*; #(
  parameter int unsigned AW = 32,
  parameter int unsigned DW = 32,
  parameter int unsigned IW = 2,
  parameter int unsigned UW = 2,
  parameter int unsigned NrReads = 1000,
  parameter int unsigned NrWrites = 1000
);

  localparam time ClkPeriod = 10ns;
  localparam time ApplTime =  2ns;
  localparam time TestTime =  8ns;

  logic  clk, rst_n;

  // interfaces
  REQRSP_BUS #(
    .ADDR_WIDTH ( AW ),
    .DATA_WIDTH ( DW )
  ) slave ();

  REQRSP_BUS_DV #(
    .ADDR_WIDTH ( AW ),
    .DATA_WIDTH ( DW )
  ) slave_dv (clk);

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AW ),
    .AXI_DATA_WIDTH ( DW ),
    .AXI_ID_WIDTH   ( IW  ),
    .AXI_USER_WIDTH ( UW )
  ) master ();

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( AW ),
    .AXI_DATA_WIDTH ( DW ),
    .AXI_ID_WIDTH   ( IW  ),
    .AXI_USER_WIDTH ( UW )
  ) master_dv (clk);

  axi_to_reqrsp_intf #(
    .AddrWidth (AW),
    .DataWidth (DW),
    .IdWidth (IW),
    .UserWidth (UW),
    .BufDepth (4)
  ) dut (
    .clk_i (clk),
    .rst_ni (rst_n),
    .busy_o (),
    .axi (master),
    .reqrsp (slave)
  );

  `AXI_ASSIGN(master, master_dv)
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

  reqrsp_monitor_t reqrsp_monitor = new (slave_dv);
  // Reqrsp Monitor.
  initial begin
    @(posedge rst_n)
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

  axi_monitor_t axi_monitor = new (master_dv);
  initial begin
    @(posedge rst_n);
    axi_monitor.monitor();
  end

  // ----------
  // Scoreboard
  // ----------
  initial begin
    automatic int unsigned id_cnt_read;
    automatic int unsigned id_cnt_write;
    forever begin
      automatic reqrsp_test::req_t req;
      automatic reqrsp_test::rsp_t rsp;
      automatic axi_monitor_t::ax_beat_t ax;
      automatic axi_monitor_t::b_beat_t b;
      automatic axi_monitor_t::r_beat_t r;
      automatic axi_monitor_t::w_beat_t w;

      reqrsp_monitor.req_mbx.get(req);
      reqrsp_monitor.rsp_mbx.get(rsp);

      // Check that we have seen the appropriate transactions on the inputs.
      if (req.write) begin
        axi_monitor.aw_mbx.peek(ax);
        axi_monitor.w_mbx.get(w);
        // Invert bits as this is signalled as a clear condition on AXI.
        if (req.amo == AMOAnd) begin
          req.data = ~req.data;
        end
        assert(req.size == ax.ax_size)
          else $error("[Write Size] Expected `%h` got `%h`", ax.ax_size, req.size);
        assert(req.strb == w.w_strb)
          else $error("[Write Strb] Expected `%h` got `%h`", w.w_strb, req.strb);
        assert(req.data == w.w_data)
          else $error("[Write Data] Expected `%h` got `%h`", w.w_data, req.data);
        assert(req.write == 1);
        assert (
          req.addr ==
            axi_pkg::beat_addr(ax.ax_addr, ax.ax_size, ax.ax_len, ax.ax_burst, id_cnt_write)
        ) else $error("[Write Addr] Expected `%h` got `%h`.", ax.ax_addr, req.addr);

        id_cnt_write++;
        // Check SCs
        assert(ax.ax_lock == (req.amo == AMOSC))
          else $error("[Write Amo] Expected `%h` got `%h`", ax.ax_lock, (req.amo == AMOSC));
        // Consume Rs for atomic instructions.
        if (ax.ax_atop[5:4] == axi_pkg::ATOP_ATOMICLOAD ||
            ax.ax_atop inside {axi_pkg::ATOP_ATOMICSWAP, axi_pkg::ATOP_ATOMICCMP}) begin
          axi_monitor.r_mbx.get(r);
          assert(req.amo == from_axi_amo(ax.ax_atop));
        end
        if (w.w_last) begin
          axi_monitor.aw_mbx.get(ax);
          axi_monitor.b_mbx.get(b);
          id_cnt_write = 0;
          assert(ax.ax_id == b.b_id);
        end
      end else begin
        axi_monitor.ar_mbx.peek(ax);
        axi_monitor.r_mbx.get(r);
        assert(req.size == ax.ax_size)
          else $error("[Read Size] Expected `%h` got `%h`", ax.ax_size, req.size);
        assert(rsp.data == r.r_data)
          else $error("[Read Data] Expected `%h` got `%h`", r.r_data, rsp.data);
        assert(ax.ax_id == r.r_id);
        assert(req.write == 0);
        assert(ax.ax_lock == (req.amo == AMOLR))
          else $error("[Read Amo] Expected `%h` got `%h`", ax.ax_lock, (req.amo == AMOLR));
        assert(
          req.addr ==
            axi_pkg::beat_addr(ax.ax_addr, ax.ax_size, ax.ax_len, ax.ax_burst, id_cnt_read)
        ) else $error("[Read Addr] Expected `%h` got `%h`.", ax.ax_addr, req.addr);
        id_cnt_read++;
        if (r.r_last) begin
          id_cnt_read = 0;
          axi_monitor.ar_mbx.get(ax);
        end
      end
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
  // AXI Master
  typedef axi_test::axi_rand_master #(
    // AXI interface parameters
    .AW ( AW ),
    .DW ( DW ),
    .IW ( IW ),
    .UW ( UW ),
    // Stimuli application and test time
    .TA ( ApplTime ),
    .TT ( TestTime ),
    .MAX_READ_TXNS (10),
    .MAX_WRITE_TXNS (10),
    .AX_MIN_WAIT_CYCLES (0),
    .AX_MAX_WAIT_CYCLES (20),
    // Only incremental bursts are supported.
    .AXI_BURST_FIXED (0),
    // Limit the burst length, to reduce simulation time.
    .AXI_MAX_BURST_LEN (10),
    // Check for exclusive accesses and atops.
    .AXI_EXCLS (1),
    .AXI_ATOPS (1)
  ) rand_axi_master_t;

  rand_axi_master_t axi_rand_master = new (master_dv);

  // AXI Random master.
  initial begin
    axi_rand_master.reset();
    @(posedge rst_n);
    axi_rand_master.run(NrReads, NrWrites);
    // Wait until all transactions have ceased.
    repeat(1000) @(posedge clk);
    $finish;
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

endmodule
