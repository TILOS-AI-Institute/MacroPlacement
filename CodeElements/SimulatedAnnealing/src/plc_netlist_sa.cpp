#include <iostream>
#include <map>
#include <vector>
#include <string>
#include <fstream>
#include <iomanip>
#include <algorithm>
#include <cmath>
#include <numeric>

#include "plc_netlist.h"


// Class PBFNetlist
// ***************************************************************************
// Simulated Annealing
// ***************************************************************************

// Simulated Annealing related functions
void PBFNetlist::InitMacroPlacement(bool spiral_flag) {
  // determine the order of grids
  for (auto& grid : grids_)
    grid->available_ = true;
  placed_macros_.clear();
  std::vector<int> grid_order(grids_.size());
  if (spiral_flag == true) {
    // arrange grid in a spiral manner
    std::vector<bool> visited_flag(grids_.size(), false);
    // direction in a counter clock-wise manner
    std::vector<int> dir_row { 0, 1, 0, -1};
    std::vector<int> dir_col { 1, 0, -1, 0};
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
      if (0 <= next_row && next_row < n_rows_ &&
          0 <= next_col && next_col < n_cols_ &&
          visited_flag[next_grid_id] == false) {
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
  // sort macros based on area in an non-decreasing order
  std::sort(sorted_macros.begin(), sorted_macros.end(), 
            [&](size_t a, int b) {
              return objects_[a]->width_ * objects_[a]->height_ >
                     objects_[b]->width_ * objects_[b]->height_;
            });   
  for (auto& macro : sorted_macros) {
    for (auto& grid_id : grid_order) {
      if (grids_[grid_id]->available_ == false) 
        continue; // this grid has been occupied by other macros
      objects_[macro]->SetPos(grids_[grid_id]->x_, grids_[grid_id]->y_, 
                              grid_width_, grid_height_, n_cols_, n_rows_);
      auto& rect = objects_[macro]->bbox_;
      if (rect.lx < 0.0 || rect.ly < 0.0 || rect.ux > canvas_width_ || rect.uy > canvas_height_) 
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
  for (auto& placed_macro : placed_macros_) {
    if (macro == placed_macro)
      continue;
    auto& rect1 = objects_[placed_macro]->bbox_;
    auto& rect2 = objects_[macro]->bbox_;
    if (rect1.lx > rect2.ux || rect1.ly > rect2.uy ||
        rect1.ux < rect2.lx || rect1.uy < rect2.ly)
      continue;  // This is no overlap
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
    const int macro_id = static_cast<int>(std::floor(distribution_(generator_) * macros_.size()));
    if (std::find(random_macros.begin(), random_macros.end(), macro_id) == random_macros.end())
      random_macros.push_back(macros_[macro_id]);
  }
  // get the positions of macros
  std::vector<std::pair<float, float> > macro_pos;
  for (auto& macro_id : random_macros) {
    const std::pair<float, float> pos { objects_[macro_id]->x_, 
                                        objects_[macro_id]->y_  };
    macro_pos.push_back(pos);
    pre_locs_[macro_id] = pos;
  }
  
  // randomly shuffle the locations
  std::shuffle(macro_pos.begin(), macro_pos.end(), generator_);
  // update the locations of macros
  for (size_t i = 0; i < random_macros.size(); i++) {
    objects_[random_macros[i]]->SetPos(macro_pos[i].first, macro_pos[i].second, 
                                       grid_width_, grid_height_, n_cols_, n_rows_);
  }
  // check feasibility
  for (auto& macro_id : random_macros) {
    if (IsFeasible(macro_id) == false) {
      for (auto& loc : pre_locs_) {
        objects_[loc.first]->SetPos(loc.second.first, loc.second.second, grid_width_, grid_height_, n_cols_, n_rows_);        
      }
      return false;
    }
  }
  return true;
}

// Randomly pick a macro, then shuffle all the neighboring locations
// Try the location one by one. If fail, restore the status
bool PBFNetlist::Shift() {
  // randomly pick a macro
  const int macro_id = macros_[static_cast<int>(std::floor(distribution_(generator_) * macros_.size()))];
  // calculate the neighboring locations and randomly shuffle
  std::vector<std::pair<float, float> > neighbor_locs;
  const std::pair<float, float> macro_loc { objects_[macro_id]->x_, objects_[macro_id]->y_ };
  pre_locs_[macro_id] = macro_loc;
  neighbor_locs.push_back(std::pair<float, float>(macro_loc.first - grid_width_, macro_loc.second));
  neighbor_locs.push_back(std::pair<float, float>(macro_loc.first + grid_width_, macro_loc.second));
  neighbor_locs.push_back(std::pair<float, float>(macro_loc.first, macro_loc.second - grid_height_));
  neighbor_locs.push_back(std::pair<float, float>(macro_loc.first, macro_loc.second + grid_height_));
  std::shuffle(neighbor_locs.begin(), neighbor_locs.end(), generator_);
  for (auto& loc : neighbor_locs) {
    objects_[macro_id]->SetPos(loc.first, loc.second, grid_width_, grid_height_, n_cols_, n_rows_);
    if (IsFeasible(macro_id) == true)
      return true;    
  }
  // restore the pos
  objects_[macro_id]->SetPos(macro_loc.first, macro_loc.second, grid_width_, grid_height_, n_cols_, n_rows_);
  return false; 
}

bool PBFNetlist::Swap() {
  for (int i = 0; i < 5; i++) {
    const int macro_a = macros_[static_cast<int>(std::floor(distribution_(generator_) * macros_.size()))];
    const int macro_b = macros_[static_cast<int>(std::floor(distribution_(generator_) * macros_.size()))];
    if (macro_a == macro_b)
      continue;
    // store the location
    pre_locs_[macro_a] = std::pair<float, float>(objects_[macro_a]->x_, 
                                                 objects_[macro_a]->y_);
    pre_locs_[macro_b] = std::pair<float, float>(objects_[macro_b]->x_, 
                                                 objects_[macro_b]->y_);
    // swap the location of macro_a and macro_b
    objects_[macro_a]->SetPos(pre_locs_[macro_b].first, pre_locs_[macro_b].second, 
                              grid_width_, grid_height_, n_cols_, n_rows_);
    objects_[macro_b]->SetPos(pre_locs_[macro_a].first, pre_locs_[macro_a].second, 
                              grid_width_, grid_height_, n_cols_, n_rows_);
    // check feasbility
    if (IsFeasible(macro_a) == true && IsFeasible(macro_b) == true)
      return true;
    // restore the location
    objects_[macro_a]->SetPos(pre_locs_[macro_a].first, pre_locs_[macro_a].second, 
                              grid_width_, grid_height_, n_cols_, n_rows_);
    objects_[macro_b]->SetPos(pre_locs_[macro_b].first, pre_locs_[macro_b].second, 
                              grid_width_, grid_height_, n_cols_, n_rows_);
  }
  return false;
}

// Move a randomly selected macro to a new random location
bool PBFNetlist::Move() {
  const int macro_a = macros_[static_cast<int>(std::floor(distribution_(generator_) * macros_.size()))];
  // store the location
  pre_locs_[macro_a] = std::pair<float, float>(objects_[macro_a]->x_, 
                                               objects_[macro_a]->y_);
  // randomly pick a grid
  const int grid_id = static_cast<int>(std::floor(distribution_(generator_) * grids_.size()));
  objects_[macro_a]->SetPos(grids_[grid_id]->x_, grids_[grid_id]->y_, grid_width_, grid_height_, n_cols_, n_rows_);
  if (IsFeasible(macro_a) == true)
    return true;
  // restore the loc
  objects_[macro_a]->SetPos(pre_locs_[macro_a].first, pre_locs_[macro_a].second,
                            grid_width_, grid_height_, n_cols_, n_rows_);
  return false;
}

bool PBFNetlist::Flip() {
  const int macro_a = macros_[static_cast<int>(std::floor(distribution_(generator_) * macros_.size()))];
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
  return true;
}

bool PBFNetlist::Action() {
  pre_orients_.clear();
  pre_locs_.clear();
  const float prob = distribution_(generator_);
  if (prob <= action_probs_[0])
    return Swap();
  else if (prob <= action_probs_[1])
    return Shift();
  else if (prob <= action_probs_[2])
    return Flip();
  else if (prob <= action_probs_[3])
    return Move();
  else  
    return Shuffle();
}


float PBFNetlist::CalcCostIncr(bool inverse_flag) {
  std::map<size_t, std::pair<float, float> > cur_locs;
  std::map<size_t, ORIENTATION> cur_orient;
  std::vector<size_t> update_macros;
  for (auto& value : pre_locs_) {
    const int macro_id = value.first;
    update_macros.push_back(macro_id);
    cur_locs[macro_id] = std::pair<float, float>(objects_[macro_id]->x_,
                                                 objects_[macro_id]->y_); 
  }
  for (auto& value : pre_orients_) {
    const int macro_id = value.first;
    update_macros.push_back(macro_id);
    cur_orient[macro_id] = objects_[macro_id]->orient_;
  }
  // calculate wirelength cost
  // update the net  
  std::set<size_t> nets;
  for (auto& macro_id : update_macros) {
    for (auto& pin : objects_[macro_id]->macro_pins_) {
      for (auto& net : pin->nets_) {
        nets.insert(net);
      }
    }
  }
  /////////////////////////////////////////////////////////////////////////
  // Calculate HPWL for the net
  for (auto& net : nets) {
    nets_[net]->UpdateHPWL();
    if (inverse_flag == false) {
      HPWL_ += nets_[net]->HPWL_;
    } else {
      HPWL_ -= nets_[net]->HPWL_;
    }
  }
  // calculate the density
  for (auto& node_id : update_macros) {
    const Rect rect = objects_[node_id]->GetBBox();
    const GridRect grid_bbox = objects_[node_id]->grid_bbox_;
    for (int y_id = grid_bbox.ly_id; y_id <= grid_bbox.uy_id; y_id++) {
      for (int x_id = grid_bbox.lx_id; x_id <= grid_bbox.ux_id; x_id++) {
        grids_[y_id * n_cols_ + x_id]->UpdateOverlap(rect, !inverse_flag);
      }
    }  
  }
  // update the routing 
  for (auto& net : nets) 
    UpdateRouting(nets_[net], !inverse_flag);
  // update the congestion caused by macro
  for (auto& macro : update_macros)
    UpdateMacroCongestion(objects_[macro], !inverse_flag);
  // We need to remove the contributions for the pre_objects
  // update the locations
  for (auto& value : pre_locs_) {
    const int macro_id = value.first;
    objects_[macro_id]->SetPos(pre_locs_[macro_id].first, 
                               pre_locs_[macro_id].second,
                               grid_width_, grid_height_, n_cols_, n_rows_);
  }
  for (auto& value : pre_orients_) {
    const int macro_id = value.first;
    objects_[macro_id]->orient_ = pre_orients_[macro_id];
    objects_[macro_id]->UpdateOrientation(grid_width_, grid_height_, n_cols_, n_rows_); 
  }
  // remove the HPWL contributed by previous locs
  for (auto& net : nets) {
    nets_[net]->UpdateHPWL();
    if (inverse_flag == false) {
      HPWL_ -= nets_[net]->HPWL_;  // remove the HPWL
    } else {
      HPWL_ += nets_[net]->HPWL_;
    }
  }
  // calculate the density
  for (auto& node_id : update_macros) {
    const Rect rect = objects_[node_id]->bbox_;
    const GridRect grid_rect = objects_[node_id]->grid_bbox_;
    for (int y_id = grid_rect.ly_id; y_id <= grid_rect.uy_id; y_id++) {
      for (int x_id = grid_rect.lx_id; x_id <= grid_rect.ux_id; x_id++) {
        grids_[y_id * n_cols_ + x_id]->UpdateOverlap(rect, inverse_flag);
      }
    }  
  }
  // update the routing 
  for (auto& net : nets) 
    UpdateRouting(nets_[net], inverse_flag);
  // update the congestion caused by macro
  for (auto& macro : update_macros)
    UpdateMacroCongestion(objects_[macro], inverse_flag);
   
  if (inverse_flag == true)
    return 0.0f;
    
  // get the top 10 % density
  std::vector<float> density_list;
  for (auto& grid : grids_)
    density_list.push_back(grid->GetDensity());
  std::sort(density_list.begin(), density_list.end(), std::greater<float>());
  density_ = 0.0;
  for (int i = 0; i < top_k_; i++)
    density_ += density_list[i];
  density_ = density_ / top_k_ * 0.5; 
  // smooth the congestion by net
  // reset smooth congestion
  for (auto& grid : grids_) {
    grid->smooth_hor_congestion_ = 0.0;
    grid->smooth_ver_congestion_ = 0.0;
  }

  for (auto& grid : grids_) {
    // smooth vertical congestion
    const int col_id = grid->x_id_;
    const int row_id = grid->y_id_;
    const int v_start = std::max(0, grid->x_id_ - smooth_factor_);
    const int v_end   = std::min(n_cols_ - 1, grid->x_id_ + smooth_factor_);
    const float ver_congestion = grid->ver_congestion_ / (v_end - v_start + 1);
    for (int i = v_start; i <= v_end; i++)
      grids_[row_id * n_cols_ + i]->smooth_ver_congestion_ += ver_congestion;
    const int h_start = std::max(0, grid->y_id_ - smooth_factor_);
    const int h_end   = std::min(n_rows_ - 1, grid->y_id_ + smooth_factor_);
    const float hor_congestion = grid->hor_congestion_ / (h_end - h_start + 1);
    for (int j = h_start; j <= h_end; j++) 
      grids_[j * n_cols_ + col_id]->smooth_hor_congestion_ += hor_congestion;
  }
  // get the top 0.1 congestion
  std::vector<float> congestion_list;
  for (auto& grid : grids_) {
    congestion_list.push_back(
        (grid->smooth_ver_congestion_ + grid->macro_ver_congestion_) / (grid_width_ * vroute_per_micro_)
    );
    congestion_list.push_back(
        (grid->smooth_hor_congestion_ + grid->macro_hor_congestion_) / (grid_height_ * hroute_per_micro_)
    );
  }
  std::sort(congestion_list.begin(), congestion_list.end(), std::greater<float>());
  congestion_ = 0.0;
  for (int i = 0; i < top_k_congestion_; i++)
    congestion_ += congestion_list[i];
  congestion_ = congestion_ / top_k_congestion_; 
  float cost = HPWL_ / norm_HPWL_ + density_ * 0.5 + congestion_ * 0.5;
  // restore the locations back
  for (auto& value : cur_locs) {
    const int macro_id = value.first;
    objects_[macro_id]->SetPos(cur_locs[macro_id].first, 
                               cur_locs[macro_id].second,
                               grid_width_, grid_height_, n_cols_, n_rows_);
  }
  for (auto& value : cur_orient) {
    const int macro_id = value.first;
    objects_[macro_id]->orient_ = cur_orient[macro_id];
    objects_[macro_id]->UpdateOrientation(grid_width_, grid_height_, n_cols_, n_rows_); 
  }
  return cost;
}

void PBFNetlist::Restore() {
  CalcCostIncr(true);
  for (auto& macro_pos : pre_locs_) 
    objects_[macro_pos.first]->SetPos(pre_locs_[macro_pos.first].first, 
                                      pre_locs_[macro_pos.first].second,
                                      grid_width_, grid_height_, 
                                      n_cols_, n_rows_);
  for (auto& macro_orient :  pre_orients_) {
    objects_[macro_orient.first]->orient_ = pre_orients_[macro_orient.first];
    objects_[macro_orient.first]->UpdateOrientation(grid_width_, grid_height_, n_cols_, n_rows_);
  }
}

void PBFNetlist::SimulatedAnnealing(std::vector<float> action_probs, 
                                    unsigned int num_actions,
                                    float max_temperature,
                                    unsigned int num_iters,
                                    int seed, 
                                    bool spiral_flag,
                                    std::string summary_file,
                                    std::string plc_file) {
  // Initialization
  action_probs_ = action_probs;
  for (size_t i = 1; i < action_probs_.size(); i++)
    action_probs_[i] += action_probs_[i-1];
  const int num_step_per_iter = num_actions;
  seed_ = seed;
  std::mt19937 generator(seed_);
  generator_ = generator;   
  // Initialize the macro locations
  InitMacroPlacement(spiral_flag);
  std::cout << "[SA Params] Action probabilities : ";
  for (auto& prob : action_probs)
    std::cout << prob << "   ";
  std::cout << std::endl;
  std::cout << "[SA Params] num_actions = " << num_actions << std::endl;
  std::cout << "[SA Params] max_temperature = " << max_temperature << std::endl;
  std::cout << "[SA Params] num_iters = " << num_iters << std::endl;
  std::cout << "[SA Params] seed = " << seed << std::endl;
  std::cout << "[SA Params] spiral_flag = " << spiral_flag << std::endl;
  std::cout << "[SA Params] summary_file = " << summary_file << std::endl;
  // calculate temperature updating factor firstly
  const int N = num_actions * macros_.size();
  const float t_min = 1e-8; // minimum temperature
  const float t_factor = std::log(t_min / max_temperature);
  float t = max_temperature;
  float cur_cost = 0.0;
  float min_cost = 0.0;
  std::vector<float> cost_list; // we need to plot the cost curve
  CallFDPlacer();
  cur_cost = CalcCost();
  min_cost = cur_cost;
  std::ofstream f;
  f.open(summary_file);
  f.close();
 
  for (int num_iter = 0; num_iter < num_iters; num_iter++) {
    // call FDPlacer to update the cost
    for (int step = 0; step < N; step++) {
      if (Action() == true) {
        const float new_cost = CalcCostIncr(false);
        if (new_cost < cur_cost) {
          cur_cost = new_cost;
        }
        float prob = std::exp((cur_cost - new_cost) / t);
        if (prob < distribution_(generator_)) {
          Restore();
        } else {
          cur_cost = new_cost;
        }
      }
      cost_list.push_back(cur_cost);
    }
    CallFDPlacer();
    cur_cost = CalcCost();
    if ((num_iter + 1) % 100 == 0) {
      f.open(summary_file, std::ios::out | std::ios::app);
      for (auto& value : cost_list)
        f << value << std::endl;
      f.close(); 
      cost_list.clear();  
      WritePlcFile(plc_file + "_step_" + std::to_string(num_iter + 1) + "_cost_" + std::to_string(cur_cost) + ".plc");    
    }    
    // update the temperature
    t = max_temperature * std::exp(t_factor * num_iter / num_iters);
  }

  if (cost_list.size() > 0) {
    f.open(summary_file, std::ios::out | std::ios::app);
    for (auto& value : cost_list)
      f << value << std::endl;
    f.close(); 
    cost_list.clear();        
  }
}
