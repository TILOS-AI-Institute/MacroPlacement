#pragma once
#include <algorithm>
#include <cassert>
#include <cmath>
#include <fstream>
#include <iostream>
#include <map>
#include <unordered_map>
#include <memory>
#include <random>
#include <set>
#include <sstream>
#include <string>
#include <vector>

// cereal includes
#include <cereal/archives/binary.hpp>
#include <cereal/types/string.hpp>
#include <cereal/types/vector.hpp>
#include <cereal/types/map.hpp>
#include <cereal/types/unordered_map.hpp>
#include <cereal/types/memory.hpp>
#include <cereal/types/set.hpp>
#include <cereal/types/utility.hpp>

#include "basic_object.h"
#include "grid.h"
#include "net.h"
#include "plc_object.h"

class PlcObject;
class Net;
class Grid;

// Class PBFNetlist representing the netlist
class PBFNetlist {
public:
  PBFNetlist(std::string netlist_pbf_file) {
    ParseNetlistFile(netlist_pbf_file);
  }

  void RestorePlacement(std::string file_name);

  void FDPlacer(float io_factor, std::vector<int> num_steps,
                std::vector<float> move_distance_factor,
                std::vector<float> attract_factor,
                std::vector<float> repel_factor, bool use_current_loc,
                bool debug_mode = true);

  // wrapper function for FDPlacer
  void CallFDPlacer() {
    const float io_factor = 1.0;
    const std::vector<int> num_steps{100, 100, 100};
    const std::vector<float> attract_factor{100.0, 1.0e-3, 1.0e-5};
    const std::vector<float> repel_factor{0.0, 1.0e6, 1.0e7};
    const std::vector<float> move_distance_factor{1.0, 1.0, 1.0};
    const bool use_current_loc = false;
    const bool debug_mode = false;
    FDPlacer(io_factor, num_steps, move_distance_factor, attract_factor,
             repel_factor, use_current_loc, debug_mode);
  };

  // Simulated Annealing
  void SimulatedAnnealing(bool &is_sync, bool is_print = false,
                          int start_iter = 0, int end_iter = 0);
  // calculate the cost
  float CalcCost(bool debug_mode = false);
  void initWorker(int worker_id, std::vector<float> action_probs,
                  unsigned int num_actions, float max_temperature,
                  float cooling_rage, unsigned int num_iters, int seed,
                  bool spiral_flag, std::string summary_file);

  void getLocAndOrient(std::unordered_map<size_t, std::pair<float, float>> &locs,
                       std::unordered_map<size_t, ORIENTATION> &orients,
                       bool only_hard_macros = true) const;

  void getMacroPinLocs(std::unordered_map<size_t, std::pair<float, float>> &locs);

  // Write the netilist and plc file
  void WriteNetlist(std::string file_name);
  void WritePlcFile(std::string file_name);
  void setWeight(float hpwl_weight, float density_weight,
                 float congestion_weight) {
    hpwl_weight_ = hpwl_weight;
    density_weight_ = density_weight;
    congestion_weight_ = congestion_weight;
  };
  void writeCostSummary(std::string file_name = "");

  void
  LocAndOrrientUpdate(const std::unordered_map<size_t, std::pair<float, float>> &cur_locs,
                      const std::unordered_map<size_t, ORIENTATION> &cur_orient);
  int getWorkerID() { return worker_id_; }
  float getCost() { return cur_cost_; }
  float getTemp() { return temp_; }
  void reportActoinDetails();

  // Function to compare two PBFNetlist instances
  void Compare(const PBFNetlist& other) const;
  void comparePBFNetlist(std::unique_ptr<PBFNetlist> &worker);
  void initializeMacroOrer();
  void setTrackBest(bool track_best) { track_best_ = track_best; }
  void UpdateBest();

  // Save the current state to a file
  void saveCheckpoint(const std::string &file_name);

  // Load the state from a file
  void loadCheckpoint(const std::string &file_name);

  // Serialization method using cereal.
  template<class Archive>
  void save(Archive & ar) const {
    ar(seed_, temp_, cooling_rate_);

    std::unordered_map<size_t, std::pair<float, float>> locs;
    std::unordered_map<size_t, ORIENTATION> orients;
    getLocAndOrient(locs, orients, false);
    ar(locs, orients);
    // Archive the random number generator's state.
    std::stringstream ss;
    ss << generator_;
    std::string rngState = ss.str();
    ar(rngState);
  }

