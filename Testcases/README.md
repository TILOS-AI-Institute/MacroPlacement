# **Synthesis, Place \& Route (SP\&R):**
Here we provide the setup to run SP&R of Ariane and mempool_tile designs on Nangate45 using commercial and open-source tools.  
Here is the detials of the available designs
1. [Ariane](./designs/ariane/): Provides the flow details to generate a post-routed database from the Ariane netlist available in [lowRISC](https://github.com/lowRISC/ariane) GitHub repository, using Genus and Innovus, and Yosys and OpenROAD tools. Also, we provide detailed description to control the memory configuration of the synthesized netlist.  
2. [mempool_tile](./design/../designs/mempool_tile/):
  
Here is the details of the directory structure:
1. [*design*](./designs/): Contains the design related informations (ariane and mempool_tile) and for each design you can find the below informations
   1. *constraints* contains the .sdc (Synopsys Design Constraint) file.
   2. *rtl* contains the netlist required to run the synthesis flow. The details of the netlist can be found in the design respective README files.
   3. *netlist* contains the Cadence-Genus synthesized netlist on Nangate45 platfrom.
   4. *scripts* contains the required flow scripts for Cadence and OpenROAD tools based SP\&R flow.
   5. *run* is provided to launch SP\&R runs for Cadence tools.
2. [*platforms*](./platforms/): Contains the technology related files for each platform. For the time being we provide only Nangate45 platform details.
   1. *lef* contains the technology, standard cells and macro lef files.
   2. *lib* contains the standard cell and macro liberty files.