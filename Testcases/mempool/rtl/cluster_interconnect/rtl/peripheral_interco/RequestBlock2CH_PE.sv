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
// Module Name:    RequestBlock2CH_PE                                         //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Request Block: it embed inside the routing trees and the   //
//                 Multiplexer to mix the request from two channels (one      //
//                 distributed in the several arbitration primitives that     //
//                 compose this routing block. The arbistrtion is round robin //
//                 and the round robin flag generator is embedded inside this //
//                 block. Flag updating happens only when requests are grant  //
//                                                                            //
// Revision:                                                                  //
// Revision v0.1 02/07/2011  - File Created                                   //
//           v0.2 14/08/2012  - Improved the Interface Structure,              //
//                             Changed the routing mechanism                  //
// Additional Comments:                                                       //
//                                                                            //
//                                                                            //
//                                                                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

`include "parameters.v"

// FOR TWO INPUTS
module RequestBlock2CH_PE
#(
    parameter ADDR_WIDTH = 32,
    parameter N_CH0      = 16, // Example Number of cores
    parameter N_CH1      = 1, // Example Number of DMAs
    parameter ID_WIDTH   = N_CH0+N_CH1,
    parameter DATA_WIDTH = 32,
    parameter BE_WIDTH   = DATA_WIDTH/8
)
(
    // CHANNEL CH0 --> (example: Used for cores) 
    input  logic [N_CH0-1:0]                     data_req_CH0_i,
    input  logic [N_CH0-1:0][ADDR_WIDTH-1:0]     data_add_CH0_i,
    input  logic [N_CH0-1:0]                     data_wen_CH0_i,
    input  logic [N_CH0-1:0][DATA_WIDTH-1:0]     data_wdata_CH0_i,
    input  logic [N_CH0-1:0][BE_WIDTH-1:0]       data_be_CH0_i,
    input  logic [N_CH0-1:0][ID_WIDTH-1:0]       data_ID_CH0_i,
`ifdef GNT_BASED_FC
    output logic [N_CH0-1:0]                     data_gnt_CH0_o,
`else
    output logic [N_CH0-1:0]                     data_stall_CH0_o,
`endif

    // CHANNEL CH1 --> (example: Used for DMAs)
    input  logic [N_CH1-1:0]                     data_req_CH1_i,
    input  logic [N_CH1-1:0][ADDR_WIDTH-1:0]     data_add_CH1_i,
    input  logic [N_CH1-1:0]                     data_wen_CH1_i,
    input  logic [N_CH1-1:0][DATA_WIDTH-1:0]     data_wdata_CH1_i,
    input  logic [N_CH1-1:0][BE_WIDTH-1:0]       data_be_CH1_i,
    input  logic [N_CH1-1:0][ID_WIDTH-1:0]       data_ID_CH1_i,
`ifdef GNT_BASED_FC
    output logic [N_CH1-1:0]                     data_gnt_CH1_o,
`else
    output logic [N_CH1-1:0]                     data_stall_CH1_o,
`endif

    // -----------------             MEMORY                    -------------------
    // ---------------- RequestBlock OUTPUT (Connected to MEMORY) ----------------
    output logic                                 data_req_o,
    output logic [ADDR_WIDTH-1:0]                data_add_o,
    output logic                                 data_wen_o,
    output logic [DATA_WIDTH-1:0]                data_wdata_o,
    output logic [BE_WIDTH-1:0]                  data_be_o,
    output logic [ID_WIDTH-1:0]                  data_ID_o,
`ifdef GNT_BASED_FC
    input  logic                                 data_gnt_i,
