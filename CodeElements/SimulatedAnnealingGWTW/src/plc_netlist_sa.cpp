#include <algorithm>
#include <cmath>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <numeric>
#include <string>
#include <vector>
#include <omp.h>

#include "plc_netlist.h"

// *****************************************************************************
// Safe exponential function
// *****************************************************************************
namespace {
  constexpr float MIN_EXP_INPUT = -15.0f;  // updated minimum input
  constexpr float MAX_EXP_INPUT = 0.0f;      // maximum input remains 0.0
  constexpr int LUT_SIZE = 10001;            // Adjust resolution as needed
  // constexpr float LUT_STEP = (MAX_EXP_INPUT - MIN_EXP_INPUT)/(static_cast<float>(LUT_SIZE) - 1.0f);
  constexpr float LUT_STEP = 1.5e-3f;  // updated step size

  float safeExpLUT[LUT_SIZE];

  bool loadSafeExpTable(const char* filename) {
    std::ifstream in(filename, std::ios::binary);
    if (!in.is_open())
      return false;
    in.read(reinterpret_cast<char*>(safeExpLUT), sizeof(safeExpLUT));
    bool success = (in.gcount() == sizeof(safeExpLUT));
    in.close();
    return success;
  }

  bool saveSafeExpTable(const char* filename) {
    std::ofstream out(filename, std::ios::binary);
    if (!out.is_open())
      return false;
    out.write(reinterpret_cast<const char*>(safeExpLUT), sizeof(safeExpLUT));
    bool success = out.good();
    out.close();
    return success;
  }

  struct SafeExpInitializer {
      SafeExpInitializer() {
          const char* tableFile = "safe_exp_table.bin";
          if (!loadSafeExpTable(tableFile)) {
              // Compute the lookup table
              for (int i = 0; i < LUT_SIZE; ++i) {
                  float x = MIN_EXP_INPUT + i * LUT_STEP;
                  safeExpLUT[i] = std::exp(x);
              }
              // Write out the table for future runs
              saveSafeExpTable(tableFile);
          }
      }
  } safeExpInitializer; // Global initializer; runs at startup.
}

inline float safeExp(float x) {
  if (x >= 0.0f)
      return 1.0f;
  if (x <= MIN_EXP_INPUT)
      return safeExpLUT[0];
  int index = static_cast<int>((x - MIN_EXP_INPUT) / LUT_STEP);
  return safeExpLUT[index];
}

// *****************************************************************************
// Compare PLCNetlist objects
// *****************************************************************************
void PBFNetlist::Compare(const PBFNetlist &other) const {
  if (n_cols_ != other.n_cols_) {
    std::cout << "Number of columns are different: " << n_cols_ << " vs "
              << other.n_cols_ << std::endl;
  }

  if (n_rows_ != other.n_rows_) {
    std::cout << "Number of rows are different: " << n_rows_ << " vs "
              << other.n_rows_ << std::endl;
  }

  if (grid_width_ != other.grid_width_) {
    std::cout << "Grid width is different: " << grid_width_ << " vs "
              << other.grid_width_ << std::endl;
  }

  if (grid_height_ != other.grid_height_) {
    std::cout << "Grid height is different: " << grid_height_ << " vs "
              << other.grid_height_ << std::endl;
  }

  if (macros_.size() != other.macros_.size()) {
    std::cout << "Number of macros are different: " << macros_.size() << " vs "
              << other.macros_.size() << std::endl;
  }

  if (ports_.size() != other.ports_.size()) {
    std::cout << "Number of IOs are different: " << ports_.size() << " vs "
              << other.ports_.size() << std::endl;
  }

  if (stdcell_clusters_.size() != other.stdcell_clusters_.size()) {
    std::cout << "Number of soft clusters are different: "
              << stdcell_clusters_.size() << " vs "
              << other.stdcell_clusters_.size() << std::endl;
  }

  // Compare macros
  for (size_t i = 0; i < macros_.size(); ++i) {
    objects_[macros_[i]]->Compare(*other.objects_[other.macros_[i]]);
  }

  // Compare standard cell clusters
  // for (size_t i = 0; i < stdcell_clusters_.size(); ++i) {
  //   objects_[stdcell_clusters_[i]]->Compare(*other.objects_[other.stdcell_clusters_[i]]);
  // }

  // Compare IOs
  for (size_t i = 0; i < ports_.size(); ++i) {
    objects_[ports_[i]]->Compare(*other.objects_[other.ports_[i]]);
  }

  // Compare macro pins
  for (size_t i = 0; i < macros_.size(); ++i) {
    for (size_t j = 0; j < objects_[macros_[i]]->macro_pins_.size(); ++j) {
      objects_[macros_[i]]->macro_pins_[j]->Compare(
          *other.objects_[other.macros_[i]]->macro_pins_[j]);
    }
  }
}

