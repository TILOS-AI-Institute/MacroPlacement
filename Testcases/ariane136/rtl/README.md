# Netlist preparation of Ariane 136-macro version
We download the Ariane netlist from [lowRISC](https://github.com/lowRISC/ariane) GitHub repository. All the required System-Verilog (.sv) files are copied into the *./rtl/* directory. For memory instantiation we make the following changes to the netlist: 
1. In [sram.sv](https://github.com/lowRISC/ariane/blob/master/src/util/sram.sv) file, remove the instantiation of module *SyncSpRamBeNx64* and instantiate the 16bit SRAM. Here is an example of the SRAM instantiation: 
```SystemVerilog
fakeram45_256x16 i_ram (.clk(clk_i), .rd_out(rdata_aligned[k*16 +: 16]),
                        .ce_in(req_i), .we_in(we_i), .addr_in(addr_i),
                        .wd_in(wdata_aligned[k*16 +: 16]));
```
2. As it is a 16bit memory the for loop is also required to be updated. Here is the snippet of the code before and after update:  

Code snippet before update:
```SystemVerilog
genvar k;
generate
    for (k = 0; k<(DATA_WIDTH+63)/64; k++) begin
        // unused byte-enable segments (8bits) are culled by the tool
        SyncSpRamBeNx64 #(
          .ADDR_WIDTH($clog2(NUM_WORDS)),
          .DATA_DEPTH(NUM_WORDS),
          .OUT_REGS (0),
          .SIM_INIT (2)
        ) i_ram (
           .Clk_CI    ( clk_i                     ),
           .Rst_RBI   ( rst_ni                    ),
           .CSel_SI   ( req_i                     ),
           .WrEn_SI   ( we_i                      ),
           .BEn_SI    ( be_aligned[k*8 +: 8]      ),  
           .WrData_DI ( wdata_aligned[k*64 +: 64] ),
           .Addr_DI   ( addr_i                    ),
           .RdData_DO ( rdata_aligned[k*64 +: 64] )
        );
    end 
endgenerate
```
Code snippet after update:
```SystemVerilog
genvar k;
generate
    for (k = 0; k<(DATA_WIDTH+15)/16; k++) begin :macro_mem
        fakeram45_256x16 i_ram (.clk(clk_i), .rd_out(rdata_aligned[k*16 +: 16]), 
                                .ce_in(req_i), .we_in(we_i), .addr_in(addr_i), 
                                .wd_in(wdata_aligned[k*16 +: 16]));
    end
endgenerate
```
Above code snippet initializes 16bit memory instances. To instantiate 64bit memory below code snippet can be used.
```SystemVerilog
genvar k;
generate
    for (k = 0; k<(DATA_WIDTH+63)/64; k++) begin :macro_mem
        fakeram45_256x64 i_ram (.clk(clk_i), .rd_out(rdata_aligned[k*64 +: 64]),
                                .ce_in(req_i), .we_in(we_i), .addr_in(addr_i),
                                .wd_in(wdata_aligned[k*64 +: 64]));
    end
endgenerate
```
sram.sv available in the *./rtl/* directory already contains these changes (16bit configuration). We used this .sv files for our synthesis run and the synthesized netlist contains 136 16bit memory macros. We also ran with 64bit configuration and in that scenario the synthesized netlist contains 37 64bit memory macros (Not added in this repo). As Yosys does not support System-Verlog files, we use the verilog netlist available in the [ORFS](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts/tree/master/flow/designs/src/ariane) GitHub and replace the 64bit memory macros with four or three 16bit memory macros based on the number of connected read-data pins. This modified netlist is available in the *./rtl/sv2v/* directory.