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
// Revision v0.2 - (19/02/2015) Restyling                                     //
//                                                                            //
// Additional Comments:                                                       //
//                                                                            //
//                                                                            //
//                                                                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

`include "parameters.v"


module ArbitrationTree 
#(
    parameter ADDR_WIDTH  = 12,
    parameter ID_WIDTH    = 20,
    parameter N_MASTER    = 16,
    parameter DATA_WIDTH  = 32,
    parameter MAX_COUNT   = 2**N_MASTER-1,
    parameter BE_WIDTH    = DATA_WIDTH/8
) 
(
    input  logic                                 clk,
    input  logic                                 rst_n,
    input  logic                                 TCDM_arb_policy_i,

    // ---------------- REQ_SIDE --------------------------
    input  logic [N_MASTER-1:0]                  data_req_i,
    input  logic [N_MASTER-1:0][ADDR_WIDTH-1:0]  data_add_i,
    input  logic [N_MASTER-1:0]                  data_wen_i,
    input  logic [N_MASTER-1:0][DATA_WIDTH-1:0]  data_wdata_i,
    input  logic [N_MASTER-1:0][BE_WIDTH-1:0]    data_be_i,
    input  logic [N_MASTER-1:0][ID_WIDTH-1:0]    data_ID_i,
  `ifdef GNT_BASED_FC
    output logic [N_MASTER-1:0]                  data_gnt_o,
  `else
    output logic [N_MASTER-1:0]                  data_stall_o,
  `endif
    // Outputs
    output logic                                 data_req_o,
    output logic [ADDR_WIDTH-1:0]                data_add_o,
    output logic                                 data_wen_o,
    output logic [DATA_WIDTH-1:0]                data_wdata_o,
    output logic [BE_WIDTH-1:0]                  data_be_o,
    output logic [ID_WIDTH-1:0]                  data_ID_o,
  `ifdef GNT_BASED_FC
    input  logic                                 data_gnt_i
  `else
    input  logic                                 data_stall_i
  `endif
);

    localparam LOG_MASTER         = $clog2(N_MASTER);
    localparam N_WIRE             =  N_MASTER - 2;

    logic [LOG_MASTER-1:0]        s_RR_FLAG;
    logic [LOG_MASTER-1:0]        s_ID;
    logic [N_MASTER-1:0][LOG_MASTER-1:0]    ID_int;

    genvar j,k;


    generate
      if(N_MASTER == 2)
        begin : INCR // START of  MASTER  == 2
                    // ---------------- FAN IN PRIMITIVE  -------------------------
                    FanInPrimitive_Req 
                    #(
                        .ADDR_WIDTH     ( ADDR_WIDTH      ), 
                        .ID_WIDTH       ( ID_WIDTH        ),
                        .DATA_WIDTH     ( DATA_WIDTH      ),
                        .BE_WIDTH       ( BE_WIDTH        ),
                        .N_MASTER       ( N_MASTER        )
                    ) 
                    i_FanInPrimitive_Req
                    (
                        .PRIO_FLAG      ( s_RR_FLAG       ),
                        // LEFT SIDE"
                        .data_wdata0_i  ( data_wdata_i[0] ),
                        .data_wdata1_i  ( data_wdata_i[1] ),
                        .data_add0_i    ( data_add_i[0]   ),
                        .data_add1_i    ( data_add_i[1]   ),
                        .data_req0_i    ( data_req_i[0]   ),
                        .data_req1_i    ( data_req_i[1]   ),
                        .data_wen0_i    ( data_wen_i[0]   ),
                        .data_wen1_i    ( data_wen_i[1]   ),
                        .data_ID0_i     ( data_ID_i[0]    ),
                        .data_ID1_i     ( data_ID_i[1]    ),
                        .ID0_i          ( 1'b0            ),
                        .ID1_i          ( 1'b1            ),
                        .data_be0_i     ( data_be_i[0]    ),
                        .data_be1_i     ( data_be_i[1]    ),
                `ifdef GNT_BASED_FC
                        .data_gnt0_o    ( data_gnt_o[0]   ),
                        .data_gnt1_o    ( data_gnt_o[1]   ),
                `else
                        .data_stall0_o  ( data_stall_o[0] ),
                        .data_stall1_o  ( data_stall_o[1] ),
                `endif
                        // RIGTH SIDE"
                        .data_wdata_o   ( data_wdata_o    ),
                        .data_add_o     ( data_add_o      ),
                        .data_req_o     ( data_req_o      ),
                        .data_wen_o     ( data_wen_o      ),
                        .data_ID_o      ( data_ID_o       ),
                        .ID_o           ( s_ID            ),
                        .data_be_o      ( data_be_o       ),
                `ifdef GNT_BASED_FC
                        .data_gnt_i     ( data_gnt_i      )
                `else
                        .data_stall_i   ( data_stall_i    )
                `endif
                        );
        end // END OF MASTER  == 2
      else // More than two master
        begin : BINARY_TREE
            //// ---------------------------------------------------------------------- ////
            //// -------               REQ ARBITRATION TREE WIRES           ----------- ////
            //// ---------------------------------------------------------------------- ////        
            logic [N_WIRE-1:0][DATA_WIDTH-1:0]     data_wdata_LEVEL;
            logic [N_WIRE-1:0][ADDR_WIDTH-1:0]     data_add_LEVEL;
            logic [N_WIRE-1:0]                     data_req_LEVEL;
            logic [N_WIRE-1:0]                     data_wen_LEVEL;
            logic [N_WIRE-1:0][ID_WIDTH-1:0]       data_ID_LEVEL;
            
            logic [N_WIRE-1:0][LOG_MASTER-1:0]     ID_LEVEL;

            logic [N_WIRE-1:0][BE_WIDTH-1:0]       data_be_LEVEL;
        `ifdef GNT_BASED_FC
            logic [N_WIRE-1:0]                     data_gnt_LEVEL;
        `else
            logic [N_WIRE-1:0]                     data_stall_LEVEL;
        `endif


               for(j=0; j < LOG_MASTER; j++) // Iteration for the number of the stages minus one
                begin : STAGE
                  for(k=0; k<2**j; k=k+1) // Iteration needed to create the binary tree
                    begin : INCR_VERT

                      if (j == 0 )  // LAST NODE, drives the module outputs
                      begin : LAST_NODE
                          FanInPrimitive_Req 
                          #(
                              .ADDR_WIDTH     ( ADDR_WIDTH              ), 
                              .ID_WIDTH       ( ID_WIDTH                ),
                              .DATA_WIDTH     ( DATA_WIDTH              ),
                              .BE_WIDTH       ( BE_WIDTH                ),
                              .N_MASTER       ( N_MASTER                )
                          ) 
                          i_FanInPrimitive_Req
                          (
                              .PRIO_FLAG      ( s_RR_FLAG[LOG_MASTER-j-1] ),
                              // LEFT SIDE
                              .data_wdata0_i  ( data_wdata_LEVEL[2*k]   ),
                              .data_wdata1_i  ( data_wdata_LEVEL[2*k+1] ),
                              .data_add0_i    ( data_add_LEVEL[2*k]     ),
                              .data_add1_i    ( data_add_LEVEL[2*k+1]   ),
                              .data_req0_i    ( data_req_LEVEL[2*k]     ),
                              .data_req1_i    ( data_req_LEVEL[2*k+1]   ),
                              .data_wen0_i    ( data_wen_LEVEL[2*k]     ),
                              .data_wen1_i    ( data_wen_LEVEL[2*k+1]   ),
                              .data_ID0_i     ( data_ID_LEVEL[2*k]      ),
                              .data_ID1_i     ( data_ID_LEVEL[2*k+1]    ),

                              .ID0_i          ( ID_LEVEL[2*k]           ),
                              .ID1_i          ( ID_LEVEL[2*k+1]         ),
                                                           
                              .data_be0_i     ( data_be_LEVEL[2*k]      ),
                              .data_be1_i     ( data_be_LEVEL[2*k+1]    ),
                          `ifdef GNT_BASED_FC
                              .data_gnt0_o    ( data_gnt_LEVEL[2*k]     ),
                              .data_gnt1_o    ( data_gnt_LEVEL[2*k+1]   ),
                          `else
                              .data_stall0_o  ( data_stall_LEVEL[2*k]   ),
                              .data_stall1_o  ( data_stall_LEVEL[2*k+1] ),
                          `endif
                              // RIGTH SIDE
                              .data_wdata_o   ( data_wdata_o            ),
                              .data_add_o     ( data_add_o              ),
                              .data_req_o     ( data_req_o              ),
                              .data_wen_o     ( data_wen_o              ),
                              .data_ID_o      ( data_ID_o               ),
                              .ID_o           ( s_ID                    ),
                              .data_be_o      ( data_be_o               ),
                          `ifdef GNT_BASED_FC
                              .data_gnt_i     ( data_gnt_i              )
                          `else
                              .data_stall_i   ( data_stall_i            )
                          `endif
                          );
                      end 
                      else if ( j < LOG_MASTER - 1) // Middle Nodes
                              begin : MIDDLE_NODES // START of MIDDLE LEVELS Nodes   
                                  FanInPrimitive_Req 
                                  #(
                                      .ADDR_WIDTH     ( ADDR_WIDTH                              ), 
                                      .ID_WIDTH       ( ID_WIDTH                                ),
                                      .DATA_WIDTH     ( DATA_WIDTH                              ),
                                      .BE_WIDTH       ( BE_WIDTH                                ),
                                      .N_MASTER       ( N_MASTER                                )
                                  ) 
                                  i_FanInPrimitive_Req
                                  (
                                      .PRIO_FLAG(s_RR_FLAG[LOG_MASTER-j-1]),
                                      // LEFT SIDE
                                      .data_wdata0_i  ( data_wdata_LEVEL[((2**j)*2-2) + 2*k]    ),
                                      .data_wdata1_i  ( data_wdata_LEVEL[((2**j)*2-2) + 2*k +1] ),
                                      .data_add0_i    ( data_add_LEVEL[((2**j)*2-2) + 2*k]      ),
                                      .data_add1_i    ( data_add_LEVEL[((2**j)*2-2) + 2*k+1]    ),
                                      .data_req0_i    ( data_req_LEVEL[((2**j)*2-2) + 2*k]      ),
                                      .data_req1_i    ( data_req_LEVEL[((2**j)*2-2) + 2*k+1]    ),
                                      .data_wen0_i    ( data_wen_LEVEL[((2**j)*2-2) + 2*k]      ),
                                      .data_wen1_i    ( data_wen_LEVEL[((2**j)*2-2) + 2*k+1]    ),
                                      
                                      .data_ID0_i     ( data_ID_LEVEL[((2**j)*2-2) + 2*k]       ),
                                      .data_ID1_i     ( data_ID_LEVEL[((2**j)*2-2) + 2*k+1]     ),

                                      .ID0_i          ( ID_LEVEL[((2**j)*2-2) + 2*k]            ),
                                      .ID1_i          ( ID_LEVEL[((2**j)*2-2) + 2*k+1]          ),                                     

                                      .data_be0_i     ( data_be_LEVEL[((2**j)*2-2) + 2*k]       ),
                                      .data_be1_i     ( data_be_LEVEL[((2**j)*2-2) + 2*k+1]     ),
                              `ifdef GNT_BASED_FC
                                      .data_gnt0_o    ( data_gnt_LEVEL[((2**j)*2-2) + 2*k]      ),
                                      .data_gnt1_o    ( data_gnt_LEVEL[((2**j)*2-2) + 2*k+1]    ),
                              `else
                                      .data_stall0_o  ( data_stall_LEVEL[((2**j)*2-2) + 2*k]    ),
                                      .data_stall1_o  ( data_stall_LEVEL[((2**j)*2-2) + 2*k+1]  ),
                              `endif

                                      // RIGTH SIDE
                                      .data_wdata_o   ( data_wdata_LEVEL[((2**(j-1))*2-2) + k]  ),
                                      .data_add_o     ( data_add_LEVEL[((2**(j-1))*2-2) + k]    ),
                                      .data_req_o     ( data_req_LEVEL[((2**(j-1))*2-2) + k]    ),
                                      .data_wen_o     ( data_wen_LEVEL[((2**(j-1))*2-2) + k]    ),
                                      .data_ID_o      ( data_ID_LEVEL[((2**(j-1))*2-2) + k]     ),
                                      .ID_o           ( ID_LEVEL[((2**(j-1))*2-2) + k]          ),
                                      .data_be_o      ( data_be_LEVEL[((2**(j-1))*2-2) + k]     ),
                              `ifdef GNT_BASED_FC
                                      .data_gnt_i     ( data_gnt_LEVEL[((2**(j-1))*2-2) + k]    )
                              `else
                                      .data_stall_i   ( data_stall_LEVEL[((2**(j-1))*2-2) + k]  )
                              `endif
                                  );
                              end  // END of MIDDLE LEVELS Nodes   
                           else // First stage (connected with the Main inputs ) --> ( j == N_MASTER - 1 )
                              begin : LEAF_NODES  // START of FIRST LEVEL Nodes (LEAF)

                                  assign ID_int[2*k]   = 2*k;
                                  assign ID_int[2*k+1] = 2*k+1;
                                  
                                  FanInPrimitive_Req 
                                  #(
                                      .ADDR_WIDTH     ( ADDR_WIDTH      ), 
                                      .ID_WIDTH       ( ID_WIDTH        ),
                                      .DATA_WIDTH     ( DATA_WIDTH      ),
                                      .BE_WIDTH       ( BE_WIDTH        ),
                                      .N_MASTER       ( N_MASTER        )
                                  ) 
                                  i_FanInPrimitive_Req
                                  (
                                      .PRIO_FLAG(s_RR_FLAG[LOG_MASTER-j-1]),
                                      // LEFT SIDE
                                      .data_wdata0_i  ( data_wdata_i[2*k]  ),
                                      .data_wdata1_i  ( data_wdata_i[2*k+1]),
                                      .data_add0_i    ( data_add_i[2*k]    ),
                                      .data_add1_i    ( data_add_i[2*k+1]  ),
                                      .data_req0_i    ( data_req_i[2*k]    ),
                                      .data_req1_i    ( data_req_i[2*k+1]  ),
                                      .data_wen0_i    ( data_wen_i[2*k]    ),
                                      .data_wen1_i    ( data_wen_i[2*k+1]  ),
                                      .data_ID0_i     ( data_ID_i[2*k]     ),
                                      .data_ID1_i     ( data_ID_i[2*k+1]   ),
                                      .ID0_i          ( ID_int[2*k]        ),
                                      .ID1_i          ( ID_int[2*k+1]      ),
                                      .data_be0_i     ( data_be_i[2*k]     ),
                                      .data_be1_i     ( data_be_i[2*k+1]   ),
                              `ifdef GNT_BASED_FC
                                      .data_gnt0_o    ( data_gnt_o[2*k]    ),
                                      .data_gnt1_o    ( data_gnt_o[2*k+1]  ),
                              `else
                                      .data_stall0_o  ( data_stall_o[2*k]  ),
                                      .data_stall1_o  ( data_stall_o[2*k+1]),
                              `endif
      
                                      // RIGTH SIDE
                                      .data_wdata_o   ( data_wdata_LEVEL[((2**(j-1))*2-2) + k] ),
                                      .data_add_o     ( data_add_LEVEL[((2**(j-1))*2-2) + k]   ),
                                      .data_req_o     ( data_req_LEVEL[((2**(j-1))*2-2) + k]   ),
                                      .data_wen_o     ( data_wen_LEVEL[((2**(j-1))*2-2) + k]   ),
                                      .data_ID_o      ( data_ID_LEVEL[((2**(j-1))*2-2) + k]    ),
                                      .ID_o           ( ID_LEVEL[((2**(j-1))*2-2) + k]         ),
                                      .data_be_o      ( data_be_LEVEL[((2**(j-1))*2-2) + k]    ),
                              `ifdef GNT_BASED_FC
                                      .data_gnt_i     ( data_gnt_LEVEL[((2**(j-1))*2-2) + k]   )
                              `else
                                      .data_stall_i   ( data_stall_LEVEL[((2**(j-1))*2-2) + k] )
                              `endif
                                  );
                              end // End of FIRST LEVEL Nodes (LEAF)
                    end
                end
    end
    endgenerate

    //COUNTER USED TO SWITCH PERIODICALLY THE PRIORITY FLAG"
    priority_Flag_Req #( .WIDTH(LOG_MASTER), .MAX_COUNT(MAX_COUNT) )  PRIORITY_ENC_REQ
    (
        .clk               ( clk                     ),
        .rst_n             ( rst_n                   ),
        .TCDM_arb_policy_i ( TCDM_arb_policy_i       ),

        .PRIO_FLAG_o       ( s_RR_FLAG               ), 
        .data_req_i        ( data_req_o              ),
        .ID_i              ( s_ID                    ),
      `ifdef GNT_BASED_FC
        .data_gnt_i        ( data_gnt_i              )
      `else
        .data_stall_i      ( data_stall_i            )
      `endif
    );


endmodule