void PBFNetlist::comparePBFNetlist(std::unique_ptr<PBFNetlist> &worker) {
  Compare(*worker);
}

// Class PBFNetlist
// ***************************************************************************
// Simulated Annealing
// ***************************************************************************

// Simulated Annealing related functions
void PBFNetlist::InitMacroPlacement(bool spiral_flag) {
  // determine the order of grids
  for (auto &grid : grids_)
    grid->available_ = true;
  placed_macros_.clear();
  std::vector<int> grid_order(grids_.size());
  if (spiral_flag == true) {
    // arrange grid in a spiral manner
    std::vector<bool> visited_flag(grids_.size(), false);
    // direction in a counter clock-wise manner
    std::vector<int> dir_row{0, 1, 0, -1};
    std::vector<int> dir_col{1, 0, -1, 0};
    int row_id = 0;
    int col_id = 0;
    int dir_id = 0;
    for (int i = 0; i < n_cols_ * n_rows_; i++) {
      const int grid_id = row_id * n_cols_ + col_id;
      visited_flag[grid_id] = true;
      grid_order[i] = grid_id;
      const int next_row = row_id + dir_row[dir_id];
      const int next_col = col_id + dir_col[dir_id];
      const int next_grid_id = next_row * n_cols_ + next_col;
      if (0 <= next_row && next_row < n_rows_ && 0 <= next_col &&
          next_col < n_cols_ && visited_flag[next_grid_id] == false) {
        col_id = next_col;
        row_id = next_row;
      } else {
        dir_id = (dir_id + 1) % 4;
        row_id += dir_row[dir_id];
        col_id += dir_col[dir_id];
      }
    }
  } else {
    std::iota(grid_order.begin(), grid_order.end(), 0);
  }

  std::vector<size_t> sorted_macros = macros_;
  // Shuffle the macros
  std::shuffle(sorted_macros.begin(), sorted_macros.end(), generator_);

  // sort macros based on area in an non-decreasing order
  std::sort(sorted_macros.begin(), sorted_macros.end(), [&](size_t a, int b) {
    return objects_[a]->width_ * objects_[a]->height_ >
           objects_[b]->width_ * objects_[b]->height_;
  });
  for (auto &macro : sorted_macros) {
    for (auto &grid_id : grid_order) {
      if (grids_[grid_id]->available_ == false)
        continue; // this grid has been occupied by other macros
      objects_[macro]->SetPos(grids_[grid_id]->x_, grids_[grid_id]->y_,
                              grid_width_, grid_height_, n_cols_, n_rows_);
      auto &rect = objects_[macro]->bbox_;
      if (rect.lx < 0.0 || rect.ly < 0.0 || rect.ux > canvas_width_ ||
          rect.uy > canvas_height_)
        continue;
      // check if there is an overlap with other macros
      if (CheckOverlap(macro) == true)
        continue; // This is some overlap with other placed macros
      // place macro on this grid
      grids_[grid_id]->available_ = false;
      placed_macros_.push_back(macro);
      break;
    }
  } // placed all the macros
  if (placed_macros_.size() != macros_.size()) {
    std::cout << "[ERROR] There is no valid initial macro tiling" << std::endl;
  }
}

bool PBFNetlist::CheckOverlap(size_t macro) {
  if (placed_macros_.empty() == true)
    return false;
  for (auto &placed_macro : placed_macros_) {
    if (macro == placed_macro)
      continue;
    auto &rect1 = objects_[placed_macro]->bbox_;
    auto &rect2 = objects_[macro]->bbox_;
    if (rect1.lx > rect2.ux || rect1.ly > rect2.uy || rect1.ux < rect2.lx ||
        rect1.uy < rect2.ly)
      continue; // This is no overlap
    else
      return true;
  }
  return false;
}

