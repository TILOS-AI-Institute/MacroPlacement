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
// ***************************************************************************************
// Calculate Cost
// ***************************************************************************************
// Calculate the cost from scratch
float PBFNetlist::CalcCost(bool debug_mode) {
  // reset
  for (auto& grid : grids_)
    grid->Reset();
  
  // calculate wirelength cost
  HPWL_ = 0.0;
  for (auto& net : nets_) {
    net->UpdateHPWL();
    HPWL_ += net->HPWL_;
  }
  
  // calculate the density
  for (auto& node_id : macro_clusters_) {
    const Rect rect = objects_[node_id]->GetBBox();
    const GridRect grid_rect = objects_[node_id]->GetGridBBox();  
    for (int y_id = grid_rect.ly_id; y_id <= grid_rect.uy_id; y_id++) {
      for (int x_id = grid_rect.lx_id; x_id <= grid_rect.ux_id; x_id++) {
        grids_[y_id * n_cols_ + x_id]->UpdateOverlap(rect, true);
      }
    }  
  }
  // get the top 10 % density
  std::vector<float> density_list;
  for (auto& grid : grids_)
    density_list.push_back(grid->GetDensity());
  std::sort(density_list.begin(), density_list.end(), std::greater<float>());
  density_ = 0.0;
  for (int i = 0; i < top_k_; i++)
    density_ += density_list[i];
  density_ = density_ / top_k_ * 0.5;
  
  // calculate the congestion cost
  // update the congestion caused by net
  for (auto& net : nets_)  {
    UpdateRouting(net, true);
  }
  // update the congestion caused by macro
  for (auto& macro : macros_)
    UpdateMacroCongestion(objects_[macro], true);
  
  // smooth the congestion by net
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
  for (int i = 0; i < top_k_congestion_; i++) {
    congestion_ += congestion_list[i];
  }
  congestion_ = congestion_ / top_k_congestion_; 
  float cost =  HPWL_ / norm_HPWL_ + density_ * 0.5 + congestion_ * 0.5;
  if (debug_mode == true) {
    std::cout << "Scratch Cost = " << cost << "  "
              << "HPWL = " << HPWL_ / norm_HPWL_ << "  "
              << "density = " << density_ << "  "
              << "congestion = " << congestion_ << std::endl;
  }
  return cost;
}

