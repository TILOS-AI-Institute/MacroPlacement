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
// Create Date:    02/07/2011                                                 //
// Design Name:    LOG_INTERCONNECT                                           //
// Module Name:    ArbitrationTree                                            //
// Project Name:   MegaLEON                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Arbitration tree: This block performs the arbitration      //
//                 between the N_MASTER requests. The arbitration is          //
//                 distributed in the several arbitration primitives that     //
//                 compose this routing block. The arbistrtion is round robin //
//                 and the round robin flag generator is embedded inside this //
//                 block. Flag updating happens only when requests are grant  //
//                                                                            //
// Revision:                                                                  //
// Revision v0.1 - File Created                                               //
// Revision v0.2 - (19/02/2015) Code Restyling                                //
//                                                                            //
// Additional Comments:                                                       //
//                                                                            //
//                                                                            //
//                                                                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

`include "parameters.v"

module ResponseBlock
#(
    parameter                        ID_WIDTH    = 20,
    parameter logic [ID_WIDTH-1:0 ]  ID          = 1'b1,
    parameter                        N_SLAVE     = 8,
    parameter                        DATA_WIDTH  = 32,
    parameter                        ROUT_WIDTH  = `log2_non_zero(N_SLAVE-1)
)
(
    // -----------------------------------------------------------//
    //                      Response HANDLING
    // -----------------------------------------------------------//
    // Signals from Memory cuts
    input logic [N_SLAVE-1:0]                    data_r_valid_i,
    input logic [N_SLAVE-1:0][DATA_WIDTH-1:0]    data_r_rdata_i,
    // Output of the ResponseTree Block
    output logic                                 data_r_valid_o,
    output logic [DATA_WIDTH-1:0]                data_r_rdata_o,


    // -----------------------------------------------------------//
    //                      Request HANDLING
    // -----------------------------------------------------------//
    input logic                                  data_req_i,
    input logic [ROUT_WIDTH-1:0]                 routing_addr_i,
    `ifdef GNT_BASED_FC
    output logic                                 data_gnt_o,
    input  logic [N_SLAVE-1:0]                   data_gnt_i,
    `else
    output logic                                 data_stall_o,
    input  logic [N_SLAVE-1:0]                   data_stall_i,
    `endif
    output logic [N_SLAVE-1:0]                   data_req_o,
    output logic [ID_WIDTH-1:0]                  data_ID_o
);


generate
    case(N_SLAVE)
        1:
        begin : SINGLE_SLAVE
                assign data_r_valid_o =  data_r_valid_i[0];
                assign data_r_rdata_o =  data_r_rdata_i[0];
        end

        2:
        begin : DUAL_SLAVE
         FanInPrimitive_Resp
         #(
             .DATA_WIDTH       ( DATA_WIDTH         )
         )
         i_FanInPrimitive_Resp
         (
             // RIGTH SIDE
             .data_r_rdata0_i  ( data_r_rdata_i[0]  ),
             .data_r_rdata1_i  ( data_r_rdata_i[1]  ),
             .data_r_valid0_i  ( data_r_valid_i[0]  ),
             .data_r_valid1_i  ( data_r_valid_i[1]  ),
             // LEFT SIDE
             .data_r_rdata_o   ( data_r_rdata_o     ),
             .data_r_valid_o   ( data_r_valid_o     )
         );
        end

        default:
        begin : MULTI_SLAVE
            // Response Tree
            ResponseTree
            #(
                .N_SLAVE         ( N_SLAVE         ),
                .DATA_WIDTH      ( DATA_WIDTH      )
            )
            i_ResponseTree
            (
                // Response Input Channel
                .data_r_valid_i  ( data_r_valid_i  ),
                .data_r_rdata_i  ( data_r_rdata_i  ),
                // Response Output Channel
                .data_r_valid_o  ( data_r_valid_o  ),
                .data_r_rdata_o  ( data_r_rdata_o  )
            );
        end
    endcase

endgenerate

    AddressDecoder_Req
    #(
        .ID_WIDTH   ( ID_WIDTH ),
        .ID         ( ID       ),
        .N_SLAVE    ( N_SLAVE  )
    )
    i_AddressDecoder_Req
    (
        // MASTER SIDE
        .data_req_i      ( data_req_i     ),            // Request from MASTER
        .routing_addr_i  ( routing_addr_i ),            // Address from MASTER
    `ifdef GNT_BASED_FC
        .data_gnt_o      ( data_gnt_o     ),            // Grant delivered to MASTER
        .data_gnt_i      ( data_gnt_i     ),            // Grant Array: one for each memory (On ARB TREE SIDE)
    `else
        .data_stall_o    ( data_stall_o   ),            // STall delivered to MASTER
        .data_stall_i    ( data_stall_i   ),            // Stall Array: one for each memory (On ARB TREE SIDE)
      `endif
        // ARB TREE SIDE
        .data_req_o      ( data_req_o     ),            // Request Array: one for each memory
        .data_ID_o       ( data_ID_o      )             // ID is sent whit the request (like a PID)
    );


endmodule