  template <class Archive>
  void load(Archive & ar) {
    ar(seed_, temp_, cooling_rate_);
    std::unordered_map<size_t, std::pair<float, float>> locs;
    std::unordered_map<size_t, ORIENTATION> orients;
    ar(locs, orients);
    LocAndOrrientUpdate(locs, orients);
    cur_cost_ = CalcCost();
    // Load the random number generator's state.
    std::string rngState;
    ar(rngState);
    std::stringstream ss(rngState);
    ss >> generator_;
  }

private:
  // information from protocol buffer netlist
  std::string pb_netlist_header_ = "";
  std::vector<std::shared_ptr<PlcObject>> objects_;
  std::vector<std::shared_ptr<PlcObject>> pre_objects_;
  std::vector<size_t> macros_;
  // stdcell clusters are soft macros
  std::vector<size_t> stdcell_clusters_;
  // Macro Cluster is consists of macros and stdcell_clusters
  std::vector<size_t> macro_clusters_;
  std::vector<size_t> ports_;
  std::vector<size_t> placed_macros_;
  std::vector<std::shared_ptr<Net>> nets_;
  std::vector<std::shared_ptr<Grid>> grids_;
  std::vector<float> cost_list_;
  // information from plc file
  std::string plc_header_ = "";
  int worker_id_ = -1;
  int accepted_count_ = 0;
  bool debug_mode_ = false;
  
  // Swap, Shift, Flip, Move, Shuffle
  int action_type_ = -1;
  std::vector<int> action_tried_ = {0, 0, 0, 0, 0};
  std::vector<int> action_valid_ = {0, 0, 0, 0, 0};
  std::vector<int> action_accepted_ = {0, 0, 0, 0, 0};
  int n_cols_ = -1;
  int n_rows_ = -1;
  float canvas_width_ = 0.0;
  float canvas_height_ = 0.0;
  float grid_width_ = 0.0;
  float grid_height_ = 0.0;
  // routing information
  int smooth_factor_ = 2;
  float overlap_threshold_ = 0.0;
  float vrouting_alloc_ = 0.0;
  float hrouting_alloc_ = 0.0;
  float hroute_per_micro_ = 0.0;
  float vroute_per_micro_ = 0.0;
  float hpwl_weight_ = 1.0;
  float density_weight_ = 0.5;
  float congestion_weight_ = 0.5;
  const float min_dist_ = 1e-4; // defined by circuit training
  float cooling_rate_ = 0.0;
  int num_step_per_iter_ = 0;
  int num_iters_ = 0;
  float temp_ = 0.0;
  float cur_cost_ = 0.0;
  float best_cost_ = 1e9;

  // random seed setting
  int seed_ = 0;
  std::mt19937 generator_;
  std::uniform_real_distribution<float> distribution_;

  // Summary file and output plc_file
  std::string summary_file_ = "";

  // cost function
  float HPWL_ = 0.0;
  float norm_HPWL_ = 1.0;
  int top_k_ = 1;
  float density_ = 0.0;
  int top_k_congestion_ = 1;
  float congestion_ = 0.0;
  bool track_best_ = false;

  std::unordered_map<size_t, std::pair<float, float>> best_locs_;
  std::unordered_map<size_t, ORIENTATION> best_orients_;

  // probabilities
  std::vector<float> action_probs_{0.0, 0.0, 0.0, 0.0, 0.0};
  std::unordered_map<size_t, std::pair<float, float>> pre_locs_;
  std::unordered_map<size_t, ORIENTATION> pre_orients_;

  // utility functions
  void ParseNetlistFile(std::string netlist_pbf_file);

  // Force-directed placement
  void InitSoftMacros(); // put all the soft macros to the center of canvas
  
  void CalcAttractiveForce(float attractive_factor, float io_factor,
                           float max_displacement);
  void CalcRepulsiveForce(float repulsive_factor, float max_displacement);
  void MoveSoftMacros(float attractive_factor, float repulsive_factor,
                      float io_factor, float max_displacement);
  void MoveNode(size_t node_id, float x_dist, float y_dist);

  // Cost Related information
  // Routing congestion
  void TwoPinNetRouting(LOC src_loc, LOC sink_loc, float weight, bool flag);
  void UpdateRouting(std::shared_ptr<Net> net, bool flag = true);
  void UpdateMacroCongestion(std::shared_ptr<PlcObject> plc_object, bool flag);

  // Simulated Annealing related macros
  void InitMacroPlacement(bool spiral_flag = true);
  bool Action();
  void Restore();
  bool CheckOverlap(size_t macro);
  bool IsFeasible(size_t macro);
  // actions
  bool Shuffle(); // permute 4 macros at a time
  // randomly pick a macro, then shuffle all the neighbor locations
  bool Shift(); 
  bool Swap(); // Randomly pick two macros and swap them
  bool Move(); // Move to a ramdom position
  bool Flip();
  void HPWLIncr(std::set<size_t> &nets, bool inverse_flag);
  void DensityIncrCost(const std::vector<size_t> &macro_ids, bool add_flag);
  void CongestionIncrCost(const std::set<size_t> &nets,
                          const std::vector<size_t> &macro_ids, bool add_flag);
  void UpdateDensityCost();
  void SmoothCongestion();
  void UpdateCongestionCost();
  float CalcCostIncr(bool inverse_flag = false);
};