// Get routing information (general case)
// multi-pin nets are decomposed into multiple two-pin nets
void PBFNetlist::UpdateRouting(std::shared_ptr<Net> net, bool flag) {
  std::set<LOC> pin_set;
  for (auto& pin : net->pins_) {
    pin_set.insert(LOC(pin->grid_bbox_.lx_id, pin->grid_bbox_.ly_id));
  } 
  // check the conditions using switch clauses
  switch(pin_set.size()) {
    case 0:
      return; // ignore empty net
    case 1:
      return; // ignore all single-pin net
    case 2: { 
        LOC src_loc = LOC(net->pins_[0]->grid_bbox_.lx_id, net->pins_[0]->grid_bbox_.ly_id);
        for (auto& loc : pin_set) {
          if (src_loc.IsEqual(loc) == false) {
            TwoPinNetRouting(src_loc, loc, net->weight_, flag);     
          }
        }
      }
      return;
    case 3:  {
        // define alias for better understanding
        std::vector<LOC> pin_locs(pin_set.size());
        std::copy(pin_set.begin(), pin_set.end(), pin_locs.begin());
        std::sort(pin_locs.begin(), pin_locs.end(), 
                [](const LOC& a, const LOC& b) {
                  return a.x_id < b.x_id;
                });
        int col_id_1 = pin_locs[0].x_id;
        int col_id_2 = pin_locs[1].x_id;
        int col_id_3 = pin_locs[2].x_id;
        int row_id_1 = pin_locs[0].y_id;
        int row_id_2 = pin_locs[1].y_id;
        int row_id_3 = pin_locs[2].y_id;        
        // checking L Routing condition
        if (col_id_1 < col_id_2 && 
            col_id_2 < col_id_3 && 
            std::min(row_id_1, row_id_3) < row_id_2 &&
            std::max(row_id_1, row_id_3) > row_id_2) {
          // L routing
          for (auto col_id = col_id_1;  col_id < col_id_2; col_id++) 
            grids_[row_id_1 * n_cols_ + col_id]->UpdateCongestionH(net->weight_, flag);
          for (auto col_id = col_id_2;  col_id < col_id_3; col_id++) 
            grids_[row_id_2 * n_cols_ + col_id]->UpdateCongestionH(net->weight_, flag);
          for (auto row_id = std::min(row_id_1, row_id_2); row_id < std::max(row_id_1, row_id_2); row_id++) 
            grids_[row_id * n_cols_ + col_id_2]->UpdateCongestionV(net->weight_, flag);
          for (auto row_id = std::min(row_id_2, row_id_3); row_id < std::max(row_id_2, row_id_3); row_id++) 
            grids_[row_id * n_cols_ + col_id_3]->UpdateCongestionV(net->weight_, flag);
          return;
        } else if (col_id_2 == col_id_3 && col_id_1 < col_id_2 && row_id_1 < std::min(row_id_2, row_id_3)) {
          // check if condition 2
          for (auto col_id = col_id_1;  col_id < col_id_2; col_id++) 
            grids_[row_id_1 * n_cols_ + col_id]->UpdateCongestionH(net->weight_, flag);
          for (auto row_id = row_id_1; row_id < std::max(row_id_2, row_id_3); row_id++) 
            grids_[row_id * n_cols_ + col_id_2]->UpdateCongestionV(net->weight_, flag);
          return;
        } else if (row_id_2 == row_id_3) {
          // check if condition 3
          for (auto col_id = col_id_1;  col_id < col_id_2; col_id++) 
            grids_[row_id_1 * n_cols_ + col_id]->UpdateCongestionH(net->weight_, flag);
          for (auto col_id = col_id_2;  col_id < col_id_3; col_id++) 
            grids_[row_id_2 * n_cols_ + col_id]->UpdateCongestionH(net->weight_, flag);
          for (auto row_id = std::min(row_id_1, row_id_2); row_id < std::max(row_id_1, row_id_2); row_id++) 
            grids_[row_id * n_cols_ + col_id_2]->UpdateCongestionV(net->weight_, flag);
          return;
        } else {
          // sort pins based on row_id
          std::sort(pin_locs.begin(), pin_locs.end(), 
                [](const LOC& a, const LOC& b) {
                  return a.y_id < b.y_id;
                });
          int col_id_1 = pin_locs[0].x_id;
          int col_id_2 = pin_locs[1].x_id;
          int col_id_3 = pin_locs[2].x_id;
          int row_id_1 = pin_locs[0].y_id;
          int row_id_2 = pin_locs[1].y_id;
          int row_id_3 = pin_locs[2].y_id;        
          int min_col_id = std::numeric_limits<int>::max();
          int max_col_id = -1 * std::numeric_limits<int>::max();
          for (auto& pin : net->pins_) {
            min_col_id = std::min(min_col_id, pin->grid_bbox_.lx_id);
            max_col_id = std::max(max_col_id, pin->grid_bbox_.lx_id);
          }
          for (auto col_id = min_col_id;  col_id < max_col_id; col_id++) 
            grids_[row_id_2 * n_cols_ + col_id]->UpdateCongestionH(net->weight_, flag);
          for (auto row_id = std::min(row_id_1, row_id_2); row_id < std::max(row_id_1, row_id_2); row_id++) 
            grids_[row_id * n_cols_ + col_id_1]->UpdateCongestionV(net->weight_, flag);
          for (auto row_id = std::min(row_id_2, row_id_3); row_id < std::max(row_id_2, row_id_3); row_id++) 
            grids_[row_id * n_cols_ + col_id_3]->UpdateCongestionV(net->weight_, flag);
          return;
        } 
      }
      return; 
    default: {
        // multi-pin nets are decomposed into multiple two-pin nets using star model
        LOC src_loc = LOC(net->pins_[0]->grid_bbox_.lx_id, net->pins_[0]->grid_bbox_.ly_id);
        for (auto& loc : pin_set) {
          if (src_loc.IsEqual(loc) == false) {
            TwoPinNetRouting(src_loc, loc, net->weight_, flag);     
          }
        }
      }
      return;
  }
}


void PBFNetlist::TwoPinNetRouting(LOC src_loc, LOC sink_loc, float weight, bool flag) {
  const int min_col_id = std::min(src_loc.x_id, sink_loc.x_id);
  const int max_col_id = std::max(src_loc.x_id, sink_loc.x_id);
  const int min_row_id = std::min(src_loc.y_id, sink_loc.y_id);
  const int max_row_id = std::max(src_loc.y_id, sink_loc.y_id);
  // update horizontal congestion
  for (int col_id = min_col_id;  col_id < max_col_id; col_id++) {
    grids_[src_loc.y_id * n_cols_ + col_id]->UpdateCongestionH(weight, flag);
  }
  // update vertical congestion
  for (int row_id = min_row_id; row_id < max_row_id; row_id++) {
    grids_[row_id * n_cols_ + sink_loc.x_id]->UpdateCongestionV(weight, flag);
  } 
}

// Update the congestion caused by macro
// true for add and false for reduce
void PBFNetlist::UpdateMacroCongestion(std::shared_ptr<PlcObject> plc_object, bool flag) {
  // calculate the horizontal and vertical congestion independently
  const GridRect& grid_bbox = plc_object->grid_bbox_;
  for (int row_id = grid_bbox.ly_id; row_id < grid_bbox.uy_id; row_id++) {
    float v_overlap = grid_height_;
    if (row_id == grid_bbox.ly_id) 
      v_overlap = (row_id + 1) * grid_height_ - plc_object->bbox_.ly;
    for (int col_id = grid_bbox.lx_id; col_id < grid_bbox.ux_id; col_id++) {
      float h_overlap = grid_width_;
      if (col_id == grid_bbox.lx_id)
        h_overlap = (col_id + 1) * grid_width_ - plc_object->bbox_.lx;
      auto& grid = grids_[row_id * n_cols_ + col_id];
      grid->UpdateMacroCongestionH(v_overlap * hrouting_alloc_, flag);
      grid->UpdateMacroCongestionV(h_overlap * vrouting_alloc_, flag);
    }
  }
} 
