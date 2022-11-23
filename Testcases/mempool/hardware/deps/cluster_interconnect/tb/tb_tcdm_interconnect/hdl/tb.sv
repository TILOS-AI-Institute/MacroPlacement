// Copyright 2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Michael Schaffner <schaffner@iis.ee.ethz.ch>, ETH Zurich
// Date: 06.03.2019
// Description: testbench for tcdm_interconnect with random and linear access patterns.
//

`include "tb.svh"
`include "defaults.svh"

import tb_pkg::*;

module tb;

  // leave this
  timeunit 1ps;
  timeprecision 1ps;

  // tcdm configuration
  localparam MutImpl        = `MUT_IMPL;
  localparam NumBanks       = `NUM_MASTER * `BANK_FACT;
  localparam NumMaster      = `NUM_MASTER;
  localparam DataWidth      = `DATA_WIDTH;
  localparam MemAddrBits    = `MEM_ADDR_BITS;
  localparam TestCycles     = `TEST_CYCLES;
  localparam NumPar         = `PAR_STAGES; // for parallel bfly only

  localparam StatsFile      = "statistics.log";

  localparam AddrWordOff    = $clog2(DataWidth-1)-3;

  localparam string impl[] = {"lic", "bfly2", "bfly4", "clos_m2n", "clos_m1n", "clos_2mn", "licOld"};

///////////////////////////////////////////////////////////////////////////////
// MUT signal declarations
///////////////////////////////////////////////////////////////////////////////

  logic [NumMaster-1:0] req_i;
  logic [NumMaster-1:0][DataWidth-1:0] add_i;
  logic [NumMaster-1:0] wen_i;
  logic [NumMaster-1:0][DataWidth-1:0] wdata_i;
  logic [NumMaster-1:0][DataWidth/8-1:0] be_i;
  logic [NumMaster-1:0] gnt_o;
  logic [NumMaster-1:0] vld_o;
  logic [NumMaster-1:0][DataWidth-1:0] rdata_o;

  logic [NumBanks-1:0] cs_o;
  logic [NumBanks-1:0][MemAddrBits-1:0] add_o;
  logic [NumBanks-1:0] wen_o;
  logic [NumBanks-1:0][DataWidth-1:0] wdata_o;
  logic [NumBanks-1:0][DataWidth/8-1:0] be_o;
  logic [NumBanks-1:0][DataWidth-1:0] rdata_i;

///////////////////////////////////////////////////////////////////////////////
// TB signal declarations
///////////////////////////////////////////////////////////////////////////////

  logic        clk_i, rst_ni;
  logic        end_of_sim;
  logic        [NumMaster-1:0] pending_req_d, pending_req_q;
  logic        [NumMaster-1:0] cnt_set;
  int unsigned cnt_val[0:NumMaster-1];
  int unsigned cnt_d[0:NumMaster-1], cnt_q[0:NumMaster-1];
  int unsigned gnt_cnt_d[0:NumMaster-1], gnt_cnt_q[0:NumMaster-1];
  int unsigned req_cnt_d[0:NumMaster-1], req_cnt_q[0:NumMaster-1];
  int unsigned bank_req_cnt_d[0:NumBanks-1], bank_req_cnt_q[0:NumBanks-1];
  int unsigned wait_cnt_d[0:NumMaster-1], wait_cnt_q[0:NumMaster-1];
  int unsigned num_cycles;
  string       test_name;
  real         pReq_test[0:NumMaster-1];
  int unsigned maxLen_test;
  logic        nonUniform_test;
  string       mut_name;