bool PBFNetlist::IsFeasible(size_t macro) {
  if (objects_[macro]->bbox_.lx < 0.0 || objects_[macro]->bbox_.ly < 0.0 ||
      objects_[macro]->bbox_.ux > canvas_width_ ||
      objects_[macro]->bbox_.uy > canvas_height_)
    return false;
  if (CheckOverlap(macro) == true)
    return false;
  return true;
}

bool PBFNetlist::Shuffle() {
  // find four macros randomly
  std::vector<int> random_macros;
  while (random_macros.size() < 4) {
    const int macro_id = static_cast<int>(
        std::floor(distribution_(generator_) * macros_.size()));
    if (std::find(random_macros.begin(), random_macros.end(), macro_id) ==
        random_macros.end())
      random_macros.push_back(macros_[macro_id]);
  }
  // get the positions of macros
  std::vector<std::pair<float, float>> macro_pos;
  for (auto &macro_id : random_macros) {
    const std::pair<float, float> pos{objects_[macro_id]->x_,
                                      objects_[macro_id]->y_};
    macro_pos.push_back(pos);
    pre_locs_[macro_id] = pos;
  }

  // randomly shuffle the locations
  std::shuffle(macro_pos.begin(), macro_pos.end(), generator_);
  // update the locations of macros
  for (size_t i = 0; i < random_macros.size(); i++) {
    objects_[random_macros[i]]->SetPos(macro_pos[i].first, macro_pos[i].second,
                                       grid_width_, grid_height_, n_cols_,
                                       n_rows_);
  }
  // check feasibility
  for (auto &macro_id : random_macros) {
    if (IsFeasible(macro_id) == false) {
      for (auto &loc : pre_locs_) {
        objects_[loc.first]->SetPos(loc.second.first, loc.second.second,
                                    grid_width_, grid_height_, n_cols_,
                                    n_rows_);
      }
      return false;
    }
  }
  action_valid_[4]++;
  return true;
}

// Randomly pick a macro, then shuffle all the neighboring locations
// Try the location one by one. If fail, restore the status
bool PBFNetlist::Shift() {
  // randomly pick a macro
  const int macro_id = macros_[static_cast<int>(
      std::floor(distribution_(generator_) * macros_.size()))];
  // calculate the neighboring locations and randomly shuffle
  std::vector<std::pair<float, float>> neighbor_locs;
  const std::pair<float, float> macro_loc{objects_[macro_id]->x_,
                                          objects_[macro_id]->y_};
  pre_locs_[macro_id] = macro_loc;
  neighbor_locs.push_back(
      std::pair<float, float>(macro_loc.first - grid_width_, macro_loc.second));
  neighbor_locs.push_back(
      std::pair<float, float>(macro_loc.first + grid_width_, macro_loc.second));
  neighbor_locs.push_back(std::pair<float, float>(
      macro_loc.first, macro_loc.second - grid_height_));
  neighbor_locs.push_back(std::pair<float, float>(
      macro_loc.first, macro_loc.second + grid_height_));
  std::shuffle(neighbor_locs.begin(), neighbor_locs.end(), generator_);
  for (auto &loc : neighbor_locs) {
    objects_[macro_id]->SetPos(loc.first, loc.second, grid_width_, grid_height_,
                               n_cols_, n_rows_);
    if (IsFeasible(macro_id) == true) {
      action_valid_[1]++;
      return true;
    }
  }
  // restore the pos
  objects_[macro_id]->SetPos(macro_loc.first, macro_loc.second, grid_width_,
                             grid_height_, n_cols_, n_rows_);
  return false;
}

