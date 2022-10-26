// Copyright 2021 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

`include "axi/assign.svh"
`include "common_cells/registers.svh"

module mempool_system
  import mempool_pkg::*;
#(
  // TCDM
  parameter addr_t       TCDMBaseAddr  = 32'h0000_0000,
  // Boot address
  parameter addr_t       BootAddr      = 32'h0000_0000
) (
  input logic                clk_i,
  input logic                rst_ni,

  input  logic               fetch_en_i,
  output logic               eoc_valid_o,
  output logic               busy_o,

  output axi_system_req_t    mst_req_o,
  input  axi_system_resp_t   mst_resp_i,

  input  axi_system_req_t    slv_req_i,
  output axi_system_resp_t   slv_resp_o
);

  import axi_pkg::xbar_cfg_t;
  import axi_pkg::xbar_rule_32_t;

  /*********
   *  AXI  *
   *********/

  // Overview of AXI buses
  //
  //      mst_demux
  //        / |
  //       /  | soc  +----------+ periph  +---------+
  //      |  0|=====>| soc_xbar |========>| periph  |
  //  mst |   |      +----------+         +---------+
  // ====>|   |
  //      |   | l2   +----------+  mem    +---------+ bank  +--------+
  //      |  1|=====>| axi2mem  |-------->| l2_xbar |------>| l2_mem |
  //       \  |      +----------+         +---------+       +--------+
  //        \_|
  //                  == axi ==>          -- tcdm -->

  localparam NumAXIMasters = NumSystemXbarMasters;
  localparam NumAXISlaves  = 3; // control regs, bootrom and the external mst ports
  localparam NumSoCRules   = NumAXISlaves - 1;

  typedef enum logic [$clog2(NumAXISlaves) - 1:0] {
    Peripherals,
    Bootrom,
    External
  } axi_soc_xbar_slave_target;

  typedef enum logic {
    SoCXBar = 0,
    L2Memory = 1
  } axi_mst_demux_slave_target;

  axi_tile_req_t    [NumAXIMasters-1:0] axi_mst_req;
  axi_tile_resp_t   [NumAXIMasters-1:0] axi_mst_resp;
  axi_tile_req_t    [NumAXIMasters-1:0] axi_l2_req;
  axi_tile_resp_t   [NumAXIMasters-1:0] axi_l2_resp;
  axi_tile_req_t    [NumAXIMasters-1:0] axi_soc_req;
  axi_tile_resp_t   [NumAXIMasters-1:0] axi_soc_resp;
  axi_system_req_t  [NumAXISlaves-1:0]  axi_periph_req;
  axi_system_resp_t [NumAXISlaves-1:0]  axi_periph_resp;
  logic             [NumCores-1:0]      wake_up;
  logic             [DataWidth-1:0]     eoc;
  ro_cache_ctrl_t                       ro_cache_ctrl;

  dma_req_t  dma_req;
  logic      dma_req_valid;
  logic      dma_req_ready;
  dma_meta_t dma_meta;
  logic      [1-1:0] dma_id;

  localparam xbar_cfg_t MstDemuxCfg = '{
    NoSlvPorts         : 1, // Each master has a private demux
    NoMstPorts         : 2, // going to either the xbar or L2
    MaxMstTrans        : 4,
    MaxSlvTrans        : 4,
    FallThrough        : 1'b0,
    LatencyMode        : axi_pkg::NO_LATENCY,
    AxiIdWidthSlvPorts : AxiTileIdWidth,
    AxiIdUsedSlvPorts  : AxiTileIdWidth,
    UniqueIds          : 0,
    AxiAddrWidth       : AddrWidth,
    AxiDataWidth       : AxiDataWidth,
    NoAddrRules        : 1
  };

  localparam xbar_cfg_t SoCXBarCfg = '{
    NoSlvPorts         : NumAXIMasters,
    NoMstPorts         : NumAXISlaves,
    MaxMstTrans        : 4,
    MaxSlvTrans        : 4,
    FallThrough        : 1'b0,
    LatencyMode        : axi_pkg::CUT_MST_PORTS,
    AxiIdWidthSlvPorts : AxiTileIdWidth,
    AxiIdUsedSlvPorts  : AxiTileIdWidth,
    UniqueIds          : 0,
    AxiAddrWidth       : AddrWidth,
    AxiDataWidth       : AxiDataWidth,
    NoAddrRules        : NumSoCRules
  };

  /*********************
   *  MemPool Cluster  *
   ********************/

  mempool_cluster #(
    .TCDMBaseAddr(TCDMBaseAddr),
    .BootAddr    (BootAddr    )
  ) i_mempool_cluster (
    .clk_i          (clk_i                          ),
    .rst_ni         (rst_ni                         ),
    .wake_up_i      (wake_up                        ),
    .testmode_i     (1'b0                           ),
    .scan_enable_i  (1'b0                           ),
    .scan_data_i    (1'b0                           ),
    .scan_data_o    (/* Unused */                   ),
    .ro_cache_ctrl_i(ro_cache_ctrl                  ),
    .dma_req_i      (dma_req                        ),
    .dma_req_valid_i(dma_req_valid                  ),
    .dma_req_ready_o(dma_req_ready                  ),
    .dma_meta_o     (dma_meta                       ),
    .axi_mst_req_o  (axi_mst_req[NumAXIMasters-2:0] ),
    .axi_mst_resp_i (axi_mst_resp[NumAXIMasters-2:0])
  );

  /**********************
   *  AXI Interconnect  *
   **********************/

  localparam addr_t PeripheralsBaseAddr   = 32'h4000_0000;
  localparam addr_t PeripheralsEndAddr    = 32'h4002_0000;
  localparam addr_t L2MemoryBaseAddr      = `ifdef L2_BASE `L2_BASE `else 32'h8000_0000 `endif;
  localparam addr_t L2MemoryEndAddr       = L2MemoryBaseAddr + L2Size;
  localparam addr_t BootromBaseAddr       = 32'hA000_0000;
  localparam addr_t BootromEndAddr        = 32'hA000_FFFF;

  xbar_rule_32_t [            0:0]  mst_demux_rules;
  xbar_rule_32_t [NumSoCRules-1:0] soc_xbar_rules;
  assign mst_demux_rules = '{
    '{idx: L2Memory, start_addr: L2MemoryBaseAddr, end_addr: L2MemoryEndAddr}
  };
  assign soc_xbar_rules = '{
    '{idx: Peripherals, start_addr: PeripheralsBaseAddr, end_addr: PeripheralsEndAddr},
    '{idx: Bootrom, start_addr: BootromBaseAddr, end_addr: BootromEndAddr}
  };

  for (genvar i = 0; i < NumAXIMasters; i++) begin : gen_mst_demux
    axi_xbar #(
      .Cfg          (MstDemuxCfg      ),
      .slv_aw_chan_t(axi_tile_aw_t    ),
      .mst_aw_chan_t(axi_tile_aw_t    ),
      .w_chan_t     (axi_tile_w_t     ),
      .slv_b_chan_t (axi_tile_b_t     ),
      .mst_b_chan_t (axi_tile_b_t     ),
      .slv_ar_chan_t(axi_tile_ar_t    ),
      .mst_ar_chan_t(axi_tile_ar_t    ),
      .slv_r_chan_t (axi_tile_r_t     ),
      .mst_r_chan_t (axi_tile_r_t     ),
      .slv_req_t    (axi_tile_req_t   ),
      .slv_resp_t   (axi_tile_resp_t  ),
      .mst_req_t    (axi_tile_req_t   ),
      .mst_resp_t   (axi_tile_resp_t  ),
      .rule_t       (xbar_rule_32_t   )
    ) i_mst_demux (
      .clk_i                (clk_i                           ),
      .rst_ni               (rst_ni                          ),
      .test_i               (1'b0                            ),
      .slv_ports_req_i      (axi_mst_req[i]                  ),
      .slv_ports_resp_o     (axi_mst_resp[i]                 ),
      .mst_ports_req_o      ({axi_l2_req[i] ,axi_soc_req[i] }),
      .mst_ports_resp_i     ({axi_l2_resp[i],axi_soc_resp[i]}),
      .addr_map_i           (mst_demux_rules                 ),
      .en_default_mst_port_i(1'b1                            ),
      .default_mst_port_i   (SoCXBar                         )
    );
  end

  axi_xbar #(
    .Cfg          (SoCXBarCfg       ),
    .slv_aw_chan_t(axi_tile_aw_t    ),
    .mst_aw_chan_t(axi_system_aw_t  ),
    .w_chan_t     (axi_tile_w_t     ),
    .slv_b_chan_t (axi_tile_b_t     ),
    .mst_b_chan_t (axi_system_b_t   ),
    .slv_ar_chan_t(axi_tile_ar_t    ),
    .mst_ar_chan_t(axi_system_ar_t  ),
    .slv_r_chan_t (axi_tile_r_t     ),
    .mst_r_chan_t (axi_system_r_t   ),
    .slv_req_t    (axi_tile_req_t   ),
    .slv_resp_t   (axi_tile_resp_t  ),
    .mst_req_t    (axi_system_req_t ),
    .mst_resp_t   (axi_system_resp_t),
    .rule_t       (xbar_rule_32_t   )
  ) i_soc_xbar (
    .clk_i                (clk_i                    ),
    .rst_ni               (rst_ni                   ),
    .test_i               (1'b0                     ),
    .slv_ports_req_i      (axi_soc_req              ),
    .slv_ports_resp_o     (axi_soc_resp             ),
    .mst_ports_req_o      (axi_periph_req           ),
    .mst_ports_resp_i     (axi_periph_resp          ),
    .addr_map_i           (soc_xbar_rules           ),
    .en_default_mst_port_i({NumAXIMasters{1'b1}}    ), // default all slave ports to master port External
    .default_mst_port_i   ({NumAXIMasters{External}})
  );

  /********
   *  L2  *
   ********/
  localparam int unsigned NumAXIMastersLog2 = NumAXIMasters == 1 ? 1 : $clog2(NumAXIMasters);
  typedef logic [L2AddrWidth-1:0] l2_mem_addr_t;
  typedef logic [L2BankAddrWidth-1:0] l2_bank_addr_t;
  typedef logic [NumAXIMastersLog2-1:0] bank_ini_t;
  // Axi2Mems to l2_xbar
  logic         [NumAXIMasters-1:0] mem_req;
  logic         [NumAXIMasters-1:0] mem_gnt;
  logic         [NumAXIMasters-1:0] mem_rvalid;
  addr_t        [NumAXIMasters-1:0] mem_addr_full;
  l2_mem_addr_t [NumAXIMasters-1:0] mem_addr;
  axi_data_t    [NumAXIMasters-1:0] mem_wdata;
  axi_strb_t    [NumAXIMasters-1:0] mem_strb;
  logic         [NumAXIMasters-1:0] mem_we;
  axi_data_t    [NumAXIMasters-1:0] mem_rdata;
  // l2_xbar to banks
  logic          [NumL2Banks-1:0] bank_req;
  logic          [NumL2Banks-1:0] bank_gnt;
  logic          [NumL2Banks-1:0] bank_rvalid;
  l2_bank_addr_t [NumL2Banks-1:0] bank_addr;
  bank_ini_t     [NumL2Banks-1:0] bank_ini_d, bank_ini_q;
  axi_data_t     [NumL2Banks-1:0] bank_wdata;
  axi_strb_t     [NumL2Banks-1:0] bank_strb;
  logic          [NumL2Banks-1:0] bank_we;
  axi_data_t     [NumL2Banks-1:0] bank_rdata;

  for (genvar i = 0; i < NumAXIMasters; i++) begin : gen_l2_adapters
    axi2mem #(
      .axi_req_t (axi_tile_req_t ),
      .axi_resp_t(axi_tile_resp_t),
      .AddrWidth (L2AddrWidth    ),
      .DataWidth (AxiDataWidth   ),
      .IdWidth   (AxiTileIdWidth ),
      .NumBanks  (1              ),
      .BufDepth  (3              )
    ) i_axi2mem (
      .clk_i       (clk_i         ),
      .rst_ni      (rst_ni        ),
      .busy_o      (/*unsused*/   ),
      .axi_req_i   (axi_l2_req[i] ),
      .axi_resp_o  (axi_l2_resp[i]),
      .mem_req_o   (mem_req[i]    ),
      .mem_gnt_i   (mem_gnt[i]    ),
      .mem_addr_o  (mem_addr[i]   ),
      .mem_wdata_o (mem_wdata[i]  ),
      .mem_strb_o  (mem_strb[i]   ),
      .mem_atop_o  (/*unused*/    ),
      .mem_we_o    (mem_we[i]     ),
      .mem_rvalid_i(mem_rvalid[i] ),
      .mem_rdata_i (mem_rdata[i]  )
    );
  end

  variable_latency_interconnect #(
    .NumIn            (NumAXIMasters  ),
    .NumOut           (NumL2Banks     ),
    .AddrWidth        (L2AddrWidth    ),
    .DataWidth        (L2BankWidth    ),
    .BeWidth          (L2BankBeWidth  ),
    .AddrMemWidth     (L2BankAddrWidth),
    .AxiVldRdy        (1'b1           ),
    .SpillRegisterReq (64'b1          ),
    .SpillRegisterResp(64'b1          )
  ) i_l2_xbar (
    .clk_i          (clk_i      ),
    .rst_ni         (rst_ni     ),
    // master side
    .req_valid_i    (mem_req    ),
    .req_ready_o    (mem_gnt    ),
    .req_tgt_addr_i (mem_addr   ),
    .req_wen_i      (mem_we     ),
    .req_wdata_i    (mem_wdata  ),
    .req_be_i       (mem_strb   ),
    .resp_valid_o   (mem_rvalid ),
    .resp_ready_i   ('1         ),
    .resp_rdata_o   (mem_rdata  ),
    // slave side
    .req_valid_o    (bank_req   ),
    .req_ready_i    ('1         ),
    .req_ini_addr_o (bank_ini_d ),
    .req_tgt_addr_o (bank_addr  ),
    .req_wen_o      (bank_we    ),
    .req_wdata_o    (bank_wdata ),
    .req_be_o       (bank_strb  ),
    .resp_valid_i   (bank_rvalid),
    .resp_ready_o   (/*unused*/ ), // This only works because resp_ready_i = 1
    .resp_ini_addr_i(bank_ini_q ),
    .resp_rdata_i   (bank_rdata )
  );

  `FF(bank_rvalid, bank_req, 1'b0, clk_i, rst_ni)
  `FF(bank_ini_q, bank_ini_d, 1'b0, clk_i, rst_ni)

  for (genvar i = 0; i < NumL2Banks; i++) begin : gen_l2_banks
    tc_sram #(
      .DataWidth(L2BankWidth   ),
      .NumWords (L2BankNumWords),
      .NumPorts (1             )
    ) l2_mem (
      .clk_i  (clk_i        ),
      .rst_ni (rst_ni       ),
      .req_i  (bank_req[i]  ),
      .we_i   (bank_we[i]   ),
      .addr_i (bank_addr[i] ),
      .wdata_i(bank_wdata[i]),
      .be_i   (bank_strb[i] ),
      .rdata_o(bank_rdata[i])
    );
  end

  /*************
   *  Bootrom  *
   *************/

  // Memory
  logic      bootrom_req;
  logic      bootrom_rvalid;
  addr_t     bootrom_addr;
  axi_data_t bootrom_rdata;

  axi2mem #(
    .axi_req_t  (axi_system_req_t ),
    .axi_resp_t (axi_system_resp_t),
    .AddrWidth  (AddrWidth        ),
    .DataWidth  (AxiDataWidth     ),
    .IdWidth    (AxiSystemIdWidth ),
    .NumBanks   (1                ),
    .BufDepth   (2                )
  ) i_axi2mem_bootrom (
    .clk_i        (clk_i                   ),
    .rst_ni       (rst_ni                  ),

    .busy_o       (/*unsused*/             ),

    .axi_req_i    (axi_periph_req[Bootrom] ),
    .axi_resp_o   (axi_periph_resp[Bootrom]),

    .mem_req_o    (bootrom_req             ),
    .mem_gnt_i    (bootrom_req             ),
    .mem_addr_o   (bootrom_addr            ),
    .mem_wdata_o  (/*unused*/              ),
    .mem_strb_o   (/*unused*/              ),
    .mem_atop_o   (/*unused*/              ),
    .mem_we_o     (/*unused*/              ),
    .mem_rvalid_i (bootrom_rvalid          ),
    .mem_rdata_i  (bootrom_rdata           )
  );

  `FF(bootrom_rvalid, bootrom_req, 1'b0, clk_i, rst_ni)

  bootrom i_bootrom (
    .clk_i  (clk_i        ),
    .req_i  (bootrom_req  ),
    .addr_i (bootrom_addr ),
    .rdata_o(bootrom_rdata)
  );

  /***********************
   *  Control Registers  *
   ***********************/

  localparam NumPeriphs = 2; // Control registers + DMA

  typedef enum logic [$clog2(NumPeriphs) - 1:0] {
    CtrlRegisters,
    DMA
  } axi_lite_xbar_slave_target;

  axi_periph_req_t                     axi_periph_narrow_req;
  axi_periph_resp_t                    axi_periph_narrow_resp;
  axi_lite_slv_req_t                   axi_lite_mst_req;
  axi_lite_slv_resp_t                  axi_lite_mst_resp;
  axi_lite_slv_req_t  [NumPeriphs-1:0] axi_lite_slv_req;
  axi_lite_slv_resp_t [NumPeriphs-1:0] axi_lite_slv_resp;

  localparam xbar_cfg_t AXILiteXBarCfg = '{
    NoSlvPorts         : 1,
    NoMstPorts         : NumPeriphs,
    MaxMstTrans        : 1,
    MaxSlvTrans        : 1,
    FallThrough        : 1'b0,
    LatencyMode        : axi_pkg::NO_LATENCY,
    AxiIdWidthSlvPorts : 0, /* Not used for AXI lite */
    AxiIdUsedSlvPorts  : 0, /* Not used for AXI lite */
    UniqueIds          : 0, /* Not used for AXI lite */
    AxiAddrWidth       : AddrWidth,
    AxiDataWidth       : AxiLiteDataWidth,
    NoAddrRules        : NumPeriphs
  };

  localparam addr_t CtrlRegistersBaseAddr = 32'h4000_0000;
  localparam addr_t CtrlRegistersEndAddr  = 32'h4001_0000;
  localparam addr_t DMABaseAddr           = 32'h4001_0000;
  localparam addr_t DMAEndAddr            = 32'h4002_0000;

  xbar_rule_32_t [NumPeriphs-1:0] axi_lite_xbar_rules;
  assign axi_lite_xbar_rules = '{
    '{idx: CtrlRegisters, start_addr: CtrlRegistersBaseAddr, end_addr: CtrlRegistersEndAddr},
    '{idx: DMA, start_addr: DMABaseAddr, end_addr: DMAEndAddr}
  };

  axi_dw_converter #(
    .AxiMaxReads         (1                ), // Number of outstanding reads
    .AxiSlvPortDataWidth (AxiDataWidth     ), // Data width of the slv port
    .AxiMstPortDataWidth (AxiLiteDataWidth ), // Data width of the mst port
    .AxiAddrWidth        (AddrWidth        ), // Address width
    .AxiIdWidth          (AxiSystemIdWidth ), // ID width
    .aw_chan_t           (axi_system_aw_t  ), // AW Channel Type
    .mst_w_chan_t        (axi_periph_w_t   ), //  W Channel Type for the mst port
    .slv_w_chan_t        (axi_system_w_t   ), //  W Channel Type for the slv port
    .b_chan_t            (axi_system_b_t   ), //  B Channel Type
    .ar_chan_t           (axi_system_ar_t  ), // AR Channel Type
    .mst_r_chan_t        (axi_periph_r_t   ), //  R Channel Type for the mst port
    .slv_r_chan_t        (axi_system_r_t   ), //  R Channel Type for the slv port
    .axi_mst_req_t       (axi_periph_req_t ), // AXI Request Type for mst ports
    .axi_mst_resp_t      (axi_periph_resp_t), // AXI Response Type for mst ports
    .axi_slv_req_t       (axi_system_req_t ), // AXI Request Type for slv ports
    .axi_slv_resp_t      (axi_system_resp_t)  // AXI Response Type for slv ports
  ) i_axi_dw_converter_ctrl (
    .clk_i      (clk_i                       ),
    .rst_ni     (rst_ni                      ),
    // Slave interface
    .slv_req_i  (axi_periph_req[Peripherals] ),
    .slv_resp_o (axi_periph_resp[Peripherals]),
    // Master interface
    .mst_req_o  (axi_periph_narrow_req       ),
    .mst_resp_i (axi_periph_narrow_resp      )
  );

  axi_to_axi_lite #(
    .AxiAddrWidth   (AddrWidth          ),
    .AxiDataWidth   (AxiLiteDataWidth   ),
    .AxiIdWidth     (AxiSystemIdWidth   ),
    .AxiUserWidth   (1                  ),
    .AxiMaxReadTxns (1                  ),
    .AxiMaxWriteTxns(1                  ),
    .FallThrough    (1'b0               ),
    .full_req_t     (axi_periph_req_t   ),
    .full_resp_t    (axi_periph_resp_t  ),
    .lite_req_t     (axi_lite_slv_req_t ),
    .lite_resp_t    (axi_lite_slv_resp_t)
  ) i_axi_to_axi_lite (
    .clk_i     (clk_i                 ),
    .rst_ni    (rst_ni                ),
    .test_i    (1'b0                  ),
    .slv_req_i (axi_periph_narrow_req ),
    .slv_resp_o(axi_periph_narrow_resp),
    .mst_req_o (axi_lite_mst_req      ),
    .mst_resp_i(axi_lite_mst_resp     )
  );

  axi_lite_xbar #(
    .Cfg       (AXILiteXBarCfg     ),
    .aw_chan_t (axi_lite_slv_aw_t  ),
    .w_chan_t  (axi_lite_slv_w_t   ),
    .b_chan_t  (axi_lite_slv_b_t   ),
    .ar_chan_t (axi_lite_slv_ar_t  ),
    .r_chan_t  (axi_lite_slv_r_t   ),
    .axi_req_t (axi_lite_slv_req_t ),
    .axi_resp_t(axi_lite_slv_resp_t),
    .rule_t    (xbar_rule_32_t     )
  ) i_axi_lite_xbar (
    .clk_i                (clk_i              ),
    .rst_ni               (rst_ni             ),
    .test_i               (1'b0               ),
    .slv_ports_req_i      (axi_lite_mst_req   ),
    .slv_ports_resp_o     (axi_lite_mst_resp  ),
    .mst_ports_req_o      (axi_lite_slv_req   ),
    .mst_ports_resp_i     (axi_lite_slv_resp  ),
    .addr_map_i           (axi_lite_xbar_rules),
    .en_default_mst_port_i('1                 ),
    .default_mst_port_i   (CtrlRegisters      )
  );

  ctrl_registers #(
    .NumRegs          (16 + 8             ),
    .TCDMBaseAddr     (TCDMBaseAddr       ),
    .TCDMSize         (TCDMSize           ),
    .NumCores         (NumCores           ),
    .axi_lite_req_t (axi_lite_slv_req_t ),
    .axi_lite_resp_t(axi_lite_slv_resp_t)
  ) i_ctrl_registers (
    .clk_i                (clk_i                           ),
    .rst_ni               (rst_ni                          ),
    .axi_lite_slave_req_i (axi_lite_slv_req[CtrlRegisters] ),
    .axi_lite_slave_resp_o(axi_lite_slv_resp[CtrlRegisters]),
    .ro_cache_ctrl_o      (ro_cache_ctrl                   ),
    .tcdm_start_address_o (/* Unused */                    ),
    .tcdm_end_address_o   (/* Unused */                    ),
    .num_cores_o          (/* Unused */                    ),
    .wake_up_o            (wake_up                         ),
    .eoc_o                (/* Unused */                    ),
    .eoc_valid_o          (eoc_valid_o                     )
  );

  mempool_dma #(
    .axi_lite_req_t(axi_lite_slv_req_t       ),
    .axi_lite_rsp_t(axi_lite_slv_resp_t      ),
    .burst_req_t   (dma_req_t                ),
    .NumBackends   (NumGroups                ),
    .DmaIdWidth    (1                        )
  ) i_mempool_dma (
    .clk_i           (clk_i                 ),
    .rst_ni          (rst_ni                ),
    .config_req_i    (axi_lite_slv_req[DMA] ),
    .config_res_o    (axi_lite_slv_resp[DMA]),
    .burst_req_o     (dma_req               ),
    .valid_o         (dma_req_valid         ),
    .ready_i         (dma_req_ready         ),
    .backend_idle_i  (dma_meta.backend_idle),
    .trans_complete_i(dma_meta.trans_complete),
    .dma_id_o        (dma_id                )
  );

  assign busy_o = 1'b0;

  // From MemPool to the Host
  assign mst_req_o                 = axi_periph_req[External];
  assign axi_periph_resp[External] = mst_resp_i;
  // From the Host to MemPool
  axi_id_remap #(
    .AxiSlvPortIdWidth   (AxiSystemIdWidth ),
    .AxiSlvPortMaxUniqIds(1                ),
    .AxiMaxTxnsPerId     (1                ),
    .AxiMstPortIdWidth   (AxiTileIdWidth   ),
    .slv_req_t           (axi_system_req_t ),
    .slv_resp_t          (axi_system_resp_t),
    .mst_req_t           (axi_tile_req_t   ),
    .mst_resp_t          (axi_tile_resp_t  )
  ) i_axi_id_remap (
    .clk_i     (clk_i                        ),
    .rst_ni    (rst_ni                       ),
    .slv_req_i (slv_req_i                    ),
    .slv_resp_o(slv_resp_o                   ),
    .mst_req_o (axi_mst_req[NumAXIMasters-1] ),
    .mst_resp_i(axi_mst_resp[NumAXIMasters-1])
  );

endmodule : mempool_system