///////////////////////////////////////////////////////////////////////////////
// helper tasks
///////////////////////////////////////////////////////////////////////////////

  // this file includes all the tasks that emulate access patterns
  `include "tb_patterns.sv"

  function automatic void printStats(string file);
    automatic real pReq_avg, wait_avg, load_avg;
    // append
    int fp = $fopen(file,"a");
    // print test configuration
    $display(test_name);
    if (nonUniform_test) begin
      // todo: need to adapt parsing script for ML as well
      $fdisplay(fp, "test config:\nnet: %s\nnumMaster: %05d\nnumBanks: %05d\ndataWidth: %05d\nmemAddrBits: %05d\ntestCycles: %05d\ntestName: %s\npReq: %e\nmaxLen: %05d", mut_name, NumMaster, NumBanks, DataWidth, MemAddrBits, TestCycles, test_name, pReq_test[0], maxLen_test);
      for (int k=0; k<$size(pReq_test); k++) begin
        $display("p[%0d]=%.2f", k, pReq_test[k]);
      end
    end else begin
      $fdisplay(fp, "test config:\nnet: %s\nnumMaster: %05d\nnumBanks: %05d\ndataWidth: %05d\nmemAddrBits: %05d\ntestCycles: %05d\ntestName: %s\npReq: %e\nmaxLen: %05d", mut_name, NumMaster, NumBanks, DataWidth, MemAddrBits, TestCycles, test_name, pReq_test[0], maxLen_test);
      $display("p=%.2f", pReq_test[0]);
    end
    if (maxLen_test>0) begin
      $display("maxLen=%02d", maxLen_test);
    end
    $display("sim cycles: %03d", num_cycles);
    $display("---------------------------------------");

    pReq_avg = 0.0;
    wait_avg = 0.0;
    load_avg = 0.0;
    for (int m=0; m<NumMaster; m++) begin
      $fdisplay(fp, "Port %03d: Req=%05d Gnt=%05d p=%e Wait=%e",
        m, req_cnt_q[m], gnt_cnt_q[m], real'(gnt_cnt_q[m])/real'(req_cnt_q[m]+0.00001), real'(wait_cnt_q[m])/real'(gnt_cnt_q[m]+0.00001));
      $display("Port %03d: Req=%05d Gnt=%05d p_req=%.2f, p_gnt=%.2f Wait=%.2f",
        m, req_cnt_q[m], gnt_cnt_q[m], real'(gnt_cnt_q[m])/real'(num_cycles), real'(gnt_cnt_q[m])/real'(req_cnt_q[m]+0.00001), real'(wait_cnt_q[m])/real'(gnt_cnt_q[m]+0.00001));
      pReq_avg += real'(gnt_cnt_q[m])/real'(req_cnt_q[m]+0.00001);
      wait_avg += real'(wait_cnt_q[m])/real'(gnt_cnt_q[m]+0.00001);
    end
    $display("");
    for (int s=0; s<NumBanks; s++) begin
      $fdisplay(fp,"Bank %03d: Req=%05d Load=%e",
        s, bank_req_cnt_q[s], real'(bank_req_cnt_q[s])/real'(num_cycles));
      $display("Bank %03d: Req=%05d Load=%.2f",
        s, bank_req_cnt_q[s], real'(bank_req_cnt_q[s])/real'(num_cycles));
      load_avg += real'(bank_req_cnt_q[s])/real'(num_cycles);
    end

    $display("");
    $display("Port Avg p=%.2f Wait=%.2f", pReq_avg / real'(NumMaster), wait_avg / real'(NumMaster));
    $display("Bank Avg Load=%.2f", load_avg / real'(NumBanks));
    $display("---------------------------------------");
    $fdisplay(fp,"");
    $fclose(fp);
  endfunction : printStats


///////////////////////////////////////////////////////////////////////////////
// Clock Process
///////////////////////////////////////////////////////////////////////////////

  initial begin : p_clock
    do begin
      clk_i = 1;#(CLK_HI);
      clk_i = 0;#(CLK_LO);
    end while (end_of_sim == 1'b0);
    repeat (100) begin
      // generate a few extra cycle to allow
      // response acquisition to complete
      clk_i = 1;#(CLK_HI);
      clk_i = 0;#(CLK_LO);
    end
  end

///////////////////////////////////////////////////////////////////////////////
// memory emulation
///////////////////////////////////////////////////////////////////////////////

  logic [NumBanks-1:0][2**MemAddrBits-1:0][DataWidth-1:0] mem_array;
  logic [NumBanks-1:0][DataWidth-1:0] rdata_q;

  always_ff @(posedge clk_i) begin : p_mem
    if(~rst_ni) begin
      // fill memory with some random numbers
      void'(randomize(mem_array));
      rdata_q <= 'x;
    end else begin
      for(int b=0; b<NumBanks; b++) begin
        if (cs_o[b]) begin
          if (wen_o[b]) begin
            for (int j=0; j< DataWidth/8; j++) begin
              if (be_o[b][j]) mem_array[b][add_o[b]][j*8 +: 8] <= wdata_o[b][j*8 +: 8];
            end
          end else begin
            // $display("%d> %08X, %08X",b,add_o[b],mem_array[b][add_o[b]]);
            rdata_q[b] <= mem_array[b][add_o[b]];
          end
        end else begin
          rdata_q[b] <= 'x;
        end
      end
    end
  end

  assign rdata_i = rdata_q;

  // pending request tracking
  // granted reqs are cleared, ungranted reqs
  // are marked as pending
  assign pending_req_d = (pending_req_q | req_i) & ~gnt_o;

  for (genvar m=0; m<NumMaster; m++) begin
    assign cnt_d[m]      = (cnt_set[m])             ? cnt_val[m]-1 :
                           (gnt_o[m] && cnt_q[m]>0) ? cnt_q[m]-1   :
                                                      cnt_q[m];

    assign gnt_cnt_d[m]  = (gnt_o[m])              ? gnt_cnt_q[m]  + 1 : gnt_cnt_q[m];
    assign req_cnt_d[m]  = (req_i[m])              ? req_cnt_q[m]  + 1 : req_cnt_q[m];
    assign wait_cnt_d[m] = (req_i[m] & ~gnt_o[m])  ? wait_cnt_q[m] + 1 : wait_cnt_q[m];
  end

  // assumes that banks always grant requests
  for (genvar s=0; s<NumBanks; s++) begin : g_req_cnt
    assign bank_req_cnt_d[s]  = (cs_o[s])          ? bank_req_cnt_q[s]  + 1 : bank_req_cnt_q[s];
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : p_req_pending
    if(~rst_ni) begin
      pending_req_q   <= '0;
      gnt_cnt_q       <= '{default:0};
      req_cnt_q       <= '{default:0};
      bank_req_cnt_q  <= '{default:0};
      wait_cnt_q      <= '{default:0};
      cnt_q           <= '{default:0};
    end else begin
      pending_req_q   <= pending_req_d;
      gnt_cnt_q       <= gnt_cnt_d;
      req_cnt_q       <= req_cnt_d;
      bank_req_cnt_q  <= bank_req_cnt_d;
      wait_cnt_q      <= wait_cnt_d;
      cnt_q           <= cnt_d;
    end
  end

  // check the memory responses using assertions
  logic [NumMaster-1:0][$clog2(NumBanks)-1:0] bank_sel;
  logic [NumMaster-1:0][MemAddrBits-1:0] bank_addr;

  for (genvar m=0; m<NumMaster; m++) begin : g_assert

    // simplifies the assertion below
    assign bank_sel[m]  = add_i[m][$clog2(NumBanks)+AddrWordOff-1:AddrWordOff];
    assign bank_addr[m] = add_i[m][$clog2(NumBanks)+AddrWordOff+MemAddrBits-1:$clog2(NumBanks)+AddrWordOff];

    bank_read : assert property(
        @(posedge clk_i) disable iff (~rst_ni) req_i[m] |-> gnt_o[m] |=> vld_o[m] && ($past(mem_array[bank_sel[m]][bank_addr[m]],1) == rdata_o[m]))
          else $fatal (1, "rdata mismatch on master %0d: exp %08X != act %06X.", m, $past(mem_array[bank_sel[m]][bank_addr[m]],1), rdata_o[m]);
  end


///////////////////////////////////////////////////////////////////////////////
// MUT
///////////////////////////////////////////////////////////////////////////////


  if (MutImpl >= 1 && MutImpl <=2) begin : g_bfly
    assign mut_name = {impl[MutImpl], $psprintf("_n%0d", NumPar)};
  end else begin : g_others
    assign mut_name = impl[MutImpl];
  end

  // parameters are overriden via defines
  // this is used to share the same wrapper
  // for the testbench and synthesis script
  tcdm_interconnect_wrap i_tcdm_interconnect (
    .clk_i   ( clk_i   ),
    .rst_ni  ( rst_ni  ),
    .req_i   ( req_i   ),
    .add_i   ( add_i   ),
    .wen_i   ( wen_i   ),
    .wdata_i ( wdata_i ),
    .be_i    ( be_i    ),
    .gnt_o   ( gnt_o   ),
    .vld_o   ( vld_o   ),
    .rdata_o ( rdata_o ),
    .req_o   ( cs_o    ),
    .gnt_i   ( cs_o    ),
    .add_o   ( add_o   ),
    .wen_o   ( wen_o   ),
    .wdata_o ( wdata_o ),
    .be_o    ( be_o    ),
    .rdata_i ( rdata_i )
  );

///////////////////////////////////////////////////////////////////////////////
// simulation coordinator process
///////////////////////////////////////////////////////////////////////////////

  initial begin : p_stim
    automatic real p[0:NumMaster-1];
    automatic int fp;
    // seq_done
    end_of_sim       = 0;
    rst_ni           = 0;

    // print some info
    $display("---------------------------------------");
    $display("TCDM Network Traffic Simulation");
    $display("---------------------------------------");
    $display("Current configuration:");
    $display("Network:        %s",   mut_name     );
    $display("NumPar:         %0d",  NumPar       );
    $display("NumMaster:      %0d",  NumMaster    );
    $display("NumBanks:       %0d",  NumBanks     );
    $display("DataWidth:      %0d",  DataWidth    );
    $display("MemAddrBits:    %0d",  MemAddrBits  );
    $display("TestCycles:     %0d",  TestCycles   );
    $display("StatsFile:      %s",   StatsFile    );

    // clear stats file
    fp = $fopen(StatsFile,"w");
    $fclose(fp);

    // reset cycles
    `APPL_WAIT_CYC(clk_i,1)
    rst_ni        = 1'b1;
    `APPL_WAIT_CYC(clk_i,100)

    $display("start with test sequences");
    $display("---------------------------------------");
    ///////////////////////////////////////////////
    // apply each test until seq_num_resp memory
    // requests have successfully completed
    ///////////////////////////////////////////////
    // uniform traffic
    randomUniformTest(TestCycles, 0.25);
    printStats(StatsFile);
    randomUniformTest(TestCycles, 0.5);
    printStats(StatsFile);
    randomUniformTest(TestCycles, 1.0);
    printStats(StatsFile);
    ///////////////////////////////////////////////
    // non-uniform traffic
    // p[0]             = 0.0;
    // p[1:NumMaster-1] = '{default:0.25};
    // randomNonUniformTest(TestCycles, p);
    // printStats(StatsFile);
    // p[0]             = 0.0;
    // p[1:NumMaster-1] = '{default:0.5};
    // randomNonUniformTest(TestCycles, p);
    // printStats(StatsFile);
    // p[0]             = 0.0;
    // p[1:NumMaster-1] = '{default:1.0};
    // randomNonUniformTest(TestCycles, p);
    // printStats(StatsFile);
    ///////////////////////////////////////////////
    // random permutations (no banking conflicts)
    randPermTest(TestCycles, 0.25);
    printStats(StatsFile);
    randPermTest(TestCycles, 0.5);
    printStats(StatsFile);
    randPermTest(TestCycles, 1.0);
    printStats(StatsFile);
    ///////////////////////////////////////////////
    linearRandTest(TestCycles, 0.25, 100);
    printStats(StatsFile);
    linearRandTest(TestCycles, 0.5, 100);
    printStats(StatsFile);
    linearRandTest(TestCycles, 1.0, 100);
    printStats(StatsFile);
    ///////////////////////////////////////////////
    // some special cases
    linearTest(TestCycles, 1.0);
    printStats(StatsFile);
    constantTest(TestCycles, 1.0);
    printStats(StatsFile);
    ///////////////////////////////////////////////
    end_of_sim = 1;
    $display("end test sequences");
    $display("---------------------------------------");
  end

endmodule
