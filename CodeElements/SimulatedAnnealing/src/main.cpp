#include <iostream>
#include <chrono>
#include <sstream>

#include "plc_netlist.h"

int main(int argc, char* argv[]) {
  std::string netlist_file = argv[1];
  std::string plc_file = argv[2];
  std::vector<float> action_probs;
  unsigned int num_actions = std::stoul(std::string(argv[3]));
  float max_temperature = std::stof(std::string(argv[4]));
  unsigned int num_iters = std::stoul(std::string(argv[5]));
  int seed = std::stoi(std::string(argv[6]));
  bool spiral_flag;
  std::istringstream(argv[7]) >> spiral_flag;
  for (int i = 0; i < 5; i++) {
    action_probs.push_back(std::stof(std::string(argv[i+8])));
  }
  std::string design_name = std::string(argv[13]);
  std::string run_dir = std::string(argv[14]);
  std::string summary_file = run_dir + "/" + design_name + ".summary";
  std::cout << std::string(80, '*') << std::endl;
  std::cout << "The Parameters for Simulated Annealing" << std::endl;
  std::cout << "[PARAMS] num_actions = " << num_actions << std::endl;
  std::cout << "[PARAMS] max_temperature = " << max_temperature << std::endl;
  std::cout << "[PARAMS] num_iters = " << num_iters << std::endl;
  std::cout << "[PARAMS] seed = " << seed << std::endl;
  std::cout << "[PARAMS] spiral_flag = " << spiral_flag << std::endl;
  std::cout << "[PARAMS] action_probs =  { ";
  for (auto& value : action_probs) 
    std::cout << value << " ";
  std::cout << " } " << std::endl;

  PBFNetlist design(netlist_file);
  std::string new_netlist_file = run_dir + "/" + design_name + ".pb.txt.final";
  std::string new_plc_file = run_dir + "/" + design_name + ".plc.final";
  design.RestorePlacement(plc_file);
  auto start_timestamp_global = std::chrono::high_resolution_clock::now();
  design.SimulatedAnnealing(action_probs, num_actions, max_temperature,
                            num_iters, seed, spiral_flag, summary_file);
  //design.CalcCost();
  auto end_timestamp_global = std::chrono::high_resolution_clock::now();
  double total_global_time
      = std::chrono::duration_cast<std::chrono::nanoseconds>(
            end_timestamp_global - start_timestamp_global)
            .count();
  total_global_time *= 1e-9;
  std::cout << "Runtime of simulated annealing : " << total_global_time << std::endl;
  design.WritePlcFile(new_plc_file);
  design.WriteNetlist(new_netlist_file);
  return 0;
}
