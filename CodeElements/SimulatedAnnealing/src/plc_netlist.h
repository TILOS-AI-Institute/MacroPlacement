#pragma once
#include <vector>
#include <map>
#include <iostream>
#include <string>
#include <fstream>
#include <sstream>
#include <algorithm>
#include <cmath>
#include <memory>
#include <random>
#include <set>
#include <cassert>

#include "basic_object.h"
#include "net.h"
#include "grid.h"
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
                  std::vector<float> repel_factor,
                  bool use_current_loc, 
                  bool debug_mode = true);
   
     // wrapper function for FDPlacer
    void CallFDPlacer() {
      const float io_factor = 1.0;
      const std::vector<int> num_steps { 100, 100, 100 };
      const std::vector<float> attract_factor { 100.0, 1.0e-3, 1.0e-5 };
      const std::vector<float> repel_factor { 0.0, 1.0e6, 1.0e7 };
      const std::vector<float> move_distance_factor { 1.0, 1.0, 1.0 };
      const bool use_current_loc = false;
      const bool debug_mode = false;
      FDPlacer(io_factor, num_steps, move_distance_factor,
               attract_factor, repel_factor,
               use_current_loc, debug_mode);      
    };

    // Simulated Annealing
    void SimulatedAnnealing(std::vector<float> action_probs, 
                            unsigned int num_actions,
                            float max_temperature,
                            unsigned int num_iters,
                            int seed, 
                            bool spiral_flag,
                            std::string summary_file, 
                            std::string plc_file);
    // calculate the cost
    float CalcCost(bool debug_mode = false);

    // Write the netilist and plc file
    void WriteNetlist(std::string file_name);
    void WritePlcFile(std::string file_name);
  
  private:
    // information from protocol buffer netlist
    std::string pb_netlist_header_ = "";
    std::vector<std::shared_ptr<PlcObject> > objects_;
    std::vector<std::shared_ptr<PlcObject> > pre_objects_;
    std::vector<size_t> macros_;
    std::vector<size_t> stdcell_clusters_;
    std::vector<size_t> macro_clusters_;
    std::vector<size_t> ports_;
    std::vector<size_t> placed_macros_;
    std::vector<std::shared_ptr<Net> > nets_;
    std::vector<std::shared_ptr<Grid> > grids_;
    
    // information from plc file
    std::string plc_header_ = "";
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
    const float min_dist_ = 1e-4; // defined by circuit training

    // random seed setting
    int seed_ = 0;
    std::mt19937 generator_;
    std::uniform_real_distribution<float> distribution_;

    // cost function
    float HPWL_ = 0.0;
    float norm_HPWL_ = 1.0;
    int top_k_ = 1;
    float density_ = 0.0;
    int top_k_congestion_ = 1;
    float congestion_ = 0.0;
    
    // probabilities
    std::vector<float> action_probs_ { 0.0, 0.0, 0.0, 0.0, 0.0 };
    std::map<size_t, std::pair<float, float> > pre_locs_;
    std::map<size_t, ORIENTATION> pre_orients_;

    // utility functions
    void ParseNetlistFile(std::string netlist_pbf_file);
    
    
    // Force-directed placement
    void InitSoftMacros(); // put all the soft macros to the center of canvas
    void CalcAttractiveForce(float attractive_factor, float io_factor, float max_displacement);
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
    bool Shift(); // randomly pick a macro, then shuffle all the neighbor locations
    bool Swap(); // Randomly pick two macros and swap them
    bool Move(); // Move to a ramdom position
    bool Flip();
    float CalcCostIncr(bool inverse_flag = false);
};
