# **Test Cases:**
Testcases currently include the following designs.
- [Ariane](https://github.com/lowRISC/ariane): We download the Ariane netlist from the [lowRISC](https://github.com/lowRISC/ariane) GitHub repository.
  - [136 macro version](./ariane136/): We instantiate 16-bit (256x16) memories to enable generation of the Ariane design with 136 macros.
  - [133 macro version](./ariane133/): The netlist of the 136-macro version is modified to generate the Ariane design with 133 macros. This is explained [here](./ariane133/).
- [MemPool](https://github.com/pulp-platform/mempool): The MemPool design is downloaded from the [mempool](https://github.com/pulp-platform/mempool) GitHub repository.
  - [tile](./mempool_tile/): MemPool tile is part of MemPool which is an open-source many-core system.
- [NVDLA](https://github.com/nvdla/hw/tree/nv_small): The NVDLA design is downloaded from the [nvdla/hw](https://github.com/nvdla/hw/tree/nv_small) GitHub repository.
  - [NVDLA nv_small](./nvdla/): We compile the RTL using the nv_small.spec available in the [nvdla/hw](https://github.com/nvdla/hw/tree/nv_small) GitHub repository. Only partition *c* has the memory macros, so we run all our flow only for partition *c*.
