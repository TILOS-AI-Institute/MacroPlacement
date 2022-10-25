#!/bin/bash

# Copyright 2021 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

MEMPOOL_DIR=$(git rev-parse --show-toplevel 2>/dev/null || echo $MEMPOOL_DIR)
cd $MEMPOOL_DIR/hardware

# Timestamp
timestamp=`date +%Y%m%d_%H%M%S`
mkdir load_thru_$timestamp

# Request forced to be in the sequential region
for seq_prob in `seq 0 0.2 1`; do
    echo "Prob. of request forced at the sequential region: ${seq_prob}"
    echo ""

    # Probability request
    for req_prob in `seq 0.02 0.02 0.6`; do
        # Clean-up
        make clean

        # Compile the verilator model
        tmpfile=`mktemp`
        tg=1 tg_ncycles=10000 tg_reqprob=${req_prob} tg_seqprob=${seq_prob} make verilate &> /dev/null

        echo "$req_prob `cat build/transcript | grep Average | cut -d: -f2` `cat build/transcript | grep Throughput | cut -d: -f2`" >> load_thru_$timestamp/results_seqprob${seq_prob}
        echo "Req. Probability: $req_prob | Avg. Latency: `cat build/transcript | grep Average | cut -d: -f2` cycle | Throughput: `cat build/transcript | grep Throughput | cut -d: -f2` req/core/cycle"
    done
done
