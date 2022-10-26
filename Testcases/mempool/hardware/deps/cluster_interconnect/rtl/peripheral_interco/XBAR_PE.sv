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
// Module Name:    XBAR_PE                                                    //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Top level for the PERIPH Crossbar. It includes both the    //
//                 Request and response Blocks.                               //
//                                                                            //
// Revision:                                                                  //
// Revision v0.1 02/07/2011  - File Created                                   //
//          v0.2 15/08/2012  - Improved the Interface Structure,              //
//                             Changed the routing mechanism                  //
//          v0.3 09/03/2015  - Improved identation                            //
//          v0.4 20/04/2018  - Supporting non power of 2 N_SLAVE              //
//                                                                            //
// Additional Comments:                                                       //
//                                                                            //
//                                                                            //
//                                                                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

`include "parameters.v"

module XBAR_PE 
#(
    parameter N_CH0          = 8, //--> CH0
    parameter N_CH1          = 1,  //--> CH1
    parameter N_SLAVE        = 9,
    parameter ID_WIDTH       = N_CH0+N_CH1,

    parameter PE_LSB         = 0,
    parameter PE_MSB         = 31,

    parameter LOG_CLUSTER    = 5,
    parameter ADDR_WIDTH     = 32,
    parameter DATA_WIDTH     = 32,
    parameter BE_WIDTH       = DATA_WIDTH/8,

    parameter PE_ROUTING_LSB = 10,
    parameter PE_ROUTING_MSB = PE_ROUTING_LSB+$clog2(N_SLAVE)-1,

    parameter CLUSTER_ALIAS  = 1'b0,
    parameter CLUSTER_ALIAS_BASE = 12'h000,

    parameter ADDR_PE_WIDTH = PE_MSB - PE_LSB + 1
)
(
    input [LOG_CLUSTER-1:0]                                CLUSTER_ID,
    // ---------------- MASTER CH0+CH1 SIDE  --------------------------
    // Req
    input  logic [N_CH0+N_CH1-1:0]                         data_req_i,                // Data request
    input  logic [N_CH0+N_CH1-1:0][ADDR_WIDTH-1:0]         data_add_i,                // Data request Address
    input  logic [N_CH0+N_CH1-1:0]                         data_wen_i,                // Data request type : 0--> Store, 1 --> Load
    input  logic [N_CH0+N_CH1-1:0][DATA_WIDTH-1:0]         data_wdata_i,              // Data request Write data
    input  logic [N_CH0+N_CH1-1:0][BE_WIDTH-1:0]           data_be_i,                 // Data request Byte enable
`ifdef GNT_BASED_FC
    output logic [N_CH0+N_CH1-1:0]                         data_gnt_o,                // Data request Grant
`else
    output logic [N_CH0+N_CH1-1:0]                         data_stall_o,              // Data request stall
`endif
    // Resp
    output logic [N_CH0+N_CH1-1:0]                         data_r_valid_o,            // Data Response Valid (For LOAD/STORE commands)
    output logic [N_CH0+N_CH1-1:0][DATA_WIDTH-1:0]         data_r_rdata_o,            // Data Response DATA (For LOAD commands)
    output logic [N_CH0+N_CH1-1:0]                         data_r_opc_o,              // Response Error


    // ---------------- MM_SIDE (Interleaved) -------------------------- 
    // Req --> to Mem
    output  logic [N_SLAVE-1:0]                            data_req_o,                // Data request
    output  logic [N_SLAVE-1:0][ADDR_PE_WIDTH-1:0]         data_add_o,                // Data request Address
    output  logic [N_SLAVE-1:0]                            data_wen_o,                // Data request type : 0--> Store, 1 --> Load
    output  logic [N_SLAVE-1:0][DATA_WIDTH-1:0]            data_wdata_o,              // Data request Wrire data
    output  logic [N_SLAVE-1:0][BE_WIDTH-1:0]              data_be_o,                 // Data request Byte enable 
    output  logic [N_SLAVE-1:0][ID_WIDTH-1:0]              data_ID_o,
`ifdef GNT_BASED_FC
    input   logic [N_SLAVE-1:0]                            data_gnt_i,                // Data request : input on slave side 
`else
    input   logic [N_SLAVE-1:0]                            data_stall_i,              // Data request stall : input on slave side     
`endif
    // Resp        --> From Mem
    input  logic [N_SLAVE-1:0][DATA_WIDTH-1:0]            data_r_rdata_i,            // Data Response DATA (For LOAD commands)
    input  logic [N_SLAVE-1:0]                            data_r_valid_i,            // Data Response: Command is Committed
    input  logic [N_SLAVE-1:0][ID_WIDTH-1:0]              data_r_ID_i,               // Data Response ID: To backroute Response
    input  logic [N_SLAVE-1:0]                            data_r_opc_i,              // Data Response: Error

    input  logic                                           clk,                       // Clock
    input  logic                                           rst_n                      // Active Low Reset
);

    // DATA ID array FORM address decoders to Request tree.
    logic  [N_CH0+N_CH1-1:0][ID_WIDTH-1:0]           data_ID;

`ifdef GNT_BASED_FC
    logic   [N_CH0+N_CH1-1:0]                        data_gnt_from_MEM[N_SLAVE-1:0];
