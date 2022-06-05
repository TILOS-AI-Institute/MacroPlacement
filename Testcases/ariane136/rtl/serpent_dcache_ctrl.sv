// Copyright 2018 ETH Zurich and University of Bologna.
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
// Date: 13.09.2018
// Description: DCache controller for read port


import ariane_pkg::*;
import serpent_cache_pkg::*;

module serpent_dcache_ctrl #(
    parameter logic [DCACHE_ID_WIDTH-1:0] RdTxId        = 1,                // ID to use for read transactions
    parameter logic [63:0]                CachedAddrBeg = 64'h00_8000_0000, // begin of cached region
    parameter logic [63:0]                CachedAddrEnd = 64'h80_0000_0000  // end of cached region
) (
    input  logic                            clk_i,          // Clock
    input  logic                            rst_ni,         // Asynchronous reset active low
    input  logic                            cache_en_i,
    // core request ports
    input  dcache_req_i_t                   req_port_i,
    output dcache_req_o_t                   req_port_o,
    // interface to miss handler
    output logic                            miss_req_o,
    input  logic                            miss_ack_i,
    output logic                            miss_we_o,       // unused (set to 0)
    output logic [63:0]                     miss_wdata_o,    // unused (set to 0)
    output logic [DCACHE_SET_ASSOC-1:0]     miss_vld_bits_o, // valid bits at the missed index
    output logic [63:0]                     miss_paddr_o,
    output logic                            miss_nc_o,       // request to I/O space
    output logic [2:0]                      miss_size_o,     // 00: 1byte, 01: 2byte, 10: 4byte, 11: 8byte, 111: cacheline
    output logic [DCACHE_ID_WIDTH-1:0]      miss_id_o,       // set to constant ID
    input  logic                            miss_replay_i,   // request collided with pending miss - have to replay the request
    input  logic                            miss_rtrn_vld_i, // signals that the miss has been served, asserted in the same cycle as when the data returns from memory
    // used to detect readout mux collisions
    input  logic                            wr_cl_vld_i,
    // cache memory interface
    output logic [DCACHE_TAG_WIDTH-1:0]     rd_tag_o,        // tag in - comes one cycle later
    output logic [DCACHE_CL_IDX_WIDTH-1:0]  rd_idx_o,
    output logic [DCACHE_OFFSET_WIDTH-1:0]  rd_off_o,
    output logic                            rd_req_o,        // read the word at offset off_i[:3] in all ways
    output logic                            rd_tag_only_o,   // set to zero here
    input  logic                            rd_ack_i,
    input  logic [63:0]                     rd_data_i,
    input  logic [DCACHE_SET_ASSOC-1:0]     rd_vld_bits_i,
    input  logic [DCACHE_SET_ASSOC-1:0]     rd_hit_oh_i
);

    // controller FSM
    typedef enum logic[2:0] {IDLE, READ, MISS_REQ, MISS_WAIT, KILL_MISS, REPLAY_REQ, REPLAY_READ} state_t;
    state_t state_d, state_q;

    logic [DCACHE_TAG_WIDTH-1:0]    address_tag_d, address_tag_q;
    logic [DCACHE_CL_IDX_WIDTH-1:0] address_idx_d, address_idx_q;
    logic [DCACHE_OFFSET_WIDTH-1:0] address_off_d, address_off_q;
    logic [DCACHE_SET_ASSOC-1:0]    vld_data_d,    vld_data_q;
    logic save_tag, rd_req_d, rd_req_q, rd_ack_d, rd_ack_q;
    logic [1:0] data_size_d, data_size_q;

///////////////////////////////////////////////////////
// misc
///////////////////////////////////////////////////////

    // map address to tag/idx/offset and save
    assign vld_data_d    = (rd_req_q)            ? rd_vld_bits_i                                                      : vld_data_q;
    assign address_tag_d = (save_tag)            ? req_port_i.address_tag                                             : address_tag_q;
    assign address_idx_d = (req_port_o.data_gnt) ? req_port_i.address_index[DCACHE_INDEX_WIDTH-1:DCACHE_OFFSET_WIDTH] : address_idx_q;
    assign address_off_d = (req_port_o.data_gnt) ? req_port_i.address_index[DCACHE_OFFSET_WIDTH-1:0]                  : address_off_q;
    assign data_size_d   = (req_port_o.data_gnt) ? req_port_i.data_size                                               : data_size_q;
    assign rd_tag_o      = address_tag_d;
    assign rd_idx_o      = address_idx_d;
    assign rd_off_o      = address_off_d;

    assign req_port_o.data_rdata = rd_data_i;

    // to miss unit
    assign miss_vld_bits_o       = vld_data_q;
    assign miss_paddr_o          = {address_tag_q, address_idx_q, address_off_q};
    assign miss_size_o           = (miss_nc_o) ? data_size_q : 3'b111;

    assign miss_nc_o = (address_tag_q <  (CachedAddrBeg>>DCACHE_INDEX_WIDTH)) || 
                       (address_tag_q >= (CachedAddrEnd>>DCACHE_INDEX_WIDTH)) || 
                       (!cache_en_i);

    assign miss_we_o    = '0;
    assign miss_wdata_o = '0;
    assign miss_id_o    = RdTxId;
    assign rd_req_d     = rd_req_o;
    assign rd_ack_d     = rd_ack_i;
    assign rd_tag_only_o = '0;

