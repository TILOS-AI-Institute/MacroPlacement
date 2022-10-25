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
// Design Name:    TCDM Wrapper (grant mask + XBAR TCDM + PIPE req/resp)      // 
// Module Name:    XBAR_TCDM_WRAPPER                                          //
// Project Name:   PULP 2/3                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    This Block wraps the Log interconnect for TCDM memories    //
//                 that are split in two regions: SRAMS and SCM               //
//                 It includes the LOG interco + te reconf pipes              //
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
//`define DEBUG_INFO


module XBAR_TCDM_WRAPPER 
#(
    parameter N_CH0           = 8, //--> CH0
    parameter N_CH1           = 2,  //--> CH1
    parameter N_SLAVE         = 8,
    parameter ID_WIDTH        = N_CH0+N_CH1,

    //FRONT END PARAMS
    parameter ADDR_WIDTH      = 32,
    parameter DATA_WIDTH      = 32,
    parameter BE_WIDTH        = DATA_WIDTH/8,
    parameter TEST_SET_BIT    = 20,

    //BACKEND parameters
    parameter ADDR_MEM_WIDTH  = 11,
    parameter ADDR_SRAM_WIDTH = 10,
    parameter ADDR_SCM_WIDTH  = 8,
    
    parameter DEBUG_PARAMS    = "ENABLE"
)
(
    // ---------------- MASTER CH0+CH1 SIDE  --------------------------
    input  logic [N_CH0+N_CH1-1:0]                         data_req_i,            // Data request
    input  logic [N_CH0+N_CH1-1:0][ADDR_WIDTH-1:0]         data_add_i,            // Data request Address
    input  logic [N_CH0+N_CH1-1:0]                         data_wen_i,            // Data request type : 0--> Store, 1 --> Load
    input  logic [N_CH0+N_CH1-1:0][DATA_WIDTH-1:0]         data_wdata_i,            // Data request Write data
    input  logic [N_CH0+N_CH1-1:0][BE_WIDTH-1:0]           data_be_i,            // Data request Byte enable
    output logic [N_CH0+N_CH1-1:0]                         data_gnt_o,              // Grant Incoming Request
    output logic [N_CH0+N_CH1-1:0]                         data_r_valid_o,            // Data Response Valid (For LOAD/STORE commands)
    output logic [N_CH0+N_CH1-1:0][DATA_WIDTH-1:0]         data_r_rdata_o,       // Data Response DATA (For LOAD commands)

    // ---------------- MM_SIDE (Interleaved) -------------------------- 
    output  logic [N_SLAVE-1:0]                            data_req_SCM_o,         // Data request
    output  logic [N_SLAVE-1:0][ADDR_SCM_WIDTH-1:0]        data_add_SCM_o,         // Data request Address
    output  logic [N_SLAVE-1:0]                            data_wen_SCM_o,        // Data request type : 0--> Store, 1 --> Load
    output  logic [N_SLAVE-1:0][DATA_WIDTH-1:0]            data_wdata_SCM_o,       // Data request Wrire data
    output  logic [N_SLAVE-1:0][BE_WIDTH-1:0]              data_be_SCM_o,          // Data request Byte enable 
    input   logic [N_SLAVE-1:0][DATA_WIDTH-1:0]            data_r_rdata_SCM_i,       // Data Response DATA (For LOAD commands)

    output  logic [N_SLAVE-1:0]                            data_req_SRAM_o,         // Data request
    output  logic [N_SLAVE-1:0][ADDR_SRAM_WIDTH-1:0]       data_add_SRAM_o,         // Data request Address
    output  logic [N_SLAVE-1:0]                            data_wen_SRAM_o,        // Data request type : 0--> Store, 1 --> Load
    output  logic [N_SLAVE-1:0][DATA_WIDTH-1:0]            data_wdata_SRAM_o,       // Data request Wrire data
    output  logic [N_SLAVE-1:0][BE_WIDTH-1:0]              data_be_SRAM_o,          // Data request Byte enable 
    input   logic [N_SLAVE-1:0][DATA_WIDTH-1:0]            data_r_rdata_SRAM_i,       // Data Response DATA (For LOAD commands)      

    input  logic                                           clk,
    input  logic                                           rst_n,
    
    input   logic [1:0]                                    TCDM_arb_policy_i,

    input  logic [N_SLAVE-1:0]                             enable_req_pipe_i,
    input  logic [N_SLAVE-1:0]                             enable_resp_pipe_i
);

  localparam ADDR_OFFSET = `ADDR_OFFSET(DATA_WIDTH);

  logic [N_SLAVE-1:0]                                    data_req_int;
  logic [N_SLAVE-1:0]                                    data_ts_set_int;
  logic [N_SLAVE-1:0][ADDR_MEM_WIDTH-1:0]                data_add_int;
  logic [N_SLAVE-1:0]                                    data_wen_int;
  logic [N_SLAVE-1:0][DATA_WIDTH-1:0]                    data_wdata_int;
  logic [N_SLAVE-1:0][BE_WIDTH-1:0]                      data_be_int;
  logic [N_SLAVE-1:0][ID_WIDTH-1:0]                      data_ID_int;
  logic [N_SLAVE-1:0]                                    data_gnt_int;
  
  logic [N_SLAVE-1:0][DATA_WIDTH-1:0]                    data_r_rdata_int;
  logic [N_SLAVE-1:0][ID_WIDTH-1:0]                      data_r_ID_int;
  logic [N_SLAVE-1:0]                                    data_r_valid_int;
      

  logic [N_SLAVE-1:0][ID_WIDTH-1:0]                      data_ID_SCM_int;
  logic [N_SLAVE-1:0][ID_WIDTH-1:0]                      data_ID_SRAM_int;
      

  logic [N_CH0+N_CH1-1:0]                                data_req_post_gmask;
  logic [N_CH0+N_CH1-1:0][ADDR_WIDTH-1:0]                data_add_post_gmask;
  logic [N_CH0+N_CH1-1:0]                                data_wen_post_gmask;
  logic [N_CH0+N_CH1-1:0][DATA_WIDTH-1:0]                data_wdata_post_gmask;
  logic [N_CH0+N_CH1-1:0][BE_WIDTH-1:0]                  data_be_post_gmask;
  logic [N_CH0+N_CH1-1:0]                                data_gnt_post_gmask;

  //avoid to send RVALID during  a SET access
  logic [N_SLAVE-1:0]                                    data_ts_set_SRAM;
  logic [N_SLAVE-1:0]                                    data_ts_set_SCM;
  logic [N_SLAVE-1:0]                                    send_back_rvalid;


  XBAR_TCDM 
  #(
      .N_CH0          (N_CH0             ),
      .N_CH1          (N_CH1             ),
      .N_SLAVE        (N_SLAVE           ),
      .ID_WIDTH       (ID_WIDTH          ),

      .ADDR_WIDTH     ( ADDR_WIDTH       ),
      .DATA_WIDTH     ( DATA_WIDTH       ),
      .BE_WIDTH       ( BE_WIDTH         ),

      .ADDR_MEM_WIDTH ( ADDR_MEM_WIDTH   ),
      .TEST_SET_BIT   ( TEST_SET_BIT     )
   )
   i_XBAR_TCDM
   (
         // ---------------- MASTER CH0+CH1 SIDE  --------------------------
      .data_req_i     (  data_req_post_gmask       ),
      .data_add_i     (  data_add_post_gmask       ),
      .data_wen_i     (  data_wen_post_gmask       ),
      .data_wdata_i   (  data_wdata_post_gmask     ),
      .data_be_i      (  data_be_post_gmask        ),
      .data_gnt_o     (  data_gnt_post_gmask       ), 

      .data_r_valid_o (                            ),
      .data_r_rdata_o (  data_r_rdata_o            ),

      // ---------------- MM_SIDE (Interleaved) -------------------------- 
      .data_req_o     (  data_req_int              ),
      .data_ts_set_o  (  data_ts_set_int           ),
      .data_add_o     (  data_add_int              ),
      .data_wen_o     (  data_wen_int              ),
      .data_wdata_o   (  data_wdata_int            ),
      .data_be_o      (  data_be_int               ), 
      .data_ID_o      (  data_ID_int               ),
      .data_gnt_i     (  data_gnt_int              ),

      .data_r_rdata_i (  data_r_rdata_int          ),
      .data_r_valid_i (  data_r_valid_int          ),
      .data_r_ID_i    (  data_r_ID_int             ),

      .TCDM_arb_policy_i( TCDM_arb_policy_i        ),

      .clk            (  clk                       ),
      .rst_n          (  rst_n                     )
   );


genvar i;


generate
    for(i=0; i<N_CH0+N_CH1; i++)
    begin  : GRANT_MASK_BLOCK
          grant_mask
          #(
              .N_SLAVE    ( N_SLAVE       ),
              .TO_SCM_BIT ( ADDR_MEM_WIDTH + `log2(N_SLAVE-1) + ADDR_OFFSET - 1),
              .ADDR_WIDTH ( ADDR_WIDTH    ),
              .DATA_WIDTH ( DATA_WIDTH    ),
              .BE_WIDTH   ( BE_WIDTH      )
          )
          i_grant_mask
          (
              .data_req_i         ( data_req_i[i]           ),
              .data_add_i         ( data_add_i[i]           ),
              .data_wen_i         ( data_wen_i[i]           ),
              .data_wdata_i       ( data_wdata_i[i]         ),
              .data_be_i          ( data_be_i[i]            ),
              .data_gnt_o         ( data_gnt_o[i]           ),
              .data_r_valid_o     ( data_r_valid_o[i]       ),

              .data_req_o         ( data_req_post_gmask[i]  ),
              .data_add_o         ( data_add_post_gmask[i]  ),
              .data_wen_o         ( data_wen_post_gmask[i]  ),
              .data_wdata_o       ( data_wdata_post_gmask[i]),
              .data_be_o          ( data_be_post_gmask[i]   ),
              .data_gnt_i         ( data_gnt_post_gmask[i]  ),

              .enable_PIPE_req_i  ( enable_req_pipe_i       ),
              .enable_PIPE_resp_i ( enable_resp_pipe_i      ),

              .clk(clk), 
              .rst_n(rst_n)
          );
    end


    for(i=0; i<N_SLAVE; i++)
    begin : PIPE_REQ
          TCDM_PIPE_REQ 
          #(
              .MEM_WIDTH          ( ADDR_MEM_WIDTH       ),
              .SCM_MEM_WIDTH      ( ADDR_SCM_WIDTH       ),
              .SRAM_MEM_WIDTH     ( ADDR_SRAM_WIDTH      ),
              .ID_WIDTH           ( ID_WIDTH             ),
              .DATA_WIDTH         ( DATA_WIDTH           ),
              .BE_WIDTH           ( BE_WIDTH             )
          )
          i_TCDM_PIPE_REQ
          (
              .clk                ( clk                  ),
              .rst_n              ( rst_n                ),

              .data_req_i         ( data_req_int[i]      ),
              .data_ts_set_i      ( data_ts_set_int[i]   ),
              .data_add_i         ( data_add_int[i]      ),
              .data_wen_i         ( data_wen_int[i]      ),
              .data_wdata_i       ( data_wdata_int[i]    ),
              .data_be_i          ( data_be_int[i]       ),
              .data_ID_i          ( data_ID_int[i]       ),
              .data_gnt_o         ( data_gnt_int[i]      ),

              .data_req_SCM_o     ( data_req_SCM_o[i]    ),
              .data_ts_set_SCM_o  ( data_ts_set_SCM[i]   ),
              .data_add_SCM_o     ( data_add_SCM_o[i]    ),
              .data_wen_SCM_o     ( data_wen_SCM_o[i]    ),
              .data_wdata_SCM_o   ( data_wdata_SCM_o[i]  ),
              .data_be_SCM_o      ( data_be_SCM_o[i]     ),
              .data_ID_SCM_o      ( data_ID_SCM_int[i]   ),

              .data_req_SRAM_o    ( data_req_SRAM_o[i]   ),
              .data_ts_set_SRAM_o ( data_ts_set_SRAM[i]  ),
              .data_add_SRAM_o    ( data_add_SRAM_o[i]   ),
              .data_wen_SRAM_o    ( data_wen_SRAM_o[i]   ),
              .data_wdata_SRAM_o  ( data_wdata_SRAM_o[i] ),
              .data_be_SRAM_o     ( data_be_SRAM_o[i]    ),
              .data_ID_SRAM_o     ( data_ID_SRAM_int[i]  ),

              .enable_pipe_req_i  ( enable_req_pipe_i[i] ),
              .enable_pipe_resp_i ( enable_resp_pipe_i[i])
          );
    end

    for(i=0; i<N_SLAVE; i++)
    begin : SEND_BACK_RVALID_BIND
          assign send_back_rvalid[i] = (data_req_SRAM_o[i] & ~data_ts_set_SRAM[i]) | (data_req_SCM_o[i] & ~data_ts_set_SCM[i]);
    end

    for(i=0; i<N_SLAVE; i++)
    begin : PIPE_RESP
          TCDM_PIPE_RESP 
          #(
                .ID_WIDTH             ( ID_WIDTH   ),
                .DATA_WIDTH           ( DATA_WIDTH )
          )
          i_TCDM_PIPE_RESP
          (
                .clk                  ( clk                                     ),
                .rst_n                ( rst_n                                   ),

                .data_r_rdata_SCM_i   ( data_r_rdata_SCM_i[i]                   ),
                .data_r_rdata_SRAM_i  ( data_r_rdata_SRAM_i[i]                  ),

                .SEL_i                (  data_req_SRAM_o[i]                     ),
                .req_i                (  send_back_rvalid[i]                    ),
                .data_ID_SCM_i        (  data_ID_SCM_int[i]                     ),
                .data_ID_SRAM_i       (  data_ID_SRAM_int[i]                    ),

                .data_r_rdata_o       ( data_r_rdata_int[i]                     ),
                .data_r_valid_o       ( data_r_valid_int[i]                     ), 
                .data_r_ID_o          ( data_r_ID_int[i]                        ), 

                .enable_pipe_i        ( enable_resp_pipe_i[i]                   )
          );
    end 
