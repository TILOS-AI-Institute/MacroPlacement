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
// Module Name:    MUX2_REQ                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    two input multiplxer whith custom ports used to multiplex  //
//                 the datapath request data. It includes an embeddedd        //
//                 Fixed Priory arbiter with max priority to Channel 0 (CH0)  //
//                                                                            //
//                                                                            //
// Revision:                                                                  //
// Revision v0.1 - File Created                                               //
// Revision v0.2 - Code Restyling (19/02/2015)                                //
//                                                                            //
// Additional Comments:                                                       //
//                                                                            //
//                                                                            //
//                                                                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////


`include "parameters.v"

module MUX2_REQ_PE 
#(
    parameter ID_WIDTH   = 20,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BE_WIDTH   = DATA_WIDTH/8
) 
(
    input  logic                              data_req_CH0_i,
    input  logic [ADDR_WIDTH-1:0]             data_add_CH0_i,
    input  logic                              data_wen_CH0_i,
    input  logic [DATA_WIDTH-1:0]             data_wdata_CH0_i,
    input  logic [BE_WIDTH-1:0]               data_be_CH0_i,
    input  logic [ID_WIDTH-1:0]               data_ID_CH0_i,
`ifdef GNT_BASED_FC
    output logic                              data_gnt_CH0_o,
`else
    output logic                              data_stall_CH0_o,
`endif


    input  logic                              data_req_CH1_i,
    input  logic [ADDR_WIDTH-1:0]             data_add_CH1_i,
    input  logic                              data_wen_CH1_i,
    input  logic [DATA_WIDTH-1:0]             data_wdata_CH1_i,
    input  logic [BE_WIDTH-1:0]               data_be_CH1_i,
    input  logic [ID_WIDTH-1:0]               data_ID_CH1_i,
`ifdef GNT_BASED_FC
    output logic                              data_gnt_CH1_o,
`else
    output logic                              data_stall_CH1_o,
`endif

    output  logic                             data_req_o,
    output  logic [ADDR_WIDTH-1:0]            data_add_o,
    output  logic                             data_wen_o,
    output  logic [DATA_WIDTH-1:0]            data_wdata_o,
    output  logic [BE_WIDTH-1:0]              data_be_o,
    output  logic [ID_WIDTH-1:0]              data_ID_o,
`ifdef GNT_BASED_FC
    input   logic                             data_gnt_i,
`else
    input   logic                             data_stall_i,
`endif

    input   logic                             clk,
    input   logic                             rst_n
);

    logic                               SEL; // Mux Selector
    logic                              RR_FLAG;

    // Request is simply an or between indoming request
    assign data_req_o = data_req_CH0_i | data_req_CH1_i;
  
      // FIXED PRIORITY ENCODER
    assign SEL               =   ~data_req_CH0_i | ( RR_FLAG & data_req_CH1_i);      // SEL FOR ROUND ROBIN MUX
`ifdef GNT_BASED_FC
    assign data_gnt_CH0_o    =    (( data_req_CH0_i & ~data_req_CH1_i) | ( data_req_CH0_i & ~RR_FLAG)) & data_gnt_i;
    assign data_gnt_CH1_o    =    ((~data_req_CH0_i &  data_req_CH1_i) | ( data_req_CH1_i &  RR_FLAG)) & data_gnt_i;
`else
    assign data_stall_CH0_o  =   (data_req_CH0_i & data_req_CH1_i & RR_FLAG)  |  ((( data_req_CH0_i & ~data_req_CH1_i) | ( data_req_CH0_i & ~RR_FLAG)) & data_stall_i);
    assign data_stall_CH1_o  =   (data_req_CH0_i & data_req_CH1_i & ~RR_FLAG) |  (((~data_req_CH0_i &  data_req_CH1_i) | ( data_req_CH1_i &  RR_FLAG)) & data_stall_i);
`endif

    always_ff @(posedge clk, negedge rst_n)
    begin
    if(rst_n == 1'b0)
        RR_FLAG <= 1'b0;
    else if((data_req_o == 1'b1) && `ifdef GNT_BASED_FC (data_gnt_i == 1'b1) `else (data_stall_i == 1'b0) `endif)
          RR_FLAG <= ~RR_FLAG;
    end

    always_comb
    begin : MUX2_REQ_COMB
        case(SEL) // synopsys full_case
        1'b0: 
        begin
              data_add_o   = data_add_CH0_i;
              data_wen_o   = data_wen_CH0_i;
              data_wdata_o = data_wdata_CH0_i;
              data_be_o    = data_be_CH0_i;
              data_ID_o    = data_ID_CH0_i;
        end

        1'b1:
        begin
              data_add_o   = data_add_CH1_i;
              data_wen_o   = data_wen_CH1_i;
              data_wdata_o = data_wdata_CH1_i;
              data_be_o    = data_be_CH1_i;
              data_ID_o    = data_ID_CH1_i;
        end
        endcase
    end
endmodule
