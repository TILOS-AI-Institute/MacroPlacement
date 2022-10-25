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
// Description: TCDM interconnect with different network topologies. Currently
// supported are: full crossbar, radix-2/4 butterflies and clos networks.
// Note that only the full crossbar allows NumIn/NumOut configurations that are not
// aligned to a power of 2.

module tcdm_interconnect #(
  ///////////////////////////
  // global parameters
  parameter int unsigned                  NumIn           = 32,           // number of initiator ports (must be aligned with power of 2 for bfly and clos)
  parameter int unsigned                  NumOut          = 64,           // number of TCDM banks (must be aligned with power of 2 for bfly and clos)
  parameter int unsigned                  AddrWidth       = 32,           // address width on initiator side
  parameter int unsigned                  DataWidth       = 32,           // word width of data
  parameter int unsigned                  BeWidth         = DataWidth/8,  // width of corresponding byte enables
  parameter int unsigned                  AddrMemWidth    = 12,           // number of address bits per TCDM bank
  parameter bit                           WriteRespOn     = 1,            // defines whether the interconnect returns a write response
  parameter int unsigned                  RespLat         = 1,            // TCDM read latency, usually 1 cycle
  // determines the width of the byte offset in a memory word. normally this can be left at the default vaule,
  // but sometimes it needs to be overridden (e.g. when meta-data is supplied to the memory via the wdata signal).
  parameter int unsigned                  ByteOffWidth    = $clog2(DataWidth-1)-3,

  // topology can be: LIC, BFLY2, BFLY4, CLOS
  parameter tcdm_interconnect_pkg::topo_e Topology        = tcdm_interconnect_pkg::LIC,
  // number of parallel butterfly's to use, only relevant for BFLY topologies
  parameter int unsigned                  NumPar          = 1,
  // this detemines which Clos config to use, only relevant for CLOS topologies
  // 1: m=0.50*n, 2: m=1.00*n, 3: m=2.00*n
  parameter int unsigned                  ClosConfig      = 2
  ///////////////////////////
) (
  input  logic                                  clk_i,
  input  logic                                  rst_ni,
  // master side
  input  logic [NumIn-1:0]                      req_i,     // request signal
  input  logic [NumIn-1:0][AddrWidth-1:0]       add_i,     // tcdm address
  input  logic [NumIn-1:0]                      wen_i,     // 1: store, 0: load
  input  logic [NumIn-1:0][DataWidth-1:0]       wdata_i,   // write data
  input  logic [NumIn-1:0][BeWidth-1:0]         be_i,      // byte enable
  output logic [NumIn-1:0]                      gnt_o,     // grant (combinationally dependent on req_i and add_i
  output logic [NumIn-1:0]                      vld_o,     // response valid, also asserted if write responses ar
  output logic [NumIn-1:0][DataWidth-1:0]       rdata_o,   // data response (for load commands)
  // slave side
  output  logic [NumOut-1:0]                    req_o,     // request out
  input   logic [NumOut-1:0]                    gnt_i,     // grant input
  output  logic [NumOut-1:0][AddrMemWidth-1:0]  add_o,     // address within bank
  output  logic [NumOut-1:0]                    wen_o,     // write enable
  output  logic [NumOut-1:0][DataWidth-1:0]     wdata_o,   // write data
  output  logic [NumOut-1:0][BeWidth-1:0]       be_o,      // byte enable
  input   logic [NumOut-1:0][DataWidth-1:0]     rdata_i    // data response (for load commands)
);

////////////////////////////////////////////////////////////////////////
// localparams and stacking of address, wen and payload data
////////////////////////////////////////////////////////////////////////

localparam int unsigned NumOutLog2    = $clog2(NumOut);
localparam int unsigned AggDataWidth  = 1+BeWidth+AddrMemWidth+DataWidth;
logic [NumIn-1:0][AggDataWidth-1:0]  data_agg_in;
logic [NumOut-1:0][AggDataWidth-1:0] data_agg_out;
logic [NumIn-1:0][NumOutLog2-1:0] bank_sel;