`else
    input  logic                                 data_stall_i,
`endif
    input   logic                                data_r_valid_i,
    input   logic [ID_WIDTH-1:0]                 data_r_ID_i,



    // GEN VALID_SIGNALS in the response path
    output logic [N_CH0-1:0]                      data_r_valid_CH0_o,
    output logic [N_CH1-1:0]                      data_r_valid_CH1_o,

    input  logic                                  clk,
    input  logic                                  rst_n

   );
   
       // OUT CHANNEL CH0 --> (example: Used for cores) 
      logic                                                data_req_CH0;
      logic [ADDR_WIDTH-1:0]                               data_add_CH0;
      logic                                                data_wen_CH0;
      logic [DATA_WIDTH-1:0]                               data_wdata_CH0;
      logic [BE_WIDTH-1:0]                                 data_be_CH0;
      logic [ID_WIDTH-1:0]                                 data_ID_CH0;
    `ifdef GNT_BASED_FC            
      logic                                                data_gnt_CH0;
    `else
      logic                                                data_stall_CH0;    
    `endif
    
      // OUT CHANNEL CH1 --> (example: Used for DMAs)
      logic                                               data_req_CH1;
      logic [ADDR_WIDTH-1:0]                              data_add_CH1;
      logic                                               data_wen_CH1;
      logic [DATA_WIDTH-1:0]                              data_wdata_CH1;
      logic [BE_WIDTH-1:0]                                data_be_CH1;
      logic [ID_WIDTH-1:0]                                data_ID_CH1;
    `ifdef GNT_BASED_FC            
      logic                                               data_gnt_CH1;
    `else 
      logic                                               data_stall_CH1;    
    `endif

  
      // CHANNEL CH0 --> (example: Used for Processing Elements / CORES) 
    logic [2**$clog2(N_CH0)-1:0]                                data_req_CH0_int;
    logic [2**$clog2(N_CH0)-1:0][ADDR_WIDTH-1:0]                data_add_CH0_int;
    logic [2**$clog2(N_CH0)-1:0]                                data_wen_CH0_int;
    logic [2**$clog2(N_CH0)-1:0][DATA_WIDTH-1:0]                data_wdata_CH0_int;
    logic [2**$clog2(N_CH0)-1:0][BE_WIDTH-1:0]                  data_be_CH0_int;
    logic [2**$clog2(N_CH0)-1:0][ID_WIDTH-1:0]                  data_ID_CH0_int;
`ifdef GNT_BASED_FC
    logic [2**$clog2(N_CH0)-1:0]                                data_gnt_CH0_int;
`else
    logic [2**$clog2(N_CH0)-1:0]                                data_stall_CH0_int;
`endif



    // CHANNEL CH0 --> (example: Used for Processing Elements / CORES) 
    logic [2**$clog2(N_CH1)-1:0]                                data_req_CH1_int;
    logic [2**$clog2(N_CH1)-1:0][ADDR_WIDTH-1:0]                data_add_CH1_int;
    logic [2**$clog2(N_CH1)-1:0]                                data_wen_CH1_int;
    logic [2**$clog2(N_CH1)-1:0][DATA_WIDTH-1:0]                data_wdata_CH1_int;
    logic [2**$clog2(N_CH1)-1:0][BE_WIDTH-1:0]                  data_be_CH1_int;
    logic [2**$clog2(N_CH1)-1:0][ID_WIDTH-1:0]                  data_ID_CH1_int;
`ifdef GNT_BASED_FC
    logic [2**$clog2(N_CH1)-1:0]                                data_gnt_CH1_int;
