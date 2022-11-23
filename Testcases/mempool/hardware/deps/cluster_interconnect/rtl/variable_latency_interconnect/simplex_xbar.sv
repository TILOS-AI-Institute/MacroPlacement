// Copyright 2020 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Authors: Matheus Cavalcante <matheusd@iis.ee.ethz.ch>, ETH Zurich
//          Michael Schaffner <schaffner@iis.ee.ethz.ch>, ETH Zurich

// Date: 16.01.2020
// Description: Simplex (uni-directional) crossbar.

module simplex_xbar #(
  parameter int unsigned NumIn      = 4,    // Number of Initiators
  parameter int unsigned NumOut     = 4,    // Number of Targets
  parameter int unsigned DataWidth  = 32,   // Data Width
  parameter bit ExtPrio             = 1'b0, // Use external arbiter priority flags
  parameter bit AxiVldRdy           = 1'b0, // Valid/ready signaling.
  parameter bit SpillRegister       = 1'b0,
  parameter bit FallThroughRegister = 1'b0,
  // Dependent parameters, DO NOT OVERRIDE!
  localparam int unsigned NumInLog  = NumIn == 1 ? 1 : $clog2(NumIn),
  localparam int unsigned NumOutLog = NumOut == 1 ? 1 : $clog2(NumOut)
) (
  input  logic                             clk_i,
  input  logic                             rst_ni,
  // External priority signal
  input  logic [NumOut-1:0][NumInLog-1:0]  rr_i,
  // Initiator side
  input  logic [NumIn-1:0]                 valid_i,    // Valid signal
  output logic [NumIn-1:0]                 ready_o,    // Ready signal
  input  logic [NumIn-1:0][NumOutLog-1:0]  tgt_addr_i, // Target address
  input  logic [NumIn-1:0][DataWidth-1:0]  data_i,     // Data
  // Target side
  output logic [NumOut-1:0]                valid_o,    // Valid signal
  input  logic [NumOut-1:0]                ready_i,    // Ready signal
  output logic [NumOut-1:0][NumInLog-1:0]  ini_addr_o, // Initiator address
  output logic [NumOut-1:0][DataWidth-1:0] data_o      // Data
);

  /*************
   *   Wires   *
   *************/

  logic [NumOut-1:0][ NumIn-1:0][DataWidth-1:0] tgt_data;
  logic [NumOut-1:0][ NumIn-1:0]                tgt_ready, tgt_valid;

  logic [ NumIn-1:0][NumOut-1:0][DataWidth-1:0] ini_data;
  logic [ NumIn-1:0][NumOut-1:0]                ini_ready, ini_valid;

  logic [NumOut-1:0]                arb_valid, arb_ready;
  logic [NumOut-1:0][DataWidth-1:0] arb_data;
  logic [NumOut-1:0][NumInLog-1:0]  arb_ini_addr;

  /******************
   *   Initiators   *
   ******************/

  for (genvar j = 0; unsigned'(j) < NumIn; j++) begin: gen_inputs

    /***********************
     *   Address decoder   *
     ***********************/

    // Instantiate a bank address decoder for each initiator
    addr_decoder #(
      .NumOut   (NumOut   ),
      .DataWidth(DataWidth),
      .AxiVldRdy(AxiVldRdy)
    ) i_addr_decoder (
      // Initiator side
      .valid_i(valid_i[j]   ),
      .addr_i (tgt_addr_i[j]),
      .data_i (data_i[j]    ),
      .ready_o(ready_o[j]   ),
      // Target side
      .valid_o(ini_valid[j] ),
      .ready_i(ini_ready[j] ),
      .data_o (ini_data[j]  )
    );

    // Reshape connections between initiator and target
    for (genvar k = 0; unsigned'(k) < NumOut; k++) begin : gen_reshape
      assign tgt_valid[k][j] = ini_valid[j][k];
      assign ini_ready[j][k] = tgt_ready[k][j];
      assign tgt_data[k][j]  = ini_data[j][k] ;
    end

  end : gen_inputs

  /***************
   *   Targets   *
   ***************/

  for (genvar k = 0; k < NumOut; k++) begin: gen_rr_outputs

    /****************
     *   Arbiters   *
     ****************/

    // Instantiate an RR arbiter for each target
    rr_arb_tree #(
      .NumIn    (NumIn    ),
      .DataWidth(DataWidth),
      .ExtPrio  (ExtPrio  ),
      .AxiVldRdy(AxiVldRdy)
    ) i_rr_arb_tree (
      .clk_i  (clk_i          ),
      .rst_ni (rst_ni         ),
      .flush_i(1'b0           ),
      .rr_i   (rr_i[k]        ),
      .req_i  (tgt_valid[k]   ),
      .gnt_o  (tgt_ready[k]   ),
      .data_i (tgt_data[k]    ),
      .gnt_i  (arb_ready[k]   ),
      .req_o  (arb_valid[k]   ),
      .data_o (arb_data[k]    ),
      .idx_o  (arb_ini_addr[k])
    );

    // If not inserting spill-registers at all, or if inserting
    // a spill registers.
    if (!FallThroughRegister || SpillRegister) begin
      spill_register #(
        .Bypass(!SpillRegister               ),
        .T     (logic[DataWidth+NumInLog-1:0])
      ) i_register (
        .clk_i  (clk_i                         ),
        .rst_ni (rst_ni                        ),
        .data_i ({arb_data[k], arb_ini_addr[k]}),
        .valid_i(arb_valid[k]                  ),
        .ready_o(arb_ready[k]                  ),
        .data_o ({data_o[k], ini_addr_o[k]}    ),
        .valid_o(valid_o[k]                    ),
        .ready_i(ready_i[k]                    )
      );
    end else begin
      fall_through_register #(
        .T(logic[DataWidth+NumInLog-1:0])
      ) i_register (
        .clk_i     (clk_i                         ),
        .rst_ni    (rst_ni                        ),
        .clr_i     (1'b0                          ),
        .testmode_i(1'b0                          ),
        .data_i    ({arb_data[k], arb_ini_addr[k]}),
        .valid_i   (arb_valid[k]                  ),
        .ready_o   (arb_ready[k]                  ),
        .data_o    ({data_o[k], ini_addr_o[k]}    ),
        .valid_o   (valid_o[k]                    ),
        .ready_i   (ready_i[k]                    )
      );
    end

  end : gen_rr_outputs

  /******************
   *   Assertions   *
   ******************/

  if (NumIn <= 0)
    $fatal(1, "[simplex_xbar] NumIn needs to be larger than 0.");

  if (NumOut <= 0)
    $fatal(1, "[simplex_xbar] NumOut needs to be larger than 0.");

endmodule : simplex_xbar
