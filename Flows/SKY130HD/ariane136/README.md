# **Synthesis, Place \& Route (SP\&R):**
Here we provide the setup to run SP&R of Ariane design with 136 macros on SKY130HD using commercial and open-source tools.
  - [**SP\&R Flow**](#spr-flow)
    - [**Cadence tools**](#using-cadence-genus-and-innovus)

## **SP\&R Flow:**
We implement Ariane design with [136 macros](../../../Testcases/ariane136/) on the SKY130HD platform using the proprietary (commercial) tools **Cadence Genus** (Synthesis) and **Cadence Innovus** (P&R), and the open-source tools **Yosys** (Synthesis) and **OpenROAD** (P&R) (Soon, we will update the OpenROAD flow details). The required *.lef* and *.lib* files are downloaded from the OpenROAD-flow-scripts (ORFS) [GitHub](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts/tree/master/flow/platforms/sky130hd). We use the [fakeram](https://github.com/jjcherry56/bsg_fakeram) generator for the SKY130HD platform to generate the 16-bit (256x16, single-ported SRAM) memory. All the required *.lib* and *.lef* files are available in the [*Enablements/SKY130HD*](../../../Enablements/SKY130HD/) directory.  
  
  
### **Using Cadence Genus and Innovus:**
All the required scripts are available in the [*./scripts/cadence/*](./scripts/cadence/) directory.  
**Synthesis:** [run_genus.tcl](./scripts/cadence/run_genus.tcl) contains the setup for synthesis using Genus. It reads the .sv files based on the list in [*./scripts/cadence/rtl_list.tcl*](./scripts/cadence/rtl_list.tcl) (changing the order of the file may cause errors). The timing constraints are provided in [*./constrains/ariane.sdc*](./constraints/ariane.sdc) file. To launch the synthesis run please use the below command
```
genus -overwrite -log log/genus.log -no_gui -files run_genus.tcl
```  
We also generate a synthesized netlist, which is available in the [*./netlist/*](./netlist/) directory.  
  
**P\&R:** [run_innovus.tcl](./scripts/cadence/run_invs.tcl) contains the setup for the P&R run using Innvous. It reads the netlist provided in [*./netlist/*](./netlist/) directory. To launch the P\&R run please use the below command.
```
innovus -64 -init run_invs.tcl -log log/run.log
```

Below is the screenshot of the Ariane SP\&R database with 136 memory macros using Cadence flow.  
<img src="./screenshots/Ariane136_Innovus_Genus.png" alt="ariane136_cadence" width="400"/>  


This script was written and developed by ABKGroup students at UCSD; however, the underlying commands and reports are copyrighted by Cadence. We thank Cadence for granting permission to share our research to help promote and foster the next generation of innovators.


<!--
### **Using OpenROAD-flow-scripts:**
Clone ORFS and build OpenROAD tools following the steps given [here](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts). To run SP&R using OpenROAD tools follow the below mentioned steps:  
1. Copy [*./scripts/OpenROAD/ariane.tar.gz*](./scripts/OpenROAD/ariane.tar.gz) file to *{ORFS Clone Directory}/OpenROAD-flow-scripts/flow/designs/nangate45* area.
2. Use command *tar -xvf ariane.tar.gz* to untar *ariane.tar.gz*. This will generate *ariane136* directory which contains all the files required to run SP&R using ORFS.
3. To launch the SP&R job go to the flow directory and use the below command
  ```
  make DESIGN_CONFIG=./designs/nangate45/ariane136/config_hier.mk
  ```
4. config_hier.mk uses the **RTL-MP** (RTL Macro Placer) for macro placement. If you wish to run macro placement using the older **Triton Macro Placer**, please use the below command:
  ```
  make DESIGN_CONFIG=./designs/nangate45/ariane136/config.mk
  ```  
  
Below is the screenshot of the Ariane SP\&R database with 136 memory macros using the ORFS (RTL-MP) flow.  
<img src="./screenshots/Ariane136_ORFS_SPNR.png" alt="ariane136_orfs" width="400"/>
-->