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
// Module Name:    RequestBlock1CH                                            //
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
// Revision v0.2 - Changes in the ADDRESS_WIDTH ( 26/07/2011 )                //
// Revision v0.3 - Code Restyling ( 19/02/2015 )                              //
//                                                                            //
// Additional Comments:                                                       //
//                                                                            //
//                                                                            //
//                                                                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

`include "parameters.v"

module RequestBlock1CH
#(
    parameter ADDR_MEM_WIDTH = 12,
    parameter N_CH0          = 16,
    parameter ID_WIDTH       = N_CH0,
    parameter DATA_WIDTH     = 32,
    parameter BE_WIDTH       = DATA_WIDTH/8
)
(
    // CHANNEL CH0 --> (example: Used for cores) 
    input  logic [N_CH0-1:0]                     data_req_CH0_i,
    input  logic [N_CH0-1:0][ADDR_MEM_WIDTH:0]   data_add_CH0_i, // Memory address + T&S bit
    input  logic [N_CH0-1:0]                     data_wen_CH0_i,
    input  logic [N_CH0-1:0][DATA_WIDTH-1:0]     data_wdata_CH0_i,
    input  logic [N_CH0-1:0][BE_WIDTH-1:0]       data_be_CH0_i,
    input  logic [N_CH0-1:0][ID_WIDTH-1:0]       data_ID_CH0_i,
`ifdef GNT_BASED_FC
    output logic [N_CH0-1:0]                     data_gnt_CH0_o,
`else
    output logic [N_CH0-1:0]                     data_stall_CH0_o,
`endif

    // -----------------             MEMORY                    -------------------
    // ---------------- RequestBlock OUTPUT (Connected to MEMORY) ----------------
    output logic                                 data_req_o,
    output logic                                 data_ts_set_o,
    output logic [ADDR_MEM_WIDTH-1:0]            data_add_o,
    output logic                                 data_wen_o,
    output logic [DATA_WIDTH-1:0]                data_wdata_o,
    output logic [BE_WIDTH-1:0]                  data_be_o,
    output logic [ID_WIDTH-1:0]                  data_ID_o,
`ifdef GNT_BASED_FC
    input  logic                                 data_gnt_i,
`else
    input  logic                                 data_stall_i,
`endif
    // GEN VALID_SIGNALS in the response path
    input logic [ID_WIDTH-1:0]                   data_r_ID_i,
    input logic                                  data_r_valid_i,
    output logic [N_CH0-1:0]                     data_r_valid_CH0_o,

    input  logic                                 TCDM_arb_policy_i,

    input  logic                                 clk,
    input  logic                                 rst_n
);



    // CHANNEL CH0 --> (example: Used for Processing Elements / CORES) 
    logic [2**$clog2(N_CH0)-1:0]                                data_req_CH0_int;
    logic [2**$clog2(N_CH0)-1:0][ADDR_MEM_WIDTH:0]              data_add_CH0_int;
    logic [2**$clog2(N_CH0)-1:0]                                data_wen_CH0_int;
    logic [2**$clog2(N_CH0)-1:0][DATA_WIDTH-1:0]                data_wdata_CH0_int;
    logic [2**$clog2(N_CH0)-1:0][BE_WIDTH-1:0]                  data_be_CH0_int;
    logic [2**$clog2(N_CH0)-1:0][ID_WIDTH-1:0]                  data_ID_CH0_int;
`ifdef GNT_BASED_FC
    logic [2**$clog2(N_CH0)-1:0]                                data_gnt_CH0_int;
`else
    logic [2**$clog2(N_CH0)-1:0]                                data_stall_CH0_int;
`endif


