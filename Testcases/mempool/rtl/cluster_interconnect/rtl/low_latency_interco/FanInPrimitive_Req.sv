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
// Module Name:    FanInPrimitive_Req                                         //
// Project Name:   MegaLEON                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Arbitration primitives used to build the arbitration trees.//
//                 They are part of the request network with a distributed    //
//                 arbiter. The arbitration Algorithm is ROUND ROBIN          //
//                                                                            //
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


module FanInPrimitive_Req 
#(
    parameter ADDR_WIDTH  = 32, 
    parameter ID_WIDTH    = 16,
    parameter DATA_WIDTH  = 32,
    parameter N_MASTER    = 8,
    parameter BE_WIDTH    = DATA_WIDTH/8
)
(
    input logic                                  PRIO_FLAG,

    // LEFT SIDE
    input  logic [DATA_WIDTH-1:0]                data_wdata0_i,
    input  logic [DATA_WIDTH-1:0]                data_wdata1_i,
    input  logic [ADDR_WIDTH-1:0]                data_add0_i,
    input  logic [ADDR_WIDTH-1:0]                data_add1_i,
    input  logic                                 data_req0_i,
    input  logic                                 data_req1_i,
    input  logic                                 data_wen0_i,
    input  logic                                 data_wen1_i,
    input  logic [BE_WIDTH-1:0]                  data_be0_i,
    input  logic [BE_WIDTH-1:0]                  data_be1_i,
    input  logic [ID_WIDTH-1:0]                  data_ID0_i,
    input  logic [ID_WIDTH-1:0]                  data_ID1_i,
    input  logic [$clog2(N_MASTER)-1:0]          ID0_i,
    input  logic [$clog2(N_MASTER)-1:0]          ID1_i,
`ifdef GNT_BASED_FC      
    output logic                                 data_gnt0_o,
    output logic                                 data_gnt1_o,
`else
    output logic                                 data_stall0_o,
    output logic                                 data_stall1_o,
`endif
    // RIGTH SIDE
    output logic [DATA_WIDTH-1:0]                data_wdata_o,
    output logic [ADDR_WIDTH-1:0]                data_add_o,
    output logic                                 data_req_o,
    output logic [ID_WIDTH-1:0]                  data_ID_o,
    output logic [$clog2(N_MASTER)-1:0]          ID_o,
    output logic                                 data_wen_o,
    output logic [BE_WIDTH-1:0]                  data_be_o,
`ifdef GNT_BASED_FC
    input  logic                                 data_gnt_i
`else
    input  logic                                 data_stall_i
`endif
);

    logic      SEL;

    assign data_req_o       =     data_req0_i | data_req1_i;
    assign SEL              =    ~data_req0_i | ( PRIO_FLAG & data_req1_i);      // SEL FOR ROUND ROBIN MUX

`ifdef GNT_BASED_FC
    // Grant gnt0 and gnt1
    assign data_gnt0_o      =    (( data_req0_i & ~data_req1_i) | ( data_req0_i & ~PRIO_FLAG)) & data_gnt_i;
    assign data_gnt1_o      =    ((~data_req0_i &  data_req1_i) | ( data_req1_i &  PRIO_FLAG)) & data_gnt_i;    
`else
    // Data stall0 and stall1
    assign data_stall0_o    =   (data_req0_i & data_req1_i & PRIO_FLAG)  |  ((( data_req0_i & ~data_req1_i) | ( data_req0_i & ~PRIO_FLAG)) & data_stall_i);
    assign data_stall1_o    =   (data_req0_i & data_req1_i & ~PRIO_FLAG) |  (((~data_req0_i &  data_req1_i) | ( data_req1_i &  PRIO_FLAG)) & data_stall_i);
`endif
    // SEL CONTROLLER
    //MUXES AND DEMUXES 
    always_comb
    begin : FanIn_MUX2
        case(SEL) //synopsys full_case
        1'b0:
        begin //PRIORITY ON CH_0
            data_wdata_o = data_wdata0_i;
            data_add_o   = data_add0_i;
            data_wen_o   = data_wen0_i;
            data_ID_o    = data_ID0_i;
            data_be_o    = data_be0_i;
            ID_o         = ID0_i;
        end

        1'b1:
        begin //PRIORITY ON CH_1
            data_wdata_o = data_wdata1_i;
            data_add_o   = data_add1_i;
            data_wen_o   = data_wen1_i;
            data_ID_o    = data_ID1_i;
            data_be_o    = data_be1_i;
            ID_o         = ID1_i;
        end

        endcase
    end
endmodule