bool PBFNetlist::Swap() {
  for (int i = 0; i < 5; i++) {
    const int macro_a = macros_[static_cast<int>(
        std::floor(distribution_(generator_) * macros_.size()))];
    const int macro_b = macros_[static_cast<int>(
        std::floor(distribution_(generator_) * macros_.size()))];
    if (macro_a == macro_b)
      continue;
    // store the location
    pre_locs_[macro_a] =
        std::pair<float, float>(objects_[macro_a]->x_, objects_[macro_a]->y_);
    pre_locs_[macro_b] =
        std::pair<float, float>(objects_[macro_b]->x_, objects_[macro_b]->y_);
    // swap the location of macro_a and macro_b
    objects_[macro_a]->SetPos(pre_locs_[macro_b].first,
                              pre_locs_[macro_b].second, grid_width_,
                              grid_height_, n_cols_, n_rows_);
    objects_[macro_b]->SetPos(pre_locs_[macro_a].first,
                              pre_locs_[macro_a].second, grid_width_,
                              grid_height_, n_cols_, n_rows_);

    // check feasbility
    if (IsFeasible(macro_a) == true && IsFeasible(macro_b) == true) {
      action_valid_[i]++;
      return true;
    }

    // restore the location
    objects_[macro_a]->SetPos(pre_locs_[macro_a].first,
                              pre_locs_[macro_a].second, grid_width_,
                              grid_height_, n_cols_, n_rows_);
    objects_[macro_b]->SetPos(pre_locs_[macro_b].first,
                              pre_locs_[macro_b].second, grid_width_,
                              grid_height_, n_cols_, n_rows_);
  }
  return false;
}

// Move a randomly selected macro to a new random location
bool PBFNetlist::Move() {
  const int macro_a = macros_[static_cast<int>(
      std::floor(distribution_(generator_) * macros_.size()))];
  // store the location
  pre_locs_[macro_a] =
      std::pair<float, float>(objects_[macro_a]->x_, objects_[macro_a]->y_);
  // randomly pick a grid
  const int grid_id =
      static_cast<int>(std::floor(distribution_(generator_) * grids_.size()));
  objects_[macro_a]->SetPos(grids_[grid_id]->x_, grids_[grid_id]->y_,
                            grid_width_, grid_height_, n_cols_, n_rows_);
  if (IsFeasible(macro_a) == true) {
    action_valid_[3]++;
    return true;
  }

  // restore the loc
  objects_[macro_a]->SetPos(pre_locs_[macro_a].first, pre_locs_[macro_a].second,
                            grid_width_, grid_height_, n_cols_, n_rows_);
  return false;
}

bool PBFNetlist::Flip() {
  const int macro_a = macros_[static_cast<int>(
      std::floor(distribution_(generator_) * macros_.size()))];
  // store the orienetation
  pre_orients_[macro_a] = objects_[macro_a]->orient_;
  const float prob = distribution_(generator_);
  if (prob <= 0.33) {
    objects_[macro_a]->Flip(true, grid_width_, grid_height_, n_cols_, n_rows_);
  } else if (prob <= 0.66) {
    objects_[macro_a]->Flip(false, grid_width_, grid_height_, n_cols_, n_rows_);
  } else {
    objects_[macro_a]->Flip(true, grid_width_, grid_height_, n_cols_, n_rows_);
    objects_[macro_a]->Flip(false, grid_width_, grid_height_, n_cols_, n_rows_);
  }
  action_valid_[2]++;
  return true;
}

bool PBFNetlist::Action() {
  pre_orients_.clear();
  pre_locs_.clear();
  const float prob = distribution_(generator_);
  if (prob <= action_probs_[0]) {
    action_type_ = 0;
    action_tried_[0]++;
    return Swap();
  } else if (prob <= action_probs_[1]) {
    action_type_ = 1;
    action_tried_[1]++;
    return Shift();
  } else if (prob <= action_probs_[2]) {
    action_type_ = 2;
    action_tried_[2]++;
    return Flip();
  } else if (prob <= action_probs_[3]) {
    action_type_ = 3;
    action_tried_[3]++;
    return Move();
  } else {
    action_type_ = 4;
    action_tried_[4]++;
    return Shuffle();
  }
}

// ------------------- HPWL Incr --------------------
void PBFNetlist::HPWLIncr(std::set<size_t> &nets, bool inverse_flag) {
  // Calculate HPWL for the net
  for (auto &net : nets) {
    nets_[net]->UpdateHPWL();
    if (inverse_flag == false) {
      HPWL_ += nets_[net]->HPWL_;
    } else {
      HPWL_ -= nets_[net]->HPWL_;
    }
  }
}

