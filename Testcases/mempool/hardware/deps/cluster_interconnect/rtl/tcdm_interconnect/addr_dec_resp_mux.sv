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
// Description: address decoder and response mux for full crossbar.

module addr_dec_resp_mux #(
    parameter int unsigned NumOut        = 32,
    parameter int unsigned ReqDataWidth  = 32,
    parameter int unsigned RespDataWidth = 32,
    parameter int unsigned RespLat       = 1,    // response latency of slaves
    parameter bit          WriteRespOn   = 1'b1, // determines whether writes should return a response or not
    parameter bit          BroadCastOn   = 1'b0  // perform broadcast
) (
  input  logic                                  clk_i,
  input  logic                                  rst_ni,
  // master side
  input  logic                                  req_i,    // request from this master
  input  logic [$clog2(NumOut)-1:0]             add_i,    // bank selection index to be decoded
  input  logic                                  wen_i,    // write enable
  input  logic [ReqDataWidth-1:0]               data_i,   // data to be transported to slaves
  output logic                                  gnt_o,    // grant to master
  output logic                                  vld_o,    // read/write response
  output logic [RespDataWidth-1:0]              rdata_o,  // read response
  // slave side
  /* verilator lint_off UNOPTFLAT */
  output logic [NumOut-1:0]                     req_o,    // request signals after decoding
  /* verilator lint_on UNOPTFLAT */
  input  logic [NumOut-1:0]                     gnt_i,    // grants from slaves
  output logic [NumOut-1:0][ReqDataWidth-1:0]   data_o,   // data to be transported to slaves
  input  logic [NumOut-1:0][RespDataWidth-1:0]  rdata_i   // read responses from slaves
);

logic [RespLat-1:0] vld_d, vld_q;

////////////////////////////////////////////////////////////////////////
// degenerate case
////////////////////////////////////////////////////////////////////////
if (NumOut == unsigned'(1)) begin : gen_one_output

  assign data_o[0] = data_i;
  assign gnt_o     = gnt_i[0];
  assign req_o[0]  = req_i;
  assign rdata_o   = rdata_i[0];
  assign vld_o     = vld_q[$high(vld_q)];

  if (RespLat > unsigned'(1)) begin : gen_lat_gt1
    assign vld_d      = {vld_q[$high(vld_q)-1:0], gnt_o & (~wen_i | WriteRespOn)};
  end else begin : gen_lat_le1
    assign vld_d      = gnt_o & (~wen_i | WriteRespOn);
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : p_reg
    if (!rst_ni) begin
      vld_q      <= '0;
    end else begin
      vld_q      <= vld_d;
    end
  end

////////////////////////////////////////////////////////////////////////
// normal case
////////////////////////////////////////////////////////////////////////
end else begin : gen_several_outputs

  // address decoder
  always_comb begin : p_addr_dec
    req_o        = '0;
    if (BroadCastOn) begin
      if (req_i) begin
        req_o      = '1;
      end
    end else begin
      req_o[add_i] = req_i;
    end
  end

  // connect data outputs
  assign data_o = {NumOut{data_i}};

  // aggregate grant signals
  assign gnt_o = |gnt_i;
  assign vld_o = vld_q[$high(vld_q)];

  // response path in case of broadcasts
  if (BroadCastOn) begin : gen_bcast
    logic [NumOut-1:0] gnt_d, gnt_q;
    logic [$clog2(NumOut)-1:0] bank_sel;

    assign gnt_d = gnt_i;

    // determine index from
    // one-hot grant vector
    lzc #(
      .WIDTH(NumOut)
    ) lzc_i (
      .in_i(gnt_q),
      .cnt_o(bank_sel),
      .empty_o()
    );

    if (RespLat > unsigned'(1)) begin : gen_lat_gt1
      logic [RespLat-2:0][$clog2(NumOut)-1:0] bank_sel_d, bank_sel_q;

      assign rdata_o = rdata_i[bank_sel_q[$high(bank_sel_q)]];
      assign vld_d   = {vld_q[$high(vld_q)-1:0], gnt_o & (~wen_i | WriteRespOn)};

      if (RespLat == unsigned'(2)) begin : gen_lat_eq2
        assign bank_sel_d = {bank_sel_q[$high(bank_sel_q)-2:0], bank_sel, bank_sel};
      end else begin : gen_lat_le2
        assign bank_sel_d = bank_sel;
      end

      always_ff @(posedge clk_i or negedge rst_ni) begin : p_reg
        if (!rst_ni) begin
          bank_sel_q <= '0;
        end else begin
          bank_sel_q <= bank_sel_d;
        end
      end

    end else begin : gen_lat_eq1
      assign rdata_o    = rdata_i[bank_sel];
      assign vld_d      = gnt_o & (~wen_i | WriteRespOn);
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : p_reg
      if (!rst_ni) begin
        gnt_q      <= '0;
        vld_q      <= '0;
      end else begin
        gnt_q      <= gnt_d;
        vld_q      <= vld_d;
      end
    end

  // non-broadcast case
  end else begin : gen_no_broadcast
    logic [RespLat-1:0][$clog2(NumOut)-1:0] bank_sel_d, bank_sel_q;

    assign rdata_o = rdata_i[bank_sel_q[$high(bank_sel_q)]];

    if (RespLat > unsigned'(1)) begin : gen_lat_gt1
      assign bank_sel_d = {bank_sel_q[$high(bank_sel_q)-1:0], add_i};
      assign vld_d      = {vld_q[$high(vld_q)-1:0], gnt_o & (~wen_i | WriteRespOn)};
    end else begin : gen_lat_le1
      assign bank_sel_d = add_i;
      assign vld_d      = gnt_o & (~wen_i | WriteRespOn);
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : p_reg
      if (!rst_ni) begin
        bank_sel_q <= '0;
        vld_q      <= '0;
      end else begin
        bank_sel_q <= bank_sel_d;
        vld_q      <= vld_d;
      end
    end
  end
end

////////////////////////////////////////////////////////////////////////
// assertions
////////////////////////////////////////////////////////////////////////

// pragma translate_off
initial begin
  assert (RespLat > 0) else
    $fatal(1,"RespLat must be greater than 0");
  assert (NumOut > 0) else
    $fatal(1,"NumOut must be greater than 0");
end
// pragma translate_on

endmodule // addr_dec_resp_mux
