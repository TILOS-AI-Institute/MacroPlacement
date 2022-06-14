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
// Description: Synthesis wrapper for tcdm_interconnect without parameters

`include "defaults.svh"

module tcdm_interconnect_wrap (
  input  logic                                                     clk_i,
  input  logic                                                     rst_ni,
  // master side
  input  logic [`NUM_MASTER-1:0]                                   req_i,     // Request signal
  input  logic [`NUM_MASTER-1:0][`DATA_WIDTH-1:0]                  add_i,     // Address
  input  logic [`NUM_MASTER-1:0]                                   wen_i,     // 1: Store, 0: Load
  input  logic [`NUM_MASTER-1:0][`DATA_WIDTH-1:0]                  wdata_i,   // Write data
  input  logic [`NUM_MASTER-1:0][`DATA_WIDTH/8-1:0]                be_i,      // Byte enable
  output logic [`NUM_MASTER-1:0]                                   gnt_o,     // Grant (combinationally dependent on req_i and add_i)
  output logic [`NUM_MASTER-1:0]                                   vld_o,     // Response valid, also asserted if write responses are enabled
  output logic [`NUM_MASTER-1:0][`DATA_WIDTH-1:0]                  rdata_o,   // Data Response DATA (For LOAD commands)
  // slave side
  output  logic [`NUM_MASTER * `BANK_FACT-1:0]                     req_o,     // Bank request
  input   logic [`NUM_MASTER * `BANK_FACT-1:0]                     gnt_i,     // Bank grant
  output  logic [`NUM_MASTER * `BANK_FACT-1:0][`MEM_ADDR_BITS-1:0] add_o,     // Address
  output  logic [`NUM_MASTER * `BANK_FACT-1:0]                     wen_o,     // 1: Store, 0: Load
  output  logic [`NUM_MASTER * `BANK_FACT-1:0][`DATA_WIDTH-1:0]    wdata_o,   // Write data
  output  logic [`NUM_MASTER * `BANK_FACT-1:0][`DATA_WIDTH/8-1:0]  be_o,      // Byte enable
  input   logic [`NUM_MASTER * `BANK_FACT-1:0][`DATA_WIDTH-1:0]    rdata_i    // Read data
);

if (`MUT_IMPL == 0) begin : gen_lic
  tcdm_interconnect #(
    .NumIn         ( `NUM_MASTER                ),
    .NumOut        ( `NUM_MASTER * `BANK_FACT   ),
    .AddrWidth     ( `DATA_WIDTH                ),
    .DataWidth     ( `DATA_WIDTH                ),
    .AddrMemWidth  ( `MEM_ADDR_BITS             ),
    .NumPar        ( `PAR_STAGES                ),
    .Topology      ( tcdm_interconnect_pkg::LIC )
  ) i_tcdm_interconnect (
    .clk_i   ,
    .rst_ni  ,
    .req_i   ,
    .add_i   ,
    .wen_i   ,
    .wdata_i ,
    .be_i    ,
    .gnt_o   ,
    .vld_o   ,
    .rdata_o ,
    .req_o   ,
    .gnt_i   ,
    .add_o   ,
    .wen_o   ,
    .wdata_o ,
    .be_o    ,
    .rdata_i
  );
end else if (`MUT_IMPL == 1) begin : gen_bfly2
  tcdm_interconnect #(
    .NumIn         ( `NUM_MASTER                  ),
    .NumOut        ( `NUM_MASTER * `BANK_FACT     ),
    .AddrWidth     ( `DATA_WIDTH                  ),
    .DataWidth     ( `DATA_WIDTH                  ),
    .AddrMemWidth  ( `MEM_ADDR_BITS               ),
    .NumPar        ( `PAR_STAGES                  ),
    .Topology      ( tcdm_interconnect_pkg::BFLY2 )
  ) i_tcdm_interconnect (
    .clk_i   ,
    .rst_ni  ,
    .req_i   ,
    .add_i   ,
    .wen_i   ,
    .wdata_i ,
    .be_i    ,
    .gnt_o   ,
    .vld_o   ,
    .rdata_o ,
    .req_o   ,
    .gnt_i   ,
    .add_o   ,
    .wen_o   ,
    .wdata_o ,
    .be_o    ,
    .rdata_i
  );
end else if (`MUT_IMPL == 2) begin : gen_bfly4
  tcdm_interconnect #(
    .NumIn         ( `NUM_MASTER                  ),
    .NumOut        ( `NUM_MASTER * `BANK_FACT     ),
    .AddrWidth     ( `DATA_WIDTH                  ),
    .DataWidth     ( `DATA_WIDTH                  ),
    .AddrMemWidth  ( `MEM_ADDR_BITS               ),
    .NumPar        ( `PAR_STAGES                  ),
    .Topology      ( tcdm_interconnect_pkg::BFLY4 )
  ) i_tcdm_interconnect (
    .clk_i   ,
    .rst_ni  ,
    .req_i   ,
    .add_i   ,
    .wen_i   ,
    .wdata_i ,
    .be_i    ,
    .gnt_o   ,
    .vld_o   ,
    .rdata_o ,
    .req_o   ,
    .gnt_i   ,
    .add_o   ,
    .wen_o   ,
    .wdata_o ,
    .be_o    ,
    .rdata_i
  );
end else if (`MUT_IMPL == 3) begin : gen_clos_m2n
  tcdm_interconnect #(
    .NumIn         ( `NUM_MASTER                 ),
    .NumOut        ( `NUM_MASTER * `BANK_FACT    ),
    .AddrWidth     ( `DATA_WIDTH                 ),
    .DataWidth     ( `DATA_WIDTH                 ),
    .AddrMemWidth  ( `MEM_ADDR_BITS              ),
    .Topology      ( tcdm_interconnect_pkg::CLOS ),
    .ClosConfig    ( 3                           )
  ) i_tcdm_interconnect (
    .clk_i   ,
    .rst_ni  ,
    .req_i   ,
    .add_i   ,
    .wen_i   ,
    .wdata_i ,
    .be_i    ,
    .gnt_o   ,
    .vld_o   ,
    .rdata_o ,
    .req_o   ,
    .gnt_i   ,
    .add_o   ,
    .wen_o   ,
    .wdata_o ,
    .be_o    ,
    .rdata_i
  );
