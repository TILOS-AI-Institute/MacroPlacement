////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// Copyright 2018 ETH Zurich and University of Bologna.                       //
// Copyright and related rights are licensed under the Solderpad Hardware     //
// License, Version 0.51 (the "License"); you may not use this file except in //
// compliance with the License.  You may obtain a copy of the License at      //
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law  //
// or agreed to in writing, software, hardware and materials distributed under//
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR     //
// CONDITIONS OF ANY KIND, either express or implied. See the License for the //
// specific language governing permissions and limitations under the License. //
//                                                                            //
// Company:        Micrel Lab @ DEIS - University of Bologna                  //
//                    Viale Risorgimento 2 40136                              //
//                    Bologna - fax 0512093785 -                              //
//                                                                            //
// Engineer:       Igor Loi - igor.loi@unibo.it                               //
//                                                                            //
// Additional contributions by:                                               //
//                                                                            //
//                                                                            //
//                                                                            //
// Create Date:    03/07/2011                                                 //
// Design Name:    LOG_INTERCONNECT                                           //
// Module Name:    XBAR_TCDM                                                  //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Top level for the TCDM Crossbar. It includes both the      //
//                 Request and response Blocks.                               //
//                                                                            //
// Revision:                                                                  //
// v0.1 03/07/2011  - File Created                                            //
// v0.2 14/08/2012  - Improved the Interface Structure,                       //
//                    Changed the routing mechanism                           //
// v0.3 19/02/2015  - Code Restyling,                                         //
//                                                                            //
// Additional Comments:                                                       //
//                                                                            //
//                                                                            //
//                                                                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

`include "parameters.v"


module XBAR_TCDM
#(
    parameter N_CH0           = 16, //--> CH0
    parameter N_CH1           = 4,   //--> CH1
    parameter N_SLAVE         = 32,
    parameter ID_WIDTH        = N_CH0+N_CH1,

    parameter ADDR_WIDTH      = 32,
    parameter DATA_WIDTH      = 32,
    parameter BE_WIDTH        = DATA_WIDTH/8,

    parameter ADDR_MEM_WIDTH  = 12,
    parameter TEST_SET_BIT    = 21
)
(
    // ---------------- MASTER CH0+CH1 SIDE  --------------------------
    input  logic [N_CH0+N_CH1-1:0]                         data_req_i,            // Data request
    input  logic [N_CH0+N_CH1-1:0][ADDR_WIDTH-1:0]         data_add_i,            // Data request Address
    input  logic [N_CH0+N_CH1-1:0]                         data_wen_i,            // Data request type : 0--> Store, 1 --> Load
    input  logic [N_CH0+N_CH1-1:0][DATA_WIDTH-1:0]         data_wdata_i,          // Data request Write data
    input  logic [N_CH0+N_CH1-1:0][BE_WIDTH-1:0]           data_be_i,             // Data request Byte enable
`ifdef GNT_BASED_FC
    output logic [N_CH0+N_CH1-1:0]                         data_gnt_o,            // Grant Incoming Request
`else
    output logic [N_CH0+N_CH1-1:0]                         data_stall_o,          // Stall Incoming Request
`endif
    output logic [N_CH0+N_CH1-1:0]                         data_r_valid_o,        // Data Response Valid (For LOAD/STORE commands)
    output logic [N_CH0+N_CH1-1:0][DATA_WIDTH-1:0]         data_r_rdata_o,        // Data Response DATA (For LOAD commands)

    // ---------------- MM_SIDE (Interleaved) --------------------------
    output  logic [N_SLAVE-1:0]                            data_req_o,            // Data request
    output  logic [N_SLAVE-1:0]                            data_ts_set_o,         // Current Request is a SET during a test&set
    output  logic [N_SLAVE-1:0][ADDR_MEM_WIDTH-1:0]        data_add_o,            // Data request Address
    output  logic [N_SLAVE-1:0]                            data_wen_o,            // Data request type : 0--> Store, 1 --> Load
    output  logic [N_SLAVE-1:0][DATA_WIDTH-1:0]            data_wdata_o,          // Data request Wrire data
    output  logic [N_SLAVE-1:0][BE_WIDTH-1:0]              data_be_o,             // Data request Byte enable
    output  logic [N_SLAVE-1:0][ID_WIDTH-1:0]              data_ID_o,             // Data request Byte enable