// --------------- Density Incr ---------------
void PBFNetlist::DensityIncrCost(const std::vector<size_t> &macro_ids,
                                 bool add_flag) {
  for (auto &node_id : macro_ids) {
    const Rect rect = objects_[node_id]->GetBBox();
    const GridRect grid_bbox = objects_[node_id]->grid_bbox_;

    // Update overlap in each grid cell covered by this macro
    for (int y_id = grid_bbox.ly_id; y_id <= grid_bbox.uy_id; y_id++) {
      for (int x_id = grid_bbox.lx_id; x_id <= grid_bbox.ux_id; x_id++) {
        // add_flag = true -> add overlap, false -> remove overlap
        grids_[y_id * n_cols_ + x_id]->UpdateOverlap(rect, add_flag);
      }
    }
  }
}

// --------------- Congestion Incr ---------------
void PBFNetlist::CongestionIncrCost(const std::set<size_t> &nets,
                                    const std::vector<size_t> &macro_ids,
                                    bool add_flag) {
  // Update routing congestion for nets
  for (auto &net_id : nets) {
    UpdateRouting(nets_[net_id], add_flag);
  }

  // Update macro-induced congestion
  for (auto &macro_id : macro_ids) {
    UpdateMacroCongestion(objects_[macro_id], add_flag);
  }
}

// ------------------- Update Density Cost --------------------
void PBFNetlist::UpdateDensityCost() {
  // get the top 10 % density
  std::vector<float> density_list;
  density_list.reserve(grids_.size());

  for (auto &grid : grids_)
    density_list.push_back(grid->GetDensity());
  // std::sort(density_list.begin(), density_list.end(), std::greater<float>());
  std::nth_element(density_list.begin(), density_list.begin() + top_k_,
                   density_list.end(), std::greater<float>());
  density_ = 0.0;
  for (int i = 0; i < top_k_; i++)
    density_ += density_list[i];
  density_ = density_ / top_k_ * 0.5;
}

// ------------------- Smooth Congestion Cost --------------------
void PBFNetlist::SmoothCongestion() {
  // smooth the congestion by net
  for (auto &grid : grids_) {
    // smooth vertical congestion
    const int col_id = grid->x_id_;
    const int row_id = grid->y_id_;
    const int v_start = std::max(0, grid->x_id_ - smooth_factor_);
    const int v_end = std::min(n_cols_ - 1, grid->x_id_ + smooth_factor_);
    const float ver_congestion = grid->ver_congestion_ / (v_end - v_start + 1);

    for (int i = v_start; i <= v_end; i++)
      grids_[row_id * n_cols_ + i]->smooth_ver_congestion_ += ver_congestion;

    const int h_start = std::max(0, grid->y_id_ - smooth_factor_);
    const int h_end = std::min(n_rows_ - 1, grid->y_id_ + smooth_factor_);
    const float hor_congestion = grid->hor_congestion_ / (h_end - h_start + 1);
    for (int j = h_start; j <= h_end; j++)
      grids_[j * n_cols_ + col_id]->smooth_hor_congestion_ += hor_congestion;
  }
}

// ------------------- Update Congestion Cost --------------------
void PBFNetlist::UpdateCongestionCost() {
  // get the top 0.1 congestion
  std::vector<float> congestion_list;
  congestion_list.reserve(grids_.size() * 2);
  for (auto &grid : grids_) {
    congestion_list.push_back(
        (grid->smooth_ver_congestion_ + grid->macro_ver_congestion_) /
        (grid_width_ * vroute_per_micro_));
    congestion_list.push_back(
        (grid->smooth_hor_congestion_ + grid->macro_hor_congestion_) /
        (grid_height_ * hroute_per_micro_));
  }

  // std::sort(congestion_list.begin(), congestion_list.end(),
  //           std::greater<float>());

  // Partition so that the first top_k_congestion_ entries are the largest
  // (unsorted)
  std::nth_element(congestion_list.begin(),
                   congestion_list.begin() + top_k_congestion_,
                   congestion_list.end(), std::greater<float>());
  congestion_ = 0.0;
  for (int i = 0; i < top_k_congestion_; i++)
    congestion_ += congestion_list[i];
  congestion_ = congestion_ / top_k_congestion_;
}

