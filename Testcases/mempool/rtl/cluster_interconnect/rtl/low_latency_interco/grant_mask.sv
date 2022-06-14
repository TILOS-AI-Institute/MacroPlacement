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
// Create Date:    12/05/2014                                                 // 
// Design Name:    PIPE_UNIT for TCDM                                         // 
// Module Name:    grant_mask                                                 //
// Project Name:   PULP 2/3                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Grant manipulator to avoid issues (multiple pending resp)  //
//                 when the reconfigurable pipeline stages are actived        //
//                                                                            //
// Revision:                                                                  //
// v0.1 - File Created                                                        //
// v0.2 14/02/2014  - Code restyling                                          //
//                                                                            //
// Additional Comments:                                                       //
//                                                                            //
//                                                                            //
//                                                                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////


`include "parameters.v"

module grant_mask
#(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BE_WIDTH   = DATA_WIDTH/8,

    parameter N_SLAVE    = 8,
    parameter TO_SCM_BIT = 15
)
(
    input  logic                         data_req_i,
    input  logic [ADDR_WIDTH-1:0]        data_add_i,
    input  logic                         data_wen_i,
    input  logic [DATA_WIDTH-1:0]        data_wdata_i,
    input  logic [BE_WIDTH-1:0]          data_be_i,
    output logic                         data_gnt_o,

    output  logic                        data_req_o,
    output  logic [ADDR_WIDTH-1:0]       data_add_o,
    output  logic                        data_wen_o,
    output  logic [DATA_WIDTH-1:0]       data_wdata_o,
    output  logic [BE_WIDTH-1:0]         data_be_o,
    input   logic                        data_gnt_i,

    input   logic [N_SLAVE-1:0]          enable_PIPE_req_i,
    input   logic [N_SLAVE-1:0]          enable_PIPE_resp_i,

    output  logic                         data_r_valid_o,

    input logic                         clk,
    input logic                         rst_n
);

    localparam ADDR_OFFSET = `ADDR_OFFSET(DATA_WIDTH);

    enum logic [1:0] {IDLE, SRAM_0, SRAM_1} CS, NS;

    logic to_SCM;

    assign data_add_o   = data_add_i;
    assign data_wen_o   = data_wen_i;
    assign data_wdata_o = data_wdata_i;
    assign data_be_o    = data_be_i;

    always_comb
    begin
      if(data_add_i[TO_SCM_BIT])
        to_SCM = 1'b1;
      else
        to_SCM = 1'b0;
    end

    always_ff @(posedge clk, negedge rst_n)
    begin
      if(rst_n == 1'b0)
      begin
        CS <= IDLE;
        data_r_valid_o <= 1'b0;
      end
      else begin
        CS <= NS;
        data_r_valid_o <= data_req_i & data_gnt_o;
      end
    end


    always_comb
    begin

      data_gnt_o      = 1'b0;
      data_req_o      = 1'b0;
      NS              = CS;

      case(CS)

      IDLE :
        begin
          if(data_req_i)
          begin
          if(to_SCM)
          begin
            data_gnt_o = data_gnt_i;
            data_req_o = data_req_i;
            NS = IDLE;
          end
          else
          begin

            case({enable_PIPE_req_i[ data_add_i[`log2(N_SLAVE-1)+ADDR_OFFSET-1:ADDR_OFFSET] ], enable_PIPE_resp_i[data_add_i[`log2(N_SLAVE-1)+ADDR_OFFSET-1:ADDR_OFFSET]]})

            2'b00: 
            begin 
                NS = IDLE; 
                data_gnt_o = data_gnt_i; 
                data_req_o = data_req_i; 
            end

            2'b01: 
            begin 
                data_gnt_o = 1'b0; 
                data_req_o = data_req_i; 
                if(data_gnt_i)
                  NS = SRAM_0;
                else
                  NS = IDLE;
            end

            2'b10:
            begin 
                data_gnt_o = 1'b0; 
                data_req_o = data_req_i; 
                if(data_gnt_i)
                  NS = SRAM_0;
                else
                  NS = IDLE;
            end

            2'b11: 
            begin 
                data_gnt_o = 1'b0; 
                data_req_o = data_req_i; 
                if(data_gnt_i)
                  NS = SRAM_1;
                else
                  NS = IDLE;
            end

            endcase
          end

          end
          else // no request
          begin
            NS = IDLE; data_gnt_o = 1'b0; data_req_o = 1'b0;
          end

        end //~IDLE

      SRAM_0 : 
        begin
          NS = IDLE; data_gnt_o = 1'b1; data_req_o = 1'b0;
        end  //~SRAM_0

      SRAM_1 :
        begin
          NS = SRAM_0; data_gnt_o = 1'b0; data_req_o = 1'b0; 
        end  //~SRAM_1

      default :
        begin
          NS = IDLE; data_gnt_o = 1'b0; data_req_o = 1'b0;
        end  //~default

      endcase
    end





endmodule
