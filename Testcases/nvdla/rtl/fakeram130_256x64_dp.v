module fakeram_256x64_dp 
(
  QA, 
  CLKA, 
  CENA, 
  AA, 
  CLKB,
  CENB, 
  AB, 
  DB, 
  STOV, 
  EMAA, 
  EMASA, 
  EMAB, 
  RET1N
);

input CLKA;
input CLKB;

input CENA;
input [7:0]  AA;
output [63:0] QA;

input CENB;
input [7:0]  AB;
input [63:0] DB;

input STOV;
input [2:0] EMAA; 
input EMASA;
input [2:0] EMAB;
input RET1N;

wire [63:0] QB;
wire [63:0] QA1;

fakeram130_256x64 rmod_a
(
   .rd_out(QA1),
   .addr_in(AA),
   .we_in(~CENA),
   .wd_in(DB), //dummy
   .w_mask_in(DB), //dummy
   .clk(CLKA),
   .ce_in(CENA)
);

fakeram130_256x64 rmod_b
(
   .rd_out(QB), //dummy
   .addr_in(AB),
   .we_in(CENB),
   .wd_in(DB), 
   .w_mask_in(DB),
   .clk(CLKB),
   .ce_in(CENB)
);

genvar k;
generate
    for (k = 0; k < 64; k=k+1) begin
        assign QA[k] = (~CENB & QB[k]) | (CENB & QA1[k]);
    end
endgenerate

endmodule

