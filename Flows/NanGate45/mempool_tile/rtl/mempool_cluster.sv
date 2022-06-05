// Copyright 2021 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

module mempool_cluster
  import mempool_pkg::*;
  import cf_math_pkg::idx_width;
#(
  // TCDM
  parameter addr_t       TCDMBaseAddr  = 32'b0,
  // Boot address
  parameter logic [31:0] BootAddr      = 32'h0000_0000,
  // Dependant parameters. DO NOT CHANGE!
  parameter int unsigned NumAXIMasters = NumGroups
) (
  // Clock and reset
  input  logic                               clk_i,
  input  logic                               rst_ni,
  input  logic                               testmode_i,
  // Scan chain
  input  logic                               scan_enable_i,
  input  logic                               scan_data_i,
  output logic                               scan_data_o,
  // Wake up signal
  input  logic           [NumCores-1:0]      wake_up_i,
  // AXI Interface
  output axi_tile_req_t  [NumAXIMasters-1:0] axi_mst_req_o,
  input  axi_tile_resp_t [NumAXIMasters-1:0] axi_mst_resp_i
);

  /************
   *  Groups  *
   ************/

  // TCDM interfaces
  // North
  tcdm_slave_req_t   [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_north_req;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_north_req_valid;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_north_req_ready;
  tcdm_master_resp_t [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_north_resp;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_north_resp_valid;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_north_resp_ready;
  tcdm_slave_req_t   [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_north_req;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_north_req_valid;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_north_req_ready;
  tcdm_master_resp_t [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_north_resp;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_north_resp_valid;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_north_resp_ready;
  // East
  tcdm_slave_req_t   [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_east_req;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_east_req_valid;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_east_req_ready;
  tcdm_master_resp_t [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_east_resp;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_east_resp_valid;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_east_resp_ready;
  tcdm_slave_req_t   [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_east_req;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_east_req_valid;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_east_req_ready;
  tcdm_master_resp_t [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_east_resp;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_east_resp_valid;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_east_resp_ready;
  // Northeast
  tcdm_slave_req_t   [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_northeast_req;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_northeast_req_valid;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_northeast_req_ready;
  tcdm_master_resp_t [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_northeast_resp;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_northeast_resp_valid;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_northeast_resp_ready;
  tcdm_slave_req_t   [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_northeast_req;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_northeast_req_valid;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_northeast_req_ready;
  tcdm_master_resp_t [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_northeast_resp;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_northeast_resp_valid;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_northeast_resp_ready;
  // Bypass
  tcdm_slave_req_t   [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_bypass_req;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_bypass_req_valid;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_bypass_req_ready;
  tcdm_master_resp_t [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_bypass_resp;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_bypass_resp_valid;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_master_bypass_resp_ready;
  tcdm_slave_req_t   [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_bypass_req;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_bypass_req_valid;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_bypass_req_ready;
  tcdm_master_resp_t [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_bypass_resp;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_bypass_resp_valid;
  logic              [NumGroups-1:0][NumTilesPerGroup-1:0] tcdm_slave_bypass_resp_ready;

  for (genvar g = 0; unsigned'(g) < NumGroups; g++) begin: gen_groups
    mempool_group #(
      .TCDMBaseAddr(TCDMBaseAddr),
      .BootAddr    (BootAddr    )
    ) i_group (
      .clk_i                             (clk_i                                            ),
      .rst_ni                            (rst_ni                                           ),
      .testmode_i                        (testmode_i                                       ),
      .scan_enable_i                     (scan_enable_i                                    ),
      .scan_data_i                       (/* Unconnected */                                ),
      .scan_data_o                       (/* Unconnected */                                ),
      .group_id_i                        (g[idx_width(NumGroups)-1:0]                      ),
      // TCDM Master interfaces
      .tcdm_master_north_req_o           (tcdm_master_north_req[g]                         ),
      .tcdm_master_north_req_valid_o     (tcdm_master_north_req_valid[g]                   ),
      .tcdm_master_north_req_ready_i     (tcdm_master_north_req_ready[g]                   ),
      .tcdm_master_north_resp_i          (tcdm_master_north_resp[g]                        ),
      .tcdm_master_north_resp_valid_i    (tcdm_master_north_resp_valid[g]                  ),
      .tcdm_master_north_resp_ready_o    (tcdm_master_north_resp_ready[g]                  ),
      .tcdm_master_east_req_o            (tcdm_master_east_req[g]                          ),
      .tcdm_master_east_req_valid_o      (tcdm_master_east_req_valid[g]                    ),
      .tcdm_master_east_req_ready_i      (tcdm_master_east_req_ready[g]                    ),
      .tcdm_master_east_resp_i           (tcdm_master_east_resp[g]                         ),
      .tcdm_master_east_resp_valid_i     (tcdm_master_east_resp_valid[g]                   ),
      .tcdm_master_east_resp_ready_o     (tcdm_master_east_resp_ready[g]                   ),
      .tcdm_master_northeast_req_o       (tcdm_master_northeast_req[g]                     ),
      .tcdm_master_northeast_req_valid_o (tcdm_master_northeast_req_valid[g]               ),
      .tcdm_master_northeast_req_ready_i (tcdm_master_northeast_req_ready[g]               ),
      .tcdm_master_northeast_resp_i      (tcdm_master_northeast_resp[g]                    ),
      .tcdm_master_northeast_resp_valid_i(tcdm_master_northeast_resp_valid[g]              ),
      .tcdm_master_northeast_resp_ready_o(tcdm_master_northeast_resp_ready[g]              ),
      .tcdm_master_bypass_req_o          (tcdm_master_bypass_req[g]                        ),
      .tcdm_master_bypass_req_valid_o    (tcdm_master_bypass_req_valid[g]                  ),
      .tcdm_master_bypass_req_ready_i    (tcdm_master_bypass_req_ready[g]                  ),
      .tcdm_master_bypass_resp_i         (tcdm_master_bypass_resp[g]                       ),
      .tcdm_master_bypass_resp_valid_i   (tcdm_master_bypass_resp_valid[g]                 ),
      .tcdm_master_bypass_resp_ready_o   (tcdm_master_bypass_resp_ready[g]                 ),
      // TCDM banks interface
      .tcdm_slave_north_req_i            (tcdm_slave_north_req[g]                          ),
      .tcdm_slave_north_req_valid_i      (tcdm_slave_north_req_valid[g]                    ),
      .tcdm_slave_north_req_ready_o      (tcdm_slave_north_req_ready[g]                    ),
      .tcdm_slave_north_resp_o           (tcdm_slave_north_resp[g]                         ),
      .tcdm_slave_north_resp_valid_o     (tcdm_slave_north_resp_valid[g]                   ),
      .tcdm_slave_north_resp_ready_i     (tcdm_slave_north_resp_ready[g]                   ),
      .tcdm_slave_east_req_i             (tcdm_slave_east_req[g]                           ),
      .tcdm_slave_east_req_valid_i       (tcdm_slave_east_req_valid[g]                     ),
      .tcdm_slave_east_req_ready_o       (tcdm_slave_east_req_ready[g]                     ),
      .tcdm_slave_east_resp_o            (tcdm_slave_east_resp[g]                          ),
      .tcdm_slave_east_resp_valid_o      (tcdm_slave_east_resp_valid[g]                    ),
      .tcdm_slave_east_resp_ready_i      (tcdm_slave_east_resp_ready[g]                    ),
      .tcdm_slave_northeast_req_i        (tcdm_slave_northeast_req[g]                      ),
      .tcdm_slave_northeast_req_valid_i  (tcdm_slave_northeast_req_valid[g]                ),
      .tcdm_slave_northeast_req_ready_o  (tcdm_slave_northeast_req_ready[g]                ),
      .tcdm_slave_northeast_resp_o       (tcdm_slave_northeast_resp[g]                     ),
      .tcdm_slave_northeast_resp_valid_o (tcdm_slave_northeast_resp_valid[g]               ),
      .tcdm_slave_northeast_resp_ready_i (tcdm_slave_northeast_resp_ready[g]               ),
      .tcdm_slave_bypass_req_i           (tcdm_slave_bypass_req[g]                         ),
      .tcdm_slave_bypass_req_valid_i     (tcdm_slave_bypass_req_valid[g]                   ),
      .tcdm_slave_bypass_req_ready_o     (tcdm_slave_bypass_req_ready[g]                   ),
      .tcdm_slave_bypass_resp_o          (tcdm_slave_bypass_resp[g]                        ),
      .tcdm_slave_bypass_resp_valid_o    (tcdm_slave_bypass_resp_valid[g]                  ),
      .tcdm_slave_bypass_resp_ready_i    (tcdm_slave_bypass_resp_ready[g]                  ),
      .wake_up_i                         (wake_up_i[g*NumCoresPerGroup +: NumCoresPerGroup]),
      // AXI interface
      .axi_mst_req_o                     (axi_mst_req_o[g]                                 ),
      .axi_mst_resp_i                    (axi_mst_resp_i[g]                                )
   );
  end : gen_groups

  /*******************
   *  Interconnects  *
   *******************/

  for (genvar ini = 0; ini < NumGroups; ini++) begin: gen_interconnections
    // East
    assign tcdm_slave_east_req[ini ^ 2'b01]       = tcdm_master_east_req[ini];
    assign tcdm_slave_east_req_valid[ini ^ 2'b01] = tcdm_master_east_req_valid[ini];
    assign tcdm_master_east_req_ready[ini]        = tcdm_slave_east_req_ready[ini ^ 2'b01];

    assign tcdm_master_east_resp[ini ^ 2'b01]       = tcdm_slave_east_resp[ini];
    assign tcdm_master_east_resp_valid[ini ^ 2'b01] = tcdm_slave_east_resp_valid[ini];
    assign tcdm_slave_east_resp_ready[ini]          = tcdm_master_east_resp_ready[ini ^ 2'b01];

    // North
    assign tcdm_slave_north_req[ini ^ 2'b10]       = tcdm_master_north_req[ini];
    assign tcdm_slave_north_req_valid[ini ^ 2'b10] = tcdm_master_north_req_valid[ini];
    assign tcdm_master_north_req_ready[ini]        = tcdm_slave_north_req_ready[ini ^ 2'b10];

    assign tcdm_master_north_resp[ini ^ 2'b10]       = tcdm_slave_north_resp[ini];
    assign tcdm_master_north_resp_valid[ini ^ 2'b10] = tcdm_slave_north_resp_valid[ini];
    assign tcdm_slave_north_resp_ready[ini]          = tcdm_master_north_resp_ready[ini ^ 2'b10];

    // Northeast

    // First north, then east
    assign tcdm_slave_bypass_req[ini ^ 2'b10]           = tcdm_master_northeast_req[ini];
    assign tcdm_slave_northeast_req[ini ^ 2'b11]        = tcdm_master_bypass_req[ini ^ 2'b10];
    assign tcdm_slave_bypass_req_valid[ini ^ 2'b10]     = tcdm_master_northeast_req_valid[ini];
    assign tcdm_slave_northeast_req_valid[ini ^ 2'b11]  = tcdm_master_bypass_req_valid[ini ^ 2'b10];
    assign tcdm_master_bypass_req_ready[ini ^ 2'b10]    = tcdm_slave_northeast_req_ready[ini ^ 2'b11];
    assign tcdm_master_northeast_req_ready[ini]         = tcdm_slave_bypass_req_ready[ini ^ 2'b10];

    // First east, then north
    assign tcdm_master_northeast_resp[ini]              = tcdm_slave_bypass_resp[ini ^ 2'b10];
    assign tcdm_master_bypass_resp[ini ^ 2'b10]         = tcdm_slave_northeast_resp[ini ^ 2'b11];
    assign tcdm_master_northeast_resp_valid[ini]        = tcdm_slave_bypass_resp_valid[ini ^ 2'b10];
    assign tcdm_master_bypass_resp_valid[ini ^ 2'b10]   = tcdm_slave_northeast_resp_valid[ini ^ 2'b11];
    assign tcdm_slave_bypass_resp_ready[ini ^ 2'b10]    = tcdm_master_northeast_resp_ready[ini];
    assign tcdm_slave_northeast_resp_ready[ini ^ 2'b11] = tcdm_master_bypass_resp_ready[ini ^ 2'b10];
  end: gen_interconnections

  /****************
   *  Assertions  *
   ****************/

  if (NumCores > 1024)
    $fatal(1, "[mempool] MemPool is currently limited to 1024 cores.");

  if (NumTiles < NumGroups)
    $fatal(1, "[mempool] MemPool requires more tiles than groups.");

  if (NumCores != NumTiles * NumCoresPerTile)
    $fatal(1, "[mempool] The number of cores is not divisible by the number of cores per tile.");

  if (BankingFactor < 1)
    $fatal(1, "[mempool] The banking factor must be a positive integer.");

  if (BankingFactor != 2**$clog2(BankingFactor))
    $fatal(1, "[mempool] The banking factor must be a power of two.");

  if (NumGroups != 4)
    $fatal(1, "[mempool] This version of the MemPool cluster only works with four groups.");

endmodule : mempool_cluster
