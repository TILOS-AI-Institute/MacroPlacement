// Copyright 2021 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

package mempool_pkg;

  import snitch_pkg::MetaIdWidth;
  import cf_math_pkg::idx_width;

  /*********************
   *  TILE PARAMETERS  *
   *********************/

  `include "axi/assign.svh"
  `include "axi/typedef.svh"

  localparam integer unsigned NumCores         = `ifdef NUM_CORES `NUM_CORES `else 0 `endif;
  localparam integer unsigned NumCoresPerTile  = `ifdef NUM_CORES_PER_TILE `NUM_CORES_PER_TILE `else 0 `endif;
  localparam integer unsigned NumGroups        = `ifdef NUM_GROUPS `NUM_GROUPS `else 0 `endif;
  localparam integer unsigned MAX_NumGroups    = 8;
  localparam integer unsigned NumTiles         = NumCores / NumCoresPerTile;
  localparam integer unsigned NumTilesPerGroup = NumTiles / NumGroups;
  localparam integer unsigned NumCoresPerGroup = NumCores / NumGroups;
  localparam integer unsigned NumCoresPerCache = NumCoresPerTile;
  localparam integer unsigned AxiCoreIdWidth   = 1;
  localparam integer unsigned AxiTileIdWidth   = AxiCoreIdWidth+1; // + 1 for cache
  localparam integer unsigned AxiDataWidth     = `ifdef AXI_DATA_WIDTH `AXI_DATA_WIDTH `else 0 `endif;
  localparam integer unsigned AxiLiteDataWidth = 32;

  /***********************
   *  MEMORY PARAMETERS  *
   ***********************/

  localparam integer unsigned AddrWidth        = 32;
  localparam integer unsigned DataWidth        = 32;
  localparam integer unsigned BeWidth          = DataWidth / 8;
  localparam integer unsigned ByteOffset       = $clog2(BeWidth);
  localparam integer unsigned BankingFactor    = `ifdef BANKING_FACTOR `BANKING_FACTOR `else 0 `endif;
  localparam bit              LrScEnable       = 1'b1;
  localparam integer unsigned TCDMSizePerBank  = 1024; // [B]
  localparam integer unsigned NumBanks         = NumCores * BankingFactor;
  localparam integer unsigned NumBanksPerTile  = NumBanks / NumTiles;
  localparam integer unsigned NumBanksPerGroup = NumBanks / NumGroups;
  localparam integer unsigned TCDMAddrMemWidth = $clog2(TCDMSizePerBank / mempool_pkg::BeWidth);
  localparam integer unsigned TCDMAddrWidth    = TCDMAddrMemWidth + idx_width(NumBanksPerGroup);

  // L2
  localparam integer unsigned L2Size           = `ifdef L2_SIZE `L2_SIZE `else 0 `endif; // [B]

  localparam integer unsigned NumL2Banks       = `ifdef L2_BANKS `L2_BANKS `else 1 `endif;
  localparam integer unsigned L2BankSize       = L2Size / NumL2Banks;
  localparam integer unsigned L2BankWidth      = AxiDataWidth;
  localparam integer unsigned L2BankBeWidth    = L2BankWidth/8;
  localparam integer unsigned L2BankNumWords   = L2BankSize / L2BankBeWidth;
  localparam integer unsigned L2BankAddrWidth  = $clog2(L2BankNumWords);

  localparam integer unsigned L2Width          = L2BankWidth * NumL2Banks;
  localparam integer unsigned L2BeWidth        = L2Width/8;
  localparam integer unsigned L2ByteOffset     = $clog2(L2BeWidth);
  localparam integer unsigned L2AddrWidth      = $clog2(L2Size);


  typedef logic [AxiCoreIdWidth-1:0] axi_core_id_t;
  typedef logic [AxiTileIdWidth-1:0] axi_tile_id_t;
  typedef logic [AxiDataWidth-1:0] axi_data_t;
  typedef logic [AxiDataWidth/8-1:0] axi_strb_t;
  typedef logic [AxiLiteDataWidth-1:0] axi_lite_data_t;
  typedef logic [AxiLiteDataWidth/8-1:0] axi_lite_strb_t;
  typedef logic [AddrWidth-1:0] addr_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [BeWidth-1:0] strb_t;

  localparam integer unsigned NumAXIMastersPerGroup = `ifdef AXI_MASTERS_PER_GROUP `AXI_MASTERS_PER_GROUP `else 1 `endif;;

  localparam NumSystemXbarMasters = (NumGroups * NumAXIMastersPerGroup) + 1; // +1 because the external host is also a master
  localparam AxiSystemIdWidth = $clog2(NumSystemXbarMasters) + AxiTileIdWidth;
  typedef logic [AxiSystemIdWidth-1:0] axi_system_id_t;

  localparam NumTestbenchXbarMasters = 1;
  localparam AxiTestbenchIdWidth = $clog2(NumTestbenchXbarMasters) + AxiSystemIdWidth;
  typedef logic [AxiTestbenchIdWidth-1:0] axi_tb_id_t;


  `AXI_TYPEDEF_AW_CHAN_T(axi_core_aw_t, addr_t, axi_core_id_t, logic);
  `AXI_TYPEDEF_W_CHAN_T(axi_core_w_t, axi_data_t, axi_strb_t, logic);
  `AXI_TYPEDEF_B_CHAN_T(axi_core_b_t, axi_core_id_t, logic);
  `AXI_TYPEDEF_AR_CHAN_T(axi_core_ar_t, addr_t, axi_core_id_t, logic);
  `AXI_TYPEDEF_R_CHAN_T(axi_core_r_t, axi_data_t, axi_core_id_t, logic);
  `AXI_TYPEDEF_REQ_T(axi_core_req_t, axi_core_aw_t, axi_core_w_t, axi_core_ar_t);
  `AXI_TYPEDEF_RESP_T(axi_core_resp_t, axi_core_b_t, axi_core_r_t );

  `AXI_TYPEDEF_AW_CHAN_T(axi_tile_aw_t, addr_t, axi_tile_id_t, logic);
  `AXI_TYPEDEF_W_CHAN_T(axi_tile_w_t, axi_data_t, axi_strb_t, logic);
  `AXI_TYPEDEF_B_CHAN_T(axi_tile_b_t, axi_tile_id_t, logic);
  `AXI_TYPEDEF_AR_CHAN_T(axi_tile_ar_t, addr_t, axi_tile_id_t, logic);
  `AXI_TYPEDEF_R_CHAN_T(axi_tile_r_t, axi_data_t, axi_tile_id_t, logic);
  `AXI_TYPEDEF_REQ_T(axi_tile_req_t, axi_tile_aw_t, axi_tile_w_t, axi_tile_ar_t);
  `AXI_TYPEDEF_RESP_T(axi_tile_resp_t, axi_tile_b_t, axi_tile_r_t );

  `AXI_TYPEDEF_AW_CHAN_T(axi_system_aw_t, addr_t, axi_system_id_t, logic);
  `AXI_TYPEDEF_W_CHAN_T(axi_system_w_t, axi_data_t, axi_strb_t, logic);
  `AXI_TYPEDEF_B_CHAN_T(axi_system_b_t, axi_system_id_t, logic);
  `AXI_TYPEDEF_AR_CHAN_T(axi_system_ar_t, addr_t, axi_system_id_t, logic);
  `AXI_TYPEDEF_R_CHAN_T(axi_system_r_t, axi_data_t, axi_system_id_t, logic);
  `AXI_TYPEDEF_REQ_T(axi_system_req_t, axi_system_aw_t, axi_system_w_t, axi_system_ar_t);
  `AXI_TYPEDEF_RESP_T(axi_system_resp_t, axi_system_b_t, axi_system_r_t);

  // AXI to periph
  `AXI_TYPEDEF_W_CHAN_T(axi_periph_w_t, axi_lite_data_t, axi_lite_strb_t, logic);
  `AXI_TYPEDEF_R_CHAN_T(axi_periph_r_t, axi_lite_data_t, axi_system_id_t, logic);
  `AXI_TYPEDEF_REQ_T(axi_periph_req_t, axi_system_aw_t, axi_periph_w_t, axi_system_ar_t);
  `AXI_TYPEDEF_RESP_T(axi_periph_resp_t, axi_system_b_t, axi_periph_r_t);

  `AXI_TYPEDEF_AW_CHAN_T(axi_tb_aw_t, addr_t, axi_tb_id_t, logic);
  `AXI_TYPEDEF_W_CHAN_T(axi_tb_w_t, axi_data_t, axi_strb_t, logic);
  `AXI_TYPEDEF_B_CHAN_T(axi_tb_b_t, axi_tb_id_t, logic);
  `AXI_TYPEDEF_AR_CHAN_T(axi_tb_ar_t, addr_t, axi_tb_id_t, logic);
  `AXI_TYPEDEF_R_CHAN_T(axi_tb_r_t, axi_data_t, axi_tb_id_t, logic);
  `AXI_TYPEDEF_REQ_T(axi_tb_req_t, axi_tb_aw_t, axi_tb_w_t, axi_tb_ar_t);
  `AXI_TYPEDEF_RESP_T(axi_tb_resp_t, axi_tb_b_t, axi_tb_r_t);

  `AXI_LITE_TYPEDEF_AW_CHAN_T(axi_lite_slv_aw_t, addr_t)
  `AXI_LITE_TYPEDEF_W_CHAN_T(axi_lite_slv_w_t, axi_lite_data_t, axi_lite_strb_t)
  `AXI_LITE_TYPEDEF_B_CHAN_T(axi_lite_slv_b_t)
  `AXI_LITE_TYPEDEF_AR_CHAN_T(axi_lite_slv_ar_t, addr_t)
  `AXI_LITE_TYPEDEF_R_CHAN_T(axi_lite_slv_r_t, axi_lite_data_t)
  `AXI_LITE_TYPEDEF_REQ_T(axi_lite_slv_req_t, axi_lite_slv_aw_t, axi_lite_slv_w_t, axi_lite_slv_ar_t)
  `AXI_LITE_TYPEDEF_RESP_T(axi_lite_slv_resp_t, axi_lite_slv_b_t, axi_lite_slv_r_t)

  /***********************
   *  INSTRUCTION CACHE  *
   ***********************/

  localparam int unsigned ICacheSizeByte  = 512 * NumCoresPerCache;     // Total Size of instruction cache in bytes
  localparam int unsigned ICacheSets      = NumCoresPerCache / 2;       // Number of sets
  localparam int unsigned ICacheLineWidth = 32 * 2 * NumCoresPerCache;  // Size of each cache line in bits

  /*********************
   *  READ-ONLY CACHE  *
   *********************/

  localparam int unsigned AxiHierRadix      = `ifdef AXI_HIER_RADIX `AXI_HIER_RADIX `else NumTilesPerGroup `endif;
  localparam int unsigned ROCacheLineWidth  = `ifdef RO_LINE_WIDTH `RO_LINE_WIDTH `else 0 `endif;
  localparam int unsigned ROCacheSizeByte   = 8192;
  localparam int unsigned ROCacheSets       = 2;

  localparam int unsigned ROCacheNumAddrRules = 4;
  typedef struct packed {
    logic enable;
    logic flush_valid;
    logic [ROCacheNumAddrRules-1:0][AddrWidth-1:0] start_addr;
    logic [ROCacheNumAddrRules-1:0][AddrWidth-1:0] end_addr;
  } ro_cache_ctrl_t;

  // RO cache reset value to avoid fatal warnings during reset in the address decoder
  localparam ro_cache_ctrl_t ro_cache_ctrl_default = '{
    enable: '0,
    flush_valid: '0,
    start_addr: {32'h18,32'h10,32'h08,32'h00},
    end_addr: {32'h1C,32'h14,32'h0C,32'h04}
  };

  /*********
   *  DMA  *
   *********/

  localparam int unsigned NumDmasPerGroup = `ifdef DMAS_PER_GROUP `DMAS_PER_GROUP `else 4 `endif;
  localparam int unsigned NumTilesPerDma = NumTilesPerGroup/NumDmasPerGroup;
  localparam int unsigned DmaDataWidth = AxiDataWidth;
  localparam int unsigned DmaNumWords = DmaDataWidth/DataWidth;
  localparam int unsigned NumSuperbanks = NumBanksPerTile/DmaNumWords;

  typedef logic [DmaNumWords*DataWidth-1:0] dma_data_t;
  typedef logic [DmaNumWords*DataWidth/8-1:0] dma_strb_t;

  typedef struct packed {
    axi_tile_id_t id;
    addr_t src;
    addr_t dst;
    logic [31:0] num_bytes;
    axi_pkg::cache_t cache_src;
    axi_pkg::cache_t cache_dst;
    axi_pkg::burst_t burst_src;
    axi_pkg::burst_t burst_dst;
    logic decouple_rw;
    logic deburst;
    logic serialize;
  } dma_req_t;

  typedef struct packed {
    logic backend_idle;
    logic trans_complete;
  } dma_meta_t;

  /**********************************
   *  TCDM INTERCONNECT PARAMETERS  *
   **********************************/

  typedef logic [TCDMAddrWidth-1:0] tcdm_addr_t;
  typedef logic [TCDMAddrMemWidth-1:0] bank_addr_t;
  typedef logic [TCDMAddrMemWidth+idx_width(NumBanksPerTile)-1:0] tile_addr_t;
  typedef logic [MetaIdWidth-1:0] meta_id_t;
  typedef logic [idx_width(NumCoresPerTile)-1:0] tile_core_id_t;
  typedef logic [idx_width(NumTilesPerGroup)-1:0] tile_group_id_t;
  typedef logic [idx_width(NumGroups)-1:0] group_id_t;
  typedef logic [3:0] amo_t;

  typedef struct packed {
    meta_id_t meta_id;
    tile_core_id_t core_id;
    amo_t amo;
    data_t data;
  } tcdm_payload_t;

  typedef struct packed {
    tcdm_payload_t wdata;
    logic wen;
    strb_t be;
    tcdm_addr_t tgt_addr;
  } tcdm_master_req_t;

  typedef struct packed {
    tcdm_payload_t rdata;
  } tcdm_master_resp_t;

  typedef struct packed {
    tcdm_payload_t wdata;
    logic wen;
    strb_t be;
    tile_addr_t tgt_addr;
    tile_group_id_t ini_addr;
  } tcdm_slave_req_t;

  typedef struct packed {
    tcdm_payload_t rdata;
    tile_group_id_t ini_addr;
  } tcdm_slave_resp_t;

  typedef struct packed {
    meta_id_t meta_id;
    tile_core_id_t core_id;
    amo_t amo;
    dma_data_t data;
  } dma_payload_t;

  typedef struct packed {
    dma_payload_t wdata;
    logic wen;
    dma_strb_t be;
    tile_addr_t tgt_addr;
  } tcdm_dma_req_t;

  typedef struct packed {
    dma_payload_t rdata;
  } tcdm_dma_resp_t;

  /**********************
   *  QUEUE PARAMETERS  *
   **********************/

  // Size of xqueues in words (must be a power of two)
  localparam int unsigned XQueueSize = `ifdef XQUEUE_SIZE `XQUEUE_SIZE `else 0 `endif;

  /*****************
   *  ADDRESS MAP  *
   *****************/

  // TCDM Memory Region
  localparam addr_t TCDMSize = NumBanks * TCDMSizePerBank;
  localparam addr_t TCDMMask = ~(TCDMSize - 1);

  // Size in bytes of memory that is sequentially addressable per tile
  localparam int unsigned SeqMemSizePerCore = `ifdef SEQ_MEM_SIZE `SEQ_MEM_SIZE `else 0 `endif;
  localparam int unsigned SeqMemSizePerTile = NumCoresPerTile*SeqMemSizePerCore;

  typedef struct packed {
    int unsigned slave_idx;
    addr_t mask;
    addr_t value;
  } address_map_t;

  /***********************
   *  TRAFFIC GENERATOR  *
   ***********************/

  // Replaces core with a traffic generator
  parameter bit TrafficGeneration  = `ifdef TRAFFIC_GEN `TRAFFIC_GEN `else 0 `endif;

endpackage : mempool_pkg
