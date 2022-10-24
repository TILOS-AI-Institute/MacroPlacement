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
//         Matheus Cavalcante <matheusd@iis.ee.ethz.ch>, ETH Zurich
// Date: 06.03.2019
// Description: Synthesis wrapper for variable_latency_interconnect without parameters

`include "defaults.svh"

module variable_latency_interconnect_wrap (
    input  logic                                                         clk_i,
    input  logic                                                         rst_ni,
    // Initiator side
    input  logic [`NUM_MASTER-1:0]                                       req_i,     // Request signal
    input  logic [`NUM_MASTER-1:0][`DATA_WIDTH-1:0]                      add_i,     // Target Address
    input  logic [`NUM_MASTER-1:0]                                       wen_i,     // Write enable
    input  logic [`NUM_MASTER-1:0][`DATA_WIDTH-1:0]                      wdata_i,   // Write data
    input  logic [`NUM_MASTER-1:0][`DATA_WIDTH/8-1:0]                    be_i,      // Byte enable
    output logic [`NUM_MASTER-1:0]                                       gnt_o,     // Grant signal
    output logic [`NUM_MASTER-1:0]                                       vld_o,     // Response valid
    input  logic [`NUM_MASTER-1:0]                                       rdy_i,     // Response ready
    output logic [`NUM_MASTER-1:0][`DATA_WIDTH-1:0]                      rdata_o,   // Data response (for load commands)
    // Target side
    output logic [`NUM_MASTER * `BANK_FACT-1:0]                          req_o,     // Request signal
    output logic [`NUM_MASTER * `BANK_FACT-1:0][$clog2(`NUM_MASTER)-1:0] ini_add_o, // Initiator address
    input  logic [`NUM_MASTER * `BANK_FACT-1:0]                          gnt_i,     // Grant signal
    output logic [`NUM_MASTER * `BANK_FACT-1:0][`MEM_ADDR_BITS-1:0]      add_o,     // Target address
    output logic [`NUM_MASTER * `BANK_FACT-1:0]                          wen_o,     // Write enable
    output logic [`NUM_MASTER * `BANK_FACT-1:0][`DATA_WIDTH-1:0]         wdata_o,   // Write data
    output logic [`NUM_MASTER * `BANK_FACT-1:0][`DATA_WIDTH/8-1:0]       be_o,      // Byte enable
    input  logic [`NUM_MASTER * `BANK_FACT-1:0]                          vld_i,     // Response valid
    output logic [`NUM_MASTER * `BANK_FACT-1:0]                          rdy_o,     // Response ready
    input  logic [`NUM_MASTER * `BANK_FACT-1:0][$clog2(`NUM_MASTER)-1:0] ini_add_i, // Initiator address (response)
    input  logic [`NUM_MASTER * `BANK_FACT-1:0][`DATA_WIDTH-1:0]         rdata_i    // Data response (for load commands)
  );

  if (`MUT_IMPL == 0) begin : gen_lic
    variable_latency_interconnect #(
      .NumIn        (`NUM_MASTER               ),
      .NumOut       (`NUM_MASTER * `BANK_FACT  ),
      .AddrWidth    (`DATA_WIDTH               ),
      .DataWidth    (`DATA_WIDTH               ),
      .AddrMemWidth (`MEM_ADDR_BITS            ),
      .Topology     (tcdm_interconnect_pkg::LIC)
    ) i_interco (
      .clk_i    (clk_i    ),
      .rst_ni   (rst_ni   ),
      .req_i    (req_i    ),
      .add_i    (add_i    ),
      .wen_i    (wen_i    ),
      .wdata_i  (wdata_i  ),
      .be_i     (be_i     ) ,
      .gnt_o    (gnt_o    ),
      .vld_o    (vld_o    ),
      .rdy_i    (rdy_i    ),
      .rdata_o  (rdata_o  ),
      .req_o    (req_o    ),
      .ini_add_o(ini_add_o),
      .gnt_i    (gnt_i    ),
      .add_o    (add_o    ),
      .wen_o    (wen_o    ) ,
      .wdata_o  (wdata_o  ),
      .be_o     (be_o     ),
      .vld_i    (vld_i    ),
      .rdy_o    (rdy_o    ),
      .ini_add_i(ini_add_i),
      .rdata_i  (rdata_i  )
    );
  end else if (`MUT_IMPL == 1) begin : gen_bfly_r2
    variable_latency_interconnect #(
      .NumIn        (`NUM_MASTER                 ),
      .NumOut       (`NUM_MASTER * `BANK_FACT    ),
      .AddrWidth    (`DATA_WIDTH                 ),
      .DataWidth    (`DATA_WIDTH                 ),
      .AddrMemWidth (`MEM_ADDR_BITS              ),
      .Topology     (tcdm_interconnect_pkg::BFLY2)
    ) i_interco (
      .clk_i    (clk_i    ),
      .rst_ni   (rst_ni   ),
      .req_i    (req_i    ),
      .add_i    (add_i    ),
      .wen_i    (wen_i    ),
      .wdata_i  (wdata_i  ),
      .be_i     (be_i     ) ,
      .gnt_o    (gnt_o    ),
      .vld_o    (vld_o    ),
      .rdy_i    (rdy_i    ),
      .rdata_o  (rdata_o  ),
      .req_o    (req_o    ),
      .ini_add_o(ini_add_o),
      .gnt_i    (gnt_i    ),
      .add_o    (add_o    ),
      .wen_o    (wen_o    ) ,
      .wdata_o  (wdata_o  ),
      .be_o     (be_o     ),
      .vld_i    (vld_i    ),
      .rdy_o    (rdy_o    ),
      .ini_add_i(ini_add_i),
      .rdata_i  (rdata_i  )
    );
  end else if (`MUT_IMPL == 2) begin : gen_bfly_r4
    variable_latency_interconnect #(
      .NumIn        (`NUM_MASTER                 ),
      .NumOut       (`NUM_MASTER * `BANK_FACT    ),
      .AddrWidth    (`DATA_WIDTH                 ),
      .DataWidth    (`DATA_WIDTH                 ),
      .AddrMemWidth (`MEM_ADDR_BITS              ),
      .Topology     (tcdm_interconnect_pkg::BFLY4)
    ) i_interco (
      .clk_i    (clk_i    ),
      .rst_ni   (rst_ni   ),
      .req_i    (req_i    ),
      .add_i    (add_i    ),
      .wen_i    (wen_i    ),
      .wdata_i  (wdata_i  ),
      .be_i     (be_i     ) ,
      .gnt_o    (gnt_o    ),
      .vld_o    (vld_o    ),
      .rdy_i    (rdy_i    ),
      .rdata_o  (rdata_o  ),
      .req_o    (req_o    ),
      .ini_add_o(ini_add_o),
      .gnt_i    (gnt_i    ),
      .add_o    (add_o    ),
      .wen_o    (wen_o    ) ,
      .wdata_o  (wdata_o  ),
      .be_o     (be_o     ),
      .vld_i    (vld_i    ),
      .rdy_o    (rdy_o    ),
      .ini_add_i(ini_add_i),
      .rdata_i  (rdata_i  )
    );
  end else begin: gen_unknown
    $fatal(1, "[variable_latency_interconnect_wrap] Unknown TCDM network configuration.");
  end

endmodule : variable_latency_interconnect_wrap
