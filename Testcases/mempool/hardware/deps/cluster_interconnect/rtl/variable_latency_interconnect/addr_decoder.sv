// Copyright 2020 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Author: Michael Schaffner <schaffner@iis.ee.ethz.ch>, ETH Zurich
//         Matheus Cavalcante <matheusd@iis.ee.ethz.ch>, ETH Zurich

// Date: 12.02.2020

// Description: Address decoder for the simplex crossbar.

module addr_decoder #(
  parameter int unsigned NumOut    = 32,
  parameter int unsigned DataWidth = 32,
  parameter bit AxiVldRdy          = 1'b1,
  // Dependent parameters, DO NOT OVERRIDE!
  localparam int unsigned NumOutLog = NumOut == 1 ? 1 : $clog2(NumOut)
) (
  // Initiator side
  input  logic                             valid_i, // Request valid from this initiator
  input  logic [NumOutLog-1:0]             addr_i,  // Target selection index to be decoded
  input  logic [DataWidth-1:0]             data_i,  // Data to be transported to the targets
  output logic                             ready_o, // Ready to the initiator
  // Target side
  output logic [NumOut-1:0]                valid_o, // Request valid to this target
  input  logic [NumOut-1:0]                ready_i, // Targets ready to accept data
  output logic [NumOut-1:0][DataWidth-1:0] data_o
);

  /**********************
   *  Degenerated case  *
   **********************/

  if (NumOut == 1) begin: gen_one_output
    assign valid_o[0] = valid_i   ;
    assign ready_o    = ready_i[0];
    assign data_o[0]  = data_i    ;
  end

  /*****************
   *  Normal case  *
   *****************/

  else begin: gen_several_outputs
    // Address decoder
    always_comb begin : p_addr_decoder
      valid_o         = '0     ;
      valid_o[addr_i] = valid_i;
    end

    // Broadcast data outputs
    assign data_o = {NumOut{data_i}};

    if (AxiVldRdy)
      // Demux ready signal
      assign ready_o = ready_i[addr_i];
    else
      // Aggregate grant signals
      assign ready_o = |ready_i;
  end

  /****************
   *  Assertions  *
   ****************/

  if (NumOut <= 0)
    $fatal(1, "[addr_decoder] NumOut must be greater than 0.");

endmodule : addr_decoder
