// Copyright 2021 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

module mempool_cluster_wrap
  import mempool_pkg::*;
#(
  // TCDM
  parameter addr_t       TCDMBaseAddr  = 32'b0000_0000,
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

  /*********************
   *  MemPool Cluster  *
   *********************/

  mempool_cluster #(
    .TCDMBaseAddr(TCDMBaseAddr),
    .BootAddr    (BootAddr    )
  ) i_mempool_cluster (
    .clk_i         (clk_i         ),
    .rst_ni        (rst_ni        ),
    .testmode_i    (testmode_i    ),
    .scan_enable_i (scan_enable_i ),
    .scan_data_i   (scan_data_i   ),
    .scan_data_o   (scan_data_o   ),
    .wake_up_i     ('0            ),
    .axi_mst_req_o (axi_mst_req_o ),
    .axi_mst_resp_i(axi_mst_resp_i)
  );

endmodule : mempool_cluster_wrap
