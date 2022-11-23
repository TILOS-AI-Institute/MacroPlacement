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
// Create Date:    29/06/2011                                                 // 
// Design Name:    LOG_INTERCONNECT                                           // 
// Module Name:    TestAndSet                                                 //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Test And Set MEMORY Interface, used to handle this atomic  //
//                 Operation in two cycles and handle flow control (req/stall)//
//                 and ID managment (backrouting) to send the response        //
//                 to the rigth master                                        //
//                                                                            //
// Revision:                                                                  //
// Revision v0.1 - File Created                                               //
// Revision v0.2 - (14-02-2015) Added an addition signal that indicated a     //
//                 pending SET operation                                      //
// Revision v0.3 - (19-02-2015) Restyling                                     //
//                                                                            //
// Additional Comments:                                                       //
//                                                                            //
//                                                                            //
//                                                                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

`include "parameters.v"

module TestAndSet 
#(
    parameter ADDR_MEM_WIDTH  = 12,
    parameter ID_WIDTH        = 20,
    parameter DATA_WIDTH      = 32,
    parameter BE_WIDTH        = DATA_WIDTH/8
)
(
    input  logic                                 clk,
    input  logic                                 rst_n,        

    // From Network Side
    input  logic                                 data_req_i,   // Data request
    input  logic [ADDR_MEM_WIDTH-1:0]            data_add_i,   // Data request Address + T&S bit
    input  logic                                 data_wen_i,   // Data request type : 0--> Store, 1 --> Load
    input  logic [DATA_WIDTH-1:0]                data_wdata_i, // Data request Wrire data
    input  logic [BE_WIDTH-1:0]                  data_be_i,    // Data request Byte enable 
    input  logic [ID_WIDTH-1:0]                  data_ID_i,    // Data request ID
`ifdef GNT_BASED_FC
    output logic                                 data_gnt_o, // Data Grant --> to Arbitration Tree
`else
    output logic                                 data_stall_o, // Data Stall --> to Arbitration Tree
`endif


    // From Memory Side
    output logic                                 data_req_o,   // Data request
    output logic                                 data_ts_set_o,// Is test and set operation
    output logic [ADDR_MEM_WIDTH-2:0]            data_add_o,   // Data request Address (No T&S bit here)
    output logic                                 data_wen_o,  // Data request type : 0--> Store, 1 --> Load
    output logic [DATA_WIDTH-1:0]                data_wdata_o, // Data request Wrire data
    output logic [BE_WIDTH-1:0]                  data_be_o,    // Data request Byte enable 
    output logic [ID_WIDTH-1:0]                  data_ID_o,
`ifdef GNT_BASED_FC        
    input  logic                                 data_gnt_i
`else
    input  logic                                 data_stall_i
`endif
);

    enum logic { LOAD_STORE, SET_STORE }       CS, NS;                // Current State and Next State
    logic                                      Enable;                // Signal Used to store the ByteEn and Address

    // Internal signal used to switch between LOAD_STORE and SET_STORE
    logic                                      TestAndSet;

    // SAMPLED INPUTS used in the SET_STORE state to comple the test and set opertation
    logic [ADDR_MEM_WIDTH-2:0]                 data_add_S;
    logic [BE_WIDTH-1:0]                       data_be_S;


    logic [ID_WIDTH-1:0]                       data_ID_S;


    // Only when data_add_i[ADDR_MEM_WIDTH] and wen == 1'b1 the test and set is asserted
    assign TestAndSet = (data_add_i[ADDR_MEM_WIDTH-1]) && (data_wen_i == 1'b1);
    assign data_ts_set_o = (CS == SET_STORE);

    always_ff @(posedge clk, negedge  rst_n)
    begin : TestAndSet_UpdataState
      if(rst_n == 1'b0)
        begin
          CS <= LOAD_STORE;
          data_add_S   <= '0;
          data_be_S    <= '0;
          data_ID_S    <= '0;
        end
      else
        begin
          CS <= NS;


          if(Enable == 1'b1) // Sample Inputs for T&S
            begin
              data_add_S   <= data_add_i[ADDR_MEM_WIDTH-2:0];
              data_be_S    <= data_be_i;
              data_ID_S    <= data_ID_i;
            end

        end
    end


    always_comb
    begin : TestAndSet_ComputeState

      case(CS)

          LOAD_STORE: 
          begin : LOAD_STORE_STATE
              data_req_o   = data_req_i;
         `ifdef GNT_BASED_FC
              data_gnt_o = data_gnt_i;
         `else
              data_stall_o = data_stall_i;
         `endif
              data_add_o   = data_add_i[ADDR_MEM_WIDTH-2:0];
              data_be_o    = data_be_i;
              data_wdata_o = data_wdata_i;
              data_wen_o   = data_wen_i;
              data_ID_o    = data_ID_i;

              if((TestAndSet == 1'b1) && (data_req_i == 1'b1))
              begin
              `ifdef GNT_BASED_FC
                  if(data_gnt_i  == 1'b1)
              `else
                  if(data_stall_i == 1'b0)
              `endif
                  begin
                    NS = SET_STORE;
                    Enable = 1'b1;
                  end
                  else
                  begin
                    NS = LOAD_STORE;
                    Enable = 1'b0;
                  end
              end
              else
              begin
                  NS = LOAD_STORE;
                  Enable = 1'b0;
              end

          end

          SET_STORE:
          begin : SET_STORE_STATE
              data_req_o   = 1'b1;

        `ifdef GNT_BASED_FC
              //data_gnt_o = data_gnt_i;
              data_gnt_o = 1'b0;
        `else
              //data_stall_o = data_stall_i;
              data_stall_o = 1'b1;
        `endif

              data_add_o   = data_add_S;
              data_be_o    = data_be_S;
              data_wdata_o = '1;
              data_wen_o   = 1'b0;
              data_ID_o    = data_ID_S;
              Enable       = 1'b0;

        `ifdef GNT_BASED_FC
              if(data_gnt_i  == 1'b1)
        `else
              if(data_stall_i == 1'b0)
        `endif
              begin
                    NS = LOAD_STORE;
              end
              else
              begin
                    NS = SET_STORE;
              end
          end



          default:
          begin
              data_req_o = 1'b0;

           `ifdef GNT_BASED_FC
              data_gnt_o = data_gnt_i;
           `else
              data_stall_o = data_stall_i;
           `endif

              data_add_o   = data_add_i[ADDR_MEM_WIDTH-2:0];
              data_be_o    = data_be_i;
              data_wdata_o = data_wdata_i;
              data_wen_o   = data_wen_i;
              data_ID_o    = data_ID_i;

              Enable     = 1'b0;
              NS         = LOAD_STORE;
          end

      endcase
    end

endmodule
