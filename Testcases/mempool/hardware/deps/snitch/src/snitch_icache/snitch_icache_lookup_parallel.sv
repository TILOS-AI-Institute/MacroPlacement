// Copyright 2020 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Fabian Schuiki <fschuiki@iis.ee.ethz.ch>

/// An actual cache lookup.
module snitch_icache_lookup_parallel #(
    parameter snitch_icache_pkg::config_t CFG = '0
)(
    input  logic clk_i,
    input  logic rst_ni,

    input  logic flush_valid_i,
    output logic flush_ready_o,

    input  logic [CFG.FETCH_AW-1:0]     in_addr_i,
    input  logic [CFG.ID_WIDTH_REQ-1:0] in_id_i,
    input  logic                        in_valid_i,
    output logic                        in_ready_o,

    output logic [CFG.FETCH_AW-1:0]     out_addr_o,
    output logic [CFG.ID_WIDTH_REQ-1:0] out_id_o,
    output logic [CFG.SET_ALIGN-1:0]    out_set_o,
    output logic                        out_hit_o,
    output logic [CFG.LINE_WIDTH-1:0]   out_data_o,
    output logic                        out_error_o,
    output logic                        out_valid_o,
    input  logic                        out_ready_i,

    input  logic [CFG.COUNT_ALIGN-1:0]  write_addr_i,
    input  logic [CFG.SET_ALIGN-1:0]    write_set_i,
    input  logic [CFG.LINE_WIDTH-1:0]   write_data_i,
    input  logic [CFG.TAG_WIDTH-1:0]    write_tag_i,
    input  logic                        write_error_i,
    input  logic                        write_valid_i,
    output logic                        write_ready_o
);

    `ifndef SYNTHESIS
    initial assert(CFG != '0);
    `endif

    // Multiplex read and write access to the RAMs onto one port, prioritizing
    // write accesses.
    logic [CFG.COUNT_ALIGN-1:0] ram_addr                             ;
    logic [CFG.SET_COUNT-1:0]   ram_enable                           ;
    logic [CFG.LINE_WIDTH-1:0]  ram_wdata, ram_rdata [CFG.SET_COUNT] ;
    logic [CFG.TAG_WIDTH+1:0]   ram_wtag,  ram_rtag  [CFG.SET_COUNT] ;
    logic                       ram_write                            ;
    logic                       ram_write_q;
    logic [CFG.COUNT_ALIGN:0]   init_count_q;

    typedef struct packed {
      logic [CFG.SET_ALIGN-1:0]   cset;
      logic                       hit;
      logic [CFG.LINE_WIDTH-1:0]  data;
      logic                       error;
    } out_buffer_t;

    out_buffer_t data_d, data_q;
    logic        buffer_ready;
    logic        buffer_valid;

    always_comb begin : p_portmux
        write_ready_o = 0;
        in_ready_o = 0;

        ram_addr   = in_addr_i >> CFG.LINE_ALIGN;
        ram_wdata  = write_data_i;
        ram_wtag   = {1'b1, write_error_i, write_tag_i};
        ram_enable = '0;
        ram_write  = 1'b0;

        if (init_count_q != $unsigned(CFG.LINE_COUNT)) begin
            ram_addr   = init_count_q;
            ram_enable = '1;
            ram_write  = 1'b1;
            ram_wdata  = '0;
            ram_wtag   = '0;
        end else  if (write_valid_i) begin
            ram_addr   = write_addr_i;
            ram_enable = $unsigned(1 << write_set_i);
            ram_write  = 1'b1;
            write_ready_o = 1'b1;
        end else if (out_ready_i) begin
            ram_enable = in_valid_i ? '1 : '0;
            in_ready_o = 1'b1;
        end
    end

    assign flush_ready_o = flush_valid_i & (init_count_q == $unsigned(CFG.LINE_COUNT));

    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni)
            init_count_q <= '0;
        else if (flush_valid_i)
            init_count_q <= '0;
        else if (init_count_q != $unsigned(CFG.LINE_COUNT))
            init_count_q <= init_count_q + 1;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            ram_write_q <= 0;
        end else begin
            ram_write_q <= ram_write;
        end
    end

    // The address register keeps track of additional metadata alongside the
    // looked up tag and data.
    logic valid_q;
    logic [CFG.FETCH_AW-1:0] addr_q;
    logic [CFG.ID_WIDTH_REQ-1:0] id_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            valid_q <= 0;
        end else begin
            if (CFG.BUFFER_LOOKUP) begin
                valid_q <= in_valid_i && in_ready_o;
            end else if ((in_valid_i && in_ready_o) || out_ready_i) begin
                valid_q <= in_valid_i && in_ready_o;
            end
        end
    end

    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            addr_q <= '0;
            id_q   <= '0;
        end else if (in_valid_i && in_ready_o) begin
            addr_q <= in_addr_i;
            id_q   <= in_id_i;
        end
    end

    // Instantiate the RAM sets.
    for (genvar i = 0; i < CFG.SET_COUNT; i++) begin : g_sets
        tc_sram #(
          .NumWords (CFG.LINE_COUNT),
          .DataWidth (CFG.TAG_WIDTH+2),
          .ByteWidth (8),
          .NumPorts (1),
          .Latency (1)
        ) i_tag (
          .clk_i (clk_i),
          .rst_ni (rst_ni),
          .req_i (ram_enable[i]),
          .we_i (ram_write),
          .addr_i (ram_addr),
          .wdata_i (ram_wtag),
          .be_i ('1),
          .rdata_o (ram_rtag[i])
        );

        tc_sram #(
          .NumWords (CFG.LINE_COUNT),
          .DataWidth (CFG.LINE_WIDTH),
          .ByteWidth (8),
          .NumPorts (1),
          .Latency (1)
        ) i_data (
          .clk_i (clk_i),
          .rst_ni (rst_ni),
          .req_i (ram_enable[i]),
          .we_i (ram_write),
          .addr_i (ram_addr),
          .wdata_i (ram_wdata),
          .be_i ('1),
          .rdata_o (ram_rdata[i])
        );
    end

    // Determine which RAM line hit, and multiplex that data to the output.
    logic [CFG.TAG_WIDTH-1:0] required_tag;
    logic [CFG.SET_COUNT-1:0] line_hit;

    always_comb begin
        automatic logic [CFG.SET_COUNT-1:0] errors;
        required_tag = addr_q >> (CFG.LINE_ALIGN + CFG.COUNT_ALIGN);
        for (int i = 0; i < CFG.SET_COUNT; i++) begin
            line_hit[i] = ram_rtag[i][CFG.TAG_WIDTH+1] &&
              ram_rtag[i][CFG.TAG_WIDTH-1:0] == required_tag;
            errors[i] = ram_rtag[i][CFG.TAG_WIDTH] && line_hit[i];
        end
        data_d.hit = |line_hit & ~ram_write_q; // Don't let refills trigger "valid" lookups
        data_d.error = |errors;
    end

    always_comb begin
        for (int i = 0; i < CFG.LINE_WIDTH; i++) begin
            automatic logic [CFG.SET_COUNT-1:0] masked;
            for (int j = 0; j < CFG.SET_COUNT; j++)
                masked[j] = ram_rdata[j][i] & line_hit[j];
            data_d.data[i] = |masked;
        end
    end

    lzc #(.WIDTH(CFG.SET_COUNT)) i_lzc (
        .in_i     ( line_hit    ),
        .cnt_o    ( data_d.cset ),
        .empty_o  (             )
    );

    // Buffer response in case we are stalled
    if (CFG.BUFFER_LOOKUP) begin : gen_buffer
      fall_through_register #(
          .T          ( out_buffer_t )
      ) i_rsp_buffer (
          .clk_i      ( clk_i        ),
          .rst_ni     ( rst_ni       ),
          .clr_i      ( 1'b0         ),
          .testmode_i ( 1'b0         ),
          // Input port
          .valid_i    ( valid_q      ),
          .ready_o    ( buffer_ready ),
          .data_i     ( data_d       ),
          // Output port
          .valid_o    ( buffer_valid ),
          .ready_i    ( out_ready_i  ),
          .data_o     ( data_q       )
      );
    end else begin : gen_connection
      assign data_q = data_d;
      assign buffer_valid = valid_q;
      assign buffer_ready = 1'b1;
    end

    // Generate the output signals.
    assign out_addr_o  = addr_q;
    assign out_id_o    = id_q;
    assign out_set_o   = data_q.cset;
    assign out_hit_o   = data_q.hit;
    assign out_data_o  = data_q.data;
    assign out_error_o = data_q.error;
    assign out_valid_o = buffer_valid;

    // Assertions
    `include "common_cells/assertions.svh"
    `ASSERT(i_rsp_buffer_ready, (valid_q |-> buffer_ready), clk_i, !rst_ni)

endmodule
