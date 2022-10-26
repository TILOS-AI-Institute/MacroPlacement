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
// Create Date:    06/07/2011                                                 // 
// Design Name:    LOG_INTERCONNECT                                           // 
// Module Name:    AddressDecoder_Req                                         //
// Project Name:   MegaLEON                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Address Decoder used to generate the individual requests   //
//                 for all the available memory cuts. It backroutes the       //
//                 stalls from the Arbitration tree to the processor          //
//                                                                            //
//                                                                            //
// Revision:                                                                  //
// Revision v0.1 - 06/07/2011 : File Created                                  //
//          v0.2 - 14/08/2012 : Changed the Routing mechanism, added dual     //
//                              Flow COntrol support (Grant or stall)         //
// Revision v0.1 -19/02/2015  : Code Restyling                                //
// Additional Comments:                                                       //
//                                                                            //
//                                                                            //
//                                                                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////
`include "parameters.v"

module AddressDecoder_Req
#(
    parameter ID_WIDTH      = 16,              // ID WIDTH (number of bits) --> see ID comment
    parameter ID            = 1,               // ID routed with REQUEST used to backroute response
    parameter N_SLAVE       = 32,              // Number of Memory cuts
    parameter ROUT_WIDTH    = `log2_non_zero(N_SLAVE-1) //
) 
(
    // MASTER SIDE
    input  logic                                 data_req_i,      // Request from Master COre
    input  logic [ROUT_WIDTH-1:0]                routing_addr_i,  // routing information from Master Core
`ifdef GNT_BASED_FC
    output logic                                 data_gnt_o,      // Grant delivered to Master Core      
    input  logic [N_SLAVE-1:0]                   data_gnt_i,      // Grant Array: one for each memory (ARB TREE SIDE)
`else
    output logic                                 data_stall_o,    // Stall delivered to Master Core      
    input  logic [N_SLAVE-1:0]                   data_stall_i,    // Stall Array: one for each memory (ARB TREE SIDE)
`endif
    output logic [N_SLAVE-1:0]                   data_req_o,      // Request Array: one for each memory
    output logic [ID_WIDTH-1:0]                  data_ID_o        // data_ID_o is sent whit the request (like a PID)
);

    assign data_ID_o = ID;            // ID is simply attached to the ID_OUT

    generate

        if(N_SLAVE == 1)
        begin :  SINGLE_SLAVE

            assign data_req_o[0] = data_req_i;
        `ifdef GNT_BASED_FC
            assign data_gnt_o = data_gnt_i[0];
        `else
            assign data_stall_o = data_stall_i[0];
        `endif

        end
        else 
        begin : MULTI_SLAVE

            always @(*)
            begin : Combinational_ADDR_DEC_REQ
                //DEFAULT VALUES
                data_req_o = '0;
                // Apply the rigth value
                data_req_o[routing_addr_i] = data_req_i;
            `ifdef GNT_BASED_FC
                data_gnt_o = data_gnt_i[routing_addr_i];
            `else
                data_stall_o = data_stall_i[routing_addr_i];
            `endif
            end

        end

    endgenerate
endmodule
