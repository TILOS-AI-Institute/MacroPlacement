# Netlist preparation of Ariane 133-macro version
For the Ariane 133-macro version, we use the Verilog netlist available in the [ORFS](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts/tree/master/flow/designs/src/ariane) GitHub and replace the 64bit memory macros with four or three 16bit memory macros based on the number of connected read-data pins. In the synthesized netlist of the Ariane 136-macro version, the memory instantiation in the valid_dirty_sram hierarchy is given below.
```verilog
  fakeram45_256x16
       \i_cache_subsystem_i_nbdcache_valid_dirty_sram_macro_mem[0].i_ram
       (.clk (clk_i), .we_in (i_cache_subsystem_i_nbdcache_we_ram),
       .ce_in (i_cache_subsystem_i_nbdcache_n_751), .addr_in
       (i_cache_subsystem_i_nbdcache_addr_ram[11:4]), .wd_in ({6'b0,
       \i_cache_subsystem_i_nbdcache_wdata_ram[valid] ,
       \i_cache_subsystem_i_nbdcache_wdata_ram[dirty] , 6'b0,
       \i_cache_subsystem_i_nbdcache_wdata_ram[valid] ,
       \i_cache_subsystem_i_nbdcache_wdata_ram[dirty] }), .w_mask_in
       (16'b0), .rd_out
       ({i_cache_subsystem_i_nbdcache_valid_dirty_sram_rdata_aligned[15:10],
       i_cache_subsystem_i_nbdcache_dirty_rdata[9:8],
       i_cache_subsystem_i_nbdcache_valid_dirty_sram_rdata_aligned[7:2],
       i_cache_subsystem_i_nbdcache_dirty_rdata[1:0]}));
  fakeram45_256x16
       \i_cache_subsystem_i_nbdcache_valid_dirty_sram_macro_mem[1].i_ram
       (.clk (clk_i), .we_in (i_cache_subsystem_i_nbdcache_we_ram),
       .ce_in (i_cache_subsystem_i_nbdcache_n_751), .addr_in
       (i_cache_subsystem_i_nbdcache_addr_ram[11:4]), .wd_in ({6'b0,
       \i_cache_subsystem_i_nbdcache_wdata_ram[valid] ,
       \i_cache_subsystem_i_nbdcache_wdata_ram[dirty] , 6'b0,
       \i_cache_subsystem_i_nbdcache_wdata_ram[valid] ,
       \i_cache_subsystem_i_nbdcache_wdata_ram[dirty] }), .w_mask_in
       (16'b0), .rd_out
       ({i_cache_subsystem_i_nbdcache_valid_dirty_sram_rdata_aligned[31:26],
       i_cache_subsystem_i_nbdcache_dirty_rdata[25:24],
       i_cache_subsystem_i_nbdcache_valid_dirty_sram_rdata_aligned[23:18],
       i_cache_subsystem_i_nbdcache_dirty_rdata[17:16]}));
  fakeram45_256x16
       \i_cache_subsystem_i_nbdcache_valid_dirty_sram_macro_mem[2].i_ram
       (.clk (clk_i), .we_in (i_cache_subsystem_i_nbdcache_we_ram),
       .ce_in (i_cache_subsystem_i_nbdcache_n_751), .addr_in
       (i_cache_subsystem_i_nbdcache_addr_ram[11:4]), .wd_in ({6'b0,
       \i_cache_subsystem_i_nbdcache_wdata_ram[valid] ,
       \i_cache_subsystem_i_nbdcache_wdata_ram[dirty] , 6'b0,
       \i_cache_subsystem_i_nbdcache_wdata_ram[valid] ,
       \i_cache_subsystem_i_nbdcache_wdata_ram[dirty] }), .w_mask_in
       (16'b0), .rd_out
       ({i_cache_subsystem_i_nbdcache_valid_dirty_sram_rdata_aligned[47:42],
       i_cache_subsystem_i_nbdcache_dirty_rdata[41:40],
       i_cache_subsystem_i_nbdcache_valid_dirty_sram_rdata_aligned[39:34],
       i_cache_subsystem_i_nbdcache_dirty_rdata[33:32]}));
  fakeram45_256x16
       \i_cache_subsystem_i_nbdcache_valid_dirty_sram_macro_mem[3].i_ram
       (.clk (clk_i), .we_in (i_cache_subsystem_i_nbdcache_we_ram),
       .ce_in (i_cache_subsystem_i_nbdcache_n_751), .addr_in
       (i_cache_subsystem_i_nbdcache_addr_ram[11:4]), .wd_in ({6'b0,
       \i_cache_subsystem_i_nbdcache_wdata_ram[valid] ,
       \i_cache_subsystem_i_nbdcache_wdata_ram[dirty] , 6'b0,
       \i_cache_subsystem_i_nbdcache_wdata_ram[valid] ,
       \i_cache_subsystem_i_nbdcache_wdata_ram[dirty] }), .w_mask_in
       (16'b0), .rd_out
       ({i_cache_subsystem_i_nbdcache_valid_dirty_sram_rdata_aligned[63:58],
       i_cache_subsystem_i_nbdcache_dirty_rdata[57:56],
       i_cache_subsystem_i_nbdcache_valid_dirty_sram_rdata_aligned[55:50],
       i_cache_subsystem_i_nbdcache_dirty_rdata[49:48]}));
```
In each of the above four memory instantiations, only four read data (rd_out) and write data (wd_in) bits are used among the 16-bits. So we replace the four 16bit memory with a single 16bit memory and update the connections accordingly. The available Verilog in the *./rtl/sv2v/* directory contains this change.
  
After this change, we noticed that logic optimization trims some memory macros during the synthesis stage, so we use set_dont_touch for all the memory instantiations in the Ariane 133-macro version.