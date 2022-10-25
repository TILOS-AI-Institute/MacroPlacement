// Copyright 2021 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

`include "register_interface/typedef.svh"

module axi_uart #(
  parameter type axi_req_t                = logic,
  parameter type axi_resp_t               = logic
) (
  input  logic       clk_i,
  input  logic       rst_ni,
  input  logic       testmode_i,
  // AXI Bus
  input  axi_req_t   axi_req_i,
  output axi_resp_t  axi_resp_o
);

  localparam AddrWidth  = $bits(axi_req_i.aw.addr);
  localparam DataWidth  = $bits(axi_req_i.w.data);
  localparam StrbWidth  = DataWidth/8;
  localparam UserWidth  = $bits(axi_req_i.aw.user);
  localparam AxiIdWidth = $bits(axi_req_i.aw.id);

  typedef logic [AddrWidth-1:0] addr_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [StrbWidth-1:0] strb_t;

  `REG_BUS_TYPEDEF_ALL(uart, addr_t, data_t, strb_t)

  uart_req_t reg_req;
  uart_rsp_t reg_resp;


  // Modelsim 2019 exhibits a werid bug in `axi_to_reg` if the ID is larger
  // than 5. It creates a vector with the size 2^ID, but only assigns the first
  // 32 entries properly. This is a tool problem that is solved in the 2020
  // version. However, since we only use this in the testbench now, we can
  // prevent this bug by reducing the ID size.

  localparam int unsigned IntIdWidth = 2;

  typedef logic [IntIdWidth-1:0]  int_id_t;
  typedef logic [UserWidth-1:0]   user_t;

  `include "axi/typedef.svh"
  // Intermediate AXI types
  `AXI_TYPEDEF_AW_CHAN_T(int_aw_t, addr_t, int_id_t, user_t);
  `AXI_TYPEDEF_W_CHAN_T(w_t, data_t, strb_t, user_t);
  `AXI_TYPEDEF_B_CHAN_T(int_b_t, int_id_t, user_t);
  `AXI_TYPEDEF_AR_CHAN_T(int_ar_t, addr_t, int_id_t, user_t);
  `AXI_TYPEDEF_R_CHAN_T(int_r_t, data_t, int_id_t, user_t);
  `AXI_TYPEDEF_REQ_T(int_req_t, int_aw_t, w_t, int_ar_t);
  `AXI_TYPEDEF_RESP_T(int_resp_t, int_b_t, int_r_t );

  // Intermediate AXI channel
  int_req_t  int_req;
  int_resp_t int_resp;

  axi_id_remap #(
    .AxiSlvPortIdWidth    (AxiIdWidth),
    .AxiSlvPortMaxUniqIds (IntIdWidth),
    .AxiMaxTxnsPerId      (4         ),
    .AxiMstPortIdWidth    (IntIdWidth),
    .slv_req_t            (axi_req_t ),
    .slv_resp_t           (axi_resp_t),
    .mst_req_t            (int_req_t ),
    .mst_resp_t           (int_resp_t)
  ) i_axi_id_remap (
    .clk_i      (clk_i     ),
    .rst_ni     (rst_ni    ),
    .slv_req_i  (axi_req_i ),
    .slv_resp_o (axi_resp_o),
    .mst_req_o  (int_req   ),
    .mst_resp_i (int_resp  )
  );

  axi_to_reg #(
    .ADDR_WIDTH         (AddrWidth ),
    .DATA_WIDTH         (DataWidth ),
    .ID_WIDTH           (IntIdWidth),
    .USER_WIDTH         (UserWidth ),
    .AXI_MAX_WRITE_TXNS (1         ),
    .AXI_MAX_READ_TXNS  (1         ),
    .DECOUPLE_W         (1'b1      ),
    .axi_req_t          (int_req_t ),
    .axi_rsp_t          (int_resp_t),
    .reg_req_t          (uart_req_t),
    .reg_rsp_t          (uart_rsp_t)
  ) i_axi_to_reg (
    .clk_i      (clk_i     ),
    .rst_ni     (rst_ni    ),
    .testmode_i (testmode_i),
    .axi_req_i  (int_req   ),
    .axi_rsp_o  (int_resp  ),
    .reg_req_o  (reg_req   ),
    .reg_rsp_i  (reg_resp  )
  );

  string str;

  `ifdef VCS
    `define UARTASSIGNOPERATOR =
  `else
    `define UARTASSIGNOPERATOR <=
  `endif

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      str `UARTASSIGNOPERATOR "";
    end else begin
      if (reg_req.valid) begin
        if (reg_req.write) begin
          for (int i = 0; i < StrbWidth; i++) begin
            if (reg_req.wstrb[i]) begin
              str `UARTASSIGNOPERATOR $sformatf("%s%c", str, reg_req.wdata[i*8+:8]);
            end
          end
          if (reg_req.wdata == 'h0a) begin
            $display("[UART] %s", str);
            str `UARTASSIGNOPERATOR "";
          end
        end
      end
    end
  end

  assign reg_resp.rdata = '0;
  assign reg_resp.error = 1'b0;
  assign reg_resp.ready = 1'b1;

endmodule : axi_uart