// ------------------- Update Location Orientation --------------------
void PBFNetlist::LocAndOrrientUpdate(
    const std::unordered_map<size_t, std::pair<float, float>> &cur_locs,
    const std::unordered_map<size_t, ORIENTATION> &cur_orient) {
  for (auto &value : cur_locs) {
    const int macro_id = value.first;
    objects_[macro_id]->SetPos(value.second.first, value.second.second,
                               grid_width_, grid_height_, n_cols_, n_rows_);
  }

  for (auto &value : cur_orient) {
    const int macro_id = value.first;
    objects_[macro_id]->orient_ = value.second;
    objects_[macro_id]->UpdateOrientation(grid_width_, grid_height_, n_cols_,
                                          n_rows_);
  }
}

void PBFNetlist::getLocAndOrient(
    std::unordered_map<size_t, std::pair<float, float>> &locs,
    std::unordered_map<size_t, ORIENTATION> &orients,
    bool only_hard_macros) const {
  for (auto &macro : macros_) {
    locs[macro] =
        std::pair<float, float>(objects_[macro]->x_, objects_[macro]->y_);
    orients[macro] = objects_[macro]->orient_;
  }
  
  if ( only_hard_macros )
    return;
  
  for (auto &stdcell_cluster : stdcell_clusters_) {
    locs[stdcell_cluster] =
        std::pair<float, float>(objects_[stdcell_cluster]->x_, objects_[stdcell_cluster]->y_);
    orients[stdcell_cluster] = objects_[stdcell_cluster]->orient_;
  }
}

void PBFNetlist::getMacroPinLocs(
    std::unordered_map<size_t, std::pair<float, float>> &locs) {
  for (auto &macro : macros_) {
    for (auto &pin : objects_[macro]->macro_pins_) {
      locs[pin->GetNodeId()] = std::pair<float, float>(pin->x_, pin->y_);
    }
  }
}

float PBFNetlist::CalcCostIncr(bool inverse_flag) {
  std::unordered_map<size_t, std::pair<float, float>> cur_locs;
  std::unordered_map<size_t, ORIENTATION> cur_orient;
  std::vector<size_t> update_macros;
  // Store the affected macro_id, locations and orientations
  for (auto &value : pre_locs_) {
    const int macro_id = value.first;
    update_macros.push_back(macro_id);
    cur_locs[macro_id] =
        std::pair<float, float>(objects_[macro_id]->x_, objects_[macro_id]->y_);
  }

  for (auto &value : pre_orients_) {
    const int macro_id = value.first;
    update_macros.push_back(macro_id);
    cur_orient[macro_id] = objects_[macro_id]->orient_;
  }

  // calculate wirelength cost
  // update the net
  std::set<size_t> nets;
  for (auto &macro_id : update_macros) {
    for (auto &pin : objects_[macro_id]->macro_pins_) {
      for (auto &net : pin->nets_) {
        nets.insert(net);
      }
    }
  }
  /////////////////////////////////////////////////////////////////////////
  // Calculate the HPWL increment
  if (hpwl_weight_ != 0)
    HPWLIncr(nets, inverse_flag);

  // calculate the density
  if (density_weight_ != 0)
    DensityIncrCost(update_macros, !inverse_flag);

  // update the routing
  if (congestion_weight_ != 0)
    CongestionIncrCost(nets, update_macros, !inverse_flag);

  // We need to remove the contributions for the pre_objects
  // update the locations
  LocAndOrrientUpdate(pre_locs_, pre_orients_);

  // remove the HPWL contributed by previous locs
  if (hpwl_weight_ != 0)
    HPWLIncr(nets, !inverse_flag);

  // calculate the density
  if (density_weight_ != 0)
    DensityIncrCost(update_macros, inverse_flag);

  // update the routing
  if (congestion_weight_ != 0)
    CongestionIncrCost(nets, update_macros, inverse_flag);

  if (inverse_flag == true)
    return 0.0f;

  // Update the density cost
  if (density_weight_ != 0)
    UpdateDensityCost();

  // Update the congestion cost
  if (congestion_weight_ != 0) {
    // Reset smooth congestion
    for (auto &grid : grids_) {
      grid->smooth_hor_congestion_ = 0.0;
      grid->smooth_ver_congestion_ = 0.0;
    }
    SmoothCongestion();
    UpdateCongestionCost();
  }

  float cost = hpwl_weight_ * (HPWL_ / norm_HPWL_) +
               density_weight_ * density_ + congestion_weight_ * congestion_;

  // Print the cost
  if (debug_mode_ == true) {
    std::cout << "Incremental Cost = " << cost << "  "
              << "HPWL = " << HPWL_ / norm_HPWL_ << "  "
              << "density = " << density_ << "  "
              << "congestion = " << congestion_ << std::endl;
  }

  // restore the locations back
  LocAndOrrientUpdate(cur_locs, cur_orient);

  return cost;
}