`ifdef GNT_BASED_FC
    input   logic [N_SLAVE-1:0]                            data_gnt_i,            // Grant In
`else
    input   logic [N_SLAVE-1:0]                            data_stall_i,          // Stall In
`endif
    input   logic [N_SLAVE-1:0][DATA_WIDTH-1:0]            data_r_rdata_i,        // Data Response DATA (For LOAD commands)
    input   logic [N_SLAVE-1:0]                            data_r_valid_i,        // Valid Response
    input   logic [N_SLAVE-1:0][ID_WIDTH-1:0]              data_r_ID_i,           // ID Response

    input   logic [1:0]                                    TCDM_arb_policy_i,

    input  logic                                           clk,
    input  logic                                           rst_n
);

    localparam ADDR_OFFSET = $clog2(BE_WIDTH);

    // DATA ID array FORM address decoders to Request tree. // UNPACKED ARRAY
    logic      [N_CH0+N_CH1-1:0][ID_WIDTH-1:0]             data_ID;

`ifdef GNT_BASED_FC
    logic   [N_CH0+N_CH1-1:0]      data_gnt_from_MEM[N_SLAVE-1:0];
`else
    logic   [N_CH0+N_CH1-1:0]      data_stall_from_MEM[N_SLAVE-1:0];
`endif

    logic   [N_SLAVE-1:0]          data_req_from_MASTER[N_CH0+N_CH1-1:0];
    logic   [N_CH0+N_CH1-1:0]      data_r_valid_from_MEM[N_SLAVE-1:0];


    logic [N_SLAVE-1:0]            data_r_valid_to_MASTER[N_CH0+N_CH1-1:0];
    logic [N_CH0+N_CH1-1:0]        data_req_to_MEM[N_SLAVE-1:0];
`ifdef GNT_BASED_FC
    logic [N_SLAVE-1:0]            data_gnt_to_MASTER[N_CH0+N_CH1-1:0];
`else
    logic [N_SLAVE-1:0]            data_stall_to_MASTER[N_CH0+N_CH1-1:0];