`else
    logic [2**$clog2(N_CH1)-1:0]                                data_stall_CH1_int;
`endif




      generate


              if(2**$clog2(N_CH0) != N_CH0) // if N_CH0 is not power of 2 --> then use power 2 ports
              begin : _DUMMY_CH0_PORTS_
                
                logic [2**$clog2(N_CH0)-N_CH0 -1 :0]                                data_req_CH0_dummy;
                logic [2**$clog2(N_CH0)-N_CH0 -1 :0][ADDR_WIDTH-1:0]                data_add_CH0_dummy; // Memory address + T&S bit
                logic [2**$clog2(N_CH0)-N_CH0 -1 :0]                                data_wen_CH0_dummy;
                logic [2**$clog2(N_CH0)-N_CH0 -1 :0][DATA_WIDTH-1:0]                data_wdata_CH0_dummy;
                logic [2**$clog2(N_CH0)-N_CH0 -1 :0][BE_WIDTH-1:0]                  data_be_CH0_dummy;
                logic [2**$clog2(N_CH0)-N_CH0 -1 :0][ID_WIDTH-1:0]                  data_ID_CH0_dummy;
            `ifdef GNT_BASED_FC
                logic [2**$clog2(N_CH0)-N_CH0 -1 :0]                                data_gnt_CH0_dummy;
            `else
                logic [2**$clog2(N_CH0)-N_CH0 -1 :0]                                data_stall_CH0_dummy;
            `endif

                assign data_req_CH0_dummy    = '0 ;  
                assign data_add_CH0_dummy    = '0 ;   
                assign data_wen_CH0_dummy    = '0 ;  
                assign data_wdata_CH0_dummy  = '0 ;
                assign data_be_CH0_dummy     = '0 ;   
                assign data_ID_CH0_dummy     = '0 ;

                assign data_req_CH0_int      = {  data_req_CH0_dummy  ,     data_req_CH0_i     };
                assign data_add_CH0_int      = {  data_add_CH0_dummy  ,     data_add_CH0_i     };
                assign data_wen_CH0_int      = {  data_wen_CH0_dummy  ,     data_wen_CH0_i     };
                assign data_wdata_CH0_int    = {  data_wdata_CH0_dummy  ,   data_wdata_CH0_i   };
                assign data_be_CH0_int       = {  data_be_CH0_dummy  ,      data_be_CH0_i      };
                assign data_ID_CH0_int       = {  data_ID_CH0_dummy  ,      data_ID_CH0_i      };        


                for(genvar j=0; j<N_CH0; j++)
                begin : _MERGING_CH0_DUMMY_PORTS_OUT_
          `ifdef GNT_BASED_FC           
                  assign data_gnt_CH0_o[j]     = data_gnt_CH0_int[j];
          `else
                  assign data_stall_CH0_o[j]   = data_stall_CH0_int[j];
          `endif        
                end
            end
            else // N_CH0 is power of 2
            begin
                  assign data_req_CH0_int   = data_req_CH0_i;
                  assign data_add_CH0_int   = data_add_CH0_i;
                  assign data_wen_CH0_int   = data_wen_CH0_i;
                  assign data_wdata_CH0_int = data_wdata_CH0_i;
                  assign data_be_CH0_int    = data_be_CH0_i;
                  assign data_ID_CH0_int    = data_ID_CH0_i;
              `ifdef GNT_BASED_FC    
                  assign data_gnt_CH0_o     = data_gnt_CH0_int;
              `else 
                  assign data_stall_CH0_o   = data_stall_CH0_int;
              `endif
            end




            if(2**$clog2(N_CH1) != N_CH1) // if N_CH1 is not power of 2 --> then use power 2 ports
            begin : _DUMMY_CH1_PORTS_
              
              logic [2**$clog2(N_CH1)-N_CH1 -1 :0]                                data_req_CH1_dummy;
              logic [2**$clog2(N_CH1)-N_CH1 -1 :0][ADDR_WIDTH-1:0]                data_add_CH1_dummy; // Memory address + T&S bit
              logic [2**$clog2(N_CH1)-N_CH1 -1 :0]                                data_wen_CH1_dummy;
              logic [2**$clog2(N_CH1)-N_CH1 -1 :0][DATA_WIDTH-1:0]                data_wdata_CH1_dummy;
              logic [2**$clog2(N_CH1)-N_CH1 -1 :0][BE_WIDTH-1:0]                  data_be_CH1_dummy;
              logic [2**$clog2(N_CH1)-N_CH1 -1 :0][ID_WIDTH-1:0]                  data_ID_CH1_dummy;
          `ifdef GNT_BASED_FC
              logic [2**$clog2(N_CH1)-N_CH1 -1 :0]                                data_gnt_CH1_dummy;
          `else
              logic [2**$clog2(N_CH1)-N_CH1 -1 :0]                                data_stall_CH1_dummy;
          `endif

              assign data_req_CH1_dummy    = '0 ;  
              assign data_add_CH1_dummy    = '0 ;   
              assign data_wen_CH1_dummy    = '0 ;  
              assign data_wdata_CH1_dummy  = '0 ;
              assign data_be_CH1_dummy     = '0 ;   
              assign data_ID_CH1_dummy     = '0 ;

              assign data_req_CH1_int      = {  data_req_CH1_dummy  ,     data_req_CH1_i     };
              assign data_add_CH1_int      = {  data_add_CH1_dummy  ,     data_add_CH1_i     };
              assign data_wen_CH1_int      = {  data_wen_CH1_dummy  ,     data_wen_CH1_i     };
              assign data_wdata_CH1_int    = {  data_wdata_CH1_dummy  ,   data_wdata_CH1_i   };
              assign data_be_CH1_int       = {  data_be_CH1_dummy  ,      data_be_CH1_i      };
              assign data_ID_CH1_int       = {  data_ID_CH1_dummy  ,      data_ID_CH1_i      };        


              for(genvar j=0; j<N_CH1; j++)
              begin : _MERGING_CH1_DUMMY_PORTS_OUT_
        `ifdef GNT_BASED_FC           
                assign data_gnt_CH1_o[j]     = data_gnt_CH1_int[j];
        `else
                assign data_stall_CH1_o[j]   = data_stall_CH1_int[j];
        `endif        
              end


          end
          else // N_CH1 is power of 2
          begin
                assign data_req_CH1_int   = data_req_CH1_i;
                assign data_add_CH1_int   = data_add_CH1_i;
                assign data_wen_CH1_int   = data_wen_CH1_i;
                assign data_wdata_CH1_int = data_wdata_CH1_i;
                assign data_be_CH1_int    = data_be_CH1_i;
                assign data_ID_CH1_int    = data_ID_CH1_i;
            `ifdef GNT_BASED_FC    
                assign data_gnt_CH1_o     = data_gnt_CH1_int;
            `else 
                assign data_stall_CH1_o   = data_stall_CH1_int;
            `endif
          end






        if(N_CH0 > 1)
        begin : CH0_ARB_TREE
            ArbitrationTree_PE 
            #(
                  .ADDR_WIDTH ( ADDR_WIDTH       ), 
                  .ID_WIDTH   ( ID_WIDTH         ), 
                  .N_MASTER   ( 2**$clog2(N_CH0) ),
                  .DATA_WIDTH ( DATA_WIDTH       ),
                  .BE_WIDTH   ( BE_WIDTH         ),
                  .MAX_COUNT  ( N_CH0 - 1        )
            )
            i_ArbitrationTree_PE
            (
              .clk           ( clk                ),
              .rst_n         ( rst_n              ),
              // INPUTS
              .data_req_i    ( data_req_CH0_int   ),
              .data_add_i    ( data_add_CH0_int   ),
              .data_wen_i    ( data_wen_CH0_int   ),
              .data_wdata_i  ( data_wdata_CH0_int ),
              .data_be_i     ( data_be_CH0_int    ),
              .data_ID_i     ( data_ID_CH0_int    ),
            `ifdef GNT_BASED_FC                    
              .data_gnt_o    ( data_gnt_CH0_int   ),
            `else
              .data_stall_o  ( data_stall_CH0_int ),
            `endif
              // OUTPUTS
              .data_req_o    ( data_req_CH0       ),
              .data_add_o    ( data_add_CH0       ),
              .data_wen_o    ( data_wen_CH0       ),
              .data_wdata_o  ( data_wdata_CH0     ),
              .data_be_o     ( data_be_CH0        ),
              .data_ID_o     ( data_ID_CH0        ),
            `ifdef GNT_BASED_FC              
              .data_gnt_i    ( data_gnt_CH0       )
            `else
              .data_stall_i  ( data_stall_CH0     )            
            `endif
          );   
        end

        if(N_CH1 > 1)
        begin : CH1_ARB_TREE
            ArbitrationTree_PE 
              #(
                  .ADDR_WIDTH    ( ADDR_WIDTH        ), 
                  .ID_WIDTH      ( ID_WIDTH          ), 
                  .N_MASTER      ( 2**$clog2(N_CH1)  ),
                  .DATA_WIDTH    ( DATA_WIDTH        ),
                  .BE_WIDTH      ( BE_WIDTH          ),
                  .MAX_COUNT     ( N_CH1 - 1         )
              )
              i_ArbitrationTree_PE
              (
                  .clk            ( clk                ),
                  .rst_n          ( rst_n              ),
                  // INPUTS
                  .data_req_i     ( data_req_CH1_int   ),
                  .data_add_i     ( data_add_CH1_int   ),
                  .data_wen_i     ( data_wen_CH1_int   ),
                  .data_wdata_i   ( data_wdata_CH1_int ),
                  .data_be_i      ( data_be_CH1_int    ),
                  .data_ID_i      ( data_ID_CH1_int    ),
                `ifdef GNT_BASED_FC                    
                  .data_gnt_o     ( data_gnt_CH1_int   ),
                `else
                  .data_stall_o   ( data_stall_CH1_int ),
                `endif
                  // OUTPUTS
                  .data_req_o     ( data_req_CH1       ),
                  .data_add_o     ( data_add_CH1       ),
                  .data_wen_o     ( data_wen_CH1       ),
                  .data_wdata_o   ( data_wdata_CH1     ),
                  .data_be_o      ( data_be_CH1        ),
                  .data_ID_o      ( data_ID_CH1        ),
                `ifdef GNT_BASED_FC
                  .data_gnt_i     ( data_gnt_CH1       )
                `else
                  .data_stall_i   ( data_stall_CH1     )
                `endif
          );
        end

        if(N_CH1 == 1)
        begin : MONO_CH1
          if(N_CH0 == 1)
            begin : MONO_CH0
                MUX2_REQ_PE 
                #(
                    .ID_WIDTH   ( ID_WIDTH     ), 
                    .ADDR_WIDTH ( ADDR_WIDTH   ),
                    .DATA_WIDTH ( DATA_WIDTH   ),
                    .BE_WIDTH   ( DATA_WIDTH/8 )
                )
                i_MUX2_REQ_PE
                (
                    // CH0 input
                    .data_req_CH0_i   (  data_req_CH0_int   ),
                    .data_add_CH0_i   (  data_add_CH0_int   ),
                    .data_wen_CH0_i   (  data_wen_CH0_int   ),
                    .data_wdata_CH0_i (  data_wdata_CH0_int ),
                    .data_be_CH0_i    (  data_be_CH0_int    ),
                    .data_ID_CH0_i    (  data_ID_CH0_int    ),
                `ifdef GNT_BASED_FC                
                    .data_gnt_CH0_o   (  data_gnt_CH0_int   ),
                `else
                    .data_stall_CH0_o (  data_stall_CH0_int ),
                `endif
                    // CH1 input
                    .data_req_CH1_i   (  data_req_CH1_int   ),
                    .data_add_CH1_i   (  data_add_CH1_int   ),
                    .data_wen_CH1_i   (  data_wen_CH1_int   ),
                    .data_wdata_CH1_i (  data_wdata_CH1_int ),
                    .data_be_CH1_i    (  data_be_CH1_int    ),
                    .data_ID_CH1_i    (  data_ID_CH1_int    ),
                `ifdef GNT_BASED_FC                
                    .data_gnt_CH1_o   (  data_gnt_CH1_int   ),
                `else
                    .data_stall_CH1_o (  data_stall_CH1_int ),
                `endif
                    // MUX output
                    .data_req_o       (  data_req_o        ),
                    .data_add_o       (  data_add_o        ),
                    .data_wen_o       (  data_wen_o        ),
                    .data_wdata_o     (  data_wdata_o      ),
                    .data_be_o        (  data_be_o         ),
                    .data_ID_o        (  data_ID_o         ), 
                `ifdef GNT_BASED_FC                
                    .data_gnt_i       (  data_gnt_i        ),
                `else
                    .data_stall_i     (  data_stall_i      ),
                `endif
                    .clk              (  clk               ),
                    .rst_n            (  rst_n             )
            );
            end // END MONO_CH0
          else
              begin : POLY_CH0
                  MUX2_REQ_PE 
                  #(
                      .ID_WIDTH   ( ID_WIDTH     ), 
                      .ADDR_WIDTH ( ADDR_WIDTH   ),
                      .DATA_WIDTH ( DATA_WIDTH   ),
                      .BE_WIDTH   ( DATA_WIDTH/8 )
                  )
                  i_MUX2_REQ_PE
                  (
                      // CH0 input
                      .data_req_CH0_i   ( data_req_CH0       ),
                      .data_add_CH0_i   ( data_add_CH0       ),
                      .data_wen_CH0_i   ( data_wen_CH0       ),
                      .data_wdata_CH0_i ( data_wdata_CH0     ),
                      .data_be_CH0_i    ( data_be_CH0        ),
                      .data_ID_CH0_i    ( data_ID_CH0        ),
                  `ifdef GNT_BASED_FC      
                      .data_gnt_CH0_o   ( data_gnt_CH0       ),
                  `else
                      .data_stall_CH0_o ( data_stall_CH0     ),
                  `endif              
                      // CH1 input
                      .data_req_CH1_i   ( data_req_CH1_int   ),
                      .data_add_CH1_i   ( data_add_CH1_int   ),
                      .data_wen_CH1_i   ( data_wen_CH1_int   ),
                      .data_wdata_CH1_i ( data_wdata_CH1_int ),
                      .data_be_CH1_i    ( data_be_CH1_int    ),
                      .data_ID_CH1_i    ( data_ID_CH1_int    ),
                `ifdef GNT_BASED_FC                
                      .data_gnt_CH1_o   ( data_gnt_CH1_int   ),
                `else
                      .data_stall_CH1_o ( data_stall_CH1_int ),
                `endif                  
                      // MUX output
                      .data_req_o       ( data_req_o        ),
                      .data_add_o       ( data_add_o        ),
                      .data_wen_o       ( data_wen_o        ),
                      .data_wdata_o     ( data_wdata_o      ),
                      .data_be_o        ( data_be_o         ),
                      .data_ID_o        ( data_ID_o         ),
                `ifdef GNT_BASED_FC                
                    .data_gnt_i         ( data_gnt_i        ),
                `else
                    .data_stall_i       ( data_stall_i      ),
                `endif
                      .clk              ( clk               ),
                      .rst_n            ( rst_n             )
              );
              end // END POLY_CH0
        end 
        else  
        begin : POLY_CH1
          if(N_CH0 == 1)
          begin : MONO_CH0
                MUX2_REQ_PE 
                #(
                    .ID_WIDTH   ( ID_WIDTH     ), 
                    .ADDR_WIDTH ( ADDR_WIDTH   ),
                    .DATA_WIDTH ( DATA_WIDTH   ),
                    .BE_WIDTH   ( DATA_WIDTH/8 )
                )
                i_MUX2_REQ_PE
                (
                    // CH0 input
                    .data_req_CH0_i    ( data_req_CH0_int     ),
                    .data_add_CH0_i    ( data_add_CH0_int     ),
                    .data_wen_CH0_i    ( data_wen_CH0_int     ),
                    .data_wdata_CH0_i  ( data_wdata_CH0_int   ),
                    .data_be_CH0_i     ( data_be_CH0_int      ),
                    .data_ID_CH0_i     ( data_ID_CH0_int      ),
                `ifdef GNT_BASED_FC                
                    .data_gnt_CH0_o    ( data_gnt_CH0_int     ),
                `else
                    .data_stall_CH0_o  ( data_stall_CH0_int   ),
                `endif                
                    // CH1 input
                    .data_req_CH1_i    ( data_req_CH1       ),
                    .data_add_CH1_i    ( data_add_CH1       ),
                    .data_wen_CH1_i    ( data_wen_CH1       ),
                    .data_wdata_CH1_i  ( data_wdata_CH1     ),
                    .data_be_CH1_i     ( data_be_CH1        ),
                    .data_ID_CH1_i     ( data_ID_CH1        ),
                `ifdef GNT_BASED_FC                
                    .data_gnt_CH1_o    ( data_gnt_CH1       ),
                `else
                    .data_stall_CH1_o  ( data_stall_CH1     ),
                `endif                
                    // MUX output
                    .data_req_o        ( data_req_o         ),
                    .data_add_o        ( data_add_o         ),
                    .data_wen_o        ( data_wen_o         ),
                    .data_wdata_o      ( data_wdata_o       ),
                    .data_be_o         ( data_be_o          ),
                    .data_ID_o         ( data_ID_o          ),
                `ifdef GNT_BASED_FC                
                    .data_gnt_i        ( data_gnt_i         ),
                `else
                    .data_stall_i      ( data_stall_i       ),
                `endif
                    .clk               ( clk                ),
                    .rst_n             ( rst_n              )
            );          
          end
          else
          begin : POLY_CH0
                MUX2_REQ_PE 
                #(
                    .ID_WIDTH   ( ID_WIDTH     ), 
                    .ADDR_WIDTH ( ADDR_WIDTH   ),
                    .DATA_WIDTH ( DATA_WIDTH   ),
                    .BE_WIDTH   ( DATA_WIDTH/8 )
                )
                i_MUX2_REQ_PE
                (
                    // CH0 input
                    .data_req_CH0_i     ( data_req_CH0     ),
                    .data_add_CH0_i     ( data_add_CH0     ),
                    .data_wen_CH0_i     ( data_wen_CH0     ),
                    .data_wdata_CH0_i   ( data_wdata_CH0   ),
                    .data_be_CH0_i      ( data_be_CH0      ),
                    .data_ID_CH0_i      ( data_ID_CH0      ),
                  `ifdef GNT_BASED_FC      
                      .data_gnt_CH0_o   ( data_gnt_CH0     ),
                  `else
                      .data_stall_CH0_o ( data_stall_CH0   ),
                  `endif
                    // CH1 input
                    .data_req_CH1_i     ( data_req_CH1     ),
                    .data_add_CH1_i     ( data_add_CH1     ),
                    .data_wen_CH1_i     ( data_wen_CH1     ),
                    .data_wdata_CH1_i   ( data_wdata_CH1   ),
                    .data_be_CH1_i      ( data_be_CH1      ),
                    .data_ID_CH1_i      ( data_ID_CH1      ),
                `ifdef GNT_BASED_FC                
                    .data_gnt_CH1_o     ( data_gnt_CH1     ),
                `else
                    .data_stall_CH1_o   ( data_stall_CH1   ),
                `endif      
                    // MUX output
                    .data_req_o         ( data_req_o       ),
                    .data_add_o         ( data_add_o       ),
                    .data_wen_o         ( data_wen_o       ),
                    .data_wdata_o       ( data_wdata_o     ),
                    .data_be_o          ( data_be_o        ),
                    .data_ID_o          ( data_ID_o        ),
                `ifdef GNT_BASED_FC                
                    .data_gnt_i         ( data_gnt_i       ),
                `else
                    .data_stall_i       ( data_stall_i     ),
                `endif
                    .clk                ( clk              ),
                    .rst_n              ( rst_n            )
                );          
          end
    end        
    endgenerate
   



    AddressDecoder_Resp_PE 
    #( 
        .ID_WIDTH(ID_WIDTH), 
        .N_MASTER(N_CH0+N_CH1)
    ) 
    i_AddressDecoder_Resp_PE
    (
      // FROM Test And Set Interface
      .data_r_valid_i(data_r_valid_i),
      .data_ID_i(data_r_ID_i),
      // To Response Network
      .data_r_valid_o({data_r_valid_CH1_o,data_r_valid_CH0_o})
    );



endmodule