void PBFNetlist::Restore() {
  CalcCostIncr(true);
  for (auto &macro_pos : pre_locs_)
    objects_[macro_pos.first]->SetPos(
        pre_locs_[macro_pos.first].first, pre_locs_[macro_pos.first].second,
        grid_width_, grid_height_, n_cols_, n_rows_);
  for (auto &macro_orient : pre_orients_) {
    objects_[macro_orient.first]->orient_ = pre_orients_[macro_orient.first];
    objects_[macro_orient.first]->UpdateOrientation(grid_width_, grid_height_,
                                                    n_cols_, n_rows_);
  }
}

// Initialize the worker
void PBFNetlist::initWorker(int worker_id, std::vector<float> action_probs,
                            unsigned int num_actions, float max_temperature,
                            float cooling_rate, unsigned int num_iters,
                            int seed, bool spiral_flag,
                            std::string summary_file) {
  worker_id_ = worker_id;
  action_probs_ = action_probs;
  for (size_t i = 1; i < action_probs_.size(); i++)
    action_probs_[i] += action_probs_[i - 1];
  seed_ = seed;
  std::mt19937 generator(seed_);
  generator_ = generator;

  // Initialization
  num_step_per_iter_ = num_actions * macros_.size();
  num_iters_ = num_iters;
  temp_ = max_temperature;
  cooling_rate_ = cooling_rate;
  summary_file_ = summary_file;
  // Initialize the macro locations
  InitMacroPlacement(spiral_flag);

  if (debug_mode_ == true)
    std::cout << "[Worker ID] " << worker_id_ << std::endl;
  else
    return;

  std::cout << "[SA Params] Action probabilities : ";
  for (auto &prob : action_probs)
    std::cout << prob << "   ";
  std::cout << std::endl;
  std::cout << "[SA Params] num_actions = " << num_actions << std::endl;
  std::cout << "[SA Params] max_temperature = " << max_temperature << std::endl;
  std::cout << "[SA Params] num_iters = " << num_iters << std::endl;
  std::cout << "[SA Params] seed = " << seed << std::endl;
  std::cout << "[SA Params] spiral_flag = " << spiral_flag << std::endl;
  std::cout << "[SA Params] summary_file = " << summary_file << std::endl;
}

// // define the same guardband
// float safeExp(float x) {
//   x = std::min(x, 50.0f);
//   x = std::max(x, -50.0f);
//   return std::exp(x);
// }

void PBFNetlist::writeCostSummary(std::string file_name) {
  if (file_name.empty() == true)
    file_name = summary_file_;

  std::ofstream f;
  f.open(file_name, std::ios::out);
  for (auto &value : cost_list_)
    f << value << std::endl;
  f.close();
}