endgenerate


`ifdef DEBUG_INFO
//synopsys translate_off
initial
begin
    if(DEBUG_PARAMS == "ENABLE")
    begin
        $display("**********************************",);
        $display(">>>> XBAR_TCDM_WRAPPER_PARAMS <<<<",);
        $display("**********************************",);
        $display("N_CH0           = %d", N_CH0   );
        $display("N_CH1           = %d",N_CH1   );
        $display("N_SLAVE         = %d",N_SLAVE );
        $display("ID_WIDTH        = %d",ID_WIDTH);
        $display("ADDR_WIDTH      = %d",ADDR_WIDTH  );
        $display("DATA_WIDTH      = %d",DATA_WIDTH  );
        $display("BE_WIDTH        = %d",BE_WIDTH    );
        $display("TEST_SET_BIT    = %d",TEST_SET_BIT);
        $display("ADDR_MEM_WIDTH  = %d",ADDR_MEM_WIDTH  );
        $display("ADDR_SRAM_WIDTH = %d",ADDR_SRAM_WIDTH );
        $display("ADDR_SCM_WIDTH  = %d",ADDR_SCM_WIDTH  );
        $display("ADDR_OFFSET     = %d",ADDR_OFFSET);
        $display("**********************************",);
    end
end                           
//synopsys translate_on
`endif



