// Copyright 2021 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>
//         Samuel Riedel <sriedel@iis.ee.ethz.ch>

/// Serve read memory requests from a read-only cache.
/// The cacheable region can be runtime configured. All writes and read
/// requests outside the configured regions will be forwarded.
module snitch_read_only_cache #(
  /// Cache Line Width
  parameter int unsigned LineWidth    = -1,
  /// The number of cache lines per set. Power of two; >= 2.
  parameter int unsigned LineCount    = -1,
  /// The set associativity of the cache. Power of two; >= 1.
  parameter int unsigned SetCount     = 1,
  /// AXI address width
  parameter int unsigned AxiAddrWidth = 0,
  /// AXI data width
  parameter int unsigned AxiDataWidth = 0,
  /// AXI id width
  parameter int unsigned AxiIdWidth   = 0,
  /// AXI user width
  parameter int unsigned AxiUserWidth = 0,
  parameter int unsigned MaxTrans     = 0,
  parameter int unsigned NrAddrRules  = 1,
  parameter type slv_req_t = logic,
  parameter type slv_rsp_t = logic,
  parameter type mst_req_t = logic,
  parameter type mst_rsp_t = logic
) (
  input  logic                                     clk_i,
  input  logic                                     rst_ni,
  input  logic                                     enable_i,
  input  logic                                     flush_valid_i,
  output logic                                     flush_ready_o,
  input  logic [NrAddrRules-1:0][AxiAddrWidth-1:0] start_addr_i,
  input  logic [NrAddrRules-1:0][AxiAddrWidth-1:0] end_addr_i,
  input  slv_req_t                                 axi_slv_req_i,
  output slv_rsp_t                                 axi_slv_rsp_o,
  output mst_req_t                                 axi_mst_req_o,
  input  mst_rsp_t                                 axi_mst_rsp_i
);

  `include "axi/typedef.svh"
  `include "common_cells/registers.svh"
  import cf_math_pkg::idx_width;

  // Check for supported parameters
  if (AxiDataWidth < 32)
    $error("snitch_read_only_cache: AxiDataWidth must be larger than 32.");
  if (AxiDataWidth > LineWidth)
    $error("snitch_read_only_cache: LineWidth must be larger than/equal to AxiDataWidth.");
  if (NrAddrRules < 1)
    $error("snitch_read_only_cache: NrAddrRules must be larger than/equal to 1.");
  if (MaxTrans < 1)
    $error("snitch_read_only_cache: MaxTrans must be larger than/equal to 1.");

  // --------------------------------------------------
  // AXI Demux
  // --------------------------------------------------
  localparam int unsigned NoMstPorts = 2;

  typedef logic [idx_width(NoMstPorts)-1:0] index_t;
  typedef enum index_t {
    Cache  = 1,
    Bypass = 0
  } index_e;

  typedef logic [AxiIdWidth-1:0] id_t;
  typedef logic [AxiIdWidth:0] mst_id_t;
  typedef logic [AxiAddrWidth-1:0] addr_t;
  typedef logic [AxiDataWidth-1:0] data_t;
  typedef logic [AxiDataWidth/8-1:0] strb_t;
  typedef logic [AxiUserWidth-1:0] user_t;

  `AXI_TYPEDEF_ALL(axi, addr_t, id_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_ALL(axi_mst, addr_t, mst_id_t, data_t, strb_t, user_t)

  axi_req_t [1:0] demux_req;
  axi_resp_t [1:0] demux_rsp;

  axi_req_t refill_req;
  axi_resp_t refill_rsp;

  index_t slv_aw_select;
  index_t slv_ar_select, slv_ar_select_q;
  index_t slv_ar_waiting;
  index_t dec_ar;

  axi_demux #(
    .AxiIdWidth  ( AxiIdWidth    ),
    .aw_chan_t   ( axi_aw_chan_t ),
    .w_chan_t    ( axi_w_chan_t  ),
    .b_chan_t    ( axi_b_chan_t  ),
    .ar_chan_t   ( axi_ar_chan_t ),
    .r_chan_t    ( axi_r_chan_t  ),
    .axi_req_t   ( axi_req_t     ),
    .axi_resp_t  ( axi_resp_t    ),
    .NoMstPorts  ( NoMstPorts    ),
    .MaxTrans    ( MaxTrans      ),
    .AxiLookBits ( AxiIdWidth    ),
    .FallThrough ( 1'b1          ),
    .SpillAw     ( 1'b0          ),
    .SpillW      ( 1'b0          ),
    .SpillB      ( 1'b0          ),
    .SpillAr     ( 1'b0          ),
    .SpillR      ( 1'b0          )
  ) i_axi_demux (
    .clk_i,
    .rst_ni,
    .test_i          ( 1'b0          ),
    .slv_req_i       ( axi_slv_req_i ),
    .slv_aw_select_i ( slv_aw_select ),
    .slv_ar_select_i ( slv_ar_select ),
    .slv_resp_o      ( axi_slv_rsp_o ),
    .mst_reqs_o      ( demux_req     ),
    .mst_resps_i     ( demux_rsp     )
  );

  typedef struct packed {
    int unsigned idx;
    addr_t       start_addr;
    addr_t       end_addr;
  } rule_t;

  rule_t [NrAddrRules-1:0] addr_map;

  for (genvar i = 0; i < NrAddrRules; i++) begin : gen_addr_map
    assign addr_map[i] = '{
      idx: Cache,
      start_addr: start_addr_i[i],
      end_addr: end_addr_i[i]
    };
  end

  addr_decode #(
    .NoIndices ( NoMstPorts  ),
    .NoRules   ( NrAddrRules ),
    .addr_t    ( addr_t      ),
    .rule_t    ( rule_t      )
  ) i_axi_aw_decode (
    .addr_i           ( axi_slv_req_i.ar.addr ),
    .addr_map_i       ( addr_map              ),
    .idx_o            ( dec_ar                ),
    .dec_valid_o      (                       ),
    .dec_error_o      (                       ),
    .en_default_idx_i ( 1'b1                  ),
    .default_idx_i    ( Bypass                )
  );

  // `AW` always bypass
  assign slv_aw_select = Bypass;

  // `AR` select logic
  `FF(slv_ar_select_q, slv_ar_select, Bypass, clk_i, rst_ni)
  `FF(slv_ar_waiting, axi_slv_req_i.ar_valid && !axi_slv_rsp_o.ar_ready, '0, clk_i, rst_ni)

  always_comb begin
    // Select cache based on address region
    slv_ar_select = dec_ar;
    // Bypass all atomic requests
    if (axi_slv_req_i.ar.lock) begin
      slv_ar_select = Bypass;
    end
    // Wrapping bursts are currently not supported
    if (axi_slv_req_i.ar.burst == axi_pkg::BURST_WRAP) begin
      slv_ar_select = Bypass;
    end
    // Only accept bursts that use full AXI width
    if (axi_slv_req_i.ar.len && (axi_slv_req_i.ar.size < $clog2(AxiDataWidth/8))) begin
      slv_ar_select = Bypass;
    end
    // Bypass cache if disabled
    if (!enable_i) begin
      slv_ar_select = Bypass;
    end
    // Keep the select signal stable if the request was not accepted
    if(slv_ar_waiting) begin
      slv_ar_select = slv_ar_select_q;
    end
  end

  // --------------------------------------------------
  // Cache Logic
  // --------------------------------------------------
  localparam int unsigned PendingCount = MaxTrans;
  localparam snitch_icache_pkg::config_t CFG = '{
    LINE_WIDTH:         LineWidth,
    LINE_COUNT:         LineCount,
    SET_COUNT:          SetCount,
    PENDING_COUNT:      PendingCount,
    FETCH_AW:           AxiAddrWidth,
    FETCH_DW:           AxiDataWidth,
    FILL_AW:            AxiAddrWidth,
    FILL_DW:            AxiDataWidth,
    L1_TAG_SCM:         0, // Unused here
    EARLY_LATCH:        0, // Unused here
    BUFFER_LOOKUP:      1, // Mandatory here
    GUARANTEE_ORDERING: 1, // Mandatory here

    FETCH_ALIGN:   $clog2(AxiDataWidth/8),
    FILL_ALIGN:    $clog2(AxiDataWidth/8),
    LINE_ALIGN:    $clog2(LineWidth/8),
    COUNT_ALIGN:   cf_math_pkg::idx_width(LineCount),
    SET_ALIGN:     cf_math_pkg::idx_width(SetCount),
    TAG_WIDTH:     AxiAddrWidth - $clog2(LineWidth/8) - $clog2(LineCount) + 1,
    ID_WIDTH_REQ:  AxiIdWidth,
    ID_WIDTH_RESP: 2**AxiIdWidth,
    PENDING_IW:    $clog2(PendingCount),
    default:       0
  };

  logic [CFG.FETCH_AW-1:0]      in_addr;
  logic [CFG.ID_WIDTH_REQ-1:0]  in_id;
  logic                         in_valid;
  logic                         in_ready;

  logic [CFG.LINE_WIDTH-1:0]    in_rsp_data;
  logic                         in_rsp_error;
  logic [CFG.ID_WIDTH_RESP-1:0] in_rsp_id;
  logic                         in_rsp_valid;
  logic                         in_rsp_ready;

  logic [CFG.FETCH_AW-1:0]      lookup_addr;
  logic [CFG.ID_WIDTH_REQ-1:0]  lookup_id;
  logic [CFG.SET_ALIGN-1:0]     lookup_set;
  logic                         lookup_hit;
  logic [CFG.LINE_WIDTH-1:0]    lookup_data;
  logic                         lookup_error;
  logic                         lookup_valid;
  logic                         lookup_ready;

  logic                         handler_req_valid;
  logic                         handler_req_ready;
  logic [CFG.FETCH_AW-1:0]      handler_req_addr;
  logic [CFG.PENDING_IW-1:0]    handler_req_id;

  logic [CFG.LINE_WIDTH-1:0]    handler_rsp_data;
  logic                         handler_rsp_error;
  logic [CFG.PENDING_IW-1:0]    handler_rsp_id;
  logic                         handler_rsp_valid;
  logic                         handler_rsp_ready;

  logic [CFG.COUNT_ALIGN-1:0]   write_addr;
  logic [CFG.SET_ALIGN-1:0]     write_set;
  logic [CFG.LINE_WIDTH-1:0]    write_data;
  logic [CFG.TAG_WIDTH-1:0]     write_tag;
  logic                         write_error;
  logic                         write_valid;
  logic                         write_ready;

  // The axi_to_cache module converts AXI requests to cache requests and
  // reconstructs AXI responses from the cache's responses
  snitch_axi_to_cache #(
    .MaxTrans ( MaxTrans   ),
    .req_t    ( axi_req_t  ),
    .resp_t   ( axi_resp_t ),
    .CFG      ( CFG        )
  ) i_axi_to_cache (
    .clk_i,
    .rst_ni,
    // Cache request
    .req_addr_o  ( in_addr          ),
    .req_id_o    ( in_id            ),
    .req_valid_o ( in_valid         ),
    .req_ready_i ( in_ready         ),
    // Cache response
    .rsp_data_i  ( in_rsp_data      ),
    .rsp_error_i ( in_rsp_error     ),
    .rsp_id_i    ( in_rsp_id        ),
    .rsp_valid_i ( in_rsp_valid     ),
    .rsp_ready_o ( in_rsp_ready     ),
    // AXI
    .slv_req_i   ( demux_req[Cache] ),
    .slv_rsp_o   ( demux_rsp[Cache] )
  );

  // The lookup module contains the actual cache RAMs and performs lookups.
  snitch_icache_lookup_parallel #(CFG) i_lookup (
    .clk_i,
    .rst_ni,

    .flush_valid_i ( flush_valid_i ),
    .flush_ready_o ( flush_ready_o ),

    .in_addr_i     ( in_addr       ),
    .in_id_i       ( in_id         ),
    .in_valid_i    ( in_valid      ),
    .in_ready_o    ( in_ready      ),

    .out_addr_o    ( lookup_addr   ),
    .out_id_o      ( lookup_id     ),
    .out_set_o     ( lookup_set    ),
    .out_hit_o     ( lookup_hit    ),
    .out_data_o    ( lookup_data   ),
    .out_error_o   ( lookup_error  ),
    .out_valid_o   ( lookup_valid  ),
    .out_ready_i   ( lookup_ready  ),

    .write_addr_i  ( write_addr    ),
    .write_set_i   ( write_set     ),
    .write_data_i  ( write_data    ),
    .write_tag_i   ( write_tag     ),
    .write_error_i ( write_error   ),
    .write_valid_i ( write_valid   ),
    .write_ready_o ( write_ready   )
  );

  // The handler module deals with the result of the lookup. It also
  // keeps track of the pending refills and ensures that no redundant memory
  // requests are made. Upon refill completion, it sends a new tag/data item
  // to the lookup module and sends the final cache response.
  snitch_icache_handler #(CFG) i_handler (
    .clk_i,
    .rst_ni,

    .in_req_addr_i   ( lookup_addr       ),
    .in_req_id_i     ( lookup_id         ),
    .in_req_set_i    ( lookup_set        ),
    .in_req_hit_i    ( lookup_hit        ),
    .in_req_data_i   ( lookup_data       ),
    .in_req_error_i  ( lookup_error      ),
    .in_req_valid_i  ( lookup_valid      ),
    .in_req_ready_o  ( lookup_ready      ),

    .in_rsp_data_o   ( in_rsp_data       ),
    .in_rsp_error_o  ( in_rsp_error      ),
    .in_rsp_id_o     ( in_rsp_id         ),
    .in_rsp_valid_o  ( in_rsp_valid      ),
    .in_rsp_ready_i  ( in_rsp_ready      ),

    .write_addr_o    ( write_addr        ),
    .write_set_o     ( write_set         ),
    .write_data_o    ( write_data        ),
    .write_tag_o     ( write_tag         ),
    .write_error_o   ( write_error       ),
    .write_valid_o   ( write_valid       ),
    .write_ready_i   ( write_ready       ),

    .out_req_addr_o  ( handler_req_addr  ),
    .out_req_id_o    ( handler_req_id    ),
    .out_req_valid_o ( handler_req_valid ),
    .out_req_ready_i ( handler_req_ready ),

    .out_rsp_data_i  ( handler_rsp_data  ),
    .out_rsp_error_i ( handler_rsp_error ),
    .out_rsp_id_i    ( handler_rsp_id    ),
    .out_rsp_valid_i ( handler_rsp_valid ),
    .out_rsp_ready_o ( handler_rsp_ready )
  );

  // The cache refill module emits AXI transactions.
  snitch_icache_refill #(
    .CFG       ( CFG        ),
    .axi_req_t ( axi_req_t  ),
    .axi_rsp_t ( axi_resp_t )
  ) i_refill (
    .clk_i,
    .rst_ni,

    .in_req_addr_i   ( handler_req_addr  ),
    .in_req_id_i     ( handler_req_id    ),
    .in_req_bypass_i ( 1'b0              ),
    .in_req_valid_i  ( handler_req_valid ),
    .in_req_ready_o  ( handler_req_ready ),

    .in_rsp_data_o   ( handler_rsp_data  ),
    .in_rsp_error_o  ( handler_rsp_error ),
    .in_rsp_id_o     ( handler_rsp_id    ),
    .in_rsp_bypass_o ( /* left open */   ),
    .in_rsp_valid_o  ( handler_rsp_valid ),
    .in_rsp_ready_i  ( handler_rsp_ready ),

    .axi_req_o       ( refill_req        ),
    .axi_rsp_i       ( refill_rsp        )
  );

  // --------------------------------------------------
  // AXI Mux
  // --------------------------------------------------
  axi_mux #(
    .SlvAxiIDWidth ( AxiIdWidth        ),
    .slv_aw_chan_t ( axi_aw_chan_t     ),
    .mst_aw_chan_t ( axi_mst_aw_chan_t ),
    .w_chan_t      ( axi_w_chan_t      ),
    .slv_b_chan_t  ( axi_b_chan_t      ),
    .mst_b_chan_t  ( axi_mst_b_chan_t  ),
    .slv_ar_chan_t ( axi_ar_chan_t     ),
    .mst_ar_chan_t ( axi_mst_ar_chan_t ),
    .slv_r_chan_t  ( axi_r_chan_t      ),
    .mst_r_chan_t  ( axi_mst_r_chan_t  ),
    .slv_req_t     ( axi_req_t         ),
    .slv_resp_t    ( axi_resp_t        ),
    .mst_req_t     ( axi_mst_req_t     ),
    .mst_resp_t    ( axi_mst_resp_t    ),
    .NoSlvPorts    ( NoMstPorts        ),
    .MaxWTrans     ( MaxTrans          ),
    .FallThrough   ( 1'b1              ),
    .SpillAw       ( 1'b0              ),
    .SpillW        ( 1'b0              ),
    .SpillB        ( 1'b0              ),
    .SpillAr       ( 1'b0              ),
    .SpillR        ( 1'b0              )
  ) i_axi_mux (
    .clk_i,
    .rst_ni,
    .test_i      ( 1'b0                            ),
    .slv_reqs_i  ( {refill_req, demux_req[Bypass]} ),
    .slv_resps_o ( {refill_rsp, demux_rsp[Bypass]} ),
    .mst_req_o   ( axi_mst_req_o                   ),
    .mst_resp_i  ( axi_mst_rsp_i                   )
  );

endmodule
