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
// Module Name:    ResponseBlock_PE                                           //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Response block that embeds address request address decoder //
//                 and Response tree.                                         //
//                                                                            //
// Revision:                                                                  //
// Revision v0.1 02/07/2011  - File Created                                   //
//          v0.2 15/08/2012  - Improved the Interface Structure,              //
//                             Changed the routing mechanism                  //
//          v0.4 20/04/2018  - Supporting non power of 2 N_SLAVE              //
//                                                                            //
// Additional Comments:                                                       //
//                                                                            //
//                                                                            //
//                                                                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////



`include "parameters.v"

module ResponseBlock_PE
#(
    parameter ID             = 1,
    parameter ID_WIDTH       = 17,
    parameter N_SLAVE        = 16,

    parameter DATA_WIDTH     = 32,

    parameter LOG_CLUSTER    = 5,
    parameter ADDR_WIDTH     = 32,
    parameter PE_ROUTING_LSB = 16,
    parameter PE_ROUTING_MSB = 19,
    parameter CLUSTER_ALIAS  = 1'b0,
    parameter CLUSTER_ALIAS_BASE = 12'h000
)
(
        input  logic [LOG_CLUSTER-1:0]                  CLUSTER_ID,
        // -----------------------------------------------------------//
        //                      Response HANDLING
        // -----------------------------------------------------------//
        // Signals from Memory cuts
        input logic [N_SLAVE-1:0]                       data_r_valid_i,
        input logic [N_SLAVE-1:0][DATA_WIDTH-1:0]       data_r_rdata_i,
        input logic [N_SLAVE-1:0]                       data_r_opc_i,
        
        // Output of the ResponseTree Block
        output logic                                    data_r_valid_o,
        output logic [DATA_WIDTH-1:0]                   data_r_rdata_o,
        output logic                                    data_r_opc_o,

        // -----------------------------------------------------------//
        //                      Request HANDLING
        // -----------------------------------------------------------//
        input logic                                     data_req_i,
        input logic [ADDR_WIDTH-1:0]                    data_add_i,
    `ifdef GNT_BASED_FC
        output logic                                    data_gnt_o,
    `else
        output logic                                    data_stall_o,
    `endif              

        
        output logic [N_SLAVE-1:0]                      data_req_o,
    `ifdef GNT_BASED_FC 
        input  logic [N_SLAVE-1:0]                      data_gnt_i,
    `else
        input  logic [N_SLAVE-1:0]                      data_stall_i,
    `endif 
        output logic [ID_WIDTH-1:0]                     data_ID_o    
);
        

     // Response channel exploded to powr of 2 inputs
     logic [2**$clog2(N_SLAVE)-1:0]                   data_r_valid_int;
     logic [2**$clog2(N_SLAVE)-1:0][DATA_WIDTH-1:0]   data_r_rdata_int;
     logic [2**$clog2(N_SLAVE)-1:0]                   data_r_opc_int;



     genvar i;

     generate
      if(2**$clog2(N_SLAVE) == N_SLAVE)
      begin : EXACT_POW2

        for(i=0;i<N_SLAVE;i++)
        begin
          assign data_r_valid_int[i] = data_r_valid_i[i];
          assign data_r_rdata_int[i] = data_r_rdata_i[i];
          assign data_r_opc_int[i]   = data_r_opc_i[i];
        end

      end
      else
      begin : NOT_POW2

        for(i=0; i<2**$clog2(N_SLAVE); i++)
        begin
            if(i<N_SLAVE)
            begin
              assign data_r_valid_int[i] = data_r_valid_i[i];
              assign data_r_rdata_int[i] = data_r_rdata_i[i];
              assign data_r_opc_int[i]   = data_r_opc_i[i];
            end
            else
            begin
              assign data_r_valid_int[i] = 1'b0;
              assign data_r_rdata_int[i] = '0;
              assign data_r_opc_int[i]   = 1'b0;
            end
        end

      end
     endgenerate


      // Response Tree
      ResponseTree_PE 
      #( 
          .N_SLAVE( 2**$clog2(N_SLAVE) ), 
          .DATA_WIDTH(DATA_WIDTH)
      )  
      i_ResponseTree_PE
      (
            // Response Input Channel
            .data_r_valid_i(data_r_valid_int),
            .data_r_rdata_i(data_r_rdata_int),
            .data_r_opc_i(data_r_opc_int),
            // Response Output Channel
            .data_r_valid_o(data_r_valid_o),
            .data_r_rdata_o(data_r_rdata_o),
            .data_r_opc_o(data_r_opc_o)
      );


      AddressDecoder_PE_Req 
      #( 
          .ID_WIDTH        ( ID_WIDTH        ), 
          .ID              ( ID              ), 
          .N_SLAVE         ( N_SLAVE         ),
          .LOG_CLUSTER     ( LOG_CLUSTER     ),
          .ADDR_WIDTH      ( ADDR_WIDTH      ),
          .PE_ROUTING_LSB  ( PE_ROUTING_LSB  ),
          .PE_ROUTING_MSB  ( PE_ROUTING_MSB  ),
          .CLUSTER_ALIAS   ( CLUSTER_ALIAS   ),
          .CLUSTER_ALIAS_BASE (CLUSTER_ALIAS_BASE)
      )
      i_AddressDecoder_PE_Req
      (
        .CLUSTER_ID(CLUSTER_ID),                // CLUSTER_ID is an input!! no Longer a parameter!!!
        // MASTER SIDE
        .data_req_i(data_req_i),                // Request from MASTER
        .data_add_i(data_add_i),                // Address from MASTER
    `ifdef GNT_BASED_FC 
        .data_gnt_o(data_gnt_o),                // Grant delivered to MASTER
        .data_gnt_i(data_gnt_i),                // Grant Array: one for each memory on ARB TREE SIDE
    `else
        .data_stall_o(data_stall_o),            // Stall delivered to MASTER
        .data_stall_i(data_stall_i),            // Stall Array: one for each memory on ARB TREE SIDE
    `endif    
        // ARB TREE SIDE
        .data_req_o(data_req_o),                // Request Array: one for each memory
        .data_ID_o(data_ID_o)                   // ID is sent whit the request (like a PID)
      );


endmodule
