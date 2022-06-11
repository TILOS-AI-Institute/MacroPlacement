# **MacroPlacement**
**MacroPlacement** is an open, transparent effort to provide a public, baseline implementation of [Google Brain's Circuit Training](https://github.com/google-research/circuit_training) (Morpheus) deep RL-based placement method.  We will provide (1) testcases in open enablements, along with multiple EDA tool flows; (2) implementations of missing or binarized elements of Circuit Training; (3) reproducible example macro placement solutions produced by our implementation; and (4) post-routing results obtained by full completion of the place-and-route flow using both proprietary and open-source tools.
  
## **Table of Content**
  <!-- - [Reproducible Example Solutions](#reproducible-example-solutions) -->
  - [Testcases](#testcases)
  - [Enablements](#enablements)
  - [Flows](#flows)
  - [Code Elements](#code-elements)
  - [FAQ](#faq)

## **Testcases**  
The list of avaialbe test cases
- Ariane (RTL)
  - [136 macro (RTL files)](./Testcases/ariane136/)
  - [133 macro](./Testcases/ariane133/)
- MemPool (RTL)
  - [tile](./Testcases/mempool_tile/)
  - group
  
In this [Nature Paper](https://www.nature.com/articles/s41586-021-03544-w), authors have used Ariane design with 133 memory (256x16, single ported SRAM) macros as one of the test cases. We noticed synthesizing the available Ariane netlist in [lowRISC](https://github.com/lowRISC/ariane) GitHub repository with 256x16 memory results in Ariane design with 136 memory macros ([Here](./Testcases/ariane136/) we show how we instantiate memories for Ariane 136). [Here](./Testcases/ariane133/) we show how we convert the Ariane 136 design to Ariane 133 design. So, we added these two versions to our testcase list. 
MemPool tile design is another testcase and we will be adding MemPool group in this list.  
  

Here we provide the detailed steps to generate the netlist for each test case. This netlist is used for the SP&R runs. The directory structure is as follows *./Testcases/testcase/<rtl\|sv2v>/*. 
  - *rtl* directory contains all the required rtl files to synthesize the test case.
  - If the main repository contains only the SystemVerilog files, we add the converted Verilog file to the sv2v directory.

## **Enablements**
The list of available enablements
- [NanGate45](./Enablements/NanGate45/)
- [ASAP7](./Enablements/ASAP7/)
  
 Open-source enablements NanGate45 and ASAP7 (will be adding) are utilized in our SP&R flow. The directory structure is *./Enablements/<NanGate45\|ASAP7>/<lib\|lef>/*. Here
 - *lib* directory contains all the required liberty files.
 - *lef* directory contains all the required lef files.
  
Also, we provide steps to generate the fakerams.

## **Flows**
Synthesis, place and route (SP&R) flow is available for each test case on each enablement. Here is the list
- NanGate45
  - [Ariane 136](./Flows/NanGate45/ariane136/)
  - [Ariane 133](./Flows/NanGate45/ariane133/)
  - [MemPool tile](./Flows/NanGate45/mempool_tile/)
  - MemPool group

Here we provide detailed information to run SP&R for each test case using the open-source tools Yosys (synthesis) and OpenROAD (P&R), and the commercial tools Cadence Genus (synthesis) and Innovus (P&R).  
The directory structure is as follows *./FLows/Enablement/testcase/<constraint\|def\|netlist\|scripts\|run>/*. Here
- *constraint* directory contains the *.sdc* file.
- *def* directory contains the def file with pin placement and die area information.
- *scripts* directory contains required scripts to run SP&R using the Cadence and OpenROAD tools.
- *netlist* directory contains the synthesized netlist. We provide a synthesized netlist that can be used to run P&R.
- Also, we provide the *run* directory to run the scripts provided in the *scripts* directory.

## **Code Elements**
List of code elements
- [Gridding](./CodeElements/Gridding/)
- [Grouping](./CodeElements/Grouping/)
- [Placement-guided hypergraph clustering (soft macro definition)](./CodeElements/Clustering/)
- [Force-directed placement](./CodeElements/FDPlacement/)
- [Simulated annealing](./CodeElements/SimulatedAnnealing/)
- [LEF/DEF and Bookshelf (OpenDB, RosettaStone) translators](./CodeElements/FormatTranslators/)

<!--## **Reproducible Example Solutions** -->

## **FAQ**
**Why are we doing this?**
- The challenges of data and benchmarking in EDA research have, in our view, been elements of recent controversy regarding the Nature work. The mission of the TILOS AI Institute includes finding solutions to these challenges -- in high-stakes applied optimization domains (such as IC EDA), and at community-scale. We want this effort to become an existence proof for transparency, reproducibility, and democratization of research in EDA.  [We applaud and thank Cadence Design Systems for allowing their tool runscripts to be shared openly by researchers, enabling reproducibility of results obtained via use of Cadence tools.]
- We do understand that Google has been working hard to complete the open-sourcing of Morpheus, and that this effort continues today. However, as pointed out in [this Doc](https://docs.google.com/document/d/1vkPRgJEiLIyT22AkQNAxO8JtIKiL95diVdJ_O4AFtJ8/edit?usp=sharing), it has been more than a year since "Data and Code Availability" was committed with publication of the [Nature paper](https://www.nature.com/articles/s41586-021-03544-w). We consider our work a "backstop" or "safety net" for Google's internal efforts, and a platform for researchers to build on. 

**What can others contribute?**
- Our shopping list includes:
- 

**What is your timeline?**
- We hope to show significant progress at the DAC-2022 Birds-of-a-Feather meeting (Open-Source EDA and Benchmarking Summit) on July 12, 2022, 7-10pm in Room 3000 of Moscone West in San Francisco.
