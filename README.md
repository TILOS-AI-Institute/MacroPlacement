# MacroPlacement
**MacroPlacement** is an open, transparent effort to provide a public, baseline implementation of Google Brain's Circuit Training (Morpheus) deep RL-based placement method.  We provide (1) testcases in open enablements, along with multiple EDA tool flows; (2) implementations of missing or binarized elements of Circuit Training; (3) reproducible example macro placement solutions produced by our implementation; and (4) post-routing results obtained by full completion of the place-and-route flow using both proprietary and open-source tools.

### List of Testcases  
- [Ariane](https://github.com/lowRISC/ariane)
  - [136-macro version](./Testcases/ariane136/)
  - [133-macro version](./Testcases/ariane133/)
- MemPool ("[tile](./Testcases/mempool_tile/)" and "group")
  
### List of Flows
Synthesis, placement and routing flows in  
- [OpenROAD](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts)  
  - Ariane
    - [136-macro version](./Flows/NanGate45/ariane136/)
    - [133-macro version](./Flows/NanGate45/ariane133/)
  - MemPool  
    - [tile](./Flows/NanGate45/mempool_tile/scripts/)
- Cadence (Genus 21.1 for synthesis and Innovus 21.1 for P&R)  
  - Ariane 
    - [136-macro version](./Flows/NanGate45/ariane136/scripts/cadence/)
    - [133-macro version](./Flows/NanGate45/ariane133/scripts/cadence/)
  - MemPool
    - [tile](./Flows/NanGate45/mempool_tile/scripts/OpenROAD/)
    - group

### List of Enablements
- [NanGate45 (FreePDK45, 45nm Open Cell Library, bsg-FakeRAM memory generation)](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/Enablements/NanGate45)
- [ASAP7 (7.5T cell library (RVT only), FakeRAM2.0 memory generation)](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/Enablements/ASAP7)  
  
### List of Code Elements
- [Gridding](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/CodeElements/Gridding) <br />
- [Grouping](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/CodeElements/Grouping) <br />
- [Placement-guided hypergraph clustering (soft macro definition)](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/CodeElements/Clustering) <br />
- [Force-directed placement](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/CodeElements/FDPlacement) <br />
- [Simulated annealing](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/CodeElements/SimulatedAnnealing)  <br />
- [LEF/DEF and Bookshelf (OpenDB, RosettaStone) translators](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/CodeElements/FormatTranslators) <br />

### Reproducible Example Solutions
