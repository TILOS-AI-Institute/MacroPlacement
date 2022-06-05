// Copyright 2021 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

`include "common_cells/registers.svh"

module ctrl_registers #(
  parameter int DataWidth                      = 32,
  parameter int NumRegs                        = 0,
  // Parameters
  parameter logic [DataWidth-1:0] TCDMBaseAddr = 0,
  parameter logic [DataWidth-1:0] TCDMSize     = 0,
  parameter logic [DataWidth-1:0] NumCores     = 0,
  // AXI Structs
  parameter type axi_lite_req_t                = logic,
  parameter type axi_lite_resp_t               = logic
) (
  input  logic                           clk_i,
  input  logic                           rst_ni,
  // AXI Bus
  input  axi_lite_req_t                  axi_lite_slave_req_i,
  output axi_lite_resp_t                 axi_lite_slave_resp_o,
  // Control registers
  output logic      [DataWidth-1:0]      eoc_o,
  output logic                           eoc_valid_o,
  output logic      [NumCores-1:0]       wake_up_o,
  output logic      [DataWidth-1:0]      tcdm_start_address_o,
  output logic      [DataWidth-1:0]      tcdm_end_address_o,
  output logic      [DataWidth-1:0]      num_cores_o
);

  import mempool_pkg::*;

  /*****************
   *  Definitions  *
   *****************/

  localparam int unsigned DataWidthInBytes = (DataWidth + 7) / 8;
  localparam int unsigned RegNumBytes      = NumRegs * DataWidthInBytes;
  localparam int unsigned RegDataWidth     = NumRegs * DataWidth;

  localparam logic [DataWidthInBytes-1:0] ReadOnlyReg  = {DataWidthInBytes{1'b1}};
  localparam logic [DataWidthInBytes-1:0] ReadWriteReg = {DataWidthInBytes{1'b0}};

  // Memory map
  // [3:0]:  eoc_reg                        (rw)
  // [7:4]:  wake_up_reg                    (rw)
  // [11:8]: tcdm_start_adress_reg          (ro)
  // [15:12]:tcdm_end_address_reg           (ro)
  // [19:16]:nr_cores_address_reg           (ro)
  localparam logic [NumRegs-1:0][DataWidth-1:0] RegRstVal = '{
    NumCores,
    TCDMBaseAddr + TCDMSize,
    TCDMBaseAddr,
    {DataWidth{1'b0}},
    {DataWidth{1'b0}}
  };
  localparam logic [NumRegs-1:0][DataWidthInBytes-1:0] AxiReadOnly = '{
    ReadOnlyReg,
    ReadOnlyReg,
    ReadOnlyReg,
    ReadWriteReg,
    ReadWriteReg
  };

  /***************
   *  Registers  *
   ***************/
  logic [DataWidth-1:0]   eoc;
  logic [DataWidth-1:0]   wake_up;
  logic [DataWidth-1:0]   tcdm_start_address;
  logic [DataWidth-1:0]   tcdm_end_address;
  logic [DataWidth-1:0]   num_cores;

  logic [RegNumBytes-1:0] wr_active_d;
  logic [RegNumBytes-1:0] wr_active_q;

  axi_lite_regs #(
    .RegNumBytes (RegNumBytes               ),
    .AxiAddrWidth(AddrWidth                 ),
    .AxiDataWidth(AxiLiteDataWidth          ),
    .AxiReadOnly (AxiReadOnly               ),
    .RegRstVal   (RegRstVal                 ),
    .req_lite_t  (axi_lite_req_t            ),
    .resp_lite_t (axi_lite_resp_t           )
  ) i_axi_lite_regs (
    .clk_i      (clk_i                                                          ),
    .rst_ni     (rst_ni                                                         ),
    .axi_req_i  (axi_lite_slave_req_i                                           ),
    .axi_resp_o (axi_lite_slave_resp_o                                          ),
    .wr_active_o(wr_active_d                                                    ),
    .rd_active_o(/* Unused */                                                   ),
    .reg_d_i    ('0                                                             ),
    .reg_load_i ('0                                                             ),
    .reg_q_o    ({num_cores, tcdm_end_address, tcdm_start_address, wake_up, eoc})
  );

  /***************
   *   Signals   *
   ***************/

  assign eoc_o                = eoc >> 1;
  assign tcdm_start_address_o = tcdm_start_address;
  assign tcdm_end_address_o   = tcdm_end_address;
  assign num_cores_o          = num_cores;

  // converts 32 bit wake up to 256 bit
  always_comb begin
    wake_up_o = '0;
    if (wr_active_q[7:4]) begin
      if (wake_up < NumCores) begin
        wake_up_o = 1 << wake_up;
      end else if (wake_up == {DataWidth{1'b1}}) begin
        wake_up_o = {NumCores{1'b1}};
      end
    end
  end

  assign eoc_valid_o = eoc[0];

  // register to add +1 latency to the wr_active signal
  `FF(wr_active_q, wr_active_d, '0, clk_i, rst_ni)

endmodule : ctrl_registers
