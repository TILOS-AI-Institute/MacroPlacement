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
// Design Name:    PIPELINE stages for TCDM response channel                  // 
// Module Name:    TCDM_PIPE_RESP                                             //
// Project Name:   PULP 2/3                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    This Block implements a PIPELINE stage for the response    //
//                 channel for TCDM memories. There are two output ports      //
//                 The first gets data frfom SCM memory, while the second     //
//                 is gets data from conventional SRAM memory. To increase the//
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

module TCDM_PIPE_RESP
#(
    parameter  ID_WIDTH        = 6,
    parameter  DATA_WIDTH      = 32
)
(
    input  logic                                 clk,
    input  logic                                 rst_n,

    input  logic [DATA_WIDTH-1:0]                data_r_rdata_SCM_i,
    input  logic [DATA_WIDTH-1:0]                data_r_rdata_SRAM_i,

    input  logic                                 SEL_i,
    input  logic                                 req_i,
    input  logic [ID_WIDTH-1:0]                  data_ID_SCM_i,
    input  logic [ID_WIDTH-1:0]                  data_ID_SRAM_i,

    output logic [DATA_WIDTH-1:0]                data_r_rdata_o,
    output logic                                 data_r_valid_o,
    output logic [ID_WIDTH-1:0]                  data_r_ID_o,
    input   logic                                enable_pipe_i
);



    logic                               data_r_valid_SRAM_int;
    logic                               data_r_valid_SCM_int;


    logic [DATA_WIDTH-1:0]              data_r_rdata_post_PIPE;
    logic                               data_r_valid_post_PIPE;
    logic [ID_WIDTH-1:0]                data_r_ID_post_PIPE;

    logic [ID_WIDTH-1:0]                data_r_ID_SCM_Q;
    logic [ID_WIDTH-1:0]                data_r_ID_SRAM_Q;



    always_ff @(posedge clk, negedge rst_n)
    begin
      if(rst_n == 1'b0)
      begin
        data_r_ID_SCM_Q      <= '0;
        data_r_ID_SRAM_Q     <= '0;
      end
      else
      begin

        if(req_i)
        begin
          data_r_ID_SCM_Q      <=  data_ID_SCM_i; 
          data_r_ID_SRAM_Q     <=  data_ID_SRAM_i;
        end

      end
    end


    //OK
    always_ff @(posedge clk, negedge rst_n)
    begin
      if(rst_n == 1'b0)
      begin

        data_r_valid_SCM_int  <= 1'b0;
        data_r_valid_SRAM_int <= 1'b0;
      end
      else
      begin
        data_r_valid_SCM_int  <= req_i & ~SEL_i;
        data_r_valid_SRAM_int <= req_i & SEL_i;
      end
    end

    //OK
    always_ff @(posedge clk, negedge rst_n)
    begin
      if(rst_n == 1'b0)
      begin
        data_r_rdata_post_PIPE    <= '0;
        data_r_valid_post_PIPE    <= 1'b0;
        data_r_ID_post_PIPE       <= '0;
      end
      else
      begin
        
        if(enable_pipe_i & data_r_valid_SRAM_int)
        begin
          data_r_rdata_post_PIPE    <= data_r_rdata_SRAM_i;
          data_r_valid_post_PIPE    <= data_r_valid_SRAM_int;
          data_r_ID_post_PIPE       <= data_r_ID_SRAM_Q;
        end
        else
        begin
          data_r_rdata_post_PIPE    <= 'X;
          data_r_valid_post_PIPE    <= 1'b0;
          data_r_ID_post_PIPE       <= '0;
        end

      end
    end


    always_comb
    begin
      if(enable_pipe_i)
      begin
        if(data_r_valid_post_PIPE) // SRAM from PIPE
        begin
          data_r_rdata_o = data_r_rdata_post_PIPE;
          data_r_valid_o = data_r_valid_post_PIPE;
          data_r_ID_o    = data_r_ID_post_PIPE;
        end
        else // From SCM
        begin
              data_r_rdata_o = data_r_rdata_SCM_i;
              data_r_valid_o = data_r_valid_SCM_int;
              data_r_ID_o    = data_r_ID_SCM_Q;
        end
      end
      else
      begin
          if(data_r_valid_SRAM_int) //SRAM No pipe
          begin
              data_r_rdata_o = data_r_rdata_SRAM_i;
              data_r_valid_o = data_r_valid_SRAM_int;
              data_r_ID_o    = data_r_ID_SRAM_Q;
          end
          else // From SCM
          begin
              data_r_rdata_o = data_r_rdata_SCM_i;
              data_r_valid_o = data_r_valid_SCM_int;
              data_r_ID_o    = data_r_ID_SCM_Q;
          end
      end
    end


endmodule
