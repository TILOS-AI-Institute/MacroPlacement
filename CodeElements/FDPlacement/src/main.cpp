#include <iostream>
#include <chrono>
#include "FD.h"

int main(int argc, char* argv[]) {
  std::string netlist_file = argv[1];
  std::string plc_file = argv[2];
  PBFNetlist design(netlist_file);
  std::string new_netlist_file = netlist_file + ".new";
  design.WriteNetlist(new_netlist_file);
  design.RestorePlacement(plc_file);
  const float io_factor = 1.0;
  const std::vector<int> num_steps { 10, 10, 10 };
  const std::vector<float> attract_factor { 100, 1.0e-3, 1.0e-5 };
  const std::vector<float> repel_factor { 0.0, 1.0e6, 1.0e6 };
  const std::vector<float> move_distance_factor { 1.0, 1.0, 1.0 };
  const bool use_current_loc = false;
  const bool debug_mode = false;
  auto start_timestamp_global = std::chrono::high_resolution_clock::now();
  design.FDPlacer(io_factor, num_steps,
                  move_distance_factor,
                  attract_factor,
                  repel_factor,
                  use_current_loc, 
                  debug_mode);
  auto end_timestamp_global = std::chrono::high_resolution_clock::now();
  double total_global_time
      = std::chrono::duration_cast<std::chrono::nanoseconds>(
            end_timestamp_global - start_timestamp_global)
            .count();
  total_global_time *= 1e-9;
  std::cout << "Runtime of FDPlacer : " << total_global_time << std::endl;
  design.WritePlcFile(plc_file + ".new");
  return 0;
}
