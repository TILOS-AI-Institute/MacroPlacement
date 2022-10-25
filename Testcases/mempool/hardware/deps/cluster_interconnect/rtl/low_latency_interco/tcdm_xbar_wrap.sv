// Copyright 2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Michael Schaffner <schaffner@iis.ee.ethz.ch>, ETH Zurich
// Date: 06.03.2019
// Description: wrapper for TCDM_XBAR for testbench and testsynthesis

module tcdm_xbar_wrap #(
    parameter NumMaster      = 8,           // number of initiator ports
    parameter NumSlave       = 16,          // number of TCDM banks
    parameter AddrWidth      = 32,          // address width on initiator side
    parameter DataWidth      = 32,          // word width of data
    parameter BeWidth        = DataWidth/8, // width of corresponding byte enables
    parameter AddrMemWidth   = 12           // number of address bits per TCDM bank
) (
    input  logic                                   clk_i,
    input  logic                                   rst_ni,
    // master side
    input  logic [NumMaster-1:0]                   req_i,     // Data request
    input  logic [NumMaster-1:0][AddrWidth-1:0]    add_i,     // Data request Address
    input  logic [NumMaster-1:0]                   wen_i,     // Data request type : 0--> Store, 1 --> Load
    input  logic [NumMaster-1:0][DataWidth-1:0]    wdata_i,   // Data request Write data
    input  logic [NumMaster-1:0][BeWidth-1:0]      be_i,      // Data request Byte enable
    output logic [NumMaster-1:0]                   gnt_o,     // Grant Incoming Request
    output logic [NumMaster-1:0]                   vld_o,     // Data Response Valid (For LOAD/STORE commands)
    output logic [NumMaster-1:0][DataWidth-1:0]    rdata_o,   // Data Response DATA (For LOAD commands)
    // slave side
    output logic [NumSlave-1:0]                    req_o,      // Reuest for bank
    input  logic [NumSlave-1:0]                    gnt_i,      // Grant input
    output logic [NumSlave-1:0][AddrMemWidth-1:0]  add_o,      // Data request Address
    output logic [NumSlave-1:0]                    wen_o,      // Data request type : 0--> Store, 1 --> Load
    output logic [NumSlave-1:0][DataWidth-1:0]     wdata_o,    // Data request Wire data
    output logic [NumSlave-1:0][BeWidth-1:0]       be_o,       // Data request Byte enable
    input  logic [NumSlave-1:0][DataWidth-1:0]     rdata_i     // Data Response DATA (For LOAD commands)
);

  logic [NumSlave-1:0][NumMaster-1:0] id_d, id_q;
  logic [NumSlave-1:0] vld_d, vld_q;
  logic [NumMaster-1:0][AddrWidth:0] add;


  assign vld_d = req_o & gnt_i;

  // disable test and set
  for (genvar k = 0; k < NumMaster; k++) begin : gen_ts
    assign add[k] = {1'b0, add_i[k]};
  end

  XBAR_TCDM #(
    .N_CH0          ( NumMaster    ),
    .N_CH1          ( 0            ),// use single channel mode
    .N_SLAVE        ( NumSlave     ),
    .ADDR_WIDTH     ( AddrWidth+1  ),
    .DATA_WIDTH     ( DataWidth    ),
    .BE_WIDTH       ( BeWidth      ),
    .ADDR_MEM_WIDTH ( AddrMemWidth ),
    .TEST_SET_BIT   ( 32           )
  ) i_XBAR_TCDM (
    .data_req_i        ( req_i         ),
    .data_add_i        ( add           ),
    .data_wen_i        ( wen_i         ),
    .data_wdata_i      ( wdata_i       ),
    .data_be_i         ( be_i          ),
    .data_gnt_o        ( gnt_o         ),
    .data_r_valid_o    ( vld_o         ),
    .data_r_rdata_o    ( rdata_o       ),
    .data_req_o        ( req_o         ),
    .data_ts_set_o     (               ),
    .data_add_o        ( add_o         ),
    .data_wen_o        ( wen_o         ),
    .data_wdata_o      ( wdata_o       ),
    .data_be_o         ( be_o          ),
    .data_ID_o         ( id_d          ),
    .data_gnt_i        ( gnt_i         ),
    .data_r_rdata_i    ( rdata_i       ),
    .data_r_valid_i    ( vld_q         ),
    .data_r_ID_i       ( id_q          ),
    .TCDM_arb_policy_i ( '0            ), // round robin
    .clk               ( clk_i         ),
    .rst_n             ( rst_ni        )
  );

  always_ff @(posedge clk_i) begin : p_regs
    if (!rst_ni) begin
      id_q  <= '0;
      vld_q <= '0;
    end else begin
      id_q  <= id_d;
      vld_q <= vld_d;
    end
  end

endmodule
