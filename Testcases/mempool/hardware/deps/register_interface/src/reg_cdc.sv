// Copyright 2020 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Fabian Schuiki <fschuiki@iis.ee.ethz.ch>
// Florian Zaruba <zarubaf@iis.ee.ethz.ch>

module reg_cdc #(
    parameter type req_t = logic,
    parameter type rsp_t = logic
) (
    input  logic src_clk_i,
    input  logic src_rst_ni,
    input  req_t src_req_i,
    output rsp_t src_rsp_o,

    input  logic dst_clk_i,
    input  logic dst_rst_ni,
    output req_t dst_req_o,
    input  rsp_t dst_rsp_i
);

    typedef enum logic { Idle, Busy } state_e;
    state_e src_state_d, src_state_q, dst_state_d, dst_state_q;
    rsp_t dst_rsp_d, dst_rsp_q;
    logic src_req_valid, src_req_ready, src_rsp_valid, src_rsp_ready;
    logic dst_req_valid, dst_req_ready, dst_rsp_valid, dst_rsp_ready;

    logic src_ready_o;
    logic dst_valid_o;

    req_t src_req, dst_req;
    rsp_t src_rsp, dst_rsp;

    always_comb begin
        src_req = src_req_i;
        src_req.valid = 0;
        dst_req_o = dst_req;
        dst_req_o.valid = dst_valid_o;

        src_rsp_o = src_rsp;
        src_rsp_o.ready = src_ready_o;
        dst_rsp = dst_rsp_i;
        dst_rsp.ready = 0;
    end


    ///////////////////////////////
    //   CLOCK DOMAIN CROSSING   //
    ///////////////////////////////

    // Crossing for the request data from src to dst domain.
    cdc_2phase #(.T(req_t)) i_cdc_req (
        .src_rst_ni  ( src_rst_ni    ),
        .src_clk_i   ( src_clk_i     ),
        .src_data_i  ( src_req       ),
        .src_valid_i ( src_req_valid ),
        .src_ready_o ( src_req_ready ),

        .dst_rst_ni  ( dst_rst_ni    ),
        .dst_clk_i   ( dst_clk_i     ),
        .dst_data_o  ( dst_req       ),
        .dst_valid_o ( dst_req_valid ),
        .dst_ready_i ( dst_req_ready )
    );

    // Crossing for the response data from dst to src domain.
    cdc_2phase #(.T(rsp_t)) i_cdc_rsp (
        .src_rst_ni  ( dst_rst_ni    ),
        .src_clk_i   ( dst_clk_i     ),
        .src_data_i  ( dst_rsp_q     ),
        .src_valid_i ( dst_rsp_valid ),
        .src_ready_o ( dst_rsp_ready ),

        .dst_rst_ni  ( src_rst_ni    ),
        .dst_clk_i   ( src_clk_i     ),
        .dst_data_o  ( src_rsp       ),
        .dst_valid_o ( src_rsp_valid ),
        .dst_ready_i ( src_rsp_ready )
    );


    //////////////////////////////
    //   SRC DOMAIN HANDSHAKE   //
    //////////////////////////////

    // In the source domain we translate src_valid_i into a transaction on the
    // CDC into the destination domain. The FSM then transitions into a busy
    // state where it waits for a response coming back on the other CDC. Once
    // this response appears the ready bit goes high for one cycle, finishing
    // the register bus handshake.

    always_comb begin
        src_state_d = src_state_q;
        src_req_valid = 0;
        src_rsp_ready = 0;
        src_ready_o = 0;
        case (src_state_q)
            Idle: begin
                if (src_req_i.valid) begin
                    src_req_valid = 1;
                    if (src_req_ready) src_state_d = Busy;
                end
            end
            Busy: begin
                src_rsp_ready = 1;
                if (src_rsp_valid) begin
                    src_ready_o = 1;
                    src_state_d = Idle;
                end
            end
            default:;
        endcase
    end

    always_ff @(posedge src_clk_i, negedge src_rst_ni) begin
        if (!src_rst_ni)
            src_state_q <= Idle;
        else
            src_state_q <= src_state_d;
    end


    //////////////////////////////
    //   DST DOMAIN HANDSHAKE   //
    //////////////////////////////

    // In the destination domain we wait for the request data coming in on the
    // CDC domain. Once this happens we forward the request and wait for the
    // peer to acknowledge. Once acknowledged we store the response data and
    // transition into a busy state. In the busy state we send the response data
    // back to the src domain and wait for the transaction to complete.

    always_comb begin
        dst_state_d = dst_state_q;
        dst_req_ready = 0;
        dst_rsp_valid = 0;
        dst_valid_o = 0;
        dst_rsp_d = dst_rsp_q;
        case (dst_state_q)
            Idle: begin
                if (dst_req_valid) begin
                    dst_valid_o = 1;
                    if (dst_rsp_i.ready) begin
                        dst_req_ready = 1;
                        dst_rsp_d = dst_rsp;
                        dst_state_d = Busy;
                    end
                end
            end
            Busy: begin
                dst_rsp_valid = 1;
                if (dst_rsp_ready) begin
                    dst_state_d = Idle;
                end
            end
            default:;
        endcase
    end

    always_ff @(posedge dst_clk_i, negedge dst_rst_ni) begin
        if (!dst_rst_ni) begin
            dst_state_q <= Idle;
            dst_rsp_q <= '0;
        end else begin
            dst_state_q <= dst_state_d;
            dst_rsp_q <= dst_rsp_d;
        end
    end

endmodule
