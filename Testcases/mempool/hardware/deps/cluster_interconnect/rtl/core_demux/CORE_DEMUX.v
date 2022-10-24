// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

`include "parameters.v"

`define SH  1'b0
`define PE  1'b1

module CORE_DEMUX
(
    input  logic [`LOG_CLUSTER-1:0]           CLUSTER_ID,
    input  logic                              clk,
    input  logic                              rst_n,

    // xP_70 SIDE
    input  logic                              data_req_i,
    input  logic [`ADDR_WIDTH - 1:0]          data_add_i,
    input  logic                              data_type_i,
    input  logic [`DATA_WIDTH - 1:0]          data_wdata_i,
    input  logic [`BYTE_ENABLE_BIT - 1:0]     data_be_i,
    output logic                              data_gnt_o,
    output logic                              data_busy_o,
    
    input  logic                              flush_pipe,     // data_exec_cancel
    input  logic                              stall_pipe,     // data_exec_stall

    input  logic                              data_r_gnt_i,     // Data Response Grant (For LOAD/STORE commands)
    output logic                              data_r_valid_o,   // Data Response Valid (For LOAD/STORE commands)
    output logic [`DATA_WIDTH - 1:0]          data_r_rdata_o,   // Data Response DATA (For LOAD commands)
    output logic                              data_r_opc_o,     // Data Response Error

    output logic  [1:0]                       conflicts_counter_o,

    // Low Latency log interconnect SIDE
    output  logic                             data_req_o_SH,
    output  logic [`ADDR_WIDTH - 1:0]         data_add_o_SH,
    output  logic                             data_type_o_SH,
    output  logic [`DATA_WIDTH - 1:0]         data_wdata_o_SH,
    output  logic [`BYTE_ENABLE_BIT - 1:0]    data_be_o_SH,
    input   logic                             data_gnt_i_SH,
    input   logic                             data_r_valid_i_SH,
    input   logic [`DATA_WIDTH - 1:0]         data_r_rdata_i_SH,

    // Peripheral interconnect SIDE
    input   logic                             data_busy_i_PE,
    output  logic                             data_req_o_PE,
    output  logic [`ADDR_WIDTH - 1:0]         data_add_o_PE,
    output  logic                             data_type_o_PE,
    output  logic [`DATA_WIDTH - 1:0]         data_wdata_o_PE,
    output  logic [`BYTE_ENABLE_BIT - 1:0]    data_be_o_PE,
    input   logic                             data_gnt_i_PE,
    input   logic                             data_r_valid_i_PE,
    input   logic                             data_r_opc_i_PE,
    input   logic [`DATA_WIDTH - 1:0]         data_r_rdata_i_PE

);

  parameter STATE_SIZE = 5;
  parameter EMPTY_REP  = 0, WAITING_GNT_PE = 1, WAITING_END_PE = 2, HALF_REP = 3, FULL_REP = 4;

  logic [STATE_SIZE - 1:0]                                    CS, NS;

  logic [1:0]                                                 PendingCmds_d;
  logic [1:0]                                                 PendingCmds;

  logic [`ADDR_WIDTH + `DATA_WIDTH + `BYTE_ENABLE_BIT + 1:0]  BUFFER_REP [1:0];
  logic                                                       SEL;

  logic                                                       enable_0;
  logic                                                       enable_all;
  logic [`ADDR_WIDTH + `DATA_WIDTH + `BYTE_ENABLE_BIT + 1:0]  out_mux;

  logic                                                       DEST;
  logic                                                       data_dest;

  logic                                                       LocalRValid_SH;
  logic                                                       local_stall_comb;

  logic                                                       data_r_valid_o_long;
  logic [`DATA_WIDTH - 1:0]                                   data_r_rdata_o_temp;
  logic                                                       data_r_opc_o_temp;
  logic [`DATA_WIDTH - 1:0]                                   mem_data_r_rdata;
  logic                                                       mem_data_r_opc;

  logic                                                       data_busy_SH;

  logic                                                       r_data_o_SEL;

  logic [`ADDR_WIDTH - 1:0]                                   data_add_pR;
  logic                                                       data_type_pR;
  logic [`DATA_WIDTH - 1:0]                                   data_wdata_pR;
  logic [`BYTE_ENABLE_BIT - 1:0]                              data_be_pR;

  // Assignment: Common Binding
  assign data_add_o_SH   = data_add_pR;
  assign data_type_o_SH  = data_type_pR;
  assign data_wdata_o_SH = data_wdata_pR;
  assign data_be_o_SH    = data_be_pR;

  assign data_add_o_PE   = data_add_pR;
  assign data_type_o_PE  = data_type_pR;
  assign data_wdata_o_PE = data_wdata_pR;
  assign data_be_o_PE    = data_be_pR;

  assign {data_dest, data_type_pR, data_be_pR, data_add_pR, data_wdata_pR} = BUFFER_REP[0];

  assign data_r_valid_o = data_r_valid_i_PE | LocalRValid_SH | data_r_valid_o_long;

  assign local_stall_comb = data_r_gnt_i & ~(LocalRValid_SH | data_r_valid_o_long);

  assign data_busy_o = data_busy_SH | data_busy_i_PE;

  assign conflicts_counter_o[0] = data_req_o_SH & ~data_gnt_i_SH;
  assign conflicts_counter_o[1] = data_req_o_PE & ~data_gnt_i_PE;

  // address Decoding
  always_comb
  begin
    if ((data_add_i[31:28] == 4'b0001)  && (data_add_i[27:23] == CLUSTER_ID))
      DEST = `SH;
    else
      DEST = `PE;
  end
  
  always_comb
  begin: MUX_2x1
  if (SEL == 1'b0)
    out_mux = {DEST, data_type_i, data_be_i, data_add_i, data_wdata_i};
  else
    out_mux = BUFFER_REP[1];
  end

  always_ff @(posedge clk, negedge rst_n)
  begin
    if (rst_n == 1'b0)
    begin
       CS                  <= '0;
       CS[EMPTY_REP]       <= 1'b1;
       PendingCmds         <= '0;
       
       BUFFER_REP[0]       <= '0;
       BUFFER_REP[1]       <= '0;

       LocalRValid_SH      <= 1'b0;
       data_r_valid_o_long <= 1'b0;
       mem_data_r_rdata    <= '0;
       mem_data_r_opc      <= '0;
    end
    else
    begin
      CS          <= NS;
      PendingCmds <= PendingCmds_d;
       
      if (enable_0 == 1'b1)
        BUFFER_REP[0] <= out_mux;
      else;
      
      if (enable_all == 1'b1)
        BUFFER_REP[1] <= {DEST, data_type_i, data_be_i, data_add_i, data_wdata_i};
      else;
      
      if (data_req_o_SH & data_gnt_i_SH & data_dest == `SH)
        LocalRValid_SH <= 1'b1;
      else
        LocalRValid_SH <= 1'b0;
       
      if (data_r_gnt_i == 1'b0 && data_r_valid_o == 1'b1)
        data_r_valid_o_long <= 1'b1;
      else
        if (data_r_gnt_i == 1'b1 && data_r_valid_o_long == 1'b1)
          data_r_valid_o_long <= 1'b0;
        else;
       
      if (data_r_gnt_i == 1'b0 && data_r_valid_o == 1'b1 && data_r_valid_o_long == 1'b0)
      begin
        mem_data_r_rdata <= data_r_rdata_o_temp;
        mem_data_r_opc   <= data_r_opc_o_temp;
      end
      else;
    end
  end
   
  always_comb
  begin
    data_gnt_o              = 1'b0;
    data_req_o_SH           = 1'b0;
    data_req_o_PE           = 1'b0;
    r_data_o_SEL            = `SH;

    enable_0              = 1'b0;
    enable_all            = 1'b0;
    SEL                   = 1'b0;
    NS                    = CS;
    PendingCmds_d         = PendingCmds;

     case (1'b1) // synopsys parallel_case full_case
       CS[EMPTY_REP] :
	 begin
            data_gnt_o = 1'b1;
	    
            //if ((data_req_i & ~stall_pipe & ~local_stall_comb & ~flush_pipe) == 1'b1)
	    if ((data_req_i & ~stall_pipe & ~flush_pipe) == 1'b1)
              begin
		 enable_0 = 1'b1;
		 
		 if (~(data_r_gnt_i == 1'b1 & data_r_valid_o == 1'b1))
		   PendingCmds_d = PendingCmds + 1'b1;
		 else;
		 
		 NS = 'b0;
		 if (DEST == `SH)
		   NS[HALF_REP] = 1'b1;
		 else
		   NS[WAITING_GNT_PE] = 1'b1;
              end
            else
              if (data_r_gnt_i == 1'b1 & data_r_valid_o == 1'b1)
		PendingCmds_d = PendingCmds - 1'b1;
              else;
	 end
       
       CS[WAITING_GNT_PE] :
	 begin
            data_req_o_PE = 1'b1;
            r_data_o_SEL  = `PE;
	    
        if (data_gnt_i_PE == 1'b1)
        begin
          NS = 'b0;
          NS[WAITING_END_PE] = 1'b1;
        end
        else;
      end

      CS[WAITING_END_PE] :
      begin
        r_data_o_SEL = `PE;

        if (data_r_gnt_i == 1'b1 & data_r_valid_o == 1'b1)
        begin
          NS = 'b0;
          NS[EMPTY_REP] = 1'b1;
          PendingCmds_d = PendingCmds - 1'b1;
        end
        else;
      end

      CS[HALF_REP] :
      begin
        data_gnt_o    = (DEST == `SH);
        data_req_o_SH = 1'b1;

        if ((data_req_i & ~stall_pipe & ~local_stall_comb & ~flush_pipe) == 1'b1)
          if (DEST == `SH)
          begin
            if (~(data_r_gnt_i == 1'b1 & data_r_valid_o == 1'b1))
              PendingCmds_d = PendingCmds + 1'b1;
            else;

            if (data_gnt_i_SH == 1'b0)
            begin
              NS = 'b0;
              NS[FULL_REP]  = 1'b1;
              SEL           = 1'b1;
              enable_all    = 1'b1;
            end
            else
              enable_0      = 1'b1;
          end
          else
          begin
            if (data_r_gnt_i == 1'b1 & data_r_valid_o == 1'b1)
              PendingCmds_d = PendingCmds - 1'b1;
            else;

            if (data_gnt_i_SH == 1'b1)
            begin
              NS = 'b0;
              NS[EMPTY_REP] = 1'b1;
            end
            else;
          end
        else
        begin
          if (data_r_gnt_i == 1'b1 & data_r_valid_o == 1'b1)
            PendingCmds_d = PendingCmds - 1'b1;
          else;

          if (data_gnt_i_SH == 1'b1)
          begin
            NS = 'b0;
            NS[EMPTY_REP] = 1'b1;
          end
          else;
        end
      end

      CS[FULL_REP] :
      begin
        data_req_o_SH = 1'b1;

        if (data_r_gnt_i == 1'b1 & data_r_valid_o == 1'b1)
          PendingCmds_d = PendingCmds - 1'b1;
        else;

        if (data_gnt_i_SH == 1'b1)
        begin
          NS = 'b0;
          NS[HALF_REP]  = 1'b1;
          SEL           = 1'b1;
          enable_0      = 1'b1;
        end
        else;
      end
    endcase
  end

  always_comb
  begin
    if (r_data_o_SEL == `SH)
      begin
        data_r_rdata_o_temp = data_r_rdata_i_SH;
        data_r_opc_o_temp   = 1'b0;
      end
    else
      begin
        data_r_rdata_o_temp = data_r_rdata_i_PE;
        data_r_opc_o_temp   = data_r_opc_i_PE;
      end
  end

  always_comb
  begin
    if (data_r_valid_o_long == 1'b1)
      begin
        data_r_rdata_o = mem_data_r_rdata;
        data_r_opc_o   = mem_data_r_opc;
      end
    else
      begin
        data_r_rdata_o = data_r_rdata_o_temp;
        data_r_opc_o   = data_r_opc_o_temp;
      end
  end

  always_comb
  begin
    if (PendingCmds == 2'b00)
      data_busy_SH = 1'b0;
    else
      data_busy_SH = 1'b1;
  end
endmodule
