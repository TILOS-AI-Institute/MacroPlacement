# **Test Cases:**
The detials of the available designs
- [Ariane](https://github.com/lowRISC/ariane): We download the Ariane netlist from the [lowRISC](https://github.com/lowRISC/ariane) GitHub repository.
  - [136-macro version](./ariane136/): We instantiate 16bit memory to generate Ariane design with 136-macro.
  - [133-macro version](./ariane133/): The netlist of the 136-macro version is modified to generate the Ariane design with 133-macro.
- [MemPool](https://github.com/pulp-platform/mempool): The MemPool design is downloaded from the [mempool](https://github.com/pulp-platform/mempool) GitHub repository.
  - [tile](./mempool_tile/): MemPool tile is part of MemPool which is an open-source many-core system targeting image processing applications. It implements 256 RISC-V cores that can access a large, shared L1 memory in at most five cycles.