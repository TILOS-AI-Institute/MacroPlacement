// ================================================================
// NVDLA Open Source Project
//
// Copyright(c) 2016 - 2017 NVIDIA Corporation. Licensed under the
// NVDLA Open Hardware License; Check "LICENSE" which comes with
// this distribution for more information.
// ================================================================
// File Name: nv_ram_rws_256x64.v
module nv_ram_rws_256x64 (
  clk,	//CLKA, CLKB
  ra,   //AA
  re,   //CENA
  dout, //Q
  wa,   //AB
  we,   //CENB
  di,   //DB
  pwrbus_ram_pd
);
parameter FORCE_CONTENTION_ASSERTION_RESET_ACTIVE=1'b0;
// port list
input clk;
input [7:0] ra;
input re;
output [63:0] dout;
input [7:0] wa;
input we;
input [63:0] di;
input [31:0] pwrbus_ram_pd;

// NC 
// The generated memory is a 2 ported register file, where port B is dedicated write and port
// A is dedicated read
// Requires the following truth table for functional mode
// Write : cena=1 cenb=0 db[M:0]=datain ab[N:0]=write addr  dataout=Q[M:0]=last data 
// Read :  cena=0 cenb=1 db[M:0]=x      aa[N:0]=read  addr  dataout=Q[M:0]=correct data at aa 
// Read/Write : cena=0 cenb=0 db[M:0]=datain ab[N:0]=write addr aa[N:0]=read addr  dataout=Q[M:0]=correct data at aa
// Read/Write : cena=0 cenb=0 db[M:0]=datain ab[N:0]=addr aa[N:0]=addr  dataout=Q[M:0]=unknown    (when concurrent read and write to the same address, write happens correctly, but not read)
// Standby:     cena=1 cenb=1 dataout=Q[M:0]=last data  

wire cena;
wire [7:0]  aa;
wire [63:0] da;

wire cenb;
wire [7:0]  ab;
wire [63:0] db;

assign  dout=da;
assign  cena=(re==1'b1)?1'b0:1'b1;
assign  aa=ra;  // Data is available from the generated memory at the next clk edge after cena is asserted, so no need to register aa or cena

//assign  cenb=~we;
assign  cenb=(we==1'b1)?1'b0:1'b1;
assign  ab=wa;
assign  db=di;


wire ret1n ;	
wire stov;
wire emasa;	// Extra Margin Adjustment read port keeper enable: Default for all voltages
wire [2:0] emaa;	// Extra margin adjustment A: Default for 0.8V
wire [2:0] emab;	// Extra margin adjustment B: Default for 0.8V

assign stov = 1'b0;
assign emasa = 1'b0;	
assign emaa = 3'b010;	// Extra margin adjustment A: Default for 0.8V
assign emab = 3'b010;	// Extra margin adjustment B: Default for 0.8V
assign ret1n = 1'b1;	

//rf_2p_hsc_256x64_nogating rmod (
//                      .QA(da), 
//                      .CLKA(clk), 
//                      .CENA(cena), 
//                      .AA(aa), 
//                      .CLKB(clk),
//                      .CENB(cenb), 
//                      .AB(ab), 
//                      .DB(db), 
//                      .STOV(stov), 
//                      .EMAA(emaa), 
//                      .EMASA(emasa), 
//                      .EMAB(emab), 
//                      .RET1N(ret1n));

//NG45 fakeram
fakeram_256x64_dp rmod (
                      .QA(da), 
                      .CLKA(clk), 
                      .CENA(cena), 
                      .AA(aa), 
                      .CLKB(clk),
                      .CENB(cenb), 
                      .AB(ab), 
                      .DB(db), 
                      .STOV(stov), 
                      .EMAA(emaa), 
                      .EMASA(emasa), 
                      .EMAB(emab), 
                      .RET1N(ret1n));


///Commented out behavioral module
/*
reg [7:0] ra_d;
wire [63:0] dout;
reg [63:0] M [255:0];
always @( posedge clk ) begin
    if (we)
       M[wa] <= di;
end
always @( posedge clk ) begin
    if (re)
       ra_d <= ra;
end
assign dout = M[ra_d];
*/

endmodule
