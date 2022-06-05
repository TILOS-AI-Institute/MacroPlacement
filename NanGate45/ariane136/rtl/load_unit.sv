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
// Author: Florian Zaruba    <zarubaf@iis.ee.ethz.ch>, ETH Zurich
//         Michael Schaffner <schaffner@iis.ee.ethz.ch>, ETH Zurich
// Date: 15.08.2018
// Description: Load Unit, takes care of all load requests

import ariane_pkg::*;

module load_unit (
    input  logic                     clk_i,    // Clock
    input  logic                     rst_ni,   // Asynchronous reset active low
    input  logic                     flush_i,
    // load unit input port
    input  logic                     valid_i,
    input  lsu_ctrl_t                lsu_ctrl_i,
    output logic                     pop_ld_o,
    // load unit output port
    output logic                     valid_o,
    output logic [TRANS_ID_BITS-1:0] trans_id_o,
    output logic [63:0]              result_o,
    output exception_t               ex_o,
    // MMU -> Address Translation
    output logic                     translation_req_o,   // request address translation
    output logic [63:0]              vaddr_o,             // virtual address out
    input  logic [63:0]              paddr_i,             // physical address in
    input  exception_t               ex_i,                // exception which may has happened earlier. for example: mis-aligned exception
    input  logic                     dtlb_hit_i,          // hit on the dtlb, send in the same cycle as the request
    // address checker
    output logic [11:0]              page_offset_o,
    input  logic                     page_offset_matches_i,
    // D$ interface
    input dcache_req_o_t             req_port_i,
    output dcache_req_i_t            req_port_o
);
    enum logic [2:0] { IDLE, WAIT_GNT, SEND_TAG, WAIT_PAGE_OFFSET,
                       ABORT_TRANSACTION, WAIT_TRANSLATION, WAIT_FLUSH
                     } state_d, state_q;
    // in order to decouple the response interface from the request interface we need a
    // a queue which can hold all outstanding memory requests
    struct packed {
        logic [TRANS_ID_BITS-1:0] trans_id;
        logic [2:0]               address_offset;
        fu_op                     operator;
    } load_data_d, load_data_q, in_data;

    // page offset is defined as the lower 12 bits, feed through for address checker
    assign page_offset_o = lsu_ctrl_i.vaddr[11:0];
    // feed-through the virtual address for VA translation
    assign vaddr_o = lsu_ctrl_i.vaddr;
    // this is a read-only interface so set the write enable to 0
    assign req_port_o.data_we = 1'b0;
    assign req_port_o.data_wdata = '0;
    // compose the queue data, control is handled in the FSM
    assign in_data = {lsu_ctrl_i.trans_id, lsu_ctrl_i.vaddr[2:0], lsu_ctrl_i.operator};
    // output address
    // we can now output the lower 12 bit as the index to the cache
    assign req_port_o.address_index = lsu_ctrl_i.vaddr[ariane_pkg::DCACHE_INDEX_WIDTH-1:0];
    // translation from last cycle, again: control is handled in the FSM
    assign req_port_o.address_tag   = paddr_i[ariane_pkg::DCACHE_TAG_WIDTH     +
                                              ariane_pkg::DCACHE_INDEX_WIDTH-1 :
                                              ariane_pkg::DCACHE_INDEX_WIDTH];
    // directly output an exception
    assign ex_o = ex_i;

    // ---------------
    // Load Control
    // ---------------
    always_comb begin : load_control
        // default assignments
        state_d              = state_q;
        load_data_d          = load_data_q;
        translation_req_o    = 1'b0;
        req_port_o.data_req  = 1'b0;
        // tag control
        req_port_o.kill_req  = 1'b0;
        req_port_o.tag_valid = 1'b0;
        req_port_o.data_be   = lsu_ctrl_i.be;
        req_port_o.data_size = extract_transfer_size(lsu_ctrl_i.operator);
        pop_ld_o             = 1'b0;

        case (state_q)
            IDLE: begin
                // we've got a new load request
                if (valid_i) begin
                    // start the translation process even though we do not know if the addresses match
                    // this should ease timing
                    translation_req_o = 1'b1;
                    // check if the page offset matches with a store, if it does then stall and wait
                    if (!page_offset_matches_i) begin
                        // make a load request to memory
                        req_port_o.data_req = 1'b1;
                        // we got no data grant so wait for the grant before sending the tag
                        if (!req_port_i.data_gnt) begin
                            state_d = WAIT_GNT;
                        end else begin
                            if (dtlb_hit_i) begin
                                // we got a grant and a hit on the DTLB so we can send the tag in the next cycle
                                state_d = SEND_TAG;
                                pop_ld_o = 1'b1;
                            end else
                                state_d = ABORT_TRANSACTION;
                        end
                    end else begin
                        // wait for the store buffer to train and the page offset to not match anymore
                        state_d = WAIT_PAGE_OFFSET;
                    end
                end
            end

            // wait here for the page offset to not match anymore
            WAIT_PAGE_OFFSET: begin
                // we make a new request as soon as the page offset does not match anymore
                if (!page_offset_matches_i) begin
                    state_d = WAIT_GNT;
                end
            end

            // abort the previous request - free the D$ arbiter
            // we are here because of a TLB miss, we need to abort the current request and give way for the
            // PTW walker to satisfy the TLB miss
            ABORT_TRANSACTION: begin
                req_port_o.kill_req  = 1'b1;
                req_port_o.tag_valid = 1'b1;
                // redo the request by going back to the wait gnt state
                state_d = WAIT_TRANSLATION;
            end

            WAIT_TRANSLATION: begin
                translation_req_o = 1'b1;
                // we've got a hit and we can continue with the request process
                if (dtlb_hit_i)
                    state_d = WAIT_GNT;
            end

            WAIT_GNT: begin
                // keep the translation request up
                translation_req_o = 1'b1;
                // keep the request up
                req_port_o.data_req = 1'b1;
                // we finally got a data grant
                if (req_port_i.data_gnt) begin
                    // so we send the tag in the next cycle
                    if (dtlb_hit_i) begin
                        state_d = SEND_TAG;
                        pop_ld_o = 1'b1;
                    end else // should we not have hit on the TLB abort this transaction an retry later
                        state_d = ABORT_TRANSACTION;
                end
                // otherwise we keep waiting on our grant
            end
            // we know for sure that the tag we want to send is valid
            SEND_TAG: begin
                req_port_o.tag_valid = 1'b1;
                state_d = IDLE;
                // we can make a new request here if we got one
                if (valid_i) begin
                    // start the translation process even though we do not know if the addresses match
                    // this should ease timing
                    translation_req_o = 1'b1;
                    // check if the page offset matches with a store, if it does stall and wait
                    if (!page_offset_matches_i) begin
                        // make a load request to memory
                        req_port_o.data_req = 1'b1;
                        // we got no data grant so wait for the grant before sending the tag
                        if (!req_port_i.data_gnt) begin
                            state_d = WAIT_GNT;
                        end else begin
                            // we got a grant so we can send the tag in the next cycle
                            if (dtlb_hit_i) begin
                                // we got a grant and a hit on the DTLB so we can send the tag in the next cycle
                                state_d = SEND_TAG;
                                pop_ld_o = 1'b1;
                            end else // we missed on the TLB -> wait for the translation
                                state_d = ABORT_TRANSACTION;
                        end
                    end else begin
                        // wait for the store buffer to train and the page offset to not match anymore
                        state_d = WAIT_PAGE_OFFSET;
                    end
                end
                // ----------
                // Exception
                // ----------
                // if we got an exception we need to kill the request immediately
                if (ex_i.valid) begin
                    req_port_o.kill_req = 1'b1;
                end
            end

            WAIT_FLUSH: begin
                // the D$ arbiter will take care of presenting this to the memory only in case we
                // have an outstanding request
                req_port_o.kill_req  = 1'b1;
                req_port_o.tag_valid = 1'b1;
                // we've killed the current request so we can go back to idle
                state_d = IDLE;
            end

        endcase

        // we got an exception
        if (ex_i.valid && valid_i) begin
            // the next state will be the idle state
            state_d = IDLE;
            // pop load - but only if we are not getting an rvalid in here - otherwise we will over-write an incoming transaction
            if (!req_port_i.data_rvalid)
                pop_ld_o = 1'b1;
        end

        // save the load data for later usage -> we should not clutter the load_data register
        if (pop_ld_o && !ex_i.valid) begin
            load_data_d = in_data;
        end

        // if we just flushed and the queue is not empty or we are getting an rvalid this cycle wait in a extra stage
        if (flush_i) begin
            state_d = WAIT_FLUSH;
        end
    end

    // ---------------
    // Retire Load
    // ---------------
    // decoupled rvalid process
    always_comb begin : rvalid_output
        valid_o = 1'b0;
        // output the queue data directly, the valid signal is set corresponding to the process above
        trans_id_o = load_data_q.trans_id;
        // we got an rvalid and are currently not flushing and not aborting the request
        if (req_port_i.data_rvalid && state_q != WAIT_FLUSH) begin
            // we killed the request
            if(!req_port_o.kill_req)
                valid_o = 1'b1;
            // the output is also valid if we got an exception
            if (ex_i.valid)
                valid_o = 1'b1;
        end
        // an exception occurred during translation (we need to check for the valid flag because we could also get an
        // exception from the store unit)
        // exceptions can retire out-of-order -> but we need to give priority to non-excepting load and stores
        // so we simply check if we got an rvalid if so we prioritize it by not retiring the exception - we simply go for another
        // round in the load FSM
        if (valid_i && ex_i.valid && !req_port_i.data_rvalid) begin
            valid_o    = 1'b1;
            trans_id_o = lsu_ctrl_i.trans_id;
        // if we are waiting for the translation to finish do not give a valid signal yet
        end else if (state_q == WAIT_TRANSLATION) begin
            valid_o = 1'b0;
        end

    end


    // latch physical address for the tag cycle (one cycle after applying the index)
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            state_q     <= IDLE;
            load_data_q <= '0;
        end else begin
            state_q     <= state_d;
            load_data_q <= load_data_d;
        end
    end

    // ---------------
    // Sign Extend
    // ---------------
    logic [63:0] shifted_data;

    // realign as needed
    assign shifted_data   = req_port_i.data_rdata >> {load_data_q.address_offset, 3'b000};

/*  // result mux (leaner code, but more logic stages.
    // can be used instead of the code below (in between //result mux fast) if timing is not so critical)
    always_comb begin
        unique case (load_data_q.operator)
            LWU:        result_o = shifted_data[31:0];
            LHU:        result_o = shifted_data[15:0];
            LBU:        result_o = shifted_data[7:0];
            LW:         result_o = 64'(signed'(shifted_data[31:0]));
            LH:         result_o = 64'(signed'(shifted_data[15:0]));
            LB:         result_o = 64'(signed'(shifted_data[ 7:0]));
            default:    result_o = shifted_data;
        endcase
    end  */

    // result mux fast
    logic [7:0]  sign_bits;
    logic [2:0]  idx_d, idx_q;
    logic        sign_bit, signed_d, signed_q, fp_sign_d, fp_sign_q;


    // prepare these signals for faster selection in the next cycle
    assign signed_d  = load_data_d.operator inside {LW, LH, LB};
    assign fp_sign_d = load_data_d.operator inside {FLW, FLH, FLB};
    assign idx_d     = (load_data_d.operator inside {LW, FLW}) ? load_data_d.address_offset + 3 :
                       (load_data_d.operator inside {LH, FLH}) ? load_data_d.address_offset + 1 :
                                                                 load_data_d.address_offset;


    assign sign_bits = { req_port_i.data_rdata[63],
                         req_port_i.data_rdata[55],
                         req_port_i.data_rdata[47],
                         req_port_i.data_rdata[39],
                         req_port_i.data_rdata[31],
                         req_port_i.data_rdata[23],
                         req_port_i.data_rdata[15],
                         req_port_i.data_rdata[7]  };

    // select correct sign bit in parallel to result shifter above
    // pull to 0 if unsigned
    assign sign_bit       = signed_q & sign_bits[idx_q] | fp_sign_q;

    // result mux
    always_comb begin
        unique case (load_data_q.operator)
            LW, LWU, FLW:    result_o = {{32{sign_bit}}, shifted_data[31:0]};
            LH, LHU, FLH:    result_o = {{48{sign_bit}}, shifted_data[15:0]};
            LB, LBU, FLB:    result_o = {{56{sign_bit}}, shifted_data[7:0]};
            default:    result_o = shifted_data;
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : p_regs
        if (~rst_ni) begin
            idx_q     <= 0;
            signed_q  <= 0;
            fp_sign_q <= 0;
        end else begin
            idx_q     <= idx_d;
            signed_q  <= signed_d;
            fp_sign_q <= fp_sign_d;
        end
    end
    // end result mux fast

///////////////////////////////////////////////////////
// assertions
///////////////////////////////////////////////////////

//pragma translate_off
`ifndef VERILATOR
    // check invalid offsets
    addr_offset0: assert property (@(posedge clk_i) disable iff (~rst_ni)
        valid_o |->  (load_data_q.operator inside {LW, LWU}) |-> load_data_q.address_offset < 5) else $fatal (1,"invalid address offset used with {LW, LWU}");
    addr_offset1: assert property (@(posedge clk_i) disable iff (~rst_ni)
        valid_o |->  (load_data_q.operator inside {LH, LHU}) |-> load_data_q.address_offset < 7) else $fatal (1,"invalid address offset used with {LH, LHU}");
    addr_offset2: assert property (@(posedge clk_i) disable iff (~rst_ni)
        valid_o |->  (load_data_q.operator inside {LB, LBU}) |-> load_data_q.address_offset < 8) else $fatal (1,"invalid address offset used with {LB, LBU}");
`endif
//pragma translate_on

endmodule
