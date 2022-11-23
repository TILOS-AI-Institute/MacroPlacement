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
// Description: patterns for testbench
//

  // random uniform address sequence with request probability p
  task automatic randomUniformTest(input int NumCycles, input real p);
    automatic int unsigned val;
    automatic logic [$clog2(NumBanks)+AddrWordOff+MemAddrBits-1:0] addr;
    test_name    = "random uniform";
    pReq_test[0] = p;
    nonUniform_test = 1'b0;
    maxLen_test  = 0;
    // reset the interconnect state, set number of vectors
    `APPL_WAIT_CYC(clk_i,100)
    num_cycles  = NumCycles;
    rst_ni      = 1'b0;
    wen_i       = '0;
    wdata_i     = '0;
    be_i        = '0;
    req_i       = '0;
    add_i       = '0;
    cnt_set     = '0;
    cnt_val     = '{default:0};
    `APPL_WAIT_CYC(clk_i,1)
    rst_ni      = 1'b1;
    `APPL_WAIT_CYC(clk_i,100)

    // only do reads for the moment
    repeat(NumCycles) begin
      `APPL_WAIT_CYC(clk_i,1)
      for (int m=0; m<NumMaster; m++) begin
        if (~pending_req_q[m]) begin
          // decide whether to request
          void'(randomize(val) with {val>0; val<=1000;});
          if (val <= int'(p*1000.0)) begin
            // draw random word address
            void'(randomize(addr));
            add_i[m] = addr;
            req_i[m] = 1'b1;
          end else begin
            req_i[m] = 1'b0;
          end
        end
      end
    end
    `APPL_WAIT_CYC(clk_i,1)
    req_i = '0;
    add_i = '0;
  endtask : randomUniformTest

  // random address sequence with two different request probabilities p
  task automatic randomNonUniformTest(input int NumCycles, input real p[0:NumMaster-1]);
    automatic int unsigned val;
    automatic logic [$clog2(NumBanks)+AddrWordOff+MemAddrBits-1:0] addr;
    test_name   = "random non-uniform";
    pReq_test   = p;
    nonUniform_test = 1'b1;
    maxLen_test = 0;
    // reset the interconnect state, set number of vectors
    `APPL_WAIT_CYC(clk_i,100)
    num_cycles  = NumCycles;
    rst_ni      = 1'b0;
    wen_i       = '0;
    wdata_i     = '0;
    be_i        = '0;
    req_i       = '0;
    add_i       = '0;
    cnt_set     = '0;
    cnt_val     = '{default:0};
    `APPL_WAIT_CYC(clk_i,1)
    rst_ni      = 1'b1;
    `APPL_WAIT_CYC(clk_i,100)

    // only do reads for the moment
    repeat(NumCycles) begin
      `APPL_WAIT_CYC(clk_i,1)
      for (int m=0; m<NumMaster; m++) begin
        if (~pending_req_q[m]) begin
          // decide whether to request
          void'(randomize(val) with {val>0; val<=1000;});
          if (val <= int'(p[m]*1000.0)) begin
            // draw random word address
            void'(randomize(addr));
            add_i[m] = addr;
            req_i[m] = 1'b1;
          end else begin
            req_i[m] = 1'b0;
          end
        end
      end
    end
    `APPL_WAIT_CYC(clk_i,1)
    req_i = '0;
    add_i = '0;
  endtask : randomNonUniformTest

  // linear read requests with probability p
  task automatic linearTest(input int NumCycles, input real p);
    automatic int unsigned val;
    automatic logic [$clog2(NumBanks)+AddrWordOff+MemAddrBits-1:0] addr;
    test_name    = "linear sweep";
    pReq_test[0] = p;
    nonUniform_test = 1'b0;
    maxLen_test  = 0;
    // reset the interconnect state, set number of vectors
    `APPL_WAIT_CYC(clk_i,100)
    num_cycles  = NumCycles;
    rst_ni      = 1'b0;
    wen_i       = '0;
    wdata_i     = '0;
    be_i        = '0;
    req_i       = '0;
    add_i       = '0;
    cnt_set     = '0;
    cnt_val     = '{default:0};
    `APPL_WAIT_CYC(clk_i,1)
    rst_ni      = 1'b1;
    `APPL_WAIT_CYC(clk_i,100)

    // only do reads for the moment
    repeat(NumCycles) begin
      `APPL_WAIT_CYC(clk_i,1)
      for (int m=0; m<NumMaster; m++) begin
        if (~pending_req_q[m]) begin
          // decide whether to request
          void'(randomize(val) with {val>0; val<=1000;});
          if (val <= int'(p*1000.0)) begin
            // increment address
            add_i[m] = add_i[m] + 4;
            req_i[m] = 1'b1;
          end else begin
            req_i[m] = 1'b0;
          end
        end
      end
    end
    `APPL_WAIT_CYC(clk_i,1)
    req_i = '0;
    add_i = '0;
  endtask : linearTest

  // linear read requests with random offsets and lengths with probability p
  task automatic linearRandTest(input int NumCycles, input real p, input int maxLen);
    automatic int unsigned val;
    automatic logic [$clog2(NumBanks)+AddrWordOff+MemAddrBits-1:0] addr;
    test_name    = "random linear bursts";
    pReq_test[0] = p;
    nonUniform_test = 1'b0;
    maxLen_test  = maxLen;
    // reset the interconnect state, set number of vectors
    `APPL_WAIT_CYC(clk_i,100)
    num_cycles  = NumCycles;
    rst_ni      = 1'b0;
    wen_i       = '0;
    wdata_i     = '0;
    be_i        = '0;
    req_i       = '0;
    add_i       = '0;
    cnt_set     = '0;
    cnt_val     = '{default:0};
    `APPL_WAIT_CYC(clk_i,1)
    rst_ni      = 1'b1;
    `APPL_WAIT_CYC(clk_i,100)

    // only do reads for the moment
    repeat(NumCycles) begin
      `APPL_WAIT_CYC(clk_i,1)
      for (int m=0; m<NumMaster; m++) begin
        if (~pending_req_q[m]) begin
          // decide whether to request
          void'(randomize(val) with {val>0; val<=1000;});
          if (val <= int'(p*1000.0)) begin
            if (cnt_q[m]==0) begin
              // draw random word address
              void'(randomize(addr));
              add_i[m]    = addr;
              cnt_set[m]  = 1'b1;
              void'(randomize(val) with {val>=1; val<maxLen;});
              cnt_val[m]  = val;
            end else begin
              add_i[m]    = add_i[m]+4;
              req_i[m]    = 1'b1;
              cnt_set[m]  = 1'b0;
            end
          end else begin
            req_i[m]    = 1'b0;
            cnt_set[m]  = 1'b0;
          end
        end
      end
    end
    `APPL_WAIT_CYC(clk_i,1)
    req_i = '0;
    add_i = '0;
  endtask : linearRandTest

  // constant address requests with probability p
  task automatic constantTest(input int NumCycles, input real p);
    automatic int unsigned val;
    automatic logic [$clog2(NumBanks)+AddrWordOff+MemAddrBits-1:0] addr;
    test_name    = "all-to-one";
    pReq_test[0] = p;
    nonUniform_test = 1'b0;
    maxLen_test  = 0;
    // reset the interconnect state, set number of vectors
    `APPL_WAIT_CYC(clk_i,100)
    num_cycles  = NumCycles;
    rst_ni      = 1'b0;
    wen_i       = '0;
    wdata_i     = '0;
    be_i        = '0;
    req_i       = '0;
    add_i       = '0;
    cnt_set     = '0;
    cnt_val     = '{default:0};
    `APPL_WAIT_CYC(clk_i,1)
    rst_ni      = 1'b1;
    `APPL_WAIT_CYC(clk_i,100)
    addr        = 0;
    // only do reads for the moment
    repeat(NumCycles) begin
      `APPL_WAIT_CYC(clk_i,1)
      for (int m=0; m<NumMaster; m++) begin
        if (~pending_req_q[m]) begin
          // decide whether to request
          void'(randomize(val) with {val>0; val<=1000;});
          if (val <= int'(p*1000.0)) begin
            // increment address
            add_i[m] = addr;
            req_i[m] = 1'b1;
          end else begin
            req_i[m] = 1'b0;
          end
        end
      end
    end
    `APPL_WAIT_CYC(clk_i,1)
    req_i = '0;
    add_i = '0;
  endtask : constantTest

  // random uniform address sequence with request probability p
  task automatic randPermTest(input int NumCycles, input real p);
    automatic int unsigned val;
    automatic int unsigned addr [0:NumBanks-1];
    test_name    = "random permutation test";
    pReq_test[0] = p;
    nonUniform_test = 1'b0;
    maxLen_test  = 0;
    // fill with unique bank IDs
    for (int m=0; m<NumBanks; m++) begin
      addr[m] = m<<AddrWordOff;
    end
    // reset the interconnect state, set number of vectors
    `APPL_WAIT_CYC(clk_i,100)
    num_cycles  = NumCycles;
    rst_ni      = 1'b0;
    wen_i       = '0;
    wdata_i     = '0;
    be_i        = '0;
    req_i       = '0;
    add_i       = '0;
    cnt_set     = '0;
    cnt_val     = '{default:0};
    `APPL_WAIT_CYC(clk_i,1)
    rst_ni      = 1'b1;
    `APPL_WAIT_CYC(clk_i,100)

    // only do reads for the moment
    repeat(NumCycles) begin
      `APPL_WAIT_CYC(clk_i,1)
      // draw other permutation
      addr.shuffle();
      for (int m=0; m<NumMaster; m++) begin
        // decide whether to request
        void'(randomize(val) with {val>0; val<=1000;});
        if (val <= int'(p*1000.0)) begin
          // assign permuted bank addresses
          add_i[m] = addr[m%NumBanks];
          req_i[m] = 1'b1;
        end else begin
          req_i[m] = 1'b0;
        end
      end
    end
    `APPL_WAIT_CYC(clk_i,1)
    req_i = '0;
    add_i = '0;
  endtask : randPermTest