void PBFNetlist::reportActoinDetails() {
  // Print action_tried_ action_valid_ action_accepted_ for each action
  // 0 is Swap, 1 is Shift, 2 is Flip, 3 is Move, 4 is Shuffle
  int total_tried = 0;
  int total_accepted = 0;
  for (int i = 0; i < 5; i++) {
    total_tried += action_tried_[i];
    total_accepted += action_accepted_[i];
  }

  std::cout << "[Action] Swap: " << action_tried_[0] << " " << action_valid_[0]
            << " " << action_accepted_[0] << " "
            << (action_accepted_[0] * 100.0 / action_tried_[0]) << "%"
            << std::endl;
  std::cout << "[Action] Shift: " << action_tried_[1] << " " << action_valid_[1]
            << " " << action_accepted_[1] << " "
            << (action_accepted_[1] * 100.0 / action_tried_[1]) << "%"
            << std::endl;
  std::cout << "[Action] Flip: " << action_tried_[2] << " " << action_valid_[2]
            << " " << action_accepted_[2] << " "
            << (action_accepted_[2] * 100.0 / action_tried_[2]) << "%"
            << std::endl;
  std::cout << "[Action] Move: " << action_tried_[3] << " " << action_valid_[3]
            << " " << action_accepted_[3] << " "
            << (action_accepted_[3] * 100.0 / action_tried_[3]) << "%"
            << std::endl;
  std::cout << "[Action] Shuffle: " << action_tried_[4] << " "
            << action_valid_[4] << " " << action_accepted_[4] << " "
            << (action_accepted_[4] * 100.0 / action_tried_[4]) << "%"
            << std::endl;
  std::cout << "[Overall Acceptance] " << (total_accepted * 100.0 / total_tried)
            << "%" << std::endl;
}

void PBFNetlist::UpdateBest() {
  if (cur_cost_ > best_cost_ ) {
    this->LocAndOrrientUpdate(best_locs_, best_orients_);
    cur_cost_ = best_cost_;
  }
}

void PBFNetlist::SimulatedAnnealing(bool &is_sync, bool is_print,
                      int start_iter, int end_iter) {
  
  // calculate temperature updating factor firstly
  const int N = num_step_per_iter_;
  float cur_cost = 0.0;
  float hpwl_cost = 0.0;
  float density_cost = 0.0;
  float congestion_cost = 0.0;
  
  if ( start_iter == end_iter || end_iter == 0 ) {
    start_iter = 0;
    end_iter = num_iters_;
  }

  // CallFDPlacer();
  cur_cost = CalcCost();
  // float best_cost = cur_cost;
  if ( track_best_ && best_cost_ > cur_cost ) {
    best_cost_ = cur_cost;
    getLocAndOrient(best_locs_, best_orients_, false);
  }

  for (int num_iter = start_iter; num_iter < end_iter && !is_sync; num_iter++) {
    for (int step = 0; step < N && !is_sync; step++) {
      // Adding cost here give us idea how FDPlacer affects cost function
      cost_list_.push_back(cur_cost);
      if (Action() == true) {
        const float new_cost = CalcCostIncr(false);
        if (new_cost < cur_cost) {
          cur_cost = new_cost;
        }
        float prob = safeExp((cur_cost - new_cost) / temp_);
        if (prob < distribution_(generator_)) {
          Restore();
        } else {
          action_accepted_[action_type_]++; // update the action accepted
          cur_cost = new_cost;
          hpwl_cost = HPWL_;
          density_cost = density_;
          congestion_cost = congestion_;
        }
      }
    }
    // call FDPlacer to update the cost
    CallFDPlacer();
    cur_cost_ = CalcCost();
    cur_cost = cur_cost_;
    temp_ = temp_ * cooling_rate_;
    if ( track_best_ ) {
      if (cur_cost < best_cost_) {
        best_cost_ = cur_cost;
        getLocAndOrient(best_locs_, best_orients_, false);
        // Save the checkpoint here
        // std::string cp_file = "./checkpoint_" + std::to_string(worker_id_) + ".cp";
        // saveCheckpoint(cp_file);
      }
    }
    
#pragma omp critical 
{
    if (is_print == true) {
      std::cout << "[Worker ID] " << worker_id_ << "  "
                << "[Final Cost] " << cur_cost << "  " << "[Iter] " << num_iter
                << "  " << "[HPWL] " << hpwl_cost / norm_HPWL_ << "  "
                << "[Density] " << density_cost << "  "
                << "[Congestion] " << congestion_cost << std::endl;
    }
}
  }
  cost_list_.push_back(cur_cost);
}