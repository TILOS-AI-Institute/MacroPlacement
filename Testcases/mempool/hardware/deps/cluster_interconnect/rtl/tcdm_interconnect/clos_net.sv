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
// Description: Clos network.

module clos_net #(
  parameter int unsigned NumIn           = 4,            // number of requestors, needs to be a power of 2
  parameter int unsigned NumOut          = 4,            // number of targets, needs to be a power of 2
  parameter int unsigned ReqDataWidth    = 32,           // word width of data
  parameter int unsigned RespDataWidth   = 32,           // word width of data
  parameter int unsigned RespLat         = 1,            // response latency of slaves
  parameter bit          WriteRespOn     = 1,            // defines whether the interconnect returns a write response
  // this detemines which clos config to use
  // 1: m=0.50*n, 2: m=1.00*n, 3: m=2.00*n,
  parameter int unsigned ClosConfig      = 2
) (
  input  logic                                  clk_i,
  input  logic                                  rst_ni,
  // master side
  input  logic [NumIn-1:0]                      req_i,     // request signal
  input  logic [NumIn-1:0][$clog2(NumOut)-1:0]  add_i,     // bank Address
  input  logic [NumIn-1:0]                      wen_i,     // 1: store, 0: load
  input  logic [NumIn-1:0][ReqDataWidth-1:0]    wdata_i,   // write data
  output logic [NumIn-1:0]                      gnt_o,     // grant (combinationally dependent on req_i and add_i)
  output logic [NumIn-1:0]                      vld_o,     // response valid, also asserted if write responses are enabled
  output logic [NumIn-1:0][RespDataWidth-1:0]   rdata_o,   // data response (for load commands)
  // slave side
  input   logic [NumOut-1:0]                    gnt_i,     // request out
  output  logic [NumOut-1:0]                    req_o,     // grant input
  output  logic [NumOut-1:0][ReqDataWidth-1:0]  wdata_o,   // write data
  input   logic [NumOut-1:0][RespDataWidth-1:0] rdata_i    // data response (for load commands)
);

// classic clos parameters, make sure they are aligned with powers of 2
// good tradeoff in terms of router complexity (with b=banking factor):  N = sqrt(NumOut / (1+1/b)))
// some values (banking factor of 2):
// 8  Banks -> N = 2,
// 16 Banks -> N = 4,
// 32 Banks -> N = 4,
// 64 Banks -> N = 8,
// 128 Banks -> N = 8,
// 256 Banks -> N = 16,
// 512 Banks -> N = 16
localparam int unsigned BankFact = NumOut/NumIn;
localparam int unsigned ClosN = 32'(tcdm_interconnect_pkg::ClosNLut[ClosConfig][$clog2(BankFact)][$clog2(NumOut)]);
localparam int unsigned ClosM = 32'(tcdm_interconnect_pkg::ClosMLut[ClosConfig][$clog2(BankFact)][$clog2(NumOut)]);
localparam int unsigned ClosR = 32'(tcdm_interconnect_pkg::ClosRLut[ClosConfig][$clog2(BankFact)][$clog2(NumOut)]);

////////////////////////////////////////////////////////////////////////
// network inter-level connections
////////////////////////////////////////////////////////////////////////

logic [NumIn-1:0][ReqDataWidth+$clog2(NumOut)-1:0] add_wdata;

logic [ClosR-1:0][ClosM-1:0]                     ingress_gnt, ingress_req;
// bank address slice for RxR routers
logic [ClosR-1:0][ClosM-1:0][$clog2(ClosR)-1:0]  ingress_add;
logic [ClosR-1:0][ClosM-1:0][ReqDataWidth+$clog2(NumOut)-1:0]   ingress_req_data;
logic [ClosR-1:0][ClosM-1:0][RespDataWidth-1:0]  ingress_resp_data;

logic [ClosM-1:0][ClosR-1:0]                     middle_gnt_out, middle_gnt_in, middle_req_out, middle_req_in;
// bank address slice for RxR routers
logic [ClosM-1:0][ClosR-1:0][$clog2(ClosR)-1:0]  middle_add_in;
// bank address slice for MxN routers
logic [ClosM-1:0][ClosR-1:0][$clog2(ClosN)-1:0]  middle_add_out;
logic [ClosM-1:0][ClosR-1:0][ReqDataWidth+$clog2(ClosN)-1:0] middle_req_data_in, middle_req_data_out;
logic [ClosM-1:0][ClosR-1:0][RespDataWidth-1:0]  middle_resp_data_out, middle_resp_data_in;

