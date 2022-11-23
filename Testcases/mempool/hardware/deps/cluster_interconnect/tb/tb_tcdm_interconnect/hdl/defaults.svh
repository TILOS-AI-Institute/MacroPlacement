`ifndef MUT_IMPL
  `define MUT_IMPL 2
 `endif
`ifndef NUM_MASTER
  `define NUM_MASTER 16
 `endif
`ifndef BANK_FACT
  `define BANK_FACT 2
 `endif
`ifndef DATA_WIDTH
  `define DATA_WIDTH 32
`endif
`ifndef TCDM_SIZE
  `define TCDM_SIZE 128*1024
`endif
`ifndef MEM_ADDR_BITS
  `define MEM_ADDR_BITS $clog2(`TCDM_SIZE/`NUM_MASTER/`BANK_FACT)
`endif
`ifndef PAR_STAGES
  `define PAR_STAGES 1
`endif
`ifndef TEST_CYCLES
  // scale this with the number of master ports (= bins)
  // for reliable statistics
  `define TEST_CYCLES (150*`NUM_MASTER)
`endif
