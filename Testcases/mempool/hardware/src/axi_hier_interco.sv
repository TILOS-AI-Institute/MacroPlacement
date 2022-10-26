// Copyright 2021 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Samuel Riedel <sriedel@iis.ee.ethz.ch>

// Implement a hierarchical AXI interconnect. Below shows one level of the interconnect. This module
// recursively instantiates itself and creates a tree of interconnects, each node with `Radix` slave
// ports.
//
//           AXI Mux    Read-only     ID Width
//                      Cache         Converter
//            |‾╲
//  +-------->|  ╲
//            |   +     +-------+     +-------+
//  +-------->| M |     |       |     |       |
//            | U |---->|   $   |---->|   >   |---->
//            | X |     |       |     |       |
//            |   +     +-------+     +-------+
//  +-------->|  ╱
//            |_╱
//                 Internal      Cache
//  Slave type     type          type          Master type

module axi_hier_interco
  import mempool_pkg::ro_cache_ctrl_t;
#(
  parameter int unsigned NumSlvPorts    = 0,
  parameter int unsigned NumMstPorts    = 0,
  parameter int unsigned Radix          = 2,
  parameter int unsigned EnableCache    = 0,
  parameter int unsigned CacheLineWidth = 0,
  parameter int unsigned CacheSizeByte  = 0,
  parameter int unsigned CacheSets      = 0,
  parameter int unsigned AddrWidth      = 0,
  parameter int unsigned DataWidth      = 0,
  parameter int unsigned SlvIdWidth     = 0,
  parameter int unsigned MstIdWidth     = 0,
  parameter int unsigned UserWidth      = 0,
  parameter type         slv_req_t      = logic,
  parameter type         slv_resp_t     = logic,
  parameter type         mst_req_t      = logic,
  parameter type         mst_resp_t     = logic
) (
  input  logic                        clk_i,
  input  logic                        rst_ni,
  input  logic                        test_i,
  input  ro_cache_ctrl_t              ro_cache_ctrl_i,
  input  slv_req_t  [NumSlvPorts-1:0] slv_req_i,
  output slv_resp_t [NumSlvPorts-1:0] slv_resp_o,
  output mst_req_t  [NumMstPorts-1:0] mst_req_o,
  input  mst_resp_t [NumMstPorts-1:0] mst_resp_i
);

  ////////////////
  //  Typedefs  //
  ////////////////

  localparam int unsigned IntIdWidth   = SlvIdWidth + $clog2(NumSlvPorts);
  localparam int unsigned CacheIdWidth = EnableCache[0] ? IntIdWidth + 1: IntIdWidth;
  localparam int unsigned NrAddrRules  = mempool_pkg::ROCacheNumAddrRules;

  typedef logic [AddrWidth-1:0]    addr_t;
  typedef logic [DataWidth-1:0]    data_t;
  typedef logic [DataWidth/8-1:0]  strb_t;
  typedef logic [SlvIdWidth-1:0]   slv_id_t;
  typedef logic [MstIdWidth-1:0]   mst_id_t;
  typedef logic [IntIdWidth-1:0]   int_id_t;
  typedef logic [CacheIdWidth-1:0] cache_id_t;
  typedef logic [UserWidth-1:0]    user_t;

  `include "axi/typedef.svh"
  // Common AXI types
  `AXI_TYPEDEF_W_CHAN_T(w_t, data_t, strb_t, user_t);
  // Slave AXI types
  `AXI_TYPEDEF_AW_CHAN_T(slv_aw_t, addr_t, slv_id_t, user_t);
  `AXI_TYPEDEF_B_CHAN_T(slv_b_t, slv_id_t, user_t);
  `AXI_TYPEDEF_AR_CHAN_T(slv_ar_t, addr_t, slv_id_t, user_t);
  `AXI_TYPEDEF_R_CHAN_T(slv_r_t, data_t, slv_id_t, user_t);
  // Intermediate AXI types
  `AXI_TYPEDEF_AW_CHAN_T(int_aw_t, addr_t, int_id_t, user_t);
  `AXI_TYPEDEF_B_CHAN_T(int_b_t, int_id_t, user_t);
  `AXI_TYPEDEF_AR_CHAN_T(int_ar_t, addr_t, int_id_t, user_t);
  `AXI_TYPEDEF_R_CHAN_T(int_r_t, data_t, int_id_t, user_t);
  `AXI_TYPEDEF_REQ_T(int_req_t, int_aw_t, w_t, int_ar_t);
  `AXI_TYPEDEF_RESP_T(int_resp_t, int_b_t, int_r_t );
  // Cache AXI types
  `AXI_TYPEDEF_AW_CHAN_T(cache_aw_t, addr_t, cache_id_t, user_t);
  `AXI_TYPEDEF_B_CHAN_T(cache_b_t, cache_id_t, user_t);
  `AXI_TYPEDEF_AR_CHAN_T(cache_ar_t, addr_t, cache_id_t, user_t);
  `AXI_TYPEDEF_R_CHAN_T(cache_r_t, data_t, cache_id_t, user_t);
  `AXI_TYPEDEF_REQ_T(cache_req_t, cache_aw_t, w_t, cache_ar_t);
  `AXI_TYPEDEF_RESP_T(cache_resp_t, cache_b_t, cache_r_t );

  ///////////////
  //  Interco  //
  ///////////////

  // Recursive module to implement multiple hierarchy levels at once

  if (NumMstPorts >  NumSlvPorts) begin : gen_error
    $error("[axi_hier_interco] `NumMstPorts` must be bigger than `NumSlvPorts`.");
  end else if (NumMstPorts == NumSlvPorts) begin : gen_top_level
    // Top-level, connect the ports to the master ports
    for (genvar i = 0; i < NumMstPorts; i++) begin : gen_bypasses
      assign mst_req_o[i]  = slv_req_i[i];
      assign slv_resp_o[i] = mst_resp_i[i];
    end
  end else if (Radix <= 1) begin : gen_error
    $error("[axi_hier_interco] `Radix` must be bigger than 1.");
  end else if (NumSlvPorts > Radix) begin : gen_axi_level_recursive
    // More than one level missing. --> Recursively call this module
    // This level will contain `NumMuxes` interconnects
    localparam int unsigned NumMuxes = NumSlvPorts / Radix;
    if (NumMuxes * Radix != NumSlvPorts) begin : gen_error
      $error("[axi_hier_interco] `NumSlvPorts` mod `Radix` must be 0.");
    end else begin : gen_level
      slv_req_t  [NumMuxes-1:0] int_req;
      slv_resp_t [NumMuxes-1:0] int_resp;

      for (genvar i = 0; i < NumMuxes; i++) begin : gen_lower_level
        axi_hier_interco #(
          .NumSlvPorts    (Radix         ),
          .NumMstPorts    (1             ),
          .Radix          (Radix         ),
          .EnableCache    (EnableCache   ),
          .CacheLineWidth (CacheLineWidth),
          .CacheSizeByte  (CacheSizeByte ),
          .CacheSets      (CacheSets     ),
          .AddrWidth      (AddrWidth     ),
          .DataWidth      (DataWidth     ),
          .SlvIdWidth     (SlvIdWidth    ),
          .MstIdWidth     (SlvIdWidth    ),
          .UserWidth      (UserWidth     ),
          .slv_req_t      (slv_req_t     ),
          .slv_resp_t     (slv_resp_t    ),
          .mst_req_t      (slv_req_t     ),
          .mst_resp_t     (slv_resp_t    )
        ) i_axi_interco (
          .clk_i           (clk_i                       ),
          .rst_ni          (rst_ni                      ),
          .test_i          (test_i                      ),
          .ro_cache_ctrl_i (ro_cache_ctrl_i             ),
          .slv_req_i       (slv_req_i[i*Radix +: Radix] ),
          .slv_resp_o      (slv_resp_o[i*Radix +: Radix]),
          .mst_req_o       (int_req[i]                  ),
          .mst_resp_i      (int_resp[i]                 )
        );
      end

      axi_hier_interco #(
        .NumSlvPorts    (NumMuxes      ),
        .NumMstPorts    (NumMstPorts   ),
        .Radix          (Radix         ),
        .EnableCache    (EnableCache>>1),
        .CacheLineWidth (CacheLineWidth),
        .CacheSizeByte  (CacheSizeByte ),
        .CacheSets      (CacheSets     ),
        .AddrWidth      (AddrWidth     ),
        .DataWidth      (DataWidth     ),
        .SlvIdWidth     (SlvIdWidth    ),
        .MstIdWidth     (MstIdWidth    ),
        .UserWidth      (UserWidth     ),
        .slv_req_t      (slv_req_t     ),
        .slv_resp_t     (slv_resp_t    ),
        .mst_req_t      (mst_req_t     ),
        .mst_resp_t     (mst_resp_t    )
      ) i_axi_interco (
        .clk_i           (clk_i          ),
        .rst_ni          (rst_ni         ),
        .test_i          (test_i         ),
        .ro_cache_ctrl_i (ro_cache_ctrl_i),
        .slv_req_i       (int_req        ),
        .slv_resp_o      (int_resp       ),
        .mst_req_o       (mst_req_o      ),
        .mst_resp_i      (mst_resp_i     )
      );
    end
  end else if (NumSlvPorts <= Radix && NumMstPorts == 1) begin : gen_bottom_level

    // Intermediate AXI channel
    int_req_t    int_req;
    int_resp_t   int_resp;
    cache_req_t  cache_req;
    cache_resp_t cache_resp;

    axi_mux #(
      // AXI parameter and channel types
      .SlvAxiIDWidth (SlvIdWidth ), // AXI ID width, slave ports
      .slv_aw_chan_t (slv_aw_t   ), // AW Channel Type, slave ports
      .mst_aw_chan_t (int_aw_t   ), // AW Channel Type, master port
      .w_chan_t      (w_t        ), //  W Channel Type, all ports
      .slv_b_chan_t  (slv_b_t    ), //  B Channel Type, slave ports
      .mst_b_chan_t  (int_b_t    ), //  B Channel Type, master port
      .slv_ar_chan_t (slv_ar_t   ), // AR Channel Type, slave ports
      .mst_ar_chan_t (int_ar_t   ), // AR Channel Type, master port
      .slv_r_chan_t  (slv_r_t    ), //  R Channel Type, slave ports
      .mst_r_chan_t  (int_r_t    ), //  R Channel Type, master port
      .slv_req_t     (slv_req_t  ), // Slave port request type
      .slv_resp_t    (slv_resp_t ), // Slave port response type
      .mst_req_t     (int_req_t  ), // Master ports request type
      .mst_resp_t    (int_resp_t ), // Master ports response type
      .NoSlvPorts    (NumSlvPorts), // Number of slave ports
      // Maximum number of outstanding transactions per write
      .MaxWTrans     (8          ),
      // If enabled, this multiplexer is purely combinatorial
      .FallThrough   (1'b0       ),
      // add spill register on write master ports, adds a cycle latency on write channels
      .SpillAw       (1'b1       ),
      .SpillW        (1'b1       ),
      .SpillB        (1'b1       ),
      // add spill register on read master ports, adds a cycle latency on read channels
      .SpillAr       (1'b1       ),
      .SpillR        (1'b1       )
    ) i_axi_mux (
      .clk_i       (clk_i     ),
      .rst_ni      (rst_ni    ),
      .test_i      (test_i    ),
      .slv_reqs_i  (slv_req_i ),
      .slv_resps_o (slv_resp_o),
      .mst_req_o   (int_req   ),
      .mst_resp_i  (int_resp  )
    );

    if (EnableCache[0]) begin: gen_ro_cache
      localparam int unsigned LineCount = CacheSizeByte/(CacheSets*CacheLineWidth/8);
      snitch_read_only_cache #(
        .LineWidth    (CacheLineWidth),
        .LineCount    (LineCount     ),
        .SetCount     (CacheSets     ),
        .AxiAddrWidth (AddrWidth     ),
        .AxiDataWidth (DataWidth     ),
        .AxiIdWidth   (IntIdWidth    ),
        .AxiUserWidth (UserWidth     ),
        .MaxTrans     (32'd16        ),
        .NrAddrRules  (NrAddrRules   ),
        .slv_req_t    (int_req_t     ),
        .slv_rsp_t    (int_resp_t    ),
        .mst_req_t    (cache_req_t   ),
        .mst_rsp_t    (cache_resp_t  )
      ) i_snitch_read_only_cache (
        .clk_i         (clk_i                      ),
        .rst_ni        (rst_ni                     ),
        .enable_i      (ro_cache_ctrl_i.enable     ),
        .flush_valid_i (ro_cache_ctrl_i.flush_valid),
        .flush_ready_o (/*unused*/                 ),
        .start_addr_i  (ro_cache_ctrl_i.start_addr ),
        .end_addr_i    (ro_cache_ctrl_i.end_addr   ),
        .axi_slv_req_i (int_req                    ),
        .axi_slv_rsp_o (int_resp                   ),
        .axi_mst_req_o (cache_req                  ),
        .axi_mst_rsp_i (cache_resp                 )
      );
    end else begin: gen_no_ro_cache
      assign cache_req = int_req;
      assign int_resp  = cache_resp;
    end

    axi_id_remap #(
      .AxiSlvPortIdWidth    (CacheIdWidth ),
      .AxiSlvPortMaxUniqIds (2**MstIdWidth),
      .AxiMaxTxnsPerId      (4            ),
      .AxiMstPortIdWidth    (MstIdWidth   ),
      .slv_req_t            (cache_req_t  ),
      .slv_resp_t           (cache_resp_t ),
      .mst_req_t            (mst_req_t    ),
      .mst_resp_t           (mst_resp_t   )
    ) i_axi_id_remap (
      .clk_i      (clk_i     ),
      .rst_ni     (rst_ni    ),
      .slv_req_i  (cache_req ),
      .slv_resp_o (cache_resp),
      .mst_req_o  (mst_req_o ),
      .mst_resp_i (mst_resp_i)
    );

    // Check all the AXI widths
    if ($bits(slv_req_i[0].aw.addr) != AddrWidth)
      $error("[axi_hier_interco] `slv_req_i.aw.addr` does not match AddrWidth.");
    if ($bits(slv_req_i[0].w.data) != DataWidth)
      $error("[axi_hier_interco] `slv_req_i.w.data` does not match DataWidth.");
    if ($bits(slv_req_i[0].aw.id) != SlvIdWidth)
      $error("[axi_hier_interco] `slv_req_i.aw.id` does not match SlvIdWidth.");
    if ($bits(slv_req_i[0].aw.user) != UserWidth)
      $error("[axi_hier_interco] `slv_req_i.aw.user` does not match UserWidth.");

    if ($bits(mst_req_o[0].aw.addr) != AddrWidth)
      $error("[axi_hier_interco] `mst_req_o.aw.addr` does not match AddrWidth.");
    if ($bits(mst_req_o[0].w.data) != DataWidth)
      $error("[axi_hier_interco] `mst_req_o.w.data` does not match DataWidth.");
    if ($bits(mst_req_o[0].aw.id) != MstIdWidth)
      $error("[axi_hier_interco] `mst_req_o.aw.id` does not match MstIdWidth.");
    if ($bits(mst_req_o[0].aw.user) != UserWidth)
      $error("[axi_hier_interco] `mst_req_o.aw.user` does not match UserWidth.");

    if ($bits(int_req.aw.addr) != AddrWidth)
      $error("[axi_hier_interco] `int_req.aw.addr` does not match AddrWidth.");
    if ($bits(int_req.w.data) != DataWidth)
      $error("[axi_hier_interco] `int_req.w.data` does not match DataWidth.");
    if ($bits(int_req.aw.id) != IntIdWidth)
      $error("[axi_hier_interco] `int_req.aw.id` does not match IntIdWidth.");
    if ($bits(int_req.aw.user) != UserWidth)
      $error("[axi_hier_interco] `int_req.aw.user` does not match UserWidth.");

    if ($bits(cache_req.aw.addr) != AddrWidth)
      $error("[axi_hier_interco] `cache_req.aw.addr` does not match AddrWidth.");
    if ($bits(cache_req.w.data) != DataWidth)
      $error("[axi_hier_interco] `cache_req.w.data` does not match DataWidth.");
    if ($bits(cache_req.aw.id) != CacheIdWidth)
      $error("[axi_hier_interco] `cache_req.aw.id` does not match CacheIdWidth.");
    if ($bits(cache_req.aw.user) != UserWidth)
      $error("[axi_hier_interco] `cache_req.aw.user` does not match UserWidth.");
  end else begin: gen_error
    $error("[axi_hier_interco] Cannot build a tree with those parameters.");
  end
endmodule
