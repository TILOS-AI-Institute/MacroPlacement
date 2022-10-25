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

// Date: 17.01.2020

// Description: Radix-2/4 butterfly network. If parameterized to Radix-4,
// the network will be built with 4x4 xbar switchboxes, but depending on the
// amount of end-points, a Radix-2 layer will be added to accomodate non-power
// of 4 parameterizations.

// Note that additional radices would not be too difficult to add - just the mixed
// radix layers need to be written in parametric form in order to accommodate
// non-power-of-radix parameterizations.

module variable_latency_bfly_net #(
  parameter int unsigned NumIn         = 32,   // Number of Initiators. Needs to be a power of 2
  parameter int unsigned NumOut        = 32,   // Number of Targets. Needs to be a power of 2
  parameter int unsigned DataWidth     = 32,   // Request Data Width
  parameter bit ExtPrio                = 1'b0, // Use external arbiter priority flags
  parameter int unsigned Radix         = 2,    // Butterfly Radix. Currently supported: 2 or 4.
  parameter bit AxiVldRdy              = 1'b0, // Valid/ready signaling.
  parameter bit FallThroughRegister    = 1'b1,
  // Spill registers
  // A bit set at position i indicates a spill register at the i-th crossbar layer.
  // The layers are counted starting at 0 from the initiator.
  parameter logic [63:0] SpillRegister = 64'h0
) (
  input  logic                                 clk_i,
  input  logic                                 rst_ni,
  // External priority signals
  input  logic [$clog2(NumOut)-1:0]            rr_i,
  // Initiator side
  input  logic [NumIn-1:0]                     valid_i,    // Request valid
  output logic [NumIn-1:0]                     ready_o,    // Request ready
  input  logic [NumIn-1:0][$clog2(NumOut)-1:0] tgt_addr_i, // Target address
  input  logic [NumIn-1:0][DataWidth-1:0]      wdata_i,    // Data
  // Target side
  output logic [NumOut-1:0]                    valid_o,    // Request valid
  input  logic [NumOut-1:0]                    ready_i,    // Request ready
  output logic [NumOut-1:0][$clog2(NumIn)-1:0] ini_addr_o, // Initiator address
  output logic [NumOut-1:0][DataWidth-1:0]     wdata_o     // Data
);

  /****************
   *   Includes   *
   ****************/

  `include "common_cells/registers.svh"

  /*******************
   *   Network I/O   *
   *******************/

  localparam int unsigned IniAddWidth = $clog2(NumIn);
  localparam int unsigned AddWidth    = $clog2(NumOut);
  localparam int unsigned NumRouters  = NumOut/Radix;
  localparam int unsigned NumStages   = ($clog2(NumOut) + $clog2(Radix) - 1)/$clog2(Radix);
  localparam int unsigned BankFact    = NumOut/NumIn;

  // Check if the Radix-4 network needs a Radix-2 stage
  localparam bit NeedsR2Stage = (Radix == 4) && (AddWidth[0] == 1'b1);

  /* verilator lint_off UNOPTFLAT */
  logic [NumStages-1:0][NumRouters-1:0][Radix-1:0]                  router_valid_in;
  logic [NumStages-1:0][NumRouters-1:0][Radix-1:0]                  router_valid_out;
  logic [NumStages-1:0][NumRouters-1:0][Radix-1:0]                  router_ready_in;
  logic [NumStages-1:0][NumRouters-1:0][Radix-1:0]                  router_ready_out;
  logic [NumStages-1:0][NumRouters-1:0][Radix-1:0][AddWidth-1:0]    router_tgt_addr_in;
  logic [NumStages-1:0][NumRouters-1:0][Radix-1:0][AddWidth-1:0]    router_tgt_addr_out;
  logic [NumStages-1:0][NumRouters-1:0][Radix-1:0][DataWidth-1:0]   router_data_in;
  logic [NumStages-1:0][NumRouters-1:0][Radix-1:0][DataWidth-1:0]   router_data_out;
  logic [NumStages-1:0][NumRouters-1:0][Radix-1:0][IniAddWidth-1:0] router_ini_add_in;
  logic [NumStages-1:0][NumRouters-1:0][Radix-1:0][IniAddWidth-1:0] router_ini_add_out;
  /* verilator lint_on UNOPTFLAT */

  /******************************
   *   Arbitration priorities   *
   ******************************/

  // We use a round robin arbiter here

  logic [$clog2(NumOut)-1:0] rr;

  if (ExtPrio) begin : gen_ext_prio
    assign rr = rr_i ;
  end else begin : gen_no_ext_prio
    // Although round robin arbitration works in some cases, it
    // it is quite likely that it interferes with linear access patterns
    // hence we use a relatively long LFSR + block cipher here to create a
    // pseudo random sequence with good randomness. the block cipher layers
    // are used to break shift register linearity.
    /*
     // NOTE(matheusd): This is a long path. We are removing this for now.

     lfsr #(
      .LfsrWidth   (64            ),
      .OutWidth    ($clog2(NumOut)),
      .CipherLayers(3             ),
      .CipherReg   (1'b1          )
    ) lfsr_req_i (
      .clk_i (clk_i                       ),
      .rst_ni(rst_ni                      ),
      .en_i  (|(req_ready_i & req_valid_o)),
      .out_o (req_rr                      )
    );

    lfsr #(
      .LfsrWidth   (64            ),
      .OutWidth    ($clog2(NumOut)),
      .CipherLayers(3             ),
      .CipherReg   (1'b1          )
    ) lfsr_resp_i (
      .clk_i (clk_i                         ),
      .rst_ni(rst_ni                        ),
      .en_i  (|(resp_ready_i & resp_valid_o)),
      .out_o (resp_rr                       )
    );*/

    assign rr = '0;
  end

  /**************************
   *   Interstage routing   *
   **************************/

  // Inputs are on the first stage.
  // Make sure to evenly distribute masters, if BankFact > 1.
  for (genvar j = 0; j < Radix*NumRouters; j++) begin : gen_inputs
    // Leave out input connections in interleaved way until we reach the radix.
    if (BankFact < Radix) begin : gen_interleaved
      if ((j % BankFact) == 0) begin : gen_connect
        assign router_valid_in[0][j/Radix][j%Radix]    = valid_i[j/BankFact]                  ;
        assign ready_o[j/BankFact]                     = router_ready_out[0][j/Radix][j%Radix];
        assign router_tgt_addr_in[0][j/Radix][j%Radix] = tgt_addr_i[j/BankFact]               ;
        assign router_data_in[0][j/Radix][j%Radix]     = wdata_i[j/BankFact]                  ;
        assign router_ini_add_in[0][j/Radix][j%Radix]  = j/BankFact                           ; // Constant
      end else begin : gen_tie_off
        assign router_valid_in[0][j/Radix][j%Radix]    = 1'b0;
        assign router_ini_add_in[0][j/Radix][j%Radix]  = '0  ;
        assign router_tgt_addr_in[0][j/Radix][j%Radix] = '0  ;
        assign router_data_in[0][j/Radix][j%Radix]     = '0  ;
      end
    // We only enter this case if each input switchbox has 1 or zero connections.
    // Only connect to lower portion of switchboxes and tie off upper portion. This allows
    // us to reduce arbitration conflicts on the first network layers.
    end else begin : gen_linear
      if (((j % Radix) == 0) && (j/Radix < NumIn)) begin : gen_connect
        assign router_valid_in[0][j/Radix][j%Radix]    = valid_i[j/Radix]                     ;
        assign router_ini_add_in[0][j/Radix][j%Radix]  = j/Radix                              ;
        assign ready_o[j/Radix]                        = router_ready_out[0][j/Radix][j%Radix];
        assign router_tgt_addr_in[0][j/Radix][j%Radix] = tgt_addr_i[j/Radix]                  ;
        assign router_data_in[0][j/Radix][j%Radix]     = wdata_i[j/Radix]                     ;
      end else begin : gen_tie_off
        assign router_valid_in[0][j/Radix][j%Radix]    = 1'b0;
        assign router_ini_add_in[0][j/Radix][j%Radix]  = '0  ;
        assign router_tgt_addr_in[0][j/Radix][j%Radix] = '0  ;
        assign router_data_in[0][j/Radix][j%Radix]     = '0  ;
      end
    end
  end

  // Outputs are on the last stage.
  for (genvar j = 0; j < Radix*NumRouters; j++) begin : gen_outputs
    if (j < NumOut) begin : gen_connect
      assign valid_o[j]                                     = router_valid_out[NumStages-1][j/Radix][j%Radix]  ;
      assign ini_addr_o[j]                                  = router_ini_add_out[NumStages-1][j/Radix][j%Radix];
      assign router_ready_in[NumStages-1][j/Radix][j%Radix] = ready_i[j]                                       ;
      assign wdata_o[j]                                     = router_data_out[NumStages-1][j/Radix][j%Radix]   ;
    end else begin : gen_tie_off
      assign router_ready_in[NumStages-1][j/Radix][j%Radix] = '1;
    end
  end

  // Wire up connections between Stages
  for (genvar l = 0; l < NumStages-1; l++) begin : gen_stages
    // Do we need to add a Radix-2?
    if (l == 0 && NeedsR2Stage) begin : gen_r4r2_stage
      localparam int unsigned pow = 2*Radix**(NumStages-l-2);

      for (genvar r = 0; r < 2*NumRouters; r++) begin : gen_routers
        for (genvar s = 0; s < 2; s++) begin : gen_ports
          localparam int unsigned k = pow * s + (r % pow) + (r / pow / 2) * pow * 2;
          localparam int unsigned j = (r / pow) % 2                                ;

          assign router_valid_in[l+1][k/2][(k%2)*2+j]    = router_valid_out[l][r/2][(r%2)*2+s]   ;
          assign router_ini_add_in[l+1][k/2][(k%2)*2+j]  = router_ini_add_out[l][r/2][(r%2)*2+s] ;
          assign router_tgt_addr_in[l+1][k/2][(k%2)*2+j] = router_tgt_addr_out[l][r/2][(r%2)*2+s];
          assign router_data_in[l+1][k/2][(k%2)*2+j]     = router_data_out[l][r/2][(r%2)*2+s]    ;
          assign router_ready_in[l][r/2][(r%2)*2+s]      = router_ready_out[l+1][k/2][(k%2)*2+j] ;
        end
      end
    end else begin : gen_std_stage
      localparam int unsigned pow = Radix**(NumStages-l-2);

      for (genvar s = 0; unsigned'(s) < Radix; s++) begin : gen_routers
        for (genvar r = 0; unsigned'(r) < NumRouters; r++) begin : gen_ports
          localparam int unsigned k = pow * s + (r % pow) + (r / pow / Radix) * pow * Radix;
          localparam int unsigned j = (r / pow) % Radix                                    ;

          assign router_valid_in[l+1][k][j]    = router_valid_out[l][r][s]   ;
          assign router_ini_add_in[l+1][k][j]  = router_ini_add_out[l][r][s] ;
          assign router_tgt_addr_in[l+1][k][j] = router_tgt_addr_out[l][r][s];
          assign router_data_in[l+1][k][j]     = router_data_out[l][r][s]    ;
          assign router_ready_in[l][r][s]      = router_ready_out[l+1][k][j] ;
        end
      end
    end
  end

  /*****************
   *   Crossbars   *
   *****************/

  logic [NumStages-1:0][NumRouters-1:0][Radix-1:0][AddWidth+IniAddWidth+DataWidth-1:0] data_in, data_out;

  for (genvar l = 0; l < NumStages; l++) begin : gen_routers1
    for (genvar r = 0; r < NumRouters; r++) begin: gen_routers2

      // Do we need to add a Radix-2 stage?
      if (l == 0 && NeedsR2Stage) begin : gen_r4r2_stage
        logic [NumStages-1:0][NumRouters-1:0][Radix-1:0][0:0] add ;
        logic [NumStages-1:0][NumRouters-1:0][Radix-1:0][0:0] prio;

        for (genvar k = 0; k < Radix; k++) begin : gen_map
          assign add[l][r][k]                                                                          = router_tgt_addr_in[l][r][k][AddWidth-1]                                              ;
          assign data_in[l][r][k]                                                                      = {router_tgt_addr_in[l][r][k]<<1, router_ini_add_in[l][r][k], router_data_in[l][r][k]};
          assign {router_tgt_addr_out[l][r][k], router_ini_add_out[l][r][k], router_data_out[l][r][k]} = data_out[l][r][k]                                                                    ;
          assign prio[l][r][k]                                                                         = rr[$clog2(NumOut)-1]                                                                 ;
        end

        for (genvar k = 0; k < 2; k++) begin: gen_xbar
          simplex_xbar #(
            .NumIn              (2                                 ),
            .NumOut             (2                                 ),
            .DataWidth          (AddWidth + IniAddWidth + DataWidth),
            .ExtPrio            (ExtPrio                           ),
            .AxiVldRdy          (AxiVldRdy                         ),
            .SpillRegister      (SpillRegister[l]                  ),
            .FallThroughRegister(FallThroughRegister               )
          ) i_xbar (
            .clk_i     (clk_i                           ),
            .rst_ni    (rst_ni                          ),
            // External priority flags
            .rr_i      (prio[l][r][k*2 +: 2]            ),
            // Initiator side
            .valid_i   (router_valid_in[l][r][k*2 +: 2] ),
            .ready_o   (router_ready_out[l][r][k*2 +: 2]),
            .tgt_addr_i(add[l][r][k*2 +: 2]             ),
            .data_i    (data_in[l][r][k*2 +: 2]         ),
            // Target side
            .valid_o   (router_valid_out[l][r][k*2 +: 2]),
            .ini_addr_o(/* Unused */                    ),
            .ready_i   (router_ready_in[l][r][k*2 +: 2] ),
            .data_o    (data_out[l][r][k*2 +: 2]        )
          );
        end

      // Instantiate switchbox of the chosen Radix.
      end else begin : gen_std_stage
        logic [NumStages-1:0][NumRouters-1:0][Radix-1:0][$clog2(Radix)-1:0] add ;
        logic [NumStages-1:0][NumRouters-1:0][Radix-1:0][$clog2(Radix)-1:0] prio;

        for (genvar k = 0; k < Radix; k++) begin : gen_map
          assign add[l][r][k]                                                                          = router_tgt_addr_in[l][r][k][AddWidth-1 -: $clog2(Radix)]                                         ;
          assign data_in[l][r][k]                                                                      = {router_tgt_addr_in[l][r][k]<<$clog2(Radix), router_ini_add_in[l][r][k], router_data_in[l][r][k]};
          assign {router_tgt_addr_out[l][r][k], router_ini_add_out[l][r][k], router_data_out[l][r][k]} = data_out[l][r][k]                                                                                ;

          // depending on where the requests are connected in the radix 4 case, we have to flip the priority vector
          // this is needed because one of the bits may be constantly set to zero
          if (BankFact < Radix) begin : gen_reverse
            for (genvar j = 0; unsigned'(j) < $clog2(Radix); j++) begin : gen_connect
              assign prio[l][r][k][$clog2(Radix)-1-j] = rr[$clog2(NumOut)-(unsigned'(l)+1-32'(NeedsR2Stage))*$clog2(Radix)-32'(NeedsR2Stage) + unsigned'(j)] ;
            end
          end else begin : gen_no_reverse
            for (genvar j = 0; unsigned'(j) < $clog2(Radix); j++) begin : gen_connect
              assign prio[l][r][k][j] = rr[$clog2(NumOut)-(unsigned'(l)+1-32'(NeedsR2Stage))*$clog2(Radix)-32'(NeedsR2Stage) + unsigned'(j)] ;
            end
          end
        end

        simplex_xbar #(
          .NumIn              (Radix                             ),
          .NumOut             (Radix                             ),
          .DataWidth          (AddWidth + IniAddWidth + DataWidth),
          .ExtPrio            (ExtPrio                           ),
          .AxiVldRdy          (AxiVldRdy                         ),
          .SpillRegister      (SpillRegister[l]                  ),
          .FallThroughRegister(FallThroughRegister               )
        ) i_xbar (
          .clk_i     (clk_i                 ),
          .rst_ni    (rst_ni                ),
          // External priority flags
          .rr_i      (prio[l][r]            ),
          // Initiator side
          .valid_i   (router_valid_in[l][r] ),
          .ready_o   (router_ready_out[l][r]),
          .tgt_addr_i(add[l][r]             ),
          .data_i    (data_in[l][r]         ),
          // Target side
          .valid_o   (router_valid_out[l][r]),
          .ini_addr_o(/* Unused */          ),
          .ready_i   (router_ready_in[l][r] ),
          .data_o    (data_out[l][r]        )
        );

      end
    end
  end

  /******************
   *   Assertions   *
   ******************/

  if (!(Radix == 2 || Radix == 4))
    $fatal(1, "[variable_latency_bfly_net] Only Radix-2 and Radix-4 are supported.");

  if (2**$clog2(NumIn) != NumIn)
    $fatal(1, "[variable_latency_bfly_net] NumIn is not aligned with a power of 2.");

  if (2**$clog2(NumOut) != NumOut)
    $fatal(1, "[variable_latency_bfly_net] NumOut is not aligned with a power of 2.");

  if (NumOut < NumIn)
    $fatal(1, "[variable_latency_bfly_net] NumOut < NumIn is not supported.");

endmodule : variable_latency_bfly_net
