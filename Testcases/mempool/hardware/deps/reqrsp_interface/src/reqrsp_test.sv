// Copyright 2020 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Fabian Schuiki <fschuiki@iis.ee.ethz.ch>
// Florian Zaruba <zarubaf@iis.ee.ethz.ch>

/// A set of testbench utilities for REQRSP interfaces.
package reqrsp_test;

  import reqrsp_pkg::*;

  class req_t #(
    parameter int AW = 32,
    parameter int DW = 32
  );
    rand logic [AW-1:0]   addr;
    rand logic            write;
    rand amo_op_e         amo;
    rand logic [DW-1:0]   data;
    rand logic [DW/8-1:0] strb;
    rand size_t           size;

    rand bit is_amo;

    constraint legal_amo_op_c {
      amo inside {
        AMOSwap, AMOAdd, AMOAnd,
        AMOOr, AMOXor, AMOMax,
        AMOMaxu, AMOMin, AMOMinu, AMOSC} -> write == 1;
    }

    // Reduce the amount of atomics.
    constraint amo_reduce_c {
      is_amo dist { 1:= 1, 0:= 10};
      is_amo -> amo inside {
        AMOSwap, AMOAdd, AMOAnd,
        AMOOr, AMOXor, AMOMax,
        AMOMaxu, AMOMin, AMOMinu
      };
    }

    /// Compare objects of same type.
    function do_compare(req_t rhs);
      return addr == rhs.addr &
             write == rhs.write &
             amo == rhs.amo &
             data == rhs.data &
             strb == rhs.strb &
             size == rhs.size;
    endfunction

  endclass

  class rsp_t #(
    parameter int DW = 32
  );
    rand logic [DW-1:0]   data;
    rand logic            error;

    /// Compare objects of same type.
    function do_compare(rsp_t rhs);
      return data == rhs.data &
             error == rhs.error;
    endfunction

  endclass

  /// A driver for the REQRSP interface.
  class reqrsp_driver #(
    parameter int  AW = -1,
    parameter int  DW = -1,
    parameter time TA = 0 , // stimuli application time
    parameter time TT = 0   // stimuli test time
  );
    virtual REQRSP_BUS_DV #(
      .ADDR_WIDTH(AW),
      .DATA_WIDTH(DW)
    ) bus;

    function new(
      virtual REQRSP_BUS_DV #(
        .ADDR_WIDTH(AW),
        .DATA_WIDTH(DW)
      ) bus
    );
      this.bus = bus;
    endfunction

    task reset_master;
      bus.q_addr  <= '0;
      bus.q_write <= '0;
      bus.q_amo   <= AMONone;
      bus.q_data  <= '0;
      bus.q_strb  <= '0;
      bus.q_size  <= '0;
      bus.q_valid <= '0;
      bus.p_ready <= '0;
    endtask

    task reset_slave;
      bus.q_ready <= '0;
      bus.p_data  <= '0;
      bus.p_error <= '0;
      bus.p_valid <= '0;
    endtask

    task cycle_start;
      #TT;
    endtask

    task cycle_end;
      @(posedge bus.clk_i);
    endtask

    /// Send a request.
    task send_req (input req_t req);
      bus.q_addr  <= #TA req.addr;
      bus.q_write <= #TA req.write;
      bus.q_amo   <= #TA req.amo;
      bus.q_data  <= #TA req.data;
      bus.q_strb  <= #TA req.strb;
      bus.q_size  <= #TA req.size;
      bus.q_valid <= #TA 1;
      cycle_start();
      while (bus.q_ready != 1) begin cycle_end(); cycle_start(); end
      cycle_end();
      bus.q_addr  <= #TA '0;
      bus.q_write <= #TA '0;
      bus.q_data  <= #TA '0;
      bus.q_strb  <= #TA '0;
      bus.q_valid <= #TA 0;
    endtask

    /// Send a response.
    task send_rsp (input rsp_t rsp);
      bus.p_data  <= #TA rsp.data;
      bus.p_error <= #TA rsp.error;
      bus.p_valid <= #TA 1;
      cycle_start();
      while (bus.p_ready != 1) begin cycle_end(); cycle_start(); end
      cycle_end();
      bus.p_data  <= #TA '0;
      bus.p_error <= #TA '0;
      bus.p_valid <= #TA 0;
    endtask

    /// Receive a request.
    task recv_req (output req_t req);
      bus.q_ready <= #TA 1;
      cycle_start();
      while (bus.q_valid != 1) begin cycle_end(); cycle_start(); end
      req = new;
      req.addr  = bus.q_addr;
      req.write = bus.q_write;
      req.amo   = bus.q_amo;
      req.data  = bus.q_data;
      req.strb  = bus.q_strb;
      req.size  = bus.q_size;
      cycle_end();
      bus.q_ready <= #TA 0;
    endtask

    /// Receive a response.
    task recv_rsp (output rsp_t rsp);
      bus.p_ready <= #TA 1;
      cycle_start();
      while (bus.p_valid != 1) begin cycle_end(); cycle_start(); end
      rsp = new;
      rsp.data  = bus.p_data;
      rsp.error = bus.p_error;
      cycle_end();
      bus.p_ready <= #TA 0;
    endtask

    /// Monitor request.
    task mon_req (output req_t req);
      cycle_start();
      while (!(bus.q_valid && bus.q_ready)) begin cycle_end(); cycle_start(); end
      req = new;
      req.addr  = bus.q_addr;
      req.write = bus.q_write;
      req.amo   = bus.q_amo;
      req.data  = bus.q_data;
      req.strb  = bus.q_strb;
      req.size  = bus.q_size;
      cycle_end();
    endtask

    /// Monitor response.
    task mon_rsp (output rsp_t rsp);
      cycle_start();
      while (!(bus.p_valid && bus.p_ready)) begin cycle_end(); cycle_start(); end
      rsp = new;
      rsp.data  = bus.p_data;
      rsp.error = bus.p_error;
      cycle_end();
    endtask

  endclass

  // Super classs for random reqrsp drivers.
  virtual class rand_reqrsp #(
    // Reqrsp interface parameters
    parameter int   AW = 32,
    parameter int   DW = 32,
    // Stimuli application and test time
    parameter time  TA = 0ps,
    parameter time  TT = 0ps
  );

    typedef reqrsp_test::reqrsp_driver #(
      // Reqrsp bus interface paramaters;
      .AW ( AW ),
      .DW ( DW ),
      // Stimuli application and test time
      .TA ( TA ),
      .TT ( TT )
    ) reqrsp_driver_t;

    reqrsp_driver_t drv;

    function new(virtual REQRSP_BUS_DV #( .ADDR_WIDTH (AW), .DATA_WIDTH (DW)) bus);
      this.drv = new (bus);
    endfunction

    task automatic rand_wait(input int unsigned min, input int unsigned max);
      int unsigned rand_success, cycles;
      rand_success = std::randomize(cycles) with {
        cycles >= min;
        cycles <= max;
        // Weigh the distribution so that the minimum cycle time is the common
        // case.
        cycles dist {min := 10, [min+1:max] := 1};
      };
      assert (rand_success) else $error("Failed to randomize wait cycles!");
      repeat (cycles) @(posedge this.drv.bus.clk_i);
    endtask

  endclass

  /// Generate random requests as a master device.
  class rand_reqrsp_master #(
    // Reqrsp interface parameters
    parameter int   AW = 32,
    parameter int   DW = 32,
    // Stimuli application and test time
    parameter time  TA = 0ps,
    parameter time  TT = 0ps,
    parameter int unsigned REQ_MIN_WAIT_CYCLES = 1,
    parameter int unsigned REQ_MAX_WAIT_CYCLES = 20,
    parameter int unsigned RSP_MIN_WAIT_CYCLES = 1,
    parameter int unsigned RSP_MAX_WAIT_CYCLES = 20
  ) extends rand_reqrsp #(.AW(AW), .DW(DW), .TA(TA), .TT(TT));

    int unsigned cnt = 0;
    bit req_done = 0;

    /// Reset the driver.
    task reset();
      drv.reset_master();
    endtask

    /// Constructor.
    function new(virtual REQRSP_BUS_DV #( .ADDR_WIDTH (AW), .DATA_WIDTH (DW)) bus);
      super.new(bus);
    endfunction

    task run(input int n);
      fork
        send_requests(n);
        recv_response();
      join
    endtask

    /// Send random requests.
    task send_requests (input int n);
      automatic req_t r = new;

      repeat (n) begin
        this.cnt++;
        assert(r.randomize());
        rand_wait(REQ_MIN_WAIT_CYCLES, REQ_MAX_WAIT_CYCLES);
        this.drv.send_req(r);
      end
      this.req_done = 1;
    endtask

    /// Receive random responses.
    task recv_response;
      while (!this.req_done || this.cnt > 0) begin
        automatic rsp_t rsp;
        this.cnt--;
        rand_wait(RSP_MIN_WAIT_CYCLES, RSP_MAX_WAIT_CYCLES);
        this.drv.recv_rsp(rsp);
      end
    endtask
  endclass

  class rand_reqrsp_slave #(
    // Reqrsp interface parameters
    parameter int   AW = 32,
    parameter int   DW = 32,
    // Stimuli application and test time
    parameter time  TA = 0ps,
    parameter time  TT = 0ps,
    parameter int unsigned REQ_MIN_WAIT_CYCLES = 0,
    parameter int unsigned REQ_MAX_WAIT_CYCLES = 10,
    parameter int unsigned RSP_MIN_WAIT_CYCLES = 0,
    parameter int unsigned RSP_MAX_WAIT_CYCLES = 10
  ) extends rand_reqrsp #(.AW(AW), .DW(DW), .TA(TA), .TT(TT));

    mailbox req_mbx = new();

    /// Reset the driver.
    task reset();
      drv.reset_slave();
    endtask

    task run();
      fork
        recv_requests();
        send_responses();
      join
    endtask

    /// Constructor.
    function new(virtual REQRSP_BUS_DV #( .ADDR_WIDTH (AW), .DATA_WIDTH (DW)) bus);
      super.new(bus);
    endfunction

    task recv_requests();
      forever begin
        automatic req_t req;
        rand_wait(REQ_MIN_WAIT_CYCLES, REQ_MAX_WAIT_CYCLES);
        this.drv.recv_req(req);
        req_mbx.put(req);
      end
    endtask

    task send_responses();
      automatic rsp_t rsp = new;
      automatic req_t req;
      forever begin
        req_mbx.get(req);
        assert(rsp.randomize());
        @(posedge this.drv.bus.clk_i);
        rand_wait(RSP_MIN_WAIT_CYCLES, RSP_MAX_WAIT_CYCLES);
        this.drv.send_rsp(rsp);
      end
    endtask
  endclass

  class reqrsp_monitor #(
    // Reqrsp interface parameters
    parameter int   AW = 32,
    parameter int   DW = 32,
    // Stimuli application and test time
    parameter time  TA = 0ps,
    parameter time  TT = 0ps
  ) extends rand_reqrsp #(.AW(AW), .DW(DW), .TA(TA), .TT(TT));

    mailbox req_mbx = new, rsp_mbx = new;

    /// Constructor.
    function new(virtual REQRSP_BUS_DV #( .ADDR_WIDTH (AW), .DATA_WIDTH (DW)) bus);
      super.new(bus);
    endfunction

    // Reqrsp Monitor.
    task monitor;
      fork
        forever begin
          automatic reqrsp_test::req_t req;
          this.drv.mon_req(req);
          req_mbx.put(req);
        end
        forever begin
          automatic reqrsp_test::rsp_t rsp;
          this.drv.mon_rsp(rsp);
          rsp_mbx.put(rsp);
        end
      join
    endtask
  endclass

endpackage
