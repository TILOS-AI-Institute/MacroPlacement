// Copyright 2021 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

`include "common_cells/registers.svh"

import "DPI-C" function void create_request (
  input  bit [31:0] core_id,
  input  bit [31:0] cycle,
  input  bit [31:0] tcdm_base_addr,
  input  bit [31:0] tcdm_mask,
  input  bit [31:0] tile_mask,
  input  bit [31:0] seq_mask,
  output bit        req_valid,
  output bit [31:0] req_id,
  output bit [31:0] req_addr);

import "DPI-C" function void probe_response (
  input bit [31:0] core_id,
  input bit [31:0] cycle,
  input bit        req_ready,
  input bit        resp_valid,
  input bit [31:0] resp_id);

module traffic_generator
  import mempool_pkg::*;
#(
  parameter  int    unsigned MaxOutStandingReads = 1024,
  parameter  int    unsigned NrTCDM              = 2,
  parameter  int    unsigned NumRules            = 1,                          // Routing rules
  parameter  addr_t          TCDMBaseAddr        = 32'b0,
  // Dependant parameters. DO NOT CHANGE!
  localparam int    unsigned StrbWidth           = DataWidth/8,
  localparam int    unsigned ReorderIdWidth      = $clog2(MaxOutStandingReads)
) (
  input  logic                                          clk_i,
  input  logic                                          rst_ni,
  input  logic         [$clog2(NumCores)-1:0]           core_id_i,
  // to TCDM
  output logic         [NrTCDM-1:0]                     tcdm_req_valid_o,
  output logic         [NrTCDM-1:0][AddrWidth-1:0]      tcdm_req_tgt_addr_o,
  output logic         [NrTCDM-1:0]                     tcdm_req_wen_o,
  output logic         [NrTCDM-1:0][DataWidth-1:0]      tcdm_req_wdata_o,
  output logic         [NrTCDM-1:0][3:0]                tcdm_req_amo_o,
  output logic         [NrTCDM-1:0][ReorderIdWidth-1:0] tcdm_req_id_o,
  output logic         [NrTCDM-1:0][StrbWidth-1:0]      tcdm_req_be_o,
  input  logic         [NrTCDM-1:0]                     tcdm_req_ready_i,
  input  logic         [NrTCDM-1:0]                     tcdm_resp_valid_i,
  output logic         [NrTCDM-1:0]                     tcdm_resp_ready_o,
  input  logic         [NrTCDM-1:0][DataWidth-1:0]      tcdm_resp_rdata_i,
  input  logic         [NrTCDM-1:0][ReorderIdWidth-1:0] tcdm_resp_id_i,
  // Address map
  input  address_map_t [NumRules-1:0]                   address_map_i
);

  /*************
   *  Imports  *
   *************/

  import snitch_pkg::dreq_t;
  import snitch_pkg::dresp_t;

  // TCDM Memory Region
  localparam int    unsigned BankOffsetBits = $clog2(NumBanksPerTile);
  localparam int    unsigned NumTilesBits   = $clog2(NumBanks/NumBanksPerTile);

  // Track the instructions
  typedef logic [ReorderIdWidth-1:0] id_t;

  // Cycle count
  logic [31:0] cycle;

  /*************
   *  Payload  *
   *************/

  dreq_t               data_qpayload;
  dresp_t              data_ppayload;
  dreq_t  [NrTCDM-1:0] tcdm_qpayload;
  dresp_t [NrTCDM-1:0] tcdm_ppayload;

  for (genvar i = 0; i < NrTCDM; i++) begin : gen_tcdm_ppayload
    assign tcdm_ppayload[i].id    = tcdm_resp_id_i[i];
    assign tcdm_ppayload[i].data  = tcdm_resp_rdata_i[i];
    assign tcdm_ppayload[i].write = 1'b0;
    assign tcdm_ppayload[i].error = 1'b0;
  end

  for (genvar i = 0; i < NrTCDM; i++) begin : gen_tcdm_qpayload
    assign tcdm_req_tgt_addr_o[i] = tcdm_qpayload[i].addr;
    assign tcdm_req_wdata_o[i]    = tcdm_qpayload[i].data;
    assign tcdm_req_amo_o[i]      = tcdm_qpayload[i].amo;
    assign tcdm_req_id_o[i]       = tcdm_qpayload[i].id;
    assign tcdm_req_wen_o[i]      = tcdm_qpayload[i].write;
    assign tcdm_req_be_o[i]       = tcdm_qpayload[i].strb;
  end

  // Generate requests
  logic                 req_valid;
  logic                 req_ready;
  logic [31:0]          req_id;
  logic [AddrWidth-1:0] req_tgt_addr;
  logic                 resp_valid;
  logic                 resp_ready;

  // Demux according to address
  snitch_addr_demux #(
    .NrOutput     (NrTCDM   ),
    .AddressWidth (AddrWidth),
    .NumRules     (NumRules ),
    .req_t        (dreq_t   ),
    .resp_t       (dresp_t  )
  ) i_snitch_addr_demux (
    .clk_i         (clk_i            ),
    .rst_ni        (rst_ni           ),
    .req_addr_i    (req_tgt_addr     ),
    .req_payload_i (data_qpayload    ),
    .req_valid_i   (req_valid        ),
    .req_ready_o   (req_ready        ),
    .resp_payload_o(data_ppayload    ),
    .resp_valid_o  (resp_valid       ),
    .resp_ready_i  (resp_ready       ),
    .req_payload_o (tcdm_qpayload    ),
    .req_valid_o   (tcdm_req_valid_o ),
    .req_ready_i   (tcdm_req_ready_i ),
    .resp_payload_i(tcdm_ppayload    ),
    .resp_valid_i  (tcdm_resp_valid_i),
    .resp_ready_o  (tcdm_resp_ready_o),
    .address_map_i (address_map_i    )
  );

  /***********************
   *  Generate requests  *
   ***********************/

  // Tile ID
  logic [NumTilesBits-1:0] tile_id;

  // Construct the payload
  assign data_qpayload = '{
    addr   : req_tgt_addr,
    id     : req_id,
    default: '0
  };

  logic [AddrWidth-1:0] TileMask;
  logic [AddrWidth-1:0] SeqMask;

  // Configure the tile mask and the sequential region mask
  always_comb begin
    // Tile ID
    tile_id = core_id_i[$clog2(NumCores)-1 -: NumTilesBits];

    // Masks
    TileMask = '0;
    SeqMask  = '0;

    TileMask[BankOffsetBits + ByteOffset +: NumTilesBits] = '1;
    SeqMask[BankOffsetBits + ByteOffset +: NumTilesBits]  = tile_id;
  end

  // We are always ready
  assign resp_ready = 1'b1;

  // Generate new requests
  always @(negedge clk_i or negedge rst_ni) begin
    // Reset deactivated
    if (!rst_ni) begin
      req_valid    <= 1'b0;
      req_id       <= '0;
      req_tgt_addr <= '0;
    end else begin
      // Create a new request
      create_request(core_id_i, cycle, TCDMBaseAddr, TCDMMask, TileMask, SeqMask, req_valid, req_id,
        req_tgt_addr);
    end
  end

  // Probe the responses
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cycle <= '0;
    end else begin
      cycle <= cycle + 1;
      // NOTE: Needs to be in the same process as `cycle`, to ensure that
      // the function gets the correct value of this variable.
      probe_response(core_id_i, cycle, req_ready, resp_valid, data_ppayload.id);
    end
  end

endmodule: traffic_generator
