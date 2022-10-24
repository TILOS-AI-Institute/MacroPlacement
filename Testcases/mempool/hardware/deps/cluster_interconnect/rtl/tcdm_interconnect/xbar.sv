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
// Date: 07.03.2019
// Description: Full crossbar, implemented as logarithmic interconnect.

module xbar #(
  parameter int unsigned NumIn           = 4,    // number of requestors
  parameter int unsigned NumOut          = 4,    // number of targets
  parameter int unsigned ReqDataWidth    = 32,   // word width of data
  parameter int unsigned RespDataWidth   = 32,   // word width of data
  parameter int unsigned RespLat         = 1,    // response latency of slaves
  parameter bit          WriteRespOn     = 1'b1, // defines whether the interconnect returns a write response
  parameter bit          BroadCastOn     = 1'b0, // perform broadcast
  parameter bit          ExtPrio         = 1'b0  // use external arbiter priority flags
) (
  input  logic                                  clk_i,
  input  logic                                  rst_ni,
  // external prio flag input
  input  logic [NumOut-1:0][$clog2(NumIn)-1:0]  rr_i,      // external prio input
  // master side
  input  logic [NumIn-1:0]                      req_i,     // request signal
  input  logic [NumIn-1:0][$clog2(NumOut)-1:0]  add_i,     // bank Address
  input  logic [NumIn-1:0]                      wen_i,     // 1: store, 0: load
  input  logic [NumIn-1:0][ReqDataWidth-1:0]    wdata_i,   // write data
  output logic [NumIn-1:0]                      gnt_o,     // grant (combinationally dependent on req_i and add_i)
  output logic [NumIn-1:0]                      vld_o,     // response valid, also asserted if write responses are enabled
  output logic [NumIn-1:0][RespDataWidth-1:0]   rdata_o,   // data response (for load commands)
  // slave side
  input  logic [NumOut-1:0]                     gnt_i,     // request out
  output logic [NumOut-1:0]                     req_o,     // grant input
  /* verilator lint_off UNOPTFLAT */
  output logic [NumOut-1:0][ReqDataWidth-1:0]   wdata_o,   // write data
  /* verilator lint_on UNOPTFLAT */
  input  logic [NumOut-1:0][RespDataWidth-1:0]  rdata_i    // data response (for load commands)
);

////////////////////////////////////////////////////////////////////////
// inter-level wires
////////////////////////////////////////////////////////////////////////

logic [NumOut-1:0][NumIn-1:0][ReqDataWidth-1:0] sl_data;
logic [NumIn-1:0][NumOut-1:0][ReqDataWidth-1:0] ma_data;
logic [NumOut-1:0][NumIn-1:0] sl_gnt, sl_req;
logic [NumIn-1:0][NumOut-1:0] ma_gnt, ma_req;

////////////////////////////////////////////////////////////////////////
// instantiate bank address decoder/resp mux for each master
////////////////////////////////////////////////////////////////////////
for (genvar j = 0; unsigned'(j) < NumIn; j++) begin : gen_inputs
  addr_dec_resp_mux #(
    .NumOut        ( NumOut        ),
    .ReqDataWidth  ( ReqDataWidth  ),
    .RespDataWidth ( RespDataWidth ),
    .RespLat       ( RespLat       ),
    .BroadCastOn   ( BroadCastOn   ),
    .WriteRespOn   ( WriteRespOn   )
  ) i_addr_dec_resp_mux (
    .clk_i   ( clk_i      ),
    .rst_ni  ( rst_ni     ),
    .req_i   ( req_i[j]   ),
    .add_i   ( add_i[j]   ),
    .wen_i   ( wen_i[j]   ),
    .data_i  ( wdata_i[j] ),
    .gnt_o   ( gnt_o[j]   ),
    .vld_o   ( vld_o[j]   ),
    .rdata_o ( rdata_o[j] ),
    .req_o   ( ma_req[j]  ),
    .gnt_i   ( ma_gnt[j]  ),
    .data_o  ( ma_data[j] ),
    .rdata_i ( rdata_i    )
  );

  // reshape connections between M/S
  for (genvar k = 0; unsigned'(k) < NumOut; k++) begin : gen_reshape
    assign sl_req[k][j]  = ma_req[j][k];
    assign ma_gnt[j][k]  = sl_gnt[k][j];
    assign sl_data[k][j] = ma_data[j][k];
  end
end

////////////////////////////////////////////////////////////////////////
// instantiate an RR arbiter for each endpoint
////////////////////////////////////////////////////////////////////////
for (genvar k = 0; unsigned'(k) < NumOut; k++) begin : gen_outputs
  if (NumIn == unsigned'(1)) begin
    assign req_o[k]      = sl_req[k][0];
    assign sl_gnt[k][0]  = gnt_i[k];
    assign wdata_o[k]    = sl_data[k][0];
  end else begin : gen_rr_arb_tree
    rr_arb_tree #(
      .NumIn     ( NumIn        ),
      .DataWidth ( ReqDataWidth ),
      .ExtPrio   ( ExtPrio      )
    ) i_rr_arb_tree (
      .clk_i   ( clk_i      ),
      .rst_ni  ( rst_ni     ),
      .flush_i ( 1'b0       ),
      .rr_i    ( rr_i[k]    ),
      .req_i   ( sl_req[k]  ),
      .gnt_o   ( sl_gnt[k]  ),
      .data_i  ( sl_data[k] ),
      .gnt_i   ( gnt_i[k]   ),
      .req_o   ( req_o[k]   ),
      .data_o  ( wdata_o[k] ),
      .idx_o   (            )// disabled
    );
  end
end

////////////////////////////////////////////////////////////////////////
// assertion
////////////////////////////////////////////////////////////////////////

// pragma translate_off
initial begin
  assert(NumIn > 0) else
    $fatal(1,"NumIn needs to be larger than 0.");
  assert(NumOut > 0) else
    $fatal(1,"NumOut needs to be larger than 0.");
end
// pragma translate_on

endmodule // xbar
