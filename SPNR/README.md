# **Synthesis, Place \& Route (SP\&R):**
Here we provide the setups to run SP&R of Ariane design with 136 macros on Nangate45 using commercial and open-source tools. First, we provide the steps for netlist preparation and then discuss the SP&R flow. Here is the contains
1. [Netlist Preparation](#netlist_preparation)
   1. [Araine deisgn with 136 memory macros](#ariane_netlist)
2. [SP\&R Flow](#spnr_flow)
   1. [Using Cadence tools](#cadence_tools)
   2. [Using OpenROAD tools](#or_tools)

## **Netlist Preparation:** (#netlist_preparation)
### **Araine deisgn with 136 memory macros:**(#ariane_netlist)
We use the Ariane netlist available in [this](https://github.com/lowRISC/ariane) GitHub repository to generate the Ariane design with 136 memory (data width is 16bit and word count is 256) macros. All the required System-Verilog (.sv) files are copied into the *./designs/ariane* directory. For memory instantiation below steps are followed: 
1. In [sram.sv](https://github.com/lowRISC/ariane/blob/master/src/util/sram.sv) file, remove the instantiation of module *SyncSpRamBeNx64* and instantiate the 16bit SRAM. Here is an example of sram instantiation: 
```SystemVerilog
fakeram45_256x16 i_ram (.clk(clk_i),.rd_out(rdata_aligned[k*16 +: 16]),.ce_in(req_i),.we_in(we_i),.addr_in(addr_i),.wd_in(wdata_aligned[k*16 +: 16]));
```
2. As It is a 16bit memory the for loop is also required to be updated. Here is the snippet of the code before and after update:  

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
        fakeram45_256x16 i_ram (.clk(clk_i),.rd_out(rdata_aligned[k*16 +: 16]),.ce_in(req_i),.we_in(we_i),.addr_in(addr_i),.wd_in(wdata_aligned[k*16 +: 16]));
    end
endgenerate
```

sram.sv available in the *./designs/ariane* directory already contains these changes. We used this .sv files for our synthesis run. As the Yosys do not support .sv files, we hack the verilog netlist available in the [ORFS](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts/tree/master/flow/designs/src/ariane) GitHub and replace the 64bit memory macros with four or three 16bit memory macros based on the number of connected read-data pins. This hack netlist is available in the *./scripts/OpenROAD/ariane136* directory.

## **SP\&R Flow:**(#spnr_flow)
We implement Ariane design on the Nangate45 platform using commercial tools Genus (Synthesis) and Innovus (P&R) and open-source tools Yosys (Synthesis) and OpenROAD (P&R). The required *.lef* and *.lib* files are downloaded from the OpenROAD-flow-scripts (ORFS) [GitHub](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts/tree/master/flow/platforms/nangate45). We use the [fakeram](https://github.com/jjcherry56/bsg_fakeram) generator for the Nangate45 platform to generate the 16-bit memory. All the required *.lib* and *.lef* files are copied into the *./platform/nangate45* directory.  

### **Using Cadence Genus and Innovus:**(#cadence_tools)
All the required scripts are available in the ./scripts/cadence directory.  
**Synthesis:** run_genus.tcl contains the setup for synthesis using Genus. It reads the .sv files based on the list in ./scripts/cadence/rtl_list.tcl (changing the order of the file may cause errors in the run.). The timing constraints are provided in ./scripts/cadence/ariane.sdc file. To launch the synthesis run please use the below command
```
genus -overwrite -log log/genus.log -no_gui -files run_genus.tcl
```  
**P\&R:** run_innovus.tcl contains the setup for the P&R run using Innvous. It reads the netlist synthesized using the Genus flow. To launch the P\&R run please use the below command.
```
innovus -64 -init run_invs.tcl -log log/run.log
```  
Below is the screenshot of the Ariane SP\&R database with 136 memory macros using Cadence flow.  
<img src="./screenshoots/Ariane136_Cadence_SPNR.png" alt="ariane136_cadence" width="400"/>  

### **Using OpenROAD-flow-scripts:**(#or_tools)
Clone ORFS and build OpenROAD tools following the steps given here. To run SP&R using OpenROAD tools please copy the *./scripts/OpenROAD/ariane136* directory to *{ORFS Clone Directory}/OpenROAD-flow-scripts/flow/designs/nangate45* area.