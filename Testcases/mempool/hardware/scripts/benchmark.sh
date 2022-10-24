#!/usr/bin/env bash

# Copyright 2021 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

MEMPOOL_DIR=$(git rev-parse --show-toplevel 2>/dev/null || echo $MEMPOOL_DIR)
cd $MEMPOOL_DIR/hardware

# Make sure an app is specified
app="$MEMPOOL_DIR/software/bin/$1"
if [[ ! -f $app ]]; then
  echo "Please specify an application to execute"
  exit -1
fi

# Create log
mailfile=email_$1

# Run all three scenarios
scenarios=('TopH')
echo "Benchmarked: $1" > $mailfile
for scenario in "${scenarios[@]}"; do
  echo $scenario
  # Do some changes to get the correct HW state
  num_hives=4
  # Run the benchmark
  buildpath=build_$1_$scenario
  result_dir=results/$(date +"%Y%m%d_%H%M%S_$1_$scenario")
  mkdir -p $result_dir
  log_file=$result_dir/benchmark_log_$1_$scenario
  rm -rf $buildpath
  buildpath=$buildpath result_dir=$result_dir num_hives=$num_hives app=$1 \
    make benchmark > $log_file &
  # Prepare notification email
  echo "Scenario $scenario:" >> $mailfile
  echo "  - Buildpath=$(pwd)/$buildpath" >> $mailfile
  echo "  - ResultDir=$(pwd)/$result_dir" >> $mailfile
  # Sleep until the compilation is done.
  while [ ! -f $buildpath/trace_hart_0000.dasm ]; do sleep 5; done
done

wait

[[ -n "$2" ]] && echo "User notes: $2" >> $mailfile
mail -s "Benchmarking $1 completed" $USER@iis.ee.ethz.ch < $mailfile
rm $mailfile
