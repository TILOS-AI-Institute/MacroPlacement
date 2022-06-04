# MacroPlacement
This repository provides detailed steps to run clustering and synthesis, place, and route (SP&R) for different designs (e.g., ariane, mempool_tile) on the Nangate45 platform.

**MacroPlacement** is an open, transparent effort to provide a public, baseline implementation of Google Brain's Circuit Training (Morpheus) deep RL-based placement method.  We provide (1) testcases and flows in open enablements; (2) implementations of missing or binarized elements of Circuit Training; (3) reproducible example macro placement solutions produced by our implementation; and (4) post-routing results obtained by full completion of the place-and-route flow using both proprietary and open-source tools.

**List of testcases and flows:**  
     Ariane (133-macro version, and 136-macro version)
     MemPool

**List of enablements:**  
     NanGate45 (FreePDK45, 45nm Open Cell Library, bsg-FakeRAM memory generation)
     ASAP7 (7.5T cell library (RVT only), FakeRAM2.0 memory generation)
     [Proprietary, only results given: GLOBALFOUNDRIES 12LP (Arm 9T cell library (SVT only), Arm memories) [**only results can be shown**]
 
**List of elements:**  
     Hypergraph clustering
     Gridding
     Force-directed placement
     Simulated annealing