logic [ClosR-1:0][ClosM-1:0]                     egress_gnt, egress_req;
// bank address slice for MxN routers
logic [ClosR-1:0][ClosM-1:0][$clog2(ClosN)-1:0]  egress_add;
logic [ClosR-1:0][ClosM-1:0][ReqDataWidth-1:0]   egress_req_data;
logic [ClosR-1:0][ClosM-1:0][RespDataWidth-1:0]  egress_resp_data;

for (genvar k = 0; unsigned'(k) < NumIn; k++) begin : gen_cat
  assign add_wdata[k] = {add_i[k], wdata_i[k]};
end

for (genvar m = 0; unsigned'(m) < ClosM; m++) begin : gen_connect1
  for (genvar r = 0; unsigned'(r) < ClosR; r++) begin : gen_connect2
    // ingress to/from middle
    // get bank address slice for next stage (middle stage contains RxR routers)
    assign ingress_add[r][m]         = ingress_req_data[r][m][ReqDataWidth+$clog2(NumOut)-1 :
                                                              ReqDataWidth+$clog2(NumOut)-$clog2(ClosR)];
    assign middle_req_in[m][r]       = ingress_req[r][m];
    assign middle_add_in[m][r]       = ingress_add[r][m];
    // we can drop the MSBs of the address here
    assign middle_req_data_in[m][r]  = ingress_req_data[r][m][ReqDataWidth+$clog2(ClosN)-1:0];
    assign ingress_gnt[r][m]         = middle_gnt_out[m][r];
    assign ingress_resp_data[r][m]   = middle_resp_data_out[m][r];

    // middle to/from egress
    // get bank address slice for next stage (middle stage contains RxR routers)
    assign middle_add_out[m][r]      = middle_req_data_out[m][r][ReqDataWidth+$clog2(ClosN)-1 :
                                                                 ReqDataWidth];

    assign egress_req[r][m]          = middle_req_out[m][r];
    assign egress_add[r][m]          = middle_add_out[m][r];
    // we can drop the MSBs of the address here
    assign egress_req_data[r][m]     = middle_req_data_out[m][r][ReqDataWidth-1:0];
    assign middle_gnt_in[m][r]       = egress_gnt[r][m];
    assign middle_resp_data_in[m][r] = egress_resp_data[r][m];
  end
end

////////////////////////////////////////////////////////////////////////
// arbitration priorities are drawn randomly on the middle and egress
// layers. the ingress layers perform broadcasting and local round robin
// arbitration.
////////////////////////////////////////////////////////////////////////
localparam NumInNode = ClosN / BankFact;

logic [ClosR-1:0][$clog2(ClosR)-1:0] rr_mid;
logic [ClosN-1:0][$clog2(ClosM)-1:0] rr_egr;
logic [$clog2(ClosM*ClosR)-1:0]      rr;


if (ClosR > unsigned'(1)) begin : gen_rr_mid
  assign rr_mid     = {ClosR{rr[$clog2(ClosR*ClosM)-1:$clog2(ClosM)]}};
end

if (ClosM > unsigned'(1)) begin : gen_rr_egr
  assign rr_egr     = {ClosN{rr[$clog2(ClosM)-1:0]}};
end

// Although round robin arbitration works in some cases, it
// it is quite likely that it interferes with linear access patterns
// hence we use a relatively long LFSR + block cipher here to create a
// pseudo random sequence with good randomness. the block cipher layers
// are used to break shift register linearity.
lfsr #(
  .LfsrWidth(64),
  .OutWidth($clog2(ClosM*ClosR)),
  .CipherLayers(3),
  .CipherReg(1'b1)
) lfsr_i (
  .clk_i,
  .rst_ni,
  .en_i(|(gnt_i & req_o)),
  .out_o(rr)
);

////////////////////////////////////////////////////////////////////////
// crossbars
////////////////////////////////////////////////////////////////////////

for (genvar r = 0; unsigned'(r) < ClosR; r++) begin : gen_ingress
  xbar #(
    .NumIn         ( NumInNode                     ),
    .NumOut        ( ClosM                         ),
    .ReqDataWidth  ( ReqDataWidth + $clog2(NumOut) ),
    .RespDataWidth ( RespDataWidth                 ),
    .RespLat       ( RespLat                       ),
    .WriteRespOn   ( WriteRespOn                   ),
    .ExtPrio       ( 1'b0                          ),
    .BroadCastOn   ( 1'b1                          )
  ) i_ingress_node (
    .clk_i   ( clk_i                                 ),
    .rst_ni  ( rst_ni                                ),
    .req_i   ( req_i[NumInNode * r +: NumInNode]     ),
    .add_i   ( '0                                    ),// ingress nodes perform broadcast
    .wen_i   ( wen_i[NumInNode * r +: NumInNode]     ),
    .wdata_i ( add_wdata[NumInNode * r +: NumInNode] ),
    .gnt_o   ( gnt_o[NumInNode * r +: NumInNode]     ),
    .vld_o   ( vld_o[NumInNode * r +: NumInNode]     ),
    .rdata_o ( rdata_o[NumInNode * r +: NumInNode]   ),
    .rr_i    ( '0                                    ),
    .gnt_i   ( ingress_gnt[r]                        ),
    .req_o   ( ingress_req[r]                        ),
    .wdata_o ( ingress_req_data[r]                   ),
    .rdata_i ( ingress_resp_data[r]                  )
  );
end

for (genvar m = 0; unsigned'(m) < ClosM; m++) begin : gen_middle
  xbar #(
    .NumIn         ( ClosR                          ),
    .NumOut        ( ClosR                          ),
    .ReqDataWidth  ( ReqDataWidth  + $clog2(ClosN)  ),
    .RespDataWidth ( RespDataWidth                  ),
    .RespLat       ( RespLat                        ),
    .ExtPrio       ( 1'(ClosR > unsigned'(1))       )
  ) i_mid_node (
    .clk_i   ( clk_i                   ),
    .rst_ni  ( rst_ni                  ),
    .req_i   ( middle_req_in[m]        ),
    .add_i   ( middle_add_in[m]        ),
    .wen_i   ( ClosR'(0)               ),
    .wdata_i ( middle_req_data_in[m]   ),
    .gnt_o   ( middle_gnt_out[m]       ),
    .vld_o   (                         ),
    .rdata_o ( middle_resp_data_out[m] ),
    .rr_i    ( rr_mid                  ),
    .gnt_i   ( middle_gnt_in[m]        ),
    .req_o   ( middle_req_out[m]       ),
    .wdata_o ( middle_req_data_out[m]  ),
    .rdata_i ( middle_resp_data_in[m]  )
  );
end

for (genvar r = 0; unsigned'(r) < ClosR; r++) begin : gen_egress
  xbar #(
    .NumIn         ( ClosM                    ),
    .NumOut        ( ClosN                    ),
    .ReqDataWidth  ( ReqDataWidth             ),
    .RespDataWidth ( RespDataWidth            ),
    .RespLat       ( RespLat                  ),
    .ExtPrio       ( 1'(ClosM > unsigned'(1)) )
  ) i_egress_node (
    .clk_i   ( clk_i                       ),
    .rst_ni  ( rst_ni                      ),
    .req_i   ( egress_req[r]               ),
    .add_i   ( egress_add[r]               ),
    .wen_i   ( ClosM'(0)                   ),
    .wdata_i ( egress_req_data[r]          ),
    .gnt_o   ( egress_gnt[r]               ),
    .vld_o   (                             ),
    .rdata_o ( egress_resp_data[r]         ),
    .rr_i    ( rr_egr                      ),
    .gnt_i   ( gnt_i[ClosN * r +: ClosN]   ),
    .req_o   ( req_o[ClosN * r +: ClosN]   ),
    .wdata_o ( wdata_o[ClosN * r +: ClosN] ),
    .rdata_i ( rdata_i[ClosN * r +: ClosN] )
  );
end

////////////////////////////////////////////////////////////////////////
// assertions
////////////////////////////////////////////////////////////////////////

// pragma translate_off
initial begin
  // some more info for debug purposes:
  // $display("\nClos Net info:\nNumIn=%0d\nNumOut=%0d\nm=%0d\nn=%0d\nr=%0d\n", NumIn, NumOut, ClosM, ClosN, ClosR);

  // these are the LUT limits
  assert(ClosConfig <= 3 && ClosConfig >= 1) else
    $fatal(1,"Unknown clos ClosConfig.");
  assert($clog2(NumOut/NumIn) <= 4) else
    $fatal(1,"Unsupported banking factor for Clos network.");
  assert($clog2(NumOut) <= 15) else
    $fatal(1,"Unsupported NumOut parameterization for Clos network.");

  // make sure the selected config is aligned to powers of 2
  assert(2**$clog2(NumOut) == NumOut) else
    $fatal(1,"NumOut is not aligned with a power of 2.");
  assert(2**$clog2(NumIn) == NumIn) else
    $fatal(1,"NumIn is not aligned with a power of 2.");
  assert(2**$clog2(ClosN) == ClosN) else
    $fatal(1,"ClosN is not aligned with a power of 2.");
  assert(2**$clog2(ClosM) == ClosM) else
    $fatal(1,"ClosM is not aligned with a power of 2.");
  assert(2**$clog2(ClosR) == ClosR) else
    $fatal(1,"ClosR is not aligned with a power of 2.");
end
// pragma translate_on


endmodule