generate

    if(2**$clog2(N_CH0) != N_CH0) // if N_CH0 is not power of 2 --> then use power 2 ports
    begin : _DUMMY_CH0_PORTS_
      
      logic [2**$clog2(N_CH0)-N_CH0 -1 :0]                                data_req_CH0_dummy;
      logic [2**$clog2(N_CH0)-N_CH0 -1 :0][ADDR_MEM_WIDTH:0]              data_add_CH0_dummy; // Memory address + T&S bit
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







    if(N_CH0 != 1) // Means 2 or more MAster, it requires Arbitration Tree and eires between Arb tree and Test and set interface
    begin : POLY_CH0
        // ---------------- Wires on the OUT MEMORY_INTERFACES MEM SIDE  --------------------------
        // ----------------         TEST AND SET WIRES on MEM            --------------------------
        // Request Channel
        logic                                           data_req_MEM;
        logic [ADDR_MEM_WIDTH:0]                        data_add_MEM; // Memory address + T&S bit
        logic                                           data_wen_MEM;
        logic [DATA_WIDTH-1:0]                          data_wdata_MEM;
        logic [BE_WIDTH-1:0]                            data_be_MEM;
        logic [ID_WIDTH-1:0]                            data_ID_MEM;
        // Response Channel
    `ifdef GNT_BASED_FC
        logic                                           data_gnt_MEM;      
    `else
        logic                                           data_stall_MEM;      
    `endif

        ArbitrationTree 
        #(
            .ADDR_WIDTH     ( ADDR_MEM_WIDTH+1   ),
            .ID_WIDTH       ( ID_WIDTH           ),
            .N_MASTER       ( 2**$clog2(N_CH0)   ),
            .DATA_WIDTH     ( DATA_WIDTH         ),
            .BE_WIDTH       ( BE_WIDTH           ),
            .MAX_COUNT      ( N_CH0-1            )
        )
        i_ArbitrationTree 
        (
            .clk               ( clk                ),
            .rst_n             ( rst_n              ),
            .TCDM_arb_policy_i ( TCDM_arb_policy_i  ),
            // INPUTS
            .data_req_i        ( data_req_CH0_int   ),
            .data_add_i        ( data_add_CH0_int   ),
            .data_wen_i        ( data_wen_CH0_int   ),
            .data_wdata_i      ( data_wdata_CH0_int ),
            .data_be_i         ( data_be_CH0_int    ),
            .data_ID_i         ( data_ID_CH0_int    ),
         `ifdef GNT_BASED_FC
            .data_gnt_o        ( data_gnt_CH0_int   ),
         `else
            .data_stall_o      ( data_stall_CH0_int ),
         `endif
            // OUTPUTS
            .data_req_o        ( data_req_MEM       ),
            .data_add_o        ( data_add_MEM       ),
            .data_wen_o        ( data_wen_MEM       ),
            .data_wdata_o      ( data_wdata_MEM     ),
            .data_be_o         ( data_be_MEM        ),
            .data_ID_o         ( data_ID_MEM        ),
         `ifdef GNT_BASED_FC
            .data_gnt_i        ( data_gnt_MEM       )
         `else
            .data_stall_i      ( data_stall_MEM     )
         `endif
        );

        TestAndSet 
        #( 
            .ADDR_MEM_WIDTH ( ADDR_MEM_WIDTH+1  ), 
            .ID_WIDTH       ( ID_WIDTH          ),
            .DATA_WIDTH     ( DATA_WIDTH        ),
            .BE_WIDTH       ( BE_WIDTH          )
        ) 
        i_TestAndSet
        (
            .clk            ( clk               ),
            .rst_n          ( rst_n             ),
            // From Network Side
            .data_req_i     ( data_req_MEM      ), // Data request
            .data_add_i     ( data_add_MEM      ), // Data request Address
            .data_wen_i     ( data_wen_MEM      ), // Data request type : 0--> Store, 1 --> Load
            .data_wdata_i   ( data_wdata_MEM    ), // Data request Wrire data
            .data_be_i      ( data_be_MEM       ), // Data request Byte enable 
            .data_ID_i      ( data_ID_MEM       ), // Data request ID (used as PID)
          `ifdef GNT_BASED_FC
            .data_gnt_o     ( data_gnt_MEM      ), // Memory Grant (Zero only the Store of the Test and SET)
          `else
            .data_stall_o   ( data_stall_MEM    ), // Memory Grant (Zero only the Store of the Test and SET)
          `endif


            // TO Memory Side
            .data_req_o     ( data_req_o        ), // Data request
            .data_ts_set_o  ( data_ts_set_o     ), // Request is a set during a test and set
            .data_add_o     ( data_add_o        ), // Data request Address
            .data_wen_o     ( data_wen_o        ), // Data request type : 0--> Store, 1 --> Load
            .data_wdata_o   ( data_wdata_o      ), // Data request Wrire data
            .data_be_o      ( data_be_o         ), // Data request Byte enable 
            .data_ID_o      ( data_ID_o         ),
          `ifdef GNT_BASED_FC
            .data_gnt_i     ( data_gnt_i        )
          `else
            .data_stall_i   ( data_stall_i      )
          `endif
        );
        
    end 
    else 
    begin : MONO_CH0
        TestAndSet 
        #(  
            .ADDR_MEM_WIDTH ( ADDR_MEM_WIDTH+1  ),
            .ID_WIDTH       ( ID_WIDTH          ),
            .DATA_WIDTH     ( DATA_WIDTH        ),
            .BE_WIDTH       ( BE_WIDTH          )
        ) 
        i_TestAndSet
        (
            .clk            ( clk                ),
            .rst_n          ( rst_n              ),
            // From Network Side
            .data_req_i     ( data_req_CH0_int   ),      // Data request
            .data_add_i     ( data_add_CH0_int   ),      // Data request Address
            .data_wen_i     ( data_wen_CH0_int   ),      // Data request type : 0--> Store, 1 --> Load
            .data_wdata_i   ( data_wdata_CH0_int ),      // Data request Wrire data
            .data_be_i      ( data_be_CH0_int    ),      // Data request Byte enable 
            .data_ID_i      ( data_ID_CH0_int    ),      // Data request ID (used as PID)
        `ifdef GNT_BASED_FC
            .data_gnt_o     ( data_gnt_CH0_int   ),      // Data Grant (becomes 0 only in the SET Store state)
        `else
            .data_stall_o   ( data_stall_CH0_int ),      // Data Stall (becomes 1 only in the SET Store state)
        `endif

            // TO Memory Side
            .data_req_o     ( data_req_o         ),        // Data request
            .data_ts_set_o  ( data_ts_set_o      ),        // Request is a set during a test and set
            .data_add_o     ( data_add_o         ),        // Data request Address
            .data_wen_o     ( data_wen_o         ),        // Data request type : 0--> Store, 1 --> Load
            .data_wdata_o   ( data_wdata_o       ),        // Data request Wrire data
            .data_be_o      ( data_be_o          ),        // Data request Byte enable 
            .data_ID_o      ( data_ID_o          ),
        `ifdef GNT_BASED_FC
            .data_gnt_i     ( data_gnt_i         )
        `else
              .data_stall_i ( data_stall_i       )
        `endif
        );
    end
  endgenerate


  AddressDecoder_Resp 
  #( 
      .ID_WIDTH(ID_WIDTH), 
      .N_MASTER(N_CH0) 
  )
  i_AddressDecoder_Resp
  (
    // FROM Test And Set Interface
    .data_r_valid_i(data_r_valid_i),
    .data_ID_i(data_r_ID_i),
    // To Response Network
    .data_r_valid_o(data_r_valid_CH0_o)
  );





endmodule
