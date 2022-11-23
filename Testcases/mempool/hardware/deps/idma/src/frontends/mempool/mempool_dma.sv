// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Samuel Riedel <sriedel@iis.ee.ethz.ch>

`include "register_interface/typedef.svh"
`include "common_cells/registers.svh"

module mempool_dma #(
  parameter int unsigned AddrWidth   = 32,
  parameter int unsigned DataWidth   = 32,
  parameter int unsigned NumBackends = 1,
  /// AXI4+ATOP request struct definition.
  parameter type         axi_lite_req_t = logic,
  /// AXI4+ATOP response struct definition.
  parameter type         axi_lite_rsp_t = logic,
  /// Arbitrary 1D burst request definition:
  /// - `id`: the AXI id used - this id should be constant, as the DMA does not support reordering
  /// - `src`, `dst`: source and destination address, same width as the AXI 4 channels
  /// - `num_bytes`: the length of the contiguous 1D transfer requested, can be up to 32/64 bit long
  ///              num_bytes will be interpreted as an unsigned number
  ///              A value of 0 will cause the backend to discard the transfer prematurely
  /// - `src_cache`, `dst_cache`: the configuration of the cache fields in the AX beats
  /// - `src_burst`, `dst_burst`: currently only incremental bursts are supported (`2'b01`)
  /// - `decouple_rw`: if set to true, there is no longer exactly one AXI write_request issued for
  ///   every read request. This mode can improve performance of unaligned transfers when crossing
  ///   the AXI page boundaries.
  /// - `deburst`: if set, the DMA will split all bursts in single transfers
  /// - `serialize`: if set, the DMA will only send AX belonging to a given Arbitrary 1D burst request
  ///              at a time. This is default behavior to prevent deadlocks. Setting `serialize` to
  ///              zero violates the AXI4+ATOP specification.
  parameter type         burst_req_t = logic,
  /// Give each DMA backend a unique id
  parameter int unsigned DmaIdWidth = -1
) (
  input  logic                            clk_i,
  input  logic                            rst_ni,
  input  axi_lite_req_t                   config_req_i,
  output axi_lite_rsp_t                   config_res_o,
  output burst_req_t                      burst_req_o,
  output logic                            valid_o,
  input  logic                            ready_i,
  input  logic                            backend_idle_i,
  input  logic                            trans_complete_i,
  output logic           [DmaIdWidth-1:0] dma_id_o
);

  // import mempool_dma_frontend_reg_pkg::BlockAw;
  // import mempool_dma_frontend_reg_pkg::mempool_dma_frontend_reg2hw_t;
  // import mempool_dma_frontend_reg_pkg::mempool_dma_frontend_hw2reg_t;
  import mempool_dma_frontend_reg_pkg::*;

  `REG_BUS_TYPEDEF_ALL(ctrl_reg, logic[BlockAw-1:0], logic[DataWidth-1:0], logic[DataWidth/8-1:0]);
  ctrl_reg_req_t ctrl_reg_req;
  ctrl_reg_rsp_t ctrl_reg_rsp;

  mempool_dma_frontend_reg2hw_t ctrl_reg2hw;
  mempool_dma_frontend_hw2reg_t ctrl_hw2reg;

  logic trans_complete_d, trans_complete_q;
  `FF(trans_complete_q, trans_complete_d, '0, clk_i, rst_ni)

  always_comb begin
    trans_complete_d = trans_complete_q;
    if (trans_complete_i) begin
      trans_complete_d = 1'b1;
    end
    if (valid_o) begin
      trans_complete_d = 1'b0;
    end
  end

  assign ctrl_hw2reg = '{
    status  : backend_idle_i,
    next_id : 1'b0,
    done    : trans_complete_q
  };

  axi_lite_to_reg #(
    .ADDR_WIDTH    (AddrWidth     ),
    .DATA_WIDTH    (DataWidth     ),
    .BUFFER_DEPTH  (1             ),
    .DECOUPLE_W    (0             ),
    .axi_lite_req_t(axi_lite_req_t),
    .axi_lite_rsp_t(axi_lite_rsp_t),
    .reg_req_t     (ctrl_reg_req_t),
    .reg_rsp_t     (ctrl_reg_rsp_t)
  ) i_axi_lite_to_reg (
    .clk_i         (clk_i       ),
    .rst_ni        (rst_ni      ),
    .axi_lite_req_i(config_req_i),
    .axi_lite_rsp_o(config_res_o),
    .reg_req_o     (ctrl_reg_req),
    .reg_rsp_i     (ctrl_reg_rsp)
  );

  mempool_dma_frontend_reg_top #(
    .reg_req_t(ctrl_reg_req_t),
    .reg_rsp_t(ctrl_reg_rsp_t)
  ) i_mempool_dma_frontend_reg_top (
    .clk_i    (clk_i       ),
    .rst_ni   (rst_ni      ),
    .reg_req_i(ctrl_reg_req),
    .reg_rsp_o(ctrl_reg_rsp),
    .reg2hw   (ctrl_reg2hw ),
    .hw2reg   (ctrl_hw2reg ),
    .devmode_i(1'b0        )
  );

  assign burst_req_o = '{
    id          : 0,
    src         : ctrl_reg2hw.src_addr,
    dst         : ctrl_reg2hw.dst_addr,
    num_bytes   : ctrl_reg2hw.num_bytes,
    cache_src   : axi_pkg::CACHE_MODIFIABLE,
    cache_dst   : axi_pkg::CACHE_MODIFIABLE,
    burst_src   : axi_pkg::BURST_INCR,
    burst_dst   : axi_pkg::BURST_INCR,
    decouple_rw : 1'b1,
    deburst     : 1'b0,
    serialize   : 1'b0
  };

  always_comb begin
    valid_o = '0;
    if (ctrl_reg2hw.next_id.re) begin
      valid_o = 1'b1;
      if (!ready_i) begin
        // Store the valid request and stall upstream
        // TODO config_res_o.raedy = 0;
      end
      // TODO stall ctrl_reg_req, ctrl_reg_rsp interface with ready_i
    end
  end

  assign dma_id_o = '0;

  // pragma translate_off
  integer cycle;
  integer transfer;
  integer size;
  integer f;
  string str;

  /* verilator lint_off BLKSEQ */
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cycle = 0;
      size = 0;
      transfer = 0;
    end else begin
      if (valid_o && ready_i) begin
        cycle = 0;
        transfer = 1;
        size = burst_req_o.num_bytes;
        str = $sformatf("[mempool_dma] Launch request of %08d bytes\n", size);
        f = $fopen("dma.log", "a");
        $fwrite(f, str);
        $fclose(f);
      end else begin
        cycle = cycle + 1;
      end

      if (transfer == 1 && trans_complete_i == 1) begin
        transfer = 0;
        str = "[mempool_dma] Finished request\n";
        str = $sformatf("%s[mempool_dma] Duration: %08d cycles, %08.8f bytes/cycle\n", str, cycle, size/cycle);
        f = $fopen("dma.log", "a");
        $fwrite(f, str);
        $fclose(f);
      end
    end
  end
  // pragma translate_on

endmodule : mempool_dma