end else if (`MUT_IMPL == 4) begin : gen_clos_m1n
  tcdm_interconnect #(
    .NumIn         ( `NUM_MASTER                 ),
    .NumOut        ( `NUM_MASTER * `BANK_FACT    ),
    .AddrWidth     ( `DATA_WIDTH                 ),
    .DataWidth     ( `DATA_WIDTH                 ),
    .AddrMemWidth  ( `MEM_ADDR_BITS              ),
    .Topology      ( tcdm_interconnect_pkg::CLOS ),
    .ClosConfig    ( 2                           )
  ) i_tcdm_interconnect (
    .clk_i   ,
    .rst_ni  ,
    .req_i   ,
    .add_i   ,
    .wen_i   ,
    .wdata_i ,
    .be_i    ,
    .gnt_o   ,
    .vld_o   ,
    .rdata_o ,
    .req_o   ,
    .gnt_i   ,
    .add_o   ,
    .wen_o   ,
    .wdata_o ,
    .be_o    ,
    .rdata_i
  );
end else if (`MUT_IMPL == 5) begin : gen_clos_m0p5n
  tcdm_interconnect #(
    .NumIn         ( `NUM_MASTER                 ),
    .NumOut        ( `NUM_MASTER * `BANK_FACT    ),
    .AddrWidth     ( `DATA_WIDTH                 ),
    .DataWidth     ( `DATA_WIDTH                 ),
    .AddrMemWidth  ( `MEM_ADDR_BITS              ),
    .Topology      ( tcdm_interconnect_pkg::CLOS ),
    .ClosConfig    ( 1                           )
  ) i_tcdm_interconnect (
    .clk_i   ,
    .rst_ni  ,
    .req_i   ,
    .add_i   ,
    .wen_i   ,
    .wdata_i ,
    .be_i    ,
    .gnt_o   ,
    .vld_o   ,
    .rdata_o ,
    .req_o   ,
    .gnt_i   ,
    .add_o   ,
    .wen_o   ,
    .wdata_o ,
    .be_o    ,
    .rdata_i
  );
end else if (`MUT_IMPL==6)  begin : gen_lic_old
  tcdm_xbar_wrap #(
    .NumIn         ( `NUM_MASTER              ),
    .NumOut        ( `NUM_MASTER * `BANK_FACT ),
    .AddrWidth     ( `DATA_WIDTH              ),
    .DataWidth     ( `DATA_WIDTH              ),
    .AddrMemWidth  ( `MEM_ADDR_BITS           )
  ) i_tcdm_xbar_wrap (
    .clk_i   ,
    .rst_ni  ,
    .req_i   ,
    .add_i   ,
    .wen_i   ,
    .wdata_i ,
    .be_i    ,
    .gnt_o   ,
    .vld_o   ,
    .rdata_o ,
    .req_o   ,
    .gnt_i   ,
    .add_o   ,
    .wen_o   ,
    .wdata_o ,
    .be_o    ,
    .rdata_i
  );
end

endmodule