// //DEBUG STUFF
// integer DCORE_0;
// integer DCORE_1;
// integer DCORE_2;
// integer DCORE_3;
// 
// 
//     initial 
//       begin
//         DCORE_0 = $fopen("debug_DCORE_0.txt");
//         DCORE_1 = $fopen("debug_DCORE_1.txt");
//         DCORE_2 = $fopen("debug_DCORE_2.txt");
//         DCORE_3 = $fopen("debug_DCORE_3.txt");
//         
//         
//         #9000000;
//         $fclose(DCORE_0);
//         $fclose(DCORE_1);
//         $fclose(DCORE_2);
//         $fclose(DCORE_3);
// 
//       end
// 
// 
//     always @ (posedge clk)
//     begin
//       if(data_req_i[0] & data_gnt_o[0])
//         if(data_wen_i[0])
//           $fdisplay(DCORE_0, "Reading at address %x\t", data_add_i[0]);
//         else
//           $fdisplay(DCORE_0, "Writing at address %x\t, with DATA=%x\t and mask %x\t ", data_add_i[0], data_wdata_i[0], data_be_i[0]);
//         
//       if(data_r_valid_o[0])
//          $fdisplay(DCORE_0, "Read DATA is =%x\t ", data_r_rdata_o[0]);
//     end
// 
//     always @ (posedge clk)
//     begin
//       if(data_req_i[1] & data_gnt_o[1])
//         if(data_wen_i[1])
//           $fdisplay(DCORE_1, "Reading at address %x\t", data_add_i[1]);
//         else
//           $fdisplay(DCORE_1, "Writing at address %x\t, with DATA=%x\t and mask %x\t ", data_add_i[1], data_wdata_i[1], data_be_i[1]);
//         
//       if(data_r_valid_o[1])
//          $fdisplay(DCORE_1, "Read DATA is =%x\t ", data_r_rdata_o[1]);
//     end
// 
//     always @ (posedge clk)
//     begin
//       if(data_req_i[2] & data_gnt_o[2])
//         if(data_wen_i[2])
//           $fdisplay(DCORE_2, "Reading at address %x\t", data_add_i[2]);
//         else
//           $fdisplay(DCORE_2, "Writing at address %x\t, with DATA=%x\t and mask %x\t ", data_add_i[2], data_wdata_i[2], data_be_i[2]);
//         
//       if(data_r_valid_o[2])
//          $fdisplay(DCORE_2, "Read DATA is =%x\t ", data_r_rdata_o[2]);
//     end
// 
//     always @ (posedge clk)
//     begin
//       if(data_req_i[3] & data_gnt_o[3])
//         if(data_wen_i[3])
//           $fdisplay(DCORE_3, "Reading at address %x\t", data_add_i[3]);
//         else
//           $fdisplay(DCORE_3, "Writing at address %x\t, with DATA=%x\t and mask %x\t ", data_add_i[3], data_wdata_i[3], data_be_i[3]);
//         
//       if(data_r_valid_o[3])
//          $fdisplay(DCORE_3, "Read DATA is =%x\t ", data_r_rdata_o[3]);
//     end

endmodule
