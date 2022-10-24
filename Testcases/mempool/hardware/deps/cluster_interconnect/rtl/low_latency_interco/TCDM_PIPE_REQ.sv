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
// Design Name:    PIPELINE stages for TCDM request channel                   // 
// Module Name:    TCDM_PIPE_REQ                                              //
// Project Name:   PULP 2/3                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    This Block implements a PIPELINE stage for the request     //
//                 channel for TCDM memories. There are two output ports      //
//                 The first is connected to SCM memory, while the second     //
//                 is connected to conventional SRAM memory. To increase the  //
//                 robustness, the SRAM port can be pipelined. SCM is         //
//                 connected directly (no Pipe)                               //
//                                                                            //
// Revision:                                                                  //
// v0.1 - File Created                                                        //
// v0.2 19/02/2015  - Code restyling                                          //
//                                                                            //
// Additional Comments:                                                       //
//                                                                            //
//                                                                            //
//                                                                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////


`include "parameters.v"

module TCDM_PIPE_REQ
#(
    parameter  MEM_WIDTH       = 11,
    parameter  SCM_MEM_WIDTH   = 8,
    parameter  SRAM_MEM_WIDTH  = 10,
    parameter  ID_WIDTH        = 12,
    parameter  DATA_WIDTH      = 32,
    parameter  BE_WIDTH        = 32
)
(
    input  logic                                 clk,
    input  logic                                 rst_n,

    input  logic                                 data_req_i,            // Data request
    input  logic                                 data_ts_set_i,         // current req is a SET during Test & SET
    input  logic [MEM_WIDTH-1:0]                 data_add_i,            // Data request Address
    input  logic                                 data_wen_i,            // Data request type : 0--> Store, 1 --> Load
    input  logic [DATA_WIDTH-1:0]                data_wdata_i,          // Data request Write data
    input  logic [BE_WIDTH-1:0]                  data_be_i,             // Data request Byte enable
    input  logic [ID_WIDTH-1:0]                  data_ID_i,             // 
    output logic                                 data_gnt_o,            // Grant Incoming Request




    output  logic                                data_req_SCM_o,        // Data request
    output  logic                                data_ts_set_SCM_o,     // current req is a SET during Test & Set to SCM
    output  logic [SCM_MEM_WIDTH-1:0]            data_add_SCM_o,        // Data request Address
    output  logic                                data_wen_SCM_o,        // Data request type : 0--> Store, 1 --> Load
    output  logic [DATA_WIDTH-1:0]               data_wdata_SCM_o,      // Data request Write data
    output  logic [BE_WIDTH-1:0]                 data_be_SCM_o,         // Data request Byte enable
    output  logic [ID_WIDTH-1:0]                 data_ID_SCM_o,         // Data request Byte enable


    output  logic                                data_req_SRAM_o,       // Data request
    output  logic                                data_ts_set_SRAM_o,    // current req is a SET during Test & Set to SRAM
    output  logic [SRAM_MEM_WIDTH-1:0]           data_add_SRAM_o,       // Data request Address
    output  logic                                data_wen_SRAM_o,       // Data request type : 0--> Store, 1 --> Load
    output  logic [DATA_WIDTH-1:0]               data_wdata_SRAM_o,     // Data request Write data
    output  logic [BE_WIDTH-1:0]                 data_be_SRAM_o,        // Data request Byte enable
    output  logic [ID_WIDTH-1:0]                 data_ID_SRAM_o,        // Data request Byte enable

    input   logic                                enable_pipe_req_i,     //
    input   logic                                enable_pipe_resp_i     //
);

localparam  PIPE_WIDTH = ID_WIDTH + MEM_WIDTH + 1 + DATA_WIDTH + BE_WIDTH + 1;

enum logic [1:0] {IDLE_SCM, SRAM_1, SRAM_0}       CS, NS;

logic                               data_req_SRAM_int;
logic                               req_PIPE_out;
logic [PIPE_WIDTH-1:0]              data_PIPE_out;
logic [PIPE_WIDTH-1:0]              data_PIPE_in;




logic                               ts_set_PIPE_out;
logic [MEM_WIDTH-1:0]               add_PIPE_temp_out;
logic [SRAM_MEM_WIDTH-1:0]          add_PIPE_out;
logic                               wen_PIPE_out;
logic [DATA_WIDTH-1:0]              wdata_PIPE_out;
logic [BE_WIDTH-1:0]                be_PIPE_out;
logic [ID_WIDTH-1:0]                ID_PIPE_out;

logic                               to_SCM;



assign add_PIPE_out = add_PIPE_temp_out[SRAM_MEM_WIDTH-1:0];


assign to_SCM = data_add_i[MEM_WIDTH-1];



always_ff @(posedge clk, negedge rst_n)
begin
  if(rst_n == 1'b0)
  begin
    CS <= IDLE_SCM;
  end
  else begin
    CS <= NS;
  end
end


always_comb
begin

  data_gnt_o      = 1'b0;
  data_req_SCM_o  = 1'b0;
  data_req_SRAM_int = 1'b0;


  case(CS)

  IDLE_SCM:
  begin
      data_gnt_o = 1'b1;
      
      data_req_SCM_o    = (to_SCM)  ? data_req_i : 1'b0;
      data_req_SRAM_int = (~to_SCM) ? data_req_i : 1'b0;

      if(data_req_i)
      begin
      if(to_SCM)
        NS = IDLE_SCM;
      else
      begin
        case({enable_pipe_req_i,enable_pipe_resp_i})
        2'b00: 
        begin 
            NS = IDLE_SCM;
        end
        
        2'b01: 
        begin 
            NS = SRAM_0;
        end
        
        2'b10: 
        begin 
            NS = SRAM_0;
        end
        
        2'b11: 
        begin 
            NS = SRAM_1;
        end
        
        endcase
        
      end
      end
      else
      begin
      NS = IDLE_SCM;
      end
  end //~IDLE




  SRAM_0 :
  begin
      NS                = IDLE_SCM;
      data_gnt_o        = 1'b0;
      data_req_SCM_o    = 1'b0;
      data_req_SRAM_int = 1'b0;      
  end //~SRAM_0
  
  SRAM_1 :
  begin
      NS = SRAM_0;
      data_gnt_o        = 1'b0;
      data_req_SCM_o    = 1'b0;
      data_req_SRAM_int = 1'b0;  
  end //~SRAM_1  
  

  default :
  begin
    NS = IDLE_SCM;
    data_gnt_o = 1'b0;
    data_req_SCM_o  = 1'b0;
    data_req_SRAM_int = 1'b0;
  end
  endcase
end


assign data_PIPE_in = {data_ts_set_i,   data_ID_i,   data_add_i,           data_wen_i,      data_wdata_i,      data_be_i   };
assign                {ts_set_PIPE_out, ID_PIPE_out, add_PIPE_temp_out,    wen_PIPE_out,    wdata_PIPE_out,    be_PIPE_out } = data_PIPE_out;



assign data_add_SCM_o     = data_add_i[SCM_MEM_WIDTH-1:0];
assign data_wen_SCM_o    = data_wen_i;
assign data_wdata_SCM_o   = data_wdata_i;
assign data_be_SCM_o      = data_be_i;
assign data_ID_SCM_o      = data_ID_i;
assign data_ts_set_SCM_o  = data_ts_set_i;























always_ff @(posedge clk, negedge rst_n)
begin
  if(rst_n == 1'b0)
  begin
    data_PIPE_out      <= '0;
    req_PIPE_out       <= 1'b0;
  end
  else
  begin
    req_PIPE_out       <= enable_pipe_req_i & data_req_SRAM_int;
    if(enable_pipe_req_i & data_req_SRAM_int)
    begin
      data_PIPE_out      <= data_PIPE_in;
    end
  end
end


always_comb
begin
  if(enable_pipe_req_i)
  begin
    data_req_SRAM_o    = req_PIPE_out;
    data_ts_set_SRAM_o = ts_set_PIPE_out;
    data_add_SRAM_o    = add_PIPE_out[SRAM_MEM_WIDTH-1:0];
    data_wen_SRAM_o    = wen_PIPE_out;
    data_wdata_SRAM_o  = wdata_PIPE_out;
    data_be_SRAM_o     = be_PIPE_out;
    data_ID_SRAM_o     = ID_PIPE_out;
  end
  else
  begin
    data_req_SRAM_o    = data_req_SRAM_int;
    data_ts_set_SRAM_o = data_ts_set_i;
    data_add_SRAM_o    = data_add_i[SRAM_MEM_WIDTH-1:0];
    data_wen_SRAM_o   = data_wen_i;
    data_wdata_SRAM_o  = data_wdata_i;
    data_be_SRAM_o     = data_be_i;
    data_ID_SRAM_o     = data_ID_i;
  end
end






endmodule
