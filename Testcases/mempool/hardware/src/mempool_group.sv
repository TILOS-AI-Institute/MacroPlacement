// Copyright 2021 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

`include "mempool/mempool.svh"
`include "reqrsp_interface/typedef.svh"
`include "common_cells/registers.svh"

module mempool_group
  import mempool_pkg::*;
  import cf_math_pkg::idx_width;
#(
  // TCDM
  parameter addr_t       TCDMBaseAddr = 32'b0,
  // Boot address
  parameter logic [31:0] BootAddr     = 32'h0000_1000
) (
  // Clock and reset
  input  logic                                                    clk_i,
  input  logic                                                    rst_ni,
  input  logic                                                    testmode_i,
  // Scan chain
  input  logic                                                    scan_enable_i,
  input  logic                                                    scan_data_i,
  output logic                                                    scan_data_o,
  // Group ID
  input  logic [idx_width(NumGroups)-1:0]                         group_id_i,
  // TCDM Master interfaces
  output `STRUCT_VECT(tcdm_slave_req_t,   [NumGroups-1:1][NumTilesPerGroup-1:0]) tcdm_master_req_o,
  output logic                            [NumGroups-1:1][NumTilesPerGroup-1:0]  tcdm_master_req_valid_o,
  input  logic                            [NumGroups-1:1][NumTilesPerGroup-1:0]  tcdm_master_req_ready_i,
  input  `STRUCT_VECT(tcdm_master_resp_t, [NumGroups-1:1][NumTilesPerGroup-1:0]) tcdm_master_resp_i,
  input  logic                            [NumGroups-1:1][NumTilesPerGroup-1:0]  tcdm_master_resp_valid_i,
  output logic                            [NumGroups-1:1][NumTilesPerGroup-1:0]  tcdm_master_resp_ready_o,
  // TCDM Slave interfaces
  input  `STRUCT_VECT(tcdm_slave_req_t,   [NumGroups-1:1][NumTilesPerGroup-1:0]) tcdm_slave_req_i,
  input  logic                            [NumGroups-1:1][NumTilesPerGroup-1:0]  tcdm_slave_req_valid_i,
  output logic                            [NumGroups-1:1][NumTilesPerGroup-1:0]  tcdm_slave_req_ready_o,
  output `STRUCT_VECT(tcdm_master_resp_t, [NumGroups-1:1][NumTilesPerGroup-1:0]) tcdm_slave_resp_o,
  output logic                            [NumGroups-1:1][NumTilesPerGroup-1:0]  tcdm_slave_resp_valid_o,
  input  logic                            [NumGroups-1:1][NumTilesPerGroup-1:0]  tcdm_slave_resp_ready_i,
  // Wake up interface
  input  logic                            [NumCoresPerGroup-1:0]                 wake_up_i,
  // RO-Cache configuration
  input  `STRUCT_PORT(ro_cache_ctrl_t)                                           ro_cache_ctrl_i,
  // DMA request
  input  `STRUCT_PORT(dma_req_t)                                                 dma_req_i,
  input  logic                                                                   dma_req_valid_i,
  output logic                                                                   dma_req_ready_o,
  // DMA status
  output `STRUCT_PORT(dma_meta_t)                                                dma_meta_o,
   // AXI Interface
  output `STRUCT_VECT(axi_tile_req_t,     [NumAXIMastersPerGroup-1:0])           axi_mst_req_o,
  input  `STRUCT_VECT(axi_tile_resp_t,    [NumAXIMastersPerGroup-1:0])           axi_mst_resp_i
);

  /*****************
   *  Definitions  *
   *****************/

  typedef logic [idx_width(NumTiles)-1:0] tile_id_t;

  /*********************
   *  Control Signals  *
   *********************/
  logic [NumCoresPerGroup-1:0] wake_up_q;
  `FF(wake_up_q, wake_up_i, '0, clk_i, rst_ni);

  ro_cache_ctrl_t ro_cache_ctrl_q;
  `FF(ro_cache_ctrl_q, ro_cache_ctrl_i, ro_cache_ctrl_default, clk_i, rst_ni);

  /**********************
   *  Ports to structs  *
   **********************/

  // The ports might be structs flattened to vectors. To access the structs'
  // internal signals, assign the flattened vectors back to structs.
  tcdm_slave_req_t   [NumGroups-1:1][NumTilesPerGroup-1:0] tcdm_master_req_s;
  tcdm_master_resp_t [NumGroups-1:1][NumTilesPerGroup-1:0] tcdm_slave_resp_s;

  for (genvar r = 1; r < NumGroups; r++) begin: gen_tcdm_struct
    assign tcdm_master_req_o[r] = tcdm_master_req_s[r];
    assign tcdm_slave_resp_o[r] = tcdm_slave_resp_s[r];
  end: gen_tcdm_struct

  /***********
   *  Tiles  *
   ***********/

  // TCDM interfaces
  tcdm_master_req_t  [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_req;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_req_valid;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_req_ready;
  tcdm_slave_req_t   [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_req;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_req_valid;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_req_ready;
  tcdm_master_resp_t [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_resp;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_resp_valid;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_resp_ready;
  tcdm_slave_resp_t  [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_resp;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_resp_valid;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_resp_ready;
  // DMA interfaces
  tcdm_dma_req_t  [NumTilesPerGroup-1:0] tcdm_dma_req;
  logic           [NumTilesPerGroup-1:0] tcdm_dma_req_valid;
  logic           [NumTilesPerGroup-1:0] tcdm_dma_req_ready;
  tcdm_dma_resp_t [NumTilesPerGroup-1:0] tcdm_dma_resp;
  logic           [NumTilesPerGroup-1:0] tcdm_dma_resp_valid;
  logic           [NumTilesPerGroup-1:0] tcdm_dma_resp_ready;

  // Connect the IOs to the tiles' signals
  assign tcdm_master_resp[NumGroups-1:1]         = tcdm_master_resp_i[NumGroups-1:1];
  assign tcdm_master_resp_valid[NumGroups-1:1]   = tcdm_master_resp_valid_i[NumGroups-1:1];
  assign tcdm_master_resp_ready_o[NumGroups-1:1] = tcdm_master_resp_ready[NumGroups-1:1];
  assign tcdm_slave_req[NumGroups-1:1]           = tcdm_slave_req_i[NumGroups-1:1];
  assign tcdm_slave_req_valid[NumGroups-1:1]     = tcdm_slave_req_valid_i[NumGroups-1:1];
  assign tcdm_slave_req_ready_o[NumGroups-1:1]   = tcdm_slave_req_ready[NumGroups-1:1];

  // AXI interfaces
  axi_tile_req_t  [NumTilesPerGroup-1:0] axi_tile_req;
  axi_tile_resp_t [NumTilesPerGroup-1:0] axi_tile_resp;
  axi_tile_req_t  [NumDmasPerGroup-1:0]  axi_dma_req;
  axi_tile_resp_t [NumDmasPerGroup-1:0]  axi_dma_resp;

  for (genvar t = 0; unsigned'(t) < NumTilesPerGroup; t++) begin: gen_tiles
    tile_id_t id;
    assign id = (group_id_i << $clog2(NumTilesPerGroup)) | t[idx_width(NumTilesPerGroup)-1:0];

    tcdm_master_req_t  [NumGroups-1:0] tran_tcdm_master_req;
    logic              [NumGroups-1:0] tran_tcdm_master_req_valid;
    logic              [NumGroups-1:0] tran_tcdm_master_req_ready;
    tcdm_slave_req_t   [NumGroups-1:0] tran_tcdm_slave_req;
    logic              [NumGroups-1:0] tran_tcdm_slave_req_valid;
    logic              [NumGroups-1:0] tran_tcdm_slave_req_ready;
    tcdm_master_resp_t [NumGroups-1:0] tran_tcdm_master_resp;
    logic              [NumGroups-1:0] tran_tcdm_master_resp_valid;
    logic              [NumGroups-1:0] tran_tcdm_master_resp_ready;
    tcdm_slave_resp_t  [NumGroups-1:0] tran_tcdm_slave_resp;
    logic              [NumGroups-1:0] tran_tcdm_slave_resp_valid;
    logic              [NumGroups-1:0] tran_tcdm_slave_resp_ready;

    mempool_tile #(
      .TCDMBaseAddr(TCDMBaseAddr),
      .BootAddr    (BootAddr    )
    ) i_tile (
      .clk_i                   (clk_i                                          ),
      .rst_ni                  (rst_ni                                         ),
      .scan_enable_i           (scan_enable_i                                  ),
      .scan_data_i             (/* Unconnected */                              ),
      .scan_data_o             (/* Unconnected */                              ),
      .tile_id_i               (id                                             ),
      // TCDM Master interfaces
      .tcdm_master_req_o       (tran_tcdm_master_req                           ),
      .tcdm_master_req_valid_o (tran_tcdm_master_req_valid                     ),
      .tcdm_master_req_ready_i (tran_tcdm_master_req_ready                     ),
      .tcdm_master_resp_i      (tran_tcdm_master_resp                          ),
      .tcdm_master_resp_valid_i(tran_tcdm_master_resp_valid                    ),
      .tcdm_master_resp_ready_o(tran_tcdm_master_resp_ready                    ),
      // TCDM banks interface
      .tcdm_slave_req_i        (tran_tcdm_slave_req                            ),
      .tcdm_slave_req_valid_i  (tran_tcdm_slave_req_valid                      ),
      .tcdm_slave_req_ready_o  (tran_tcdm_slave_req_ready                      ),
      .tcdm_slave_resp_o       (tran_tcdm_slave_resp                           ),
      .tcdm_slave_resp_valid_o (tran_tcdm_slave_resp_valid                     ),
      .tcdm_slave_resp_ready_i (tran_tcdm_slave_resp_ready                     ),
      // TCDM DMA interfaces
      .tcdm_dma_req_i          (tcdm_dma_req[t]                                ),
      .tcdm_dma_req_valid_i    (tcdm_dma_req_valid[t]                          ),
      .tcdm_dma_req_ready_o    (tcdm_dma_req_ready[t]                          ),
      .tcdm_dma_resp_o         (tcdm_dma_resp[t]                               ),
      .tcdm_dma_resp_valid_o   (tcdm_dma_resp_valid[t]                         ),
      .tcdm_dma_resp_ready_i   (tcdm_dma_resp_ready[t]                         ),
      // AXI interface
      .axi_mst_req_o           (axi_tile_req[t]                                ),
      .axi_mst_resp_i          (axi_tile_resp[t]                               ),
      // Wake up interface
      .wake_up_i               (wake_up_q[t*NumCoresPerTile +: NumCoresPerTile])
    );

    // Transpose the group requests
    for (genvar g = 0; g < NumGroups; g++) begin: gen_tran_group_req
      assign tcdm_master_req[g][t]          = tran_tcdm_master_req[g];
      assign tcdm_master_req_valid[g][t]    = tran_tcdm_master_req_valid[g];
      assign tran_tcdm_master_req_ready[g]  = tcdm_master_req_ready[g][t];
      assign tran_tcdm_master_resp[g]       = tcdm_master_resp[g][t];
      assign tran_tcdm_master_resp_valid[g] = tcdm_master_resp_valid[g][t];
      assign tcdm_master_resp_ready[g][t]   = tran_tcdm_master_resp_ready[g];
      assign tran_tcdm_slave_req[g]         = tcdm_slave_req[g][t];
      assign tran_tcdm_slave_req_valid[g]   = tcdm_slave_req_valid[g][t];
      assign tcdm_slave_req_ready[g][t]     = tran_tcdm_slave_req_ready[g];
      assign tcdm_slave_resp[g][t]          = tran_tcdm_slave_resp[g];
      assign tcdm_slave_resp_valid[g][t]    = tran_tcdm_slave_resp_valid[g];
      assign tran_tcdm_slave_resp_ready[g]  = tcdm_slave_resp_ready[g][t];
    end: gen_tran_group_req
  end : gen_tiles

  /*************************
   *  Local Interconnect  *
   *************************/

  // The local port is always at the index 0 out of the NumGroups TCDM ports of the tile.

  logic           [NumTilesPerGroup-1:0] master_local_req_valid;
  logic           [NumTilesPerGroup-1:0] master_local_req_ready;
  tcdm_addr_t     [NumTilesPerGroup-1:0] master_local_req_tgt_addr;
  logic           [NumTilesPerGroup-1:0] master_local_req_wen;
  tcdm_payload_t  [NumTilesPerGroup-1:0] master_local_req_wdata;
  strb_t          [NumTilesPerGroup-1:0] master_local_req_be;
  logic           [NumTilesPerGroup-1:0] master_local_resp_valid;
  logic           [NumTilesPerGroup-1:0] master_local_resp_ready;
  tcdm_payload_t  [NumTilesPerGroup-1:0] master_local_resp_rdata;
  logic           [NumTilesPerGroup-1:0] slave_local_req_valid;
  logic           [NumTilesPerGroup-1:0] slave_local_req_ready;
  tile_addr_t     [NumTilesPerGroup-1:0] slave_local_req_tgt_addr;
  tile_group_id_t [NumTilesPerGroup-1:0] slave_local_req_ini_addr;
  logic           [NumTilesPerGroup-1:0] slave_local_req_wen;
  tcdm_payload_t  [NumTilesPerGroup-1:0] slave_local_req_wdata;
  strb_t          [NumTilesPerGroup-1:0] slave_local_req_be;
  logic           [NumTilesPerGroup-1:0] slave_local_resp_valid;
  logic           [NumTilesPerGroup-1:0] slave_local_resp_ready;
  tile_group_id_t [NumTilesPerGroup-1:0] slave_local_resp_ini_addr;
  tcdm_payload_t  [NumTilesPerGroup-1:0] slave_local_resp_rdata;

  for (genvar t = 0; t < NumTilesPerGroup; t++) begin: gen_local_connections
    assign master_local_req_valid[t]     = tcdm_master_req_valid[0][t];
    assign master_local_req_tgt_addr[t]  = tcdm_master_req[0][t].tgt_addr;
    assign master_local_req_wen[t]       = tcdm_master_req[0][t].wen;
    assign master_local_req_wdata[t]     = tcdm_master_req[0][t].wdata;
    assign master_local_req_be[t]        = tcdm_master_req[0][t].be;
    assign tcdm_master_req_ready[0][t]   = master_local_req_ready[t];
    assign slave_local_resp_valid[t]     = tcdm_slave_resp_valid[0][t];
    assign slave_local_resp_ini_addr[t]  = tcdm_slave_resp[0][t].ini_addr;
    assign slave_local_resp_rdata[t]     = tcdm_slave_resp[0][t].rdata;
    assign tcdm_slave_resp_ready[0][t]   = slave_local_resp_ready[t];
    assign tcdm_master_resp_valid[0][t]  = master_local_resp_valid[t];
    assign tcdm_master_resp[0][t].rdata  = master_local_resp_rdata[t];
    assign master_local_resp_ready[t]    = tcdm_master_resp_ready[0][t];
    assign tcdm_slave_req_valid[0][t]    = slave_local_req_valid[t];
    assign tcdm_slave_req[0][t].tgt_addr = slave_local_req_tgt_addr[t];
    assign tcdm_slave_req[0][t].ini_addr = slave_local_req_ini_addr[t];
    assign tcdm_slave_req[0][t].wen      = slave_local_req_wen[t];
    assign tcdm_slave_req[0][t].wdata    = slave_local_req_wdata[t];
    assign tcdm_slave_req[0][t].be       = slave_local_req_be[t];
    assign slave_local_req_ready[t]      = tcdm_slave_req_ready[0][t];
  end

  variable_latency_interconnect #(
    .NumIn            (NumTilesPerGroup                             ),
    .NumOut           (NumTilesPerGroup                             ),
    .AddrWidth        (TCDMAddrWidth                                ),
    .DataWidth        ($bits(tcdm_payload_t)                        ),
    .BeWidth          (DataWidth/8                                  ),
    .ByteOffWidth     (0                                            ),
    .AddrMemWidth     (TCDMAddrMemWidth + idx_width(NumBanksPerTile)),
    .Topology         (tcdm_interconnect_pkg::LIC                   ),
    // The local interconnect needs no extra spill registers
    .SpillRegisterReq (64'b0                                        ),
    .SpillRegisterResp(64'b0                                        ),
    .AxiVldRdy        (1'b1                                         )
  ) i_local_interco (
    .clk_i          (clk_i                    ),
    .rst_ni         (rst_ni                   ),
    .req_valid_i    (master_local_req_valid   ),
    .req_ready_o    (master_local_req_ready   ),
    .req_tgt_addr_i (master_local_req_tgt_addr),
    .req_wen_i      (master_local_req_wen     ),
    .req_wdata_i    (master_local_req_wdata   ),
    .req_be_i       (master_local_req_be      ),
    .resp_valid_o   (master_local_resp_valid  ),
    .resp_ready_i   (master_local_resp_ready  ),
    .resp_rdata_o   (master_local_resp_rdata  ),
    .resp_ini_addr_i(slave_local_resp_ini_addr),
    .resp_rdata_i   (slave_local_resp_rdata   ),
    .resp_valid_i   (slave_local_resp_valid   ),
    .resp_ready_o   (slave_local_resp_ready   ),
    .req_valid_o    (slave_local_req_valid    ),
    .req_ready_i    (slave_local_req_ready    ),
    .req_be_o       (slave_local_req_be       ),
    .req_wdata_o    (slave_local_req_wdata    ),
    .req_wen_o      (slave_local_req_wen      ),
    .req_ini_addr_o (slave_local_req_ini_addr ),
    .req_tgt_addr_o (slave_local_req_tgt_addr )
  );

  /**************************
   *  Remote Interconnects  *
   **************************/

  for (genvar r = 1; r < NumGroups; r++) begin: gen_remote_interco
    logic           [NumTilesPerGroup-1:0] master_remote_req_valid;
    logic           [NumTilesPerGroup-1:0] master_remote_req_ready;
    tcdm_addr_t     [NumTilesPerGroup-1:0] master_remote_req_tgt_addr;
    logic           [NumTilesPerGroup-1:0] master_remote_req_wen;
    tcdm_payload_t  [NumTilesPerGroup-1:0] master_remote_req_wdata;
    strb_t          [NumTilesPerGroup-1:0] master_remote_req_be;
    logic           [NumTilesPerGroup-1:0] master_remote_resp_valid;
    logic           [NumTilesPerGroup-1:0] master_remote_resp_ready;
    tcdm_payload_t  [NumTilesPerGroup-1:0] master_remote_resp_rdata;
    logic           [NumTilesPerGroup-1:0] slave_remote_req_valid;
    logic           [NumTilesPerGroup-1:0] slave_remote_req_ready;
    tile_addr_t     [NumTilesPerGroup-1:0] slave_remote_req_tgt_addr;
    tile_group_id_t [NumTilesPerGroup-1:0] slave_remote_req_ini_addr;
    logic           [NumTilesPerGroup-1:0] slave_remote_req_wen;
    tcdm_payload_t  [NumTilesPerGroup-1:0] slave_remote_req_wdata;
    strb_t          [NumTilesPerGroup-1:0] slave_remote_req_be;
    logic           [NumTilesPerGroup-1:0] slave_remote_resp_valid;
    logic           [NumTilesPerGroup-1:0] slave_remote_resp_ready;
    tile_group_id_t [NumTilesPerGroup-1:0] slave_remote_resp_ini_addr;
    tcdm_payload_t  [NumTilesPerGroup-1:0] slave_remote_resp_rdata;

    for (genvar t = 0; t < NumTilesPerGroup; t++) begin: gen_remote_connections
      assign master_remote_req_valid[t]       = tcdm_master_req_valid[r][t];
      assign master_remote_req_tgt_addr[t]    = tcdm_master_req[r][t].tgt_addr;
      assign master_remote_req_wen[t]         = tcdm_master_req[r][t].wen;
      assign master_remote_req_wdata[t]       = tcdm_master_req[r][t].wdata;
      assign master_remote_req_be[t]          = tcdm_master_req[r][t].be;
      assign tcdm_master_req_ready[r][t]      = master_remote_req_ready[t];
      assign tcdm_master_req_valid_o[r][t]    = slave_remote_req_valid[t];
      assign tcdm_master_req_s[r][t].tgt_addr = slave_remote_req_tgt_addr[t];
      assign tcdm_master_req_s[r][t].ini_addr = slave_remote_req_ini_addr[t];
      assign tcdm_master_req_s[r][t].wen      = slave_remote_req_wen[t];
      assign tcdm_master_req_s[r][t].wdata    = slave_remote_req_wdata[t];
      assign tcdm_master_req_s[r][t].be       = slave_remote_req_be[t];
      assign slave_remote_req_ready[t]        = tcdm_master_req_ready_i[r][t];
      assign slave_remote_resp_valid[t]       = tcdm_slave_resp_valid[r][t];
      assign slave_remote_resp_ini_addr[t]    = tcdm_slave_resp[r][t].ini_addr;
      assign slave_remote_resp_rdata[t]       = tcdm_slave_resp[r][t].rdata;
      assign tcdm_slave_resp_ready[r][t]      = slave_remote_resp_ready[t];
      assign tcdm_slave_resp_valid_o[r][t]    = master_remote_resp_valid[t];
      assign tcdm_slave_resp_s[r][t].rdata    = master_remote_resp_rdata[t];
      assign master_remote_resp_ready[t]      = tcdm_slave_resp_ready_i[r][t];
    end: gen_remote_connections

    variable_latency_interconnect #(
      .NumIn              (NumTilesPerGroup                             ),
      .NumOut             (NumTilesPerGroup                             ),
      .AddrWidth          (TCDMAddrWidth                                ),
      .DataWidth          ($bits(tcdm_payload_t)                        ),
      .BeWidth            (DataWidth/8                                  ),
      .ByteOffWidth       (0                                            ),
      .AddrMemWidth       (TCDMAddrMemWidth + idx_width(NumBanksPerTile)),
      .Topology           (tcdm_interconnect_pkg::LIC                   ),
      .AxiVldRdy          (1'b1                                         ),
      .SpillRegisterReq   (64'b1                                        ),
      .SpillRegisterResp  (64'b1                                        ),
      .FallThroughRegister(1'b1                                         )
    ) i_remote_interco (
      .clk_i          (clk_i                     ),
      .rst_ni         (rst_ni                    ),
      .req_valid_i    (master_remote_req_valid   ),
      .req_ready_o    (master_remote_req_ready   ),
      .req_tgt_addr_i (master_remote_req_tgt_addr),
      .req_wen_i      (master_remote_req_wen     ),
      .req_wdata_i    (master_remote_req_wdata   ),
      .req_be_i       (master_remote_req_be      ),
      .resp_valid_o   (master_remote_resp_valid  ),
      .resp_ready_i   (master_remote_resp_ready  ),
      .resp_rdata_o   (master_remote_resp_rdata  ),
      .resp_ini_addr_i(slave_remote_resp_ini_addr),
      .resp_rdata_i   (slave_remote_resp_rdata   ),
      .resp_valid_i   (slave_remote_resp_valid   ),
      .resp_ready_o   (slave_remote_resp_ready   ),
      .req_valid_o    (slave_remote_req_valid    ),
      .req_ready_i    (slave_remote_req_ready    ),
      .req_be_o       (slave_remote_req_be       ),
      .req_wdata_o    (slave_remote_req_wdata    ),
      .req_wen_o      (slave_remote_req_wen      ),
      .req_ini_addr_o (slave_remote_req_ini_addr ),
      .req_tgt_addr_o (slave_remote_req_tgt_addr )
    );

  end: gen_remote_interco

  /**********************
   *  AXI Interconnect  *
   **********************/

  axi_tile_req_t   [NumAXIMastersPerGroup-1:0] axi_mst_req;
  axi_tile_resp_t  [NumAXIMastersPerGroup-1:0] axi_mst_resp;

  axi_hier_interco #(
    .NumSlvPorts    (NumTilesPerGroup+NumDmasPerGroup),
    .NumMstPorts    (NumAXIMastersPerGroup           ),
    .Radix          (AxiHierRadix                    ),
    .EnableCache    (32'hFFFFFFFF                    ),
    .CacheLineWidth (ROCacheLineWidth                ),
    .CacheSizeByte  (ROCacheSizeByte                 ),
    .CacheSets      (ROCacheSets                     ),
    .AddrWidth      (AddrWidth                       ),
    .DataWidth      (AxiDataWidth                    ),
    .SlvIdWidth     (AxiTileIdWidth                  ),
    .MstIdWidth     (AxiTileIdWidth                  ),
    .UserWidth      (1                               ),
    .slv_req_t      (axi_tile_req_t                  ),
    .slv_resp_t     (axi_tile_resp_t                 ),
    .mst_req_t      (axi_tile_req_t                  ),
    .mst_resp_t     (axi_tile_resp_t                 )
  ) i_axi_interco (
    .clk_i           (clk_i                       ),
    .rst_ni          (rst_ni                      ),
    .test_i          (1'b0                        ),
    .ro_cache_ctrl_i (ro_cache_ctrl_q             ),
    .slv_req_i       ({axi_dma_req,axi_tile_req}  ),
    .slv_resp_o      ({axi_dma_resp,axi_tile_resp}),
    .mst_req_o       (axi_mst_req                 ),
    .mst_resp_i      (axi_mst_resp                )
  );

  for (genvar m = 0; m < NumAXIMastersPerGroup; m++) begin: gen_axi_group_cuts
    axi_cut #(
      .ar_chan_t (axi_tile_ar_t  ),
      .aw_chan_t (axi_tile_aw_t  ),
      .r_chan_t  (axi_tile_r_t   ),
      .w_chan_t  (axi_tile_w_t   ),
      .b_chan_t  (axi_tile_b_t   ),
      .axi_req_t (axi_tile_req_t ),
      .axi_resp_t(axi_tile_resp_t)
    ) i_axi_cut (
      .clk_i     (clk_i            ),
      .rst_ni    (rst_ni           ),
      .slv_req_i (axi_mst_req[m]   ),
      .slv_resp_o(axi_mst_resp[m]  ),
      .mst_req_o (axi_mst_req_o[m] ),
      .mst_resp_i(axi_mst_resp_i[m])
    );
  end: gen_axi_group_cuts

  /*********
   *  DMA  *
   *********/
  dma_req_t  dma_req_cut;
  logic      dma_req_cut_valid;
  logic      dma_req_cut_ready;
  dma_meta_t dma_meta_cut;

  spill_register #(
    .T(dma_req_t)
  ) i_dma_req_register (
    .clk_i  (clk_i            ),
    .rst_ni (rst_ni           ),
    .data_i (dma_req_i        ),
    .valid_i(dma_req_valid_i  ),
    .ready_o(dma_req_ready_o  ),
    .data_o (dma_req_cut      ),
    .valid_o(dma_req_cut_valid),
    .ready_i(dma_req_cut_ready)
  );

  `FF(dma_meta_o, dma_meta_cut, '0, clk_i, rst_ni);

  dma_req_t  [NumDmasPerGroup-1:0] dma_req;
  logic      [NumDmasPerGroup-1:0] dma_req_valid;
  logic      [NumDmasPerGroup-1:0] dma_req_ready;
  dma_meta_t [NumDmasPerGroup-1:0] dma_meta;

  idma_distributed_midend #(
    .NoMstPorts     (NumDmasPerGroup                   ),
    .DmaRegionWidth (NumBanksPerGroup*4/NumDmasPerGroup),
    .DmaRegionStart (TCDMBaseAddr                      ),
    .DmaRegionEnd   (TCDMBaseAddr+TCDMSize             ),
    .TransFifoDepth (4                                 ),
    .burst_req_t    (dma_req_t                         ),
    .meta_t         (dma_meta_t                        )
  ) i_idma_distributed_midend (
    .clk_i       (clk_i            ),
    .rst_ni      (rst_ni           ),
    .burst_req_i (dma_req_cut      ),
    .valid_i     (dma_req_cut_valid),
    .ready_o     (dma_req_cut_ready),
    .meta_o      (dma_meta_cut     ),
    .burst_req_o (dma_req          ),
    .valid_o     (dma_req_valid    ),
    .ready_i     (dma_req_ready    ),
    .meta_i      (dma_meta         )
  );

  // xbar
  localparam int unsigned NumRules = 1;
  typedef struct packed {
    int unsigned idx;
    logic [AddrWidth-1:0] start_addr;
    logic [AddrWidth-1:0] end_addr;
  } xbar_rule_t;
  xbar_rule_t [NumRules-1:0] addr_map;
  assign addr_map = '{
    '{ // TCDM
      start_addr: TCDMBaseAddr,
      end_addr:   TCDMBaseAddr + TCDMSize,
      idx:        1
    }
  };

  `REQRSP_TYPEDEF_ALL(reqrsp, addr_t, axi_data_t, axi_strb_t)


  for (genvar d = 0; unsigned'(d) < NumDmasPerGroup; d++) begin: gen_dmas
    localparam int unsigned a = NumTilesPerGroup + d;

    axi_tile_req_t  axi_dma_premux_req;
    axi_tile_resp_t axi_dma_premux_resp;
    axi_tile_req_t  tcdm_req;
    axi_tile_resp_t tcdm_resp;

    logic backend_idle;
    logic trans_complete;

    axi_dma_backend #(
      .DataWidth       (AxiDataWidth   ),
      .AddrWidth       (AddrWidth      ),
      .IdWidth         (AxiTileIdWidth ),
      .AxReqFifoDepth  (2              ),
      .TransFifoDepth  (1              ),
      .BufferDepth     (3              ),
      .axi_req_t       (axi_tile_req_t ),
      .axi_res_t       (axi_tile_resp_t),
      .burst_req_t     (dma_req_t      ),
      .DmaIdWidth      (1              ),
      .DmaTracing      (0              )
    ) i_axi_dma_backend (
      .clk_i            (clk_i                     ),
      .rst_ni           (rst_ni                    ),
      .dma_id_i         (1'b0                      ),
      .axi_dma_req_o    (axi_dma_premux_req        ),
      .axi_dma_res_i    (axi_dma_premux_resp       ),
      .burst_req_i      (dma_req[d]                ),
      .valid_i          (dma_req_valid[d]          ),
      .ready_o          (dma_req_ready[d]          ),
      .backend_idle_o   (dma_meta[d].backend_idle  ),
      .trans_complete_o (dma_meta[d].trans_complete)
    );

    // ------------------------------------------------------
    // AXI connection to EXT/TCDM
    // ------------------------------------------------------

    localparam axi_pkg::xbar_cfg_t XbarCfg = '{
      NoSlvPorts:         1,
      NoMstPorts:         2,
      MaxMstTrans:        8,
      MaxSlvTrans:        8,
      FallThrough:        1'b0,
      LatencyMode:        axi_pkg::CUT_ALL_PORTS,
      AxiIdWidthSlvPorts: AxiTileIdWidth,
      AxiIdUsedSlvPorts:  AxiTileIdWidth,
      UniqueIds:          1'b0,
      AxiAddrWidth:       AddrWidth,
      AxiDataWidth:       AxiDataWidth,
      NoAddrRules:        NumRules
    };

    axi_xbar #(
      .Cfg          (XbarCfg        ),
      .slv_aw_chan_t(axi_tile_aw_t  ),
      .mst_aw_chan_t(axi_tile_aw_t  ),
      .w_chan_t     (axi_tile_w_t   ),
      .slv_b_chan_t (axi_tile_b_t   ),
      .mst_b_chan_t (axi_tile_b_t   ),
      .slv_ar_chan_t(axi_tile_ar_t  ),
      .mst_ar_chan_t(axi_tile_ar_t  ),
      .slv_r_chan_t (axi_tile_r_t   ),
      .mst_r_chan_t (axi_tile_r_t   ),
      .slv_req_t    (axi_tile_req_t ),
      .slv_resp_t   (axi_tile_resp_t),
      .mst_req_t    (axi_tile_req_t ),
      .mst_resp_t   (axi_tile_resp_t),
      .rule_t       (xbar_rule_t    )
    ) i_dma_axi_xbar (
      .clk_i                (clk_i                        ),
      .rst_ni               (rst_ni                       ),
      .test_i               (1'b0                         ),
      .slv_ports_req_i      (axi_dma_premux_req           ),
      .slv_ports_resp_o     (axi_dma_premux_resp          ),
      .mst_ports_req_o      ({tcdm_req,axi_dma_req[d]}    ),
      .mst_ports_resp_i     ({tcdm_resp,axi_dma_resp[d]}  ),
      .addr_map_i           (addr_map                     ),
      .en_default_mst_port_i('1                           ),
      .default_mst_port_i   ('0                           )
    );

    reqrsp_req_t dma_reqrsp_req;
    reqrsp_rsp_t dma_reqrsp_rsp;
    reqrsp_req_t [NumTilesPerDma-1:0] dma_tile_req;
    reqrsp_rsp_t [NumTilesPerDma-1:0] dma_tile_rsp;

    axi_to_reqrsp #(
      .axi_req_t   (axi_tile_req_t ),
      .axi_rsp_t   (axi_tile_resp_t),
      .AddrWidth   (AddrWidth      ),
      .DataWidth   (AxiDataWidth   ),
      .IdWidth     (AxiTileIdWidth ),
      .BufDepth    (2              ),
      .reqrsp_req_t(reqrsp_req_t   ),
      .reqrsp_rsp_t(reqrsp_rsp_t   )
    ) i_axi_to_reqrsp (
      .clk_i       (clk_i         ),
      .rst_ni      (rst_ni        ),
      .busy_o      (/*unused*/    ),
      .axi_req_i   (tcdm_req      ),
      .axi_rsp_o   (tcdm_resp     ),
      .reqrsp_req_o(dma_reqrsp_req),
      .reqrsp_rsp_i(dma_reqrsp_rsp)
    );

    if (NumTilesPerDma > 1) begin: gen_dma_reqrsp_demux
      reqrsp_demux #(
        .NrPorts  (NumTilesPerDma),
        .req_t    (reqrsp_req_t  ),
        .rsp_t    (reqrsp_rsp_t  ),
        .RespDepth(2             )
      ) i_reqrsp_demux (
         .clk_i       (clk_i                                                                                  ),
         .rst_ni      (rst_ni                                                                                 ),
         .slv_select_i(dma_reqrsp_req.q.addr[idx_width(NumBanksPerTile)+ByteOffset+:idx_width(NumTilesPerDma)]),
         .slv_req_i   (dma_reqrsp_req                                                                         ),
         .slv_rsp_o   (dma_reqrsp_rsp                                                                         ),
         .mst_req_o   (dma_tile_req                                                                           ),
         .mst_rsp_i   (dma_tile_rsp                                                                           )
      );
    end else begin: gen_dma_reqrsp_bypass
      assign dma_tile_req = dma_reqrsp_req;
      assign dma_reqrsp_rsp = dma_tile_rsp;
    end

    // Assignment to TCDM interconnect
    // TODO: Reordering might be problematic
    for (genvar t = 0; unsigned'(t) < NumTilesPerDma; t++) begin: gen_dma_tile_connection
      assign tcdm_dma_req[d*NumTilesPerDma+t] = '{
               wdata: dma_tile_req[t].q.data,
               wen: dma_tile_req[t].q.write,
               be: dma_tile_req[t].q.strb,
               tgt_addr: {dma_tile_req[t].q.addr[ByteOffset + idx_width(NumBanksPerTile) + $clog2(NumTilesPerGroup) + $clog2(NumGroups)+:TCDMAddrMemWidth],
                          dma_tile_req[t].q.addr[ByteOffset+:idx_width(NumBanksPerTile)]}
             };
      assign tcdm_dma_req_valid[d*NumTilesPerDma+t]  = dma_tile_req[t].q_valid;
      assign dma_tile_rsp[t].q_ready = tcdm_dma_req_ready[d*NumTilesPerDma+t];
      assign dma_tile_rsp[t].p = '{
               data: tcdm_dma_resp[d*NumTilesPerDma+t].rdata,
               error: '0
             };
      assign dma_tile_rsp[t].p_valid = tcdm_dma_resp_valid[d*NumTilesPerDma+t];
      assign tcdm_dma_resp_ready[d*NumTilesPerDma+t] =dma_tile_req[t].p_ready;
    end
  end

endmodule: mempool_group
