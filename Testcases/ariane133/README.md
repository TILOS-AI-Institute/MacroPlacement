# Netlist preparation of Ariane 133-macro version
For the Ariane 133-macro version, we use the Verilog netlist available in the [ORFS](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts/tree/master/flow/designs/src/ariane) GitHub and replace each 64-bit memory macro with either four or three 16-bit memory macros based on the number of connected read-data pins. In the synthesized netlist of the Ariane 136-macro version, the memory instantiation in the valid_dirty_sram hierarchy is given below.
```Verilog
  fakeram45_256x16 \macro_mem[0].i_ram (.clk (clk_i), .we_in (we_i),
       .ce_in (req_i), .addr_in (addr_i), .wd_in ({6'b0, wdata_i[1:0],
       6'b0, wdata_i[1:0]}), .w_mask_in (16'b0), .rd_out
       ({rdata_aligned[15:10], rdata_o[9:8], rdata_aligned[7:2],
       rdata_o[1:0]}));
  fakeram45_256x16 \macro_mem[1].i_ram (.clk (clk_i), .we_in (we_i),
       .ce_in (req_i), .addr_in (addr_i), .wd_in ({6'b0, wdata_i[1:0],
       6'b0, wdata_i[1:0]}), .w_mask_in (16'b0), .rd_out
       ({rdata_aligned[31:26], rdata_o[25:24], rdata_aligned[23:18],
       rdata_o[17:16]}));
  fakeram45_256x16 \macro_mem[2].i_ram (.clk (clk_i), .we_in (we_i),
       .ce_in (req_i), .addr_in (addr_i), .wd_in ({6'b0, wdata_i[1:0],
       6'b0, wdata_i[1:0]}), .w_mask_in (16'b0), .rd_out
       ({rdata_aligned[47:42], rdata_o[41:40], rdata_aligned[39:34],
       rdata_o[33:32]}));
  fakeram45_256x16 \macro_mem[3].i_ram (.clk (clk_i), .we_in (we_i),
       .ce_in (req_i), .addr_in (addr_i), .wd_in ({6'b0, wdata_i[1:0],
       6'b0, wdata_i[1:0]}), .w_mask_in (16'b0), .rd_out
       ({rdata_aligned[63:58], rdata_o[57:56], rdata_aligned[55:50],
       rdata_o[49:48]}));
```
In each of the above four memory instantiations, only four read data (rd_out) and write data (wd_in) bits are used among the 16 bits. So, we replace the four 16-bit memories with a single 16-bit memory and update the connections accordingly. Here is the updated version with the single memory macro

```Verilog
  fakeram45_256x16 \macro_mem[0].i_ram (.clk (clk_i), .we_in (we_i),
       .ce_in (req_i), .addr_in (addr_i), .wd_in ({wdata_i[1:0], wdata_i[1:0],
       wdata_i[1:0], wdata_i[1:0], wdata_i[1:0], wdata_i[1:0], wdata_i[1:0], 
       wdata_i[1:0]}), .w_mask_in (16'b0), .rd_out ({rdata_o[57:56], 
       rdata_o[41:40], rdata_o[25:24], rdata_o[9:8], rdata_o[17:16], 
       rdata_o[33:32], rdata_o[49:48], rdata_o[1:0]}));
```
The available Verilog in the *./rtl/sv2v/* directory contains this change.

After this change, we have noticed that logic optimization trims some memory macros during the synthesis stage, so we currently use set_dont_touch for all the memory instantiations in the Ariane 133-macro version.
