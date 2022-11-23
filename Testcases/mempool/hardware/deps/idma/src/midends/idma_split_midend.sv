// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Samuel Riedel <sriedel@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

module idma_split_midend #(
  parameter int unsigned DmaRegionWidth = 1, // [B] Region that one port covers in bytes
  parameter int unsigned DmaRegionStart = 32'h0000_0000,
  parameter int unsigned DmaRegionEnd   = 32'h1000_0000,
  parameter int unsigned AddrWidth      = 32,
  parameter type         burst_req_t    = logic,
  parameter type         meta_t         = logic
) (
  input  logic       clk_i,
  input  logic       rst_ni,
  // Slave
  input  burst_req_t burst_req_i,
  input  logic       valid_i,
  output logic       ready_o,
  output meta_t      meta_o,
  // Master
  output burst_req_t burst_req_o,
  output logic       valid_o,
  input  logic       ready_i,
  input  meta_t      meta_i
);

  localparam DmaRegionAddressBits = $clog2(DmaRegionWidth);

  typedef logic [AddrWidth-1:0] addr_t;

  addr_t start_addr, end_addr;
  logic req_valid;


  // Handle Metadata
  // Forward idle signal and count the trans_comlete signal
  logic [31:0] num_trans_d, num_trans_q;

  assign meta_o.backend_idle = meta_i.backend_idle;
  always_comb begin
    num_trans_d = num_trans_q;
    meta_o.trans_complete = 1'b0;
    if (req_valid) begin
      num_trans_d += 1;
    end
    if (meta_i.trans_complete) begin
      num_trans_d -= 1;
    end
    if (num_trans_q == 1 && num_trans_d == 0) begin
      meta_o.trans_complete = 1'b1;
    end
  end
  `FF(num_trans_q, num_trans_d, '0, clk_i, rst_ni)

  // Split requests
  always_comb begin
    if (($unsigned(burst_req_i.src) >= DmaRegionStart) && ($unsigned(burst_req_i.src) < DmaRegionEnd)) begin
      start_addr = burst_req_i.src;
    end else begin
      start_addr = burst_req_i.dst;
    end
    end_addr = start_addr + burst_req_i.num_bytes;
  end

  enum logic {Idle, Busy} state_d, state_q;
  burst_req_t req_d, req_q;

  `FFARN(state_q, state_d, Idle, clk_i, rst_ni)
  `FFARN(req_q, req_d, '0, clk_i, rst_ni)

  always_comb begin
    state_d = state_q;
    req_d = req_q;
    burst_req_o = '0;
    valid_o = 1'b0;
    ready_o = 1'b0;
    req_valid = 1'b0;

    unique case (state_q)
      Idle: begin
        if (valid_i) begin // Splitting required.
          if (DmaRegionWidth-start_addr[DmaRegionAddressBits-1:0] >= burst_req_i.num_bytes) begin
            // No splitting required, just forward
            burst_req_o = burst_req_i;
            valid_o = 1'b1;
            ready_o = ready_i;
            req_valid = ready_i;
          end else begin
            // Store and acknowledge
            req_d = burst_req_i;
            ready_o = 1'b1;
            // Feed through the first request
            burst_req_o = burst_req_i;
            // Modify it's size
            burst_req_o.num_bytes = DmaRegionWidth-start_addr[DmaRegionAddressBits-1:0];
            // Forward request
            valid_o = 1'b1;
            if (ready_i) begin
              // Increment the address and reduce the number of outstanding splits
              req_d.num_bytes -= DmaRegionWidth-start_addr[DmaRegionAddressBits-1:0];
              req_d.src += DmaRegionWidth-start_addr[DmaRegionAddressBits-1:0];
              req_d.dst += DmaRegionWidth-start_addr[DmaRegionAddressBits-1:0];
              req_valid = 1'b1;
            end
            state_d = Busy;
          end
        end
      end
      Busy: begin
        // Sent next burst from split.
        burst_req_o = req_q;
        valid_o = 1'b1;
        req_valid = ready_i;
        if (req_q.num_bytes <= DmaRegionWidth) begin
          // Last split
          if (ready_i) begin
            state_d = Idle;
          end
        end else begin
          // Clip size and increment address
          burst_req_o.num_bytes = DmaRegionWidth;
          if (ready_i) begin
            req_d.num_bytes = req_q.num_bytes - DmaRegionWidth;
            req_d.src = req_q.src + DmaRegionWidth;
            req_d.dst = req_q.dst + DmaRegionWidth;
          end
        end
      end
      default: /*do nothing*/;
    endcase
  end

  // pragma translate_off
  int f;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    automatic string str;
    if (rst_ni && valid_i && ready_o) begin
      str = "[idma_split_midend] Got request\n";
      str = $sformatf("%sSplit: Request in: From: 0x%8x To: 0x%8x with size %d\n", str, burst_req_i.src, burst_req_i.dst, burst_req_i.num_bytes);
      f = $fopen("dma.log", "a");
      $fwrite(f, str);
      $fclose(f);
    end
    if (rst_ni && valid_o && ready_i) begin
      str = $sformatf("Split: Out %6d: From: 0x%8x To: 0x%8x with size %d\n", num_trans_q, burst_req_o.src, burst_req_o.dst, burst_req_o.num_bytes);
      f = $fopen("dma.log", "a");
      $fwrite(f, str);
      $fclose(f);
    end
  end
  // pragma translate_on

endmodule