///////////////////////////////////////////////////////
// main control logic
///////////////////////////////////////////////////////

    always_comb begin : p_fsm
        // default assignment
        state_d                = state_q;
        save_tag               = 1'b0;
        rd_req_o               = 1'b0;
        miss_req_o             = 1'b0;
        req_port_o.data_rvalid = 1'b0;
        req_port_o.data_gnt    = 1'b0;

        // interfaces
        unique case (state_q)
            //////////////////////////////////
            // wait for an incoming request
            IDLE: begin

                if (req_port_i.data_req) begin
                    rd_req_o = 1'b1;

                    if (rd_ack_i) begin
                        state_d = READ;
                        req_port_o.data_gnt = 1'b1;
                    end
                end
            end
            //////////////////////////////////
            // check whether we have a hit
            // in case the cache is disabled,
            // or in case the address is NC, we
            // reuse the miss mechanism to handle
            // the request
            READ, REPLAY_READ: begin
                // speculatively request cache line
                rd_req_o = 1'b1;

                // kill -> go back to IDLE
                if(req_port_i.kill_req) begin
                    state_d = IDLE;
                    req_port_o.data_rvalid = 1'b1;
                end else if(req_port_i.tag_valid | state_q==REPLAY_READ) begin
                    save_tag = (state_q!=REPLAY_READ);
                    if(wr_cl_vld_i | ~rd_ack_q) begin
                        state_d = REPLAY_REQ;
                    // we've got a hit
                    end else if((|rd_hit_oh_i) & cache_en_i) begin
                        state_d = IDLE;
                        req_port_o.data_rvalid = 1'b1;
                        // we can handle another request
                        if (rd_ack_i && req_port_i.data_req) begin
                            state_d = READ;
                            req_port_o.data_gnt = 1'b1;
                        end
                    // we've got a miss
                    end else begin
                        state_d = MISS_REQ;
                    end
                end
            end
            //////////////////////////////////
            // issue request
            MISS_REQ: begin
                miss_req_o = 1'b1;

                if(req_port_i.kill_req) begin
                    req_port_o.data_rvalid = 1'b1;
                    if(miss_ack_i) begin
                        state_d = KILL_MISS;
                    end else begin
                        state_d = IDLE;
                    end
                end else if(miss_replay_i) begin
                    state_d  = REPLAY_REQ;
                end else if(miss_ack_i) begin
                    state_d  = MISS_WAIT;
                end
            end
            //////////////////////////////////
            // wait until the memory transaction
            // returns.
            MISS_WAIT: begin
                if(req_port_i.kill_req) begin
                    req_port_o.data_rvalid = 1'b1;
                    if(miss_rtrn_vld_i) begin
                        state_d = IDLE;
                    end else begin
                        state_d = KILL_MISS;
                    end
                end else if(miss_rtrn_vld_i) begin
                    state_d = IDLE;
                    req_port_o.data_rvalid = 1'b1;
                end
            end
            //////////////////////////////////
            // replay read request
            REPLAY_REQ: begin
                rd_req_o = 1'b1;
                if (req_port_i.kill_req) begin
                    req_port_o.data_rvalid = 1'b1;
                    state_d = IDLE;
                end else if(rd_ack_i) begin
                    state_d = REPLAY_READ;
                end
            end
            //////////////////////////////////
            // killed miss,
            // wait until miss unit responds and
            // go back to idle
            KILL_MISS: begin
                if (miss_rtrn_vld_i) begin
                    state_d = IDLE;
                end
            end
            default: begin
                // we should never get here
                state_d = IDLE;
            end
        endcase // state_q
    end

///////////////////////////////////////////////////////
// ff's
///////////////////////////////////////////////////////

always_ff @(posedge clk_i or negedge rst_ni) begin : p_regs
    if(~rst_ni) begin
        state_q          <= IDLE;
        address_tag_q    <= '0;
        address_idx_q    <= '0;
        address_off_q    <= '0;
        vld_data_q       <= '0;
        data_size_q      <= '0;
        rd_req_q         <= '0;
        rd_ack_q         <= '0;
    end else begin
        state_q          <= state_d;
        address_tag_q    <= address_tag_d;
        address_idx_q    <= address_idx_d;
        address_off_q    <= address_off_d;
        vld_data_q       <= vld_data_d;
        data_size_q      <= data_size_d;
        rd_req_q         <= rd_req_d;
        rd_ack_q         <= rd_ack_d;
    end
end


///////////////////////////////////////////////////////
// assertions
///////////////////////////////////////////////////////

//pragma translate_off
`ifndef VERILATOR

  hot1: assert property (
      @(posedge clk_i) disable iff (~rst_ni) (~rd_ack_i) |=> cache_en_i |-> $onehot0(rd_hit_oh_i))
         else $fatal(1,"[l1 dcache ctrl] rd_hit_oh_i signal must be hot1");

   initial begin
      // assert wrong parameterizations
      assert (DCACHE_INDEX_WIDTH<=12)
        else $fatal(1,"[l1 dcache ctrl] cache index width can be maximum 12bit since VM uses 4kB pages");
   end
`endif
//pragma translate_on

endmodule // serpent_dcache_ctrl