// Copyright 2021 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

import "DPI-C" function void read_elf (input string filename);
import "DPI-C" function byte get_section (output longint address, output longint len);
import "DPI-C" context function byte read_section(input longint address, inout byte buffer[]);

`define wait_for(signal) \
  do \
    @(posedge clk); \
  while (!signal);

module mempool_tb;

  /*****************
   *  Definitions  *
   *****************/

  timeunit      1ns;
  timeprecision 1ps;

  import mempool_pkg::*;
  import axi_pkg::xbar_cfg_t;
  import axi_pkg::xbar_rule_32_t;

  `ifdef BOOT_ADDR
  localparam BootAddr = `BOOT_ADDR;
  `else
  localparam BootAddr = 0;
  `endif

  localparam ClockPeriod = 2ns;
  localparam TA          = 0.2ns;
  localparam TT          = 0.8ns;

  localparam PollEoc     = 0;

 /********************************
   *  Clock and Reset Generation  *
   ********************************/

  logic clk;
  logic rst_n;

  // Toggling the clock
  always #(ClockPeriod/2) clk = !clk;

  // Controlling the reset
  initial begin
    clk   = 1'b1;
    rst_n = 1'b0;

    repeat (5)
      #(ClockPeriod);

    rst_n = 1'b1;
  end

  /*********
   *  AXI  *
   *********/

  `include "axi/assign.svh"

  localparam NumAXIMasters = 1;
  localparam NumAXISlaves  = 2;
  localparam NumRules  = NumAXISlaves-1;

  typedef enum logic [$clog2(NumAXISlaves)-1:0] {
    UART,
    Host
  } axi_slave_target;

  axi_system_req_t    [NumAXIMasters - 1:0] axi_mst_req;
  axi_system_resp_t   [NumAXIMasters - 1:0] axi_mst_resp;
  axi_tb_req_t        [NumAXISlaves - 1:0]  axi_mem_req;
  axi_tb_resp_t       [NumAXISlaves - 1:0]  axi_mem_resp;

  axi_system_req_t                          to_mempool_req;
  axi_system_resp_t                         to_mempool_resp;

  localparam xbar_cfg_t XBarCfg = '{
    NoSlvPorts        : NumAXIMasters,
    NoMstPorts        : NumAXISlaves,
    MaxMstTrans       : 4,
    MaxSlvTrans       : 4,
    FallThrough       : 1'b0,
    LatencyMode       : axi_pkg::CUT_MST_PORTS,
    AxiIdWidthSlvPorts: AxiSystemIdWidth,
    AxiIdUsedSlvPorts : AxiSystemIdWidth,
    UniqueIds         : 0,
    AxiAddrWidth      : AddrWidth,
    AxiDataWidth      : DataWidth,
    NoAddrRules       : NumRules
  };

  /*********
   *  DUT  *
   *********/

  logic fetch_en;
  logic eoc_valid;

  mempool_system #(
    .TCDMBaseAddr(32'h0   ),
    .BootAddr    (BootAddr)
  ) dut (
    .clk_i          (clk            ),
    .rst_ni         (rst_n          ),
    .fetch_en_i     (fetch_en       ),
    .eoc_valid_o    (eoc_valid      ),
    .busy_o         (/*Unused*/     ),
    .mst_req_o      (axi_mst_req    ),
    .mst_resp_i     (axi_mst_resp   ),
    .slv_req_i      (to_mempool_req ),
    .slv_resp_o     (to_mempool_resp)
  );

  /**********************
   *  AXI Interconnect  *
   **********************/

  localparam addr_t UARTBaseAddr = 32'hC000_0000;
  localparam addr_t UARTEndAddr = 32'hC000_FFFF;

  xbar_rule_32_t [NumRules-1:0] xbar_routing_rules = '{
    '{idx: UART, start_addr: UARTBaseAddr, end_addr: UARTEndAddr}
  };

  axi_xbar #(
    .Cfg          (XBarCfg          ),
    .slv_aw_chan_t(axi_system_aw_t  ),
    .mst_aw_chan_t(axi_tb_aw_t      ),
    .w_chan_t     (axi_tb_w_t       ),
    .slv_b_chan_t (axi_system_b_t   ),
    .mst_b_chan_t (axi_tb_b_t       ),
    .slv_ar_chan_t(axi_system_ar_t  ),
    .mst_ar_chan_t(axi_tb_ar_t      ),
    .slv_r_chan_t (axi_system_r_t   ),
    .mst_r_chan_t (axi_tb_r_t       ),
    .slv_req_t    (axi_system_req_t ),
    .slv_resp_t   (axi_system_resp_t),
    .mst_req_t    (axi_tb_req_t     ),
    .mst_resp_t   (axi_tb_resp_t    ),
    .rule_t       (xbar_rule_32_t)
  ) i_testbench_xbar (
    .clk_i                (clk                  ),
    .rst_ni               (rst_n                ),
    .test_i               (1'b0                 ),
    .slv_ports_req_i      (axi_mst_req          ),
    .slv_ports_resp_o     (axi_mst_resp         ),
    .mst_ports_req_o      (axi_mem_req          ),
    .mst_ports_resp_i     (axi_mem_resp         ),
    .addr_map_i           (xbar_routing_rules   ),
    .en_default_mst_port_i('1                   ), // default all slave ports to master port Host
    .default_mst_port_i   ({NumAXIMasters{Host}})
  );

  /**********
   *  HOST  *
   **********/
  assign axi_mem_resp[Host] = '0;

  /**********
   *  UART  *
   **********/

  axi_uart #(
    .axi_req_t (axi_tb_req_t ),
    .axi_resp_t(axi_tb_resp_t)
  ) i_axi_uart (
    .clk_i     (clk               ),
    .rst_ni    (rst_n             ),
    .testmode_i(1'b0              ),
    .axi_req_i (axi_mem_req[UART] ),
    .axi_resp_o(axi_mem_resp[UART])
  );

  /*********
   *  WFI  *
   *********/

`ifndef TARGET_SYNTHESIS
`ifndef TARGET_VERILATOR

  // Helper debug signal with the wfi of each core
  logic [NumCores-1:0]          wfi;
  for (genvar g = 0; g < NumGroups; g++) begin: gen_wfi_groups
    for (genvar t = 0; t < NumTilesPerGroup; t++) begin: gen_wfi_tiles
      for (genvar c = 0; c < NumCoresPerTile; c++) begin: gen_wfi_cores
        assign wfi[g*NumTilesPerGroup*NumCoresPerTile + t*NumCoresPerTile + c] = dut.i_mempool_cluster.gen_groups[g].i_group.gen_tiles[t].i_tile.gen_cores[c].gen_mempool_cc.riscv_core.i_snitch.wfi_q;
      end: gen_wfi_cores
    end: gen_wfi_tiles
  end: gen_wfi_groups

`endif
`endif

  /************************
   *  Write/Read via AXI  *
   ************************/

  task write_to_mempool(input addr_t addr, input data_t data, output axi_pkg::resp_t resp);
    to_mempool_req.aw.id = 'h18d;
    to_mempool_req.aw.addr = addr;
    to_mempool_req.aw.size = 'h2;
    to_mempool_req.aw.burst = axi_pkg::BURST_INCR;
    to_mempool_req.aw_valid = 1'b1;
    `wait_for(to_mempool_resp.aw_ready)
    to_mempool_req.aw_valid = 1'b0;
    to_mempool_req.w.data = data << addr[ByteOffset +: $clog2(AxiDataWidth/DataWidth)] * DataWidth;
    to_mempool_req.w.strb = {BeWidth{1'b1}} << addr[ByteOffset +: $clog2(AxiDataWidth/DataWidth)] * BeWidth;
    to_mempool_req.w.last = 1'b1;
    to_mempool_req.w.user = '0;
    to_mempool_req.w_valid = 1'b1;
    `wait_for(to_mempool_resp.w_ready)
    to_mempool_req.w_valid = 1'b0;
    to_mempool_req.b_ready = 1'b1;
    `wait_for(to_mempool_resp.b_valid)
    resp = to_mempool_resp.b.resp;
    to_mempool_req.b_ready = 1'b0;
  endtask

  task read_from_mempool(input addr_t addr, output data_t data, output axi_pkg::resp_t resp);
    to_mempool_req.ar.id = 'h18d;
    to_mempool_req.ar.addr = addr;
    to_mempool_req.ar.size = 'h2;
    to_mempool_req.ar.burst = axi_pkg::BURST_INCR;
    to_mempool_req.ar_valid = 1'b1;
    `wait_for(to_mempool_resp.ar_ready)
    to_mempool_req.ar_valid = 1'b0;
    to_mempool_req.r_ready = 1'b1;
    `wait_for(to_mempool_resp.r_valid)
    data = to_mempool_resp.r.data >> addr[ByteOffset +: $clog2(AxiDataWidth/DataWidth)] * DataWidth;
    resp = to_mempool_resp.r.resp;
    to_mempool_req.r_ready = 1'b0;
    $display("[TB] Read %08x from %08x at %t (resp=%d).", data, addr, $time, resp);
  endtask

  axi_pkg::resp_t resp;

  // Simulation control
  initial begin
    localparam ctrl_phys_addr = 32'h4000_0000;
    localparam ctrl_size      = 32'h0100_0000;
    localparam l2_phys_addr   = 32'h8000_0000;
    localparam l2_size        = 32'h0700_0000;
    localparam ctrl_virt_addr = ctrl_phys_addr;
    localparam l2_virt_addr   = l2_phys_addr;
    addr_t first, last, phys_addr;
    data_t rdata;
    axi_pkg::resp_t resp;
    fetch_en = 1'b0;
    to_mempool_req = '{default: '0};
    to_mempool_req.aw.burst = axi_pkg::BURST_INCR;
    to_mempool_req.ar.burst = axi_pkg::BURST_INCR;
    to_mempool_req.aw.cache = axi_pkg::CACHE_MODIFIABLE;
    to_mempool_req.ar.cache = axi_pkg::CACHE_MODIFIABLE;
    // Wait for reset.
    wait (rst_n);
    @(posedge clk);

    // Give the cores time to execute the bootrom's program
    #(1000*ClockPeriod);

    // Wake up all cores
    write_to_mempool(ctrl_virt_addr + 32'h4, {DataWidth{1'b1}}, resp);
    assert(resp == axi_pkg::RESP_OKAY);

    if (PollEoc) begin
      // Poll for EOC (as done on the host at the moment)
      do begin
        #(1000*ClockPeriod);
        @(posedge clk);
        read_from_mempool(ctrl_virt_addr, rdata, resp);
        assert(resp == axi_pkg::RESP_OKAY);
      end while (rdata == 0);
    end else begin
      // Wait for the interrupt
      wait (eoc_valid);
      read_from_mempool(ctrl_virt_addr, rdata, resp);
      assert(resp == axi_pkg::RESP_OKAY);
    end
    $timeformat(-9, 2, " ns", 0);
    $display("[EOC] Simulation ended at %t (retval = %0d).", $time, rdata >> 1);
    $finish(0);
    // Start MemPool
    fetch_en = 1'b1;
  end

  /***********************
   *  L2 Initialization  *
   ***********************/

  for (genvar bank = 0; bank < NumL2Banks; bank++) begin : gen_l2_banks_init
    initial begin : l2_init
      automatic logic [L2BankWidth-1:0] mem_row;
      byte buffer [];
      addr_t address;
      addr_t length;
      string binary;

      // Initialize memories
      void'($value$plusargs("PRELOAD=%s", binary));
      if (binary != "") begin
        // Read ELF
        read_elf(binary);
        $display("Loading %s", binary);
        while (get_section(address, length)) begin
          // Read sections
          automatic int nwords = (length + L2BeWidth - 1)/L2BeWidth;
          $display("Loading section %x of length %x", address, length);
          buffer = new[nwords * L2BeWidth];
          void'(read_section(address, buffer));
          // Initializing memories
          for (int w = 0; w < nwords; w++) begin
            mem_row = '0;
            for (int b = 0; b < L2BankBeWidth; b++) begin
              mem_row[8 * b +: 8] = buffer[(bank + w * NumL2Banks) * L2BankBeWidth + b];
            end
            if (address >= dut.L2MemoryBaseAddr && address < dut.L2MemoryEndAddr) begin
              dut.gen_l2_banks[bank].l2_mem.init_val[(address - dut.L2MemoryBaseAddr + (w << L2ByteOffset)) >> L2ByteOffset] = mem_row;
            end else begin
              $display("Cannot initialize address %x, which doesn't fall into the L2 region.", address);
            end
          end
        end
      end
    end : l2_init
  end : gen_l2_banks_init

endmodule : mempool_tb
