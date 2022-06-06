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
  import axi_pkg::atop_t;
  localparam TCDMSize = NumBanks * TCDMSizePerBank;

  /*********
   *  AXI  *
   *********/

  localparam NumAXIMasters = NumGroups + 1; // +1 because the external host is also a master
  localparam NumAXISlaves  = 4;            // control regs, l2 memory, bootrom and the external mst ports
  localparam NumRules      = NumAXISlaves - 1;

  typedef enum logic [$clog2(NumAXISlaves) - 1:0] {
    CtrlRegisters,
    L2Memory,
    Bootrom,
    External
  } axi_slave_target;

  axi_tile_req_t    [NumAXIMasters - 1:0] axi_mst_req;
  axi_tile_resp_t   [NumAXIMasters - 1:0] axi_mst_resp;
  axi_system_req_t  [NumAXISlaves - 1:0]  axi_mem_req;
  axi_system_resp_t [NumAXISlaves - 1:0]  axi_mem_resp;
  logic             [NumCores - 1:0]      wake_up;
  logic             [DataWidth - 1:0]     eoc;

  localparam xbar_cfg_t XBarCfg = '{
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
    NoAddrRules        : NumRules
  };

  /*********************
   *  MemPool Cluster  *
   ********************/

  mempool_cluster #(
    .TCDMBaseAddr(TCDMBaseAddr),
    .BootAddr    (BootAddr    )
  ) i_mempool_cluster (
    .clk_i         (clk_i                          ),
    .rst_ni        (rst_ni                         ),
    .wake_up_i     (wake_up                        ),
    .testmode_i    (1'b0                           ),
    .scan_enable_i (1'b0                           ),
    .scan_data_i   (1'b0                           ),
    .scan_data_o   (/* Unused */                   ),
    .axi_mst_req_o (axi_mst_req[NumAXIMasters-2:0] ),
    .axi_mst_resp_i(axi_mst_resp[NumAXIMasters-2:0])
  );

  /**********************
   *  AXI Interconnect  *
   **********************/

  localparam addr_t CtrlRegistersBaseAddr = 32'h4000_0000;
  localparam addr_t CtrlRegistersEndAddr  = 32'h4000_FFFF;
  localparam addr_t L2MemoryBaseAddr      = `ifdef L2_BASE `L2_BASE `else 32'h8000_0000 `endif;
  localparam addr_t L2MemoryEndAddr       = L2MemoryBaseAddr + L2Size;
  localparam addr_t BootromBaseAddr       = 32'hA000_0000;
  localparam addr_t BootromEndAddr        = 32'hA000_FFFF;

  xbar_rule_32_t [NumRules - 1:0] xbar_routing_rules;
  assign xbar_routing_rules = '{
    '{idx: CtrlRegisters, start_addr: CtrlRegistersBaseAddr, end_addr: CtrlRegistersEndAddr},
    '{idx: L2Memory, start_addr: L2MemoryBaseAddr, end_addr: L2MemoryEndAddr},
    '{idx: Bootrom, start_addr: BootromBaseAddr, end_addr: BootromEndAddr}
  };

  axi_xbar #(
    .Cfg          (XBarCfg          ),
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
  ) i_xbar (
    .clk_i                (clk_i                    ),
    .rst_ni               (rst_ni                   ),
    .test_i               (1'b0                     ),
    .slv_ports_req_i      (axi_mst_req              ),
    .slv_ports_resp_o     (axi_mst_resp             ),
    .mst_ports_req_o      (axi_mem_req              ),
    .mst_ports_resp_i     (axi_mem_resp             ),
    .addr_map_i           (xbar_routing_rules       ),
    .en_default_mst_port_i('1                       ), // default all slave ports to master port External
    .default_mst_port_i   ({NumAXIMasters{External}})
  );

  /********
   *  L2  *
   ********/
  localparam L2NumWords  = L2Size / L2BeWidth;
  localparam L2AddrWidth = $clog2(L2NumWords);

  // Memory
  logic      mem_req;
  logic      mem_rvalid;
  addr_t     mem_addr;
  axi_data_t mem_wdata;
  axi_strb_t mem_strb;
  logic      mem_we;
  axi_data_t mem_rdata;

  axi2mem #(
    .axi_req_t  (axi_system_req_t ),
    .axi_resp_t (axi_system_resp_t),
    .AddrWidth  (AddrWidth),
    .DataWidth  (AxiDataWidth),
    .IdWidth    (AxiSystemIdWidth),
    .NumBanks   (1),
    .BufDepth   (2)
  ) i_axi2mem_l2mem (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),

    .busy_o       (/*unsused*/),

    .axi_req_i    (axi_mem_req[L2Memory] ),
    .axi_resp_o   (axi_mem_resp[L2Memory]),

    .mem_req_o    (mem_req),
    .mem_gnt_i    (mem_req),
    .mem_addr_o   (mem_addr),
    .mem_wdata_o  (mem_wdata),
    .mem_strb_o   (mem_strb),
    .mem_atop_o   (/*unused*/),
    .mem_we_o     (mem_we),
    .mem_rvalid_i (mem_rvalid),
    .mem_rdata_i  (mem_rdata)
  );

  `FF(mem_rvalid, mem_req, 1'b0, clk_i, rst_ni)

  tc_sram #(
    .DataWidth(AxiDataWidth),
    .NumWords (L2NumWords  ),
    .NumPorts (1           )
  ) l2_mem (
    .clk_i  (clk_i                                ),
    .rst_ni (rst_ni                               ),
    .req_i  (mem_req                              ),
    .we_i   (mem_we                               ),
    .addr_i (mem_addr[L2ByteOffset +: L2AddrWidth]),
    .wdata_i(mem_wdata                            ),
    .be_i   (mem_strb                             ),
    .rdata_o(mem_rdata                            )
  );

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
    .AddrWidth  (AddrWidth),
    .DataWidth  (AxiDataWidth),
    .IdWidth    (AxiSystemIdWidth),
    .NumBanks   (1),
    .BufDepth   (2)
  ) i_axi2mem_bootrom (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),

    .busy_o       (/*unsused*/),

    .axi_req_i    (axi_mem_req[Bootrom] ),
    .axi_resp_o   (axi_mem_resp[Bootrom]),

    .mem_req_o    (bootrom_req),
    .mem_gnt_i    (bootrom_req),
    .mem_addr_o   (bootrom_addr),
    .mem_wdata_o  (/*unused*/),
    .mem_strb_o   (/*unused*/),
    .mem_atop_o   (/*unused*/),
    .mem_we_o     (/*unused*/),
    .mem_rvalid_i (bootrom_rvalid),
    .mem_rdata_i  (bootrom_rdata)
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

  axi_ctrl_req_t    axi_ctrl_req;
  axi_ctrl_resp_t   axi_ctrl_resp;
  axi_lite_slv_req_t  axi_lite_ctrl_registers_req;
  axi_lite_slv_resp_t axi_lite_ctrl_registers_resp;

  axi_dw_converter #(
    .AxiMaxReads         (1                ), // Number of outstanding reads
    .AxiSlvPortDataWidth (AxiDataWidth     ), // Data width of the slv port
    .AxiMstPortDataWidth (AxiLiteDataWidth ), // Data width of the mst port
    .AxiAddrWidth        (AddrWidth        ), // Address width
    .AxiIdWidth          (AxiSystemIdWidth ), // ID width
    .aw_chan_t           (axi_system_aw_t  ), // AW Channel Type
    .mst_w_chan_t        (axi_ctrl_w_t     ), //  W Channel Type for the mst port
    .slv_w_chan_t        (axi_system_w_t   ), //  W Channel Type for the slv port
    .b_chan_t            (axi_system_b_t   ), //  B Channel Type
    .ar_chan_t           (axi_system_ar_t  ), // AR Channel Type
    .mst_r_chan_t        (axi_ctrl_r_t     ), //  R Channel Type for the mst port
    .slv_r_chan_t        (axi_system_r_t   ), //  R Channel Type for the slv port
    .axi_mst_req_t       (axi_ctrl_req_t   ), // AXI Request Type for mst ports
    .axi_mst_resp_t      (axi_ctrl_resp_t  ), // AXI Response Type for mst ports
    .axi_slv_req_t       (axi_system_req_t ), // AXI Request Type for slv ports
    .axi_slv_resp_t      (axi_system_resp_t)  // AXI Response Type for slv ports
  ) i_axi_dw_converter_ctrl (
    .clk_i      (clk_i                      ),
    .rst_ni     (rst_ni                     ),
    // Slave interface
    .slv_req_i  (axi_mem_req[CtrlRegisters] ),
    .slv_resp_o (axi_mem_resp[CtrlRegisters]),
    // Master interface
    .mst_req_o  (axi_ctrl_req               ),
    .mst_resp_i (axi_ctrl_resp              )
  );

  axi_to_axi_lite #(
    .AxiAddrWidth   (AddrWidth          ),
    .AxiDataWidth   (AxiLiteDataWidth   ),
    .AxiIdWidth     (AxiSystemIdWidth   ),
    .AxiUserWidth   (1                  ),
    .AxiMaxReadTxns (1                  ),
    .AxiMaxWriteTxns(1                  ),
    .FallThrough    (1'b0               ),
    .full_req_t     (axi_ctrl_req_t     ),
    .full_resp_t    (axi_ctrl_resp_t    ),
    .lite_req_t     (axi_lite_slv_req_t ),
    .lite_resp_t    (axi_lite_slv_resp_t)
  ) i_axi_to_axi_lite (
    .clk_i     (clk_i                       ),
    .rst_ni    (rst_ni                      ),
    .test_i    (1'b0                        ),
    .slv_req_i (axi_ctrl_req                ),
    .slv_resp_o(axi_ctrl_resp               ),
    .mst_req_o (axi_lite_ctrl_registers_req ),
    .mst_resp_i(axi_lite_ctrl_registers_resp)
  );

  ctrl_registers #(
    .NumRegs        (5                  ),
    .TCDMBaseAddr   (TCDMBaseAddr       ),
    .TCDMSize       (TCDMSize           ),
    .NumCores       (NumCores           ),
    .axi_lite_req_t (axi_lite_slv_req_t ),
    .axi_lite_resp_t(axi_lite_slv_resp_t)
  ) i_ctrl_registers (
    .clk_i                (clk_i                       ),
    .rst_ni               (rst_ni                      ),
    .axi_lite_slave_req_i (axi_lite_ctrl_registers_req ),
    .axi_lite_slave_resp_o(axi_lite_ctrl_registers_resp),
    .tcdm_start_address_o (/* Unused */                ),
    .tcdm_end_address_o   (/* Unused */                ),
    .num_cores_o          (/* Unused */                ),
    .wake_up_o            (wake_up                     ),
    .eoc_o                (/* Unused */                ),
    .eoc_valid_o          (eoc_valid_o                 )
  );

  assign busy_o = 1'b0;

  // From MemPool to the Host
  assign mst_req_o              = axi_mem_req[External];
  assign axi_mem_resp[External] = mst_resp_i;
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