`else
    logic   [N_CH0+N_CH1-1:0]                        data_stall_from_MEM[N_SLAVE-1:0];
`endif
    logic   [N_SLAVE-1:0]                            data_req_from_MASTER[N_CH0+N_CH1-1:0];
    logic   [N_CH0+N_CH1-1:0]                        data_r_valid_from_MEM[N_SLAVE-1:0];

    logic [N_SLAVE-1:0]                              data_r_valid_to_MASTER[N_CH0+N_CH1-1:0];
    logic [N_CH0+N_CH1-1:0]                          data_req_to_MEM[N_SLAVE-1:0];
`ifdef GNT_BASED_FC
    logic [N_SLAVE-1:0]                              data_gnt_to_MASTER[N_CH0+N_CH1-1:0];
`else
    logic [N_SLAVE-1:0]                              data_stall_to_MASTER[N_CH0+N_CH1-1:0];
`endif

    logic [N_CH0+N_CH1-1:0][ADDR_PE_WIDTH-1:0]       data_add;


    genvar j,k;

    generate

        for (k=0; k<N_CH0+N_CH1; k++)
        begin
          assign data_add[k] = data_add_i[k][PE_MSB:PE_LSB];

          for (j=0; j<N_SLAVE; j++)
            begin
              assign data_r_valid_to_MASTER[k][j] = data_r_valid_from_MEM[j][k];
              assign data_req_to_MEM[j][k]        = data_req_from_MASTER[k][j];
          `ifdef GNT_BASED_FC
              assign data_gnt_to_MASTER[k][j]     = data_gnt_from_MEM[j][k];
          `else
              assign data_stall_to_MASTER[k][j]    = data_stall_from_MEM[j][k];          
          `endif
            end
        end


        for (j=0; j<  N_SLAVE; j++)
        begin : RequestBlock
           if(N_CH1 != 0)
           begin : CH0_CH1
              RequestBlock2CH_PE   
              #( 
                  .ADDR_WIDTH ( ADDR_PE_WIDTH ), 
                  .N_CH0      ( N_CH0         ),
                  .N_CH1      ( N_CH1         ),
                  .ID_WIDTH   ( ID_WIDTH      ),
                  .DATA_WIDTH ( DATA_WIDTH    ),
                  .BE_WIDTH   ( DATA_WIDTH/8  )
              )
              i_RequestBlock2CH_PE
              (
                // CHANNEL CH0 --> (example: Used for cores) 
                .data_req_CH0_i      ( data_req_to_MEM[j]    [N_CH0-1:0]             ),
                .data_add_CH0_i      ( data_add              [N_CH0-1:0]             ),
                .data_wen_CH0_i      ( data_wen_i            [N_CH0-1:0]             ),
                .data_wdata_CH0_i    ( data_wdata_i          [N_CH0-1:0]             ),
                .data_be_CH0_i       ( data_be_i             [N_CH0-1:0]             ),
                .data_ID_CH0_i       ( data_ID               [N_CH0-1:0]             ),
          `ifdef GNT_BASED_FC
                .data_gnt_CH0_o      ( data_gnt_from_MEM[j]  [N_CH0-1:0]             ),
          `else
                 .data_stall_CH0_o   ( data_stall_from_MEM[j][N_CH0-1:0]             ),
          `endif                 
                // CHANNEL CH1 --> ( example: Used for DMAs )
                .data_req_CH1_i      ( data_req_to_MEM[j]    [N_CH1+N_CH0-1:N_CH0]   ),
                .data_add_CH1_i      ( data_add              [N_CH1+N_CH0-1:N_CH0]   ),
                .data_wen_CH1_i      ( data_wen_i            [N_CH1+N_CH0-1:N_CH0]   ),
                .data_wdata_CH1_i    ( data_wdata_i          [N_CH1+N_CH0-1:N_CH0]   ),
                .data_be_CH1_i       ( data_be_i             [N_CH1+N_CH0-1:N_CH0]   ),
                .data_ID_CH1_i       ( data_ID               [N_CH1+N_CH0-1:N_CH0]   ),
          `ifdef GNT_BASED_FC
                 .data_gnt_CH1_o     ( data_gnt_from_MEM[j]  [N_CH1+N_CH0-1:N_CH0]   ),
          `else
                .data_stall_CH1_o    ( data_stall_from_MEM[j][N_CH1+N_CH0-1:N_CH0]   ),
          `endif                  
                // -----------------             MEMORY                    -------------------
                // ---------------- RequestBlock OUTPUT (Connected to MEMORY) ----------------
                .data_req_o          ( data_req_o[j]                                 ),
                .data_add_o          ( data_add_o[j]                                 ),
                .data_wen_o          ( data_wen_o[j]                                 ),
                .data_wdata_o        ( data_wdata_o[j]                               ),
                .data_be_o           ( data_be_o[j]                                  ),
                .data_ID_o           ( data_ID_o[j]                                  ),
          `ifdef GNT_BASED_FC
                .data_gnt_i          ( data_gnt_i[j]                                 ),          
          `else
                 .data_stall_i       ( data_stall_i[j]                               ),         
          `endif   
                .data_r_valid_i      ( data_r_valid_i[j]                             ),
                .data_r_ID_i         ( data_r_ID_i[j]                                ),

                // GEN VALID_SIGNALS in the response path
                .data_r_valid_CH0_o  ( data_r_valid_from_MEM[j][N_CH0-1:0]           ), // N_CH0 Bit
                .data_r_valid_CH1_o  ( data_r_valid_from_MEM[j][N_CH0+N_CH1-1:N_CH0] ), // N_CH1 Bit
                .clk                 ( clk                                           ),
                .rst_n               ( rst_n                                         )
            );
           end
           else
           begin : CH0_ONLY
              RequestBlock1CH_PE  
              #( 
                  .ADDR_WIDTH(ADDR_PE_WIDTH), 
                  .N_CH0(N_CH0), 
                  .ID_WIDTH(ID_WIDTH),
                  .DATA_WIDTH(DATA_WIDTH),
                  .BE_WIDTH(DATA_WIDTH/8)
              ) 
              i_RequestBlock1CH_PE
              (
                // CHANNEL CH0 --> (example: Used for cores) 
                .data_req_CH0_i(data_req_to_MEM[j]),
                .data_add_CH0_i(data_add),
                .data_wen_CH0_i(data_wen_i),
                .data_wdata_CH0_i(data_wdata_i),
                .data_be_CH0_i(data_be_i),
                .data_ID_CH0_i(data_ID),
          `ifdef GNT_BASED_FC
                 .data_gnt_CH0_o(data_gnt_from_MEM[j]),
          `else
                .data_stall_CH0_o(data_stall_from_MEM[j]),
          `endif
                // -----------------             MEMORY                    -------------------
                // ---------------- RequestBlock OUTPUT (Connected to MEMORY) ----------------
                .data_req_o(data_req_o[j]),
                .data_add_o(data_add_o[j]),
                .data_wen_o(data_wen_o[j]),
                .data_wdata_o(data_wdata_o[j]),
                .data_be_o(data_be_o[j]),
                .data_ID_o(data_ID_o[j]),
          `ifdef GNT_BASED_FC
                .data_gnt_i(data_gnt_i[j]),
          `else
                .data_stall_i(data_stall_i[j]),
          `endif
                .data_r_valid_i(data_r_valid_i[j]),
                .data_r_ID_i(data_r_ID_i[j]),
                // GEN VALID_SIGNALS in the response path
                .data_r_valid_CH0_o(data_r_valid_from_MEM[j]), // N_CH0 Bit
                .clk(clk),
                .rst_n(rst_n)
            );
           end
        end

        for (j=0; j<  N_CH0+N_CH1; j++)
        begin : ResponseBlock_PE_Block
            ResponseBlock_PE 
            #( 
                .ID             ( 2**j           ), 
                .ID_WIDTH       ( ID_WIDTH       ), 
                .N_SLAVE        ( N_SLAVE        ),
                .DATA_WIDTH     ( DATA_WIDTH     ),
                .LOG_CLUSTER    ( LOG_CLUSTER    ),
                .ADDR_WIDTH     ( ADDR_WIDTH     ),
                .PE_ROUTING_LSB ( PE_ROUTING_LSB ),
                .PE_ROUTING_MSB ( PE_ROUTING_MSB ),
                .CLUSTER_ALIAS  ( CLUSTER_ALIAS  ),
                .CLUSTER_ALIAS_BASE (CLUSTER_ALIAS_BASE)
            ) 
            i_ResponseBlock_PE
            (
                .CLUSTER_ID(CLUSTER_ID),
                // Signals from Memory cuts
                .data_r_valid_i(data_r_valid_to_MASTER[j]),
                .data_r_rdata_i(data_r_rdata_i),
                .data_r_opc_i(data_r_opc_i),
                // Output of the ResponseTree Block
                .data_r_valid_o(data_r_valid_o[j]),
                .data_r_rdata_o(data_r_rdata_o[j]),
                .data_r_opc_o(data_r_opc_o[j]),
                // Inputs form MAsters
                .data_req_i(data_req_i[j]),
                .data_add_i(data_add_i[j]),
      `ifdef GNT_BASED_FC
                  .data_gnt_o(data_gnt_o[j]),  // grant to master port
                  .data_gnt_i(data_gnt_to_MASTER[j]), // Signal from Request Block
      `else
                  .data_stall_o(data_stall_o[j]),         // stall to master port
                  .data_stall_i(data_stall_to_MASTER[j]), // Signal from Request Block
      `endif
                // Signal to/from Request Block
                .data_req_o(data_req_from_MASTER[j]),
                // Generated ID
                .data_ID_o(data_ID[j])
            );
          end

    endgenerate

endmodule