`endif
    logic [N_CH0+N_CH1-1:0][ADDR_MEM_WIDTH:0]          data_add;
    logic [N_CH0+N_CH1-1:0][`log2(N_SLAVE-1)-1:0]      data_routing;

    genvar j,k;

    generate


    for (k=0; k<N_CH0+N_CH1; k++)
    begin : wiring_req_rout

        assign data_add[k]     = {data_add_i[k][TEST_SET_BIT] , data_add_i[k][ADDR_MEM_WIDTH+`log2(N_SLAVE-1)+ADDR_OFFSET-1:`log2(N_SLAVE-1)+ADDR_OFFSET]};
        if(N_SLAVE == 1)
           assign data_routing[k] =  '0; // Only one memory --> no routing info are needed
        else
           assign data_routing[k] =  data_add_i[k][`log2(N_SLAVE-1)+ADDR_OFFSET-1:ADDR_OFFSET];

        for (j=0; j<N_SLAVE; j++)
          begin : Wiring_flow_ctrl
          assign data_r_valid_to_MASTER[k][j] = data_r_valid_from_MEM[j][k];
          assign data_req_to_MEM[j][k]        = data_req_from_MASTER[k][j];
`ifdef GNT_BASED_FC
          assign data_gnt_to_MASTER[k][j]     = data_gnt_from_MEM[j][k];
`else
          assign data_stall_to_MASTER[k][j]   = data_stall_from_MEM[j][k];
`endif
          end
    end

        for (j=0; j<  N_SLAVE; j++)
          begin : RequestBlock
          if(N_CH1 != 0)
            begin : CH0_CH1
                RequestBlock2CH
                #(
                    .ADDR_MEM_WIDTH ( ADDR_MEM_WIDTH ),
                    .N_CH0          ( N_CH0          ),
                    .N_CH1          ( N_CH1          ),
                    .ID_WIDTH       ( ID_WIDTH       ),
                    .DATA_WIDTH     ( DATA_WIDTH     ),
                    .BE_WIDTH       ( BE_WIDTH       )
                )
                i_RequestBlock2CH
                (
                    // CHANNEL CH0 --> (example: Used for cores)
                    .data_req_CH0_i     ( data_req_to_MEM[j][N_CH0-1:0]     ),
                    .data_add_CH0_i     ( data_add[N_CH0-1:0]               ), //Memory cut address + T&S
                    .data_wen_CH0_i     ( data_wen_i[N_CH0-1:0]             ),
                    .data_wdata_CH0_i   ( data_wdata_i[N_CH0-1:0]           ),
                    .data_be_CH0_i      ( data_be_i[N_CH0-1:0]              ),
                    .data_ID_CH0_i      ( data_ID[N_CH0-1:0]                ),
      `ifdef GNT_BASED_FC
                    .data_gnt_CH0_o     ( data_gnt_from_MEM[j][N_CH0-1:0]   ),
      `else
                    .data_stall_CH0_o   ( data_stall_from_MEM[j][N_CH0-1:0] ),
      `endif
                    // CHANNEL CH1 --> (example: Used for DMAs)
                    .data_req_CH1_i     ( data_req_to_MEM[j][N_CH1+N_CH0-1:N_CH0] ),
                    .data_add_CH1_i     ( data_add[N_CH0+N_CH1-1:N_CH0]           ), //Memory cut address + T&S
                    .data_wen_CH1_i     ( data_wen_i[N_CH1+N_CH0-1:N_CH0]         ),
                    .data_wdata_CH1_i   ( data_wdata_i[N_CH1+N_CH0-1:N_CH0]       ),
                    .data_be_CH1_i      ( data_be_i[N_CH1+N_CH0-1:N_CH0]          ),
                    .data_ID_CH1_i      ( data_ID[N_CH1+N_CH0-1:N_CH0]            ),
      `ifdef GNT_BASED_FC
                    .data_gnt_CH1_o     ( data_gnt_from_MEM[j][N_CH1+N_CH0-1:N_CH0]    ),
      `else
                    .data_stall_CH1_o   ( data_stall_from_MEM[j][N_CH1+N_CH0-1:N_CH0]  ),
      `endif
                    // -----------------             MEMORY                    -------------------
                    // ---------------- RequestBlock OUTPUT (Connected to MEMORY) ----------------
                    .data_req_o         ( data_req_o[j]                                 ),
                    .data_ts_set_o      ( data_ts_set_o[j]                              ),
                    .data_add_o         ( data_add_o[j]                                 ),
                    .data_wen_o         ( data_wen_o[j]                                 ),
                    .data_wdata_o       ( data_wdata_o[j]                               ),
                    .data_be_o          ( data_be_o[j]                                  ),
                    .data_ID_o          ( data_ID_o[j]                                  ),
                    .data_gnt_i         ( data_gnt_i[j]                                 ),
                    // GEN VALID_SIGNALS in the response path
                    .data_r_ID_i        ( data_r_ID_i[j]                                ),
                    .data_r_valid_i     ( data_r_valid_i[j]                             ),
                    .data_r_valid_CH0_o ( data_r_valid_from_MEM[j][N_CH0-1:0]           ), // N_CH0 Bit
                    .data_r_valid_CH1_o ( data_r_valid_from_MEM[j][N_CH0+N_CH1-1:N_CH0] ), // N_CH1 Bit

                    .TCDM_arb_policy_i  ( TCDM_arb_policy_i                             ),

                    .clk                ( clk                                           ),
                    .rst_n              ( rst_n                                         )
                );
        end
          else
            begin : CH0_ONLY
                RequestBlock1CH
                #(
                    .ADDR_MEM_WIDTH     ( ADDR_MEM_WIDTH           ),
                    .N_CH0              ( N_CH0                    ),
                    .ID_WIDTH           ( ID_WIDTH                 ),
                    .DATA_WIDTH         ( DATA_WIDTH               ),
                    .BE_WIDTH           ( BE_WIDTH                 )
                )
                i_RequestBlock1CH
                (
                    // CHANNEL CH0 --> (example: Used for cores)
                    .data_req_CH0_i     ( data_req_to_MEM[j]       ),
                    .data_add_CH0_i     ( data_add                 ),
                    .data_wen_CH0_i     ( data_wen_i               ),
                    .data_wdata_CH0_i   ( data_wdata_i             ),
                    .data_be_CH0_i      ( data_be_i                ),
                    .data_ID_CH0_i      ( data_ID                  ),
  `ifdef GNT_BASED_FC
                    .data_gnt_CH0_o     ( data_gnt_from_MEM[j]     ),
  `else
                    .data_stall_CH0_o   ( data_stall_from_MEM[j]   ),
  `endif
                    // -----------------             MEMORY                    -------------------
                    // ---------------- RequestBlock OUTPUT (Connected to MEMORY) ----------------
                    .data_req_o         ( data_req_o[j]            ),
                    .data_ts_set_o      ( data_ts_set_o[j]         ),
                    .data_add_o         ( data_add_o[j]            ),
                    .data_wen_o         ( data_wen_o[j]            ),
                    .data_wdata_o       ( data_wdata_o[j]          ),
                    .data_be_o          ( data_be_o[j]             ),
                    .data_ID_o          ( data_ID_o[j]             ),
                    .data_gnt_i         ( data_gnt_i[j]            ),
                    // GEN VALID_SIGNALS in the response path
                    .data_r_ID_i        ( data_r_ID_i[j]           ),
                    .data_r_valid_i     ( data_r_valid_i[j]        ),
                    .data_r_valid_CH0_o ( data_r_valid_from_MEM[j] ), // N_CH0 Bit

                    .TCDM_arb_policy_i  ( TCDM_arb_policy_i[0]     ),
                    .clk(clk),
                    .rst_n(rst_n)
                );
            end

          end

        for (j=0; j<  N_CH0+N_CH1; j++)
          begin : ResponseBlock
          ResponseBlock
          #(
              .ID              ( {{(ID_WIDTH-1){1'b0}}, 1'b1}<<j ),
              .ID_WIDTH        ( ID_WIDTH                        ),
              .N_SLAVE         ( N_SLAVE                         ),
              .DATA_WIDTH      ( DATA_WIDTH                      )
          )
          i_ResponseBlock
          (
              // Signals from Memory cuts
              .data_r_valid_i  ( data_r_valid_to_MASTER[j] ),
              .data_r_rdata_i  ( data_r_rdata_i            ),
              // Output of the ResponseTree Block
              .data_r_valid_o  ( data_r_valid_o[j]         ),
              .data_r_rdata_o  ( data_r_rdata_o[j]         ),
              // Inputs form MAsters
              .data_req_i      ( data_req_i[j]             ),
              .routing_addr_i  ( data_routing[j]           ),
          `ifdef GNT_BASED_FC
              .data_gnt_o      ( data_gnt_o[j]             ),
          `else
              .data_stall_o    ( data_stall_o[j]           ),
          `endif
              // Signal to/from Request Block
              .data_req_o      ( data_req_from_MASTER[j]   ),
          `ifdef GNT_BASED_FC
              .data_gnt_i      ( data_gnt_to_MASTER[j]     ),
          `else
              .data_stall_i    ( data_stall_to_MASTER[j]   ),
          `endif
              // Generated ID
              .data_ID_o       ( data_ID[j]                )
          );
          end
    endgenerate
endmodule
