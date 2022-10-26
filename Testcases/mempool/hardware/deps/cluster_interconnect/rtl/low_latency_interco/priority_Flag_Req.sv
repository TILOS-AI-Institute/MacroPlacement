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
// Module Name:    RR_Flag_Req                                                //
// Project Name:   MegaLEON                                                   //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Round Robing FLAG generator for the arbitration trees.     //
//                 The values ( RR_FLAG_REQ ) is update only when request and //
//                 grant are high. This allow to avoid high sw activity when  //
//                 there is no valid traffic. Allows for clock gating         //
//                 insertion                                                  //
//                                                                            //
// Revision:                                                                  //
// Revision v0.1 - File Created                                               //
// Revision v0.2 - (19/02/2015) --> Code restyling                            //
//                                                                            //
// Additional Comments:                                                       //
//                                                                            //
//                                                                            //
//                                                                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

`include "parameters.v"


module priority_Flag_Req 
#(
      parameter WIDTH     = 3,
      parameter MAX_COUNT = 2**WIDTH-1
)
(
      input  logic                 clk,
      input  logic                 rst_n,
      input  logic                 TCDM_arb_policy_i,

      output logic [WIDTH-1:0]     PRIO_FLAG_o,
      input  logic                 data_req_i,
      input  logic [WIDTH-1:0]     ID_i,
`ifdef GNT_BASED_FC
      input  logic                 data_gnt_i
`else
      input  logic                 data_stall_i
`endif
);

   always_ff @(posedge clk, negedge rst_n)
   begin : Prio_Flag_Req_SEQ
      if(rst_n == 1'b0)
         PRIO_FLAG_o <= '0;
      else
      `ifdef GNT_BASED_FC
            if( data_req_i  & data_gnt_i )
      `else
            if( data_req_i  & ~data_stall_i )
      `endif
            begin
                  if(TCDM_arb_policy_i == 1'b0)
                  begin : RR_PRIORIY
                     if(PRIO_FLAG_o < MAX_COUNT)
                        PRIO_FLAG_o <= PRIO_FLAG_o + 1'b1;
                     else
                        PRIO_FLAG_o <= '0;
                  end
                  else
                  begin : LAST_WIN_PRIO
                     PRIO_FLAG_o <= ID_i;
                  end
            end
   end
   
endmodule
