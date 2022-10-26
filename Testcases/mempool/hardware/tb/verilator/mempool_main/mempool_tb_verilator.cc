// Copyright 2021 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <fstream>
#include <iostream>

#include "verilated_toplevel.h"
#include "verilator_memutil.h"
#include "verilator_sim_ctrl.h"

// Please define the following parameters with sensible values
#ifndef L2_BASE
#define L2_BASE (-1)
#endif
#ifndef L2_SIZE
#define L2_SIZE (-1)
#endif
#ifndef L2_BANKS
#define L2_BANKS (-1)
#endif
#ifndef AXI_DATA_WIDTH
#define AXI_DATA_WIDTH (-1)
#endif

// Histogram printing function
extern "C" void print_histogram();

int main(int argc, char **argv) {
  mempool_tb_verilator top;
  VerilatorMemUtil memutil;
  VerilatorSimCtrl &simctrl = VerilatorSimCtrl::GetInstance();
  simctrl.SetTop(&top, &top.clk_i, &top.rst_ni,
                 VerilatorSimCtrlFlags::ResetPolarityNegative);

#ifndef TRAFFIC_GEN
  std::vector<std::string> l2_scope;
  for (int i = 0; i < L2_BANKS; ++i) {
    l2_scope.push_back("TOP.mempool_tb_verilator.dut.gen_l2_banks[" +
                       std::to_string(i) + "].l2_mem");
  }
  MemArea l2_mem(l2_scope, L2_SIZE / (AXI_DATA_WIDTH / 8), AXI_DATA_WIDTH / 8);
  memutil.RegisterMemoryArea("ram", L2_BASE, &l2_mem);
  simctrl.RegisterExtension(&memutil);
#endif

  simctrl.SetInitialResetDelay(1);
  simctrl.SetResetDuration(4);

  bool exit_app = false;
  int ret_code = simctrl.ParseCommandArgs(argc, argv, exit_app);
  if (exit_app) {
    return ret_code;
  }

  std::cout << "Simulation of MemPool" << std::endl
            << "=====================" << std::endl
            << std::endl;

  simctrl.RunSimulation();

#ifdef TRAFFIC_GEN
  // Print the latency histogram
  print_histogram();
#endif

  if (!simctrl.WasSimulationSuccessful()) {
    return 1;
  }

  return 0;
}