for (genvar j = 0; unsigned'(j) < NumIn; j++) begin : gen_inputs
  // extract bank index
  assign bank_sel[j] = add_i[j][ByteOffWidth+NumOutLog2-1:ByteOffWidth];
  // aggregate data to be routed to slaves
  assign data_agg_in[j] = {wen_i[j], be_i[j], add_i[j][ByteOffWidth+NumOutLog2+AddrMemWidth-1:ByteOffWidth+NumOutLog2], wdata_i[j]};
end

// disaggregate data
for (genvar k = 0; unsigned'(k) < NumOut; k++) begin : gen_outputs
  assign {wen_o[k], be_o[k], add_o[k], wdata_o[k]} = data_agg_out[k];
end

////////////////////////////////////////////////////////////////////////
// tuned logarithmic interconnect architecture, based on rr_arb_tree primitives
////////////////////////////////////////////////////////////////////////
if (Topology == tcdm_interconnect_pkg::LIC) begin : gen_lic
  xbar #(
    .NumIn         ( NumIn        ),
    .NumOut        ( NumOut       ),
    .ReqDataWidth  ( AggDataWidth ),
    .RespDataWidth ( DataWidth    ),
    .RespLat       ( RespLat      ),
    .WriteRespOn   ( WriteRespOn  )
  ) i_xbar (
    .clk_i   ( clk_i        ),
    .rst_ni  ( rst_ni       ),
    .req_i   ( req_i        ),
    .add_i   ( bank_sel     ),
    .wen_i   ( wen_i        ),
    .wdata_i ( data_agg_in  ),
    .gnt_o   ( gnt_o        ),
    .rdata_o ( rdata_o      ),
    .rr_i    ( '0           ),
    .vld_o   ( vld_o        ),
    .gnt_i   ( gnt_i        ),
    .req_o   ( req_o        ),
    .wdata_o ( data_agg_out ),
    .rdata_i ( rdata_i      )
  );
////////////////////////////////////////////////////////////////////////
// butterfly network (radix 2 or 4) with parallelization option
// (NumPar>1 results in a hybrid between lic and bfly)
////////////////////////////////////////////////////////////////////////
end else if (Topology == tcdm_interconnect_pkg::BFLY2 || Topology == tcdm_interconnect_pkg::BFLY4) begin : gen_bfly
  localparam int unsigned NumPerSlice = NumIn/NumPar;
  localparam int unsigned Radix       = 2**Topology;
  logic [NumOut-1:0][NumPar-1:0][AggDataWidth-1:0]  data1;
  logic [NumOut-1:0][NumPar-1:0][DataWidth-1:0]     rdata1;
  logic [NumOut-1:0][NumPar-1:0] gnt1, req1;

  logic [NumPar-1:0][NumOut-1:0][AggDataWidth-1:0]  data1_trsp;
  logic [NumPar-1:0][NumOut-1:0][DataWidth-1:0]     rdata1_trsp;
  logic [NumPar-1:0][NumOut-1:0] gnt1_trsp, req1_trsp;

  logic [$clog2(NumIn)-1:0] rr;
  logic [NumOutLog2-1:0] rr1;

  // Although round robin arbitration works in some cases, it
  // it is quite likely that it interferes with linear access patterns
  // hence we use a relatively long LFSR + block cipher here to create a
  // pseudo random sequence with good randomness. the block cipher layers
  // are used to break shift register linearity.
  lfsr #(
    .LfsrWidth(64),
    .OutWidth($clog2(NumIn)),
    .CipherLayers(3),
    .CipherReg(1'b1)
  ) lfsr_i (
    .clk_i,
    .rst_ni,
    .en_i(|(gnt_i & req_o)),
    .out_o(rr)
  );

  // // this performs a density estimation of the lfsr output
  // // in order to assess the quality of the pseudo random sequence
  // // ideally this should be flat
  // // pragma translate_off
  // int unsigned cnt [0:NumOut-1];
  // int unsigned cycle;
  // always_ff @(posedge clk_i or negedge rst_ni) begin : p_stats
  //   if(!rst_ni) begin
  //      cnt <= '{default:0};
  //      cycle <= 0;
  //   end else begin
  //     if (|(gnt_i & req_o)) begin
  //       cnt[rr] <= cnt[rr]+1;
  //       cycle   <= cycle + 1;
  //      if ((cycle % 9500) == 0 && (cycle>0)) begin
  //         $display("------------------------");
  //         $display("--- LFSR Binning:    ---");
  //         $display("------------------------");
  //         for (int unsigned k=0; k<NumOut; k++) begin
  //           $display("Bin[%d] = %6f", k, real'(cnt[k]) / real'(cycle));
  //         end
  //         $display("------------------------");
  //       end
  //     end
  //   end
  // end
  // // pragma translate_on

  // Round Robin arbitration alternative
  // logic [NumOutLog2-1:0] rr_d, rr_q;
  // assign rr_d = (|(gnt_i & req_o)) ? rr_q + 1'b1 : rr_q;
  // assign rr = rr_q;

  // always_ff @(posedge clk_i or negedge rst_ni) begin : p_rr
  //   if(!rst_ni) begin
  //     rr_q <= '0;
  //   end else begin
  //     rr_q  <= rr_d;
  //   end
  // end


  // this sets the uppermost bits to zero in case of parallel
  // stages, since these are not needed anymore (i.e. these
  // butterfly layers are collision free and do not need
  // arbitration).
  assign rr1 = NumOutLog2'(rr[$high(rr):$clog2(NumPar)]);

  for (genvar j = 0; unsigned'(j) < NumPar; j++) begin : gen_bfly2_net
    bfly_net #(
      .NumIn         ( NumPerSlice  ),
      .NumOut        ( NumOut       ),
      .ReqDataWidth  ( AggDataWidth ),
      .RespDataWidth ( DataWidth    ),
      .RespLat       ( RespLat      ),
      .Radix         ( Radix        ),
      .WriteRespOn   ( WriteRespOn  ),
      .ExtPrio       ( 1'b1         )
    ) i_bfly_net (
      .clk_i    ( clk_i             ),
      .rst_ni   ( rst_ni            ),
      .rr_i     ( rr1               ),
      .req_i    ( req_i[j*NumPerSlice +: NumPerSlice  ]      ),
      .gnt_o    ( gnt_o[j*NumPerSlice +: NumPerSlice ]       ),
      .add_i    ( bank_sel[j*NumPerSlice +: NumPerSlice ]    ),
      .wen_i    ( wen_i[j*NumPerSlice +: NumPerSlice  ]      ),
      .wdata_i  ( data_agg_in[j*NumPerSlice +: NumPerSlice ] ),
      .rdata_o  ( rdata_o[j*NumPerSlice +: NumPerSlice ]     ),
      .vld_o    ( vld_o[j*NumPerSlice +: NumPerSlice  ]      ),
      .req_o    ( req1_trsp[j]      ),
      .gnt_i    ( gnt1_trsp[j]      ),
      .wdata_o  ( data1_trsp[j]     ),
      .rdata_i  ( rdata1_trsp[j]    )
    );
  end

  // transpose between rr arbiters and parallel butterflies
  for (genvar k = 0; unsigned'(k) < NumOut; k++) begin : gen_trsp1
    assign rdata1[k] = {NumPar{rdata_i[k]}};
    for (genvar j = 0; unsigned'(j) < NumPar; j++) begin : gen_trsp2
      // request
      assign data1[k][j] = data1_trsp[j][k];
      assign req1[k][j]  = req1_trsp[j][k];
      // return
      assign rdata1_trsp[j][k] = rdata1[k][j];
      assign gnt1_trsp[j][k]   = gnt1[k][j];
    end
  end

  if (NumPar > unsigned'(1)) begin : gen_rr_arb

    logic [$clog2(NumPar)-1:0] rr2;
    assign rr2 = $clog2(NumPar)'(rr[$clog2(NumPar)-1:0]);

    for (genvar k = 0; unsigned'(k) < NumOut; k++) begin : gen_par
      rr_arb_tree #(
        .NumIn     ( NumPar       ),
        .DataWidth ( AggDataWidth ),
        .ExtPrio   ( 1'b1         )
      ) i_rr_arb_tree (
        .clk_i   ( clk_i           ),
        .rst_ni  ( rst_ni          ),
        .flush_i ( 1'b0            ),
        .rr_i    ( rr2             ),
        .req_i   ( req1[k]         ),
        .gnt_o   ( gnt1[k]         ),
        .data_i  ( data1[k]        ),
        .gnt_i   ( gnt_i[k]        ),
        .req_o   ( req_o[k]        ),
        .data_o  ( data_agg_out[k] ),
        .idx_o   (                 )// disabled
      );
    end
  end else begin : gen_no_rr_arb
      // just connect through in this case
      assign data_agg_out = data1;
      assign req_o        = req1;
      assign gnt1         = gnt_i;
  end
  // pragma translate_off
  initial begin
    assert(NumPar >= unsigned'(1)) else
      $fatal(1,"NumPar must be greater or equal 1.");
  end
  // pragma translate_on
////////////////////////////////////////////////////////////////////////
// clos network
////////////////////////////////////////////////////////////////////////
end else if (Topology == tcdm_interconnect_pkg::CLOS) begin : gen_clos
  clos_net #(
    .NumIn         ( NumIn        ),
    .NumOut        ( NumOut       ),
    .ReqDataWidth  ( AggDataWidth ),
    .RespDataWidth ( DataWidth    ),
    .RespLat       ( RespLat      ),
    .WriteRespOn   ( WriteRespOn  ),
    .ClosConfig    ( ClosConfig   )
  ) i_clos_net (
    .clk_i    ( clk_i        ),
    .rst_ni   ( rst_ni       ),
    .req_i    ( req_i        ),
    .gnt_o    ( gnt_o        ),
    .add_i    ( bank_sel     ),
    .wen_i    ( wen_i        ),
    .wdata_i  ( data_agg_in  ),
    .rdata_o  ( rdata_o      ),
    .vld_o    ( vld_o        ),
    .req_o    ( req_o        ),
    .gnt_i    ( gnt_i        ),
    .wdata_o  ( data_agg_out ),
    .rdata_i  ( rdata_i      )
  );
////////////////////////////////////////////////////////////////////////
end else begin : gen_unknown
  // pragma translate_off
  initial begin
    $fatal(1,"Unknown TCDM configuration %d.", Topology);
  end
  // pragma translate_on
end
////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////
// assertions
////////////////////////////////////////////////////////////////////////

// pragma translate_off
initial begin
	assert(AddrMemWidth+NumOutLog2 <= AddrWidth) else
    $fatal(1,"Address not wide enough to accomodate the requested TCDM configuration.");
  assert(NumOut >= NumIn) else
    $fatal(1,"NumOut < NumIn is not supported.");
end
// pragma translate_on

endmodule // tcdm_interconnect
