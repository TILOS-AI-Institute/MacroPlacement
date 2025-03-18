#include <algorithm>
#include <cmath>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <unordered_map>
#include <numeric>
#include <string>
#include <vector>

#include "plc_netlist.h"
// *****************************************************************************
// Calculate Cost
// *****************************************************************************
// Calculate the cost from scratch
float PBFNetlist::CalcCost(bool debug_mode) {
  // reset
  for (auto &grid : grids_)
    grid->Reset();

  // calculate wirelength cost
  HPWL_ = 0.0;
  for (auto &net : nets_) {
    net->UpdateHPWL();
    HPWL_ += net->HPWL_;
  }

  // calculate the density
  DensityIncrCost(macro_clusters_, true);

  // get the top 10 % density
  UpdateDensityCost();

  // calculate the congestion cost
  // update the congestion caused by net
  for (auto &net : nets_) {
    UpdateRouting(net, true);
  }
  
  // update the congestion caused by macro
  for (auto &macro : macros_)
    UpdateMacroCongestion(objects_[macro], true);

  // smooth the congestion by net
  SmoothCongestion();

  // get the top 0.1 congestion
  UpdateCongestionCost();

  float cost = hpwl_weight_ * (HPWL_ / norm_HPWL_) +
               density_weight_ * density_ + congestion_weight_ * congestion_;

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
  for (auto &pin : net->pins_) {
    pin_set.insert(LOC(pin->grid_bbox_.lx_id, pin->grid_bbox_.ly_id));
  }
  // check the conditions using switch clauses
  switch (pin_set.size()) {
  case 0:
    return; // ignore empty net
  case 1:
    return; // ignore all single-pin net
  case 2: {
    LOC src_loc =
        LOC(net->pins_[0]->grid_bbox_.lx_id, net->pins_[0]->grid_bbox_.ly_id);
    for (auto &loc : pin_set) {
      if (src_loc.IsEqual(loc) == false) {
        TwoPinNetRouting(src_loc, loc, net->weight_, flag);
      }
    }
  }
    return;
  case 3: {
    // define alias for better understanding
    std::vector<LOC> pin_locs(pin_set.size());
    std::copy(pin_set.begin(), pin_set.end(), pin_locs.begin());
    std::sort(pin_locs.begin(), pin_locs.end(),
              [](const LOC &a, const LOC &b) { return a.x_id < b.x_id; });
    int col_id_1 = pin_locs[0].x_id;
    int col_id_2 = pin_locs[1].x_id;
    int col_id_3 = pin_locs[2].x_id;
    int row_id_1 = pin_locs[0].y_id;
    int row_id_2 = pin_locs[1].y_id;
    int row_id_3 = pin_locs[2].y_id;
    // checking L Routing condition
    if (col_id_1 < col_id_2 && col_id_2 < col_id_3 &&
        std::min(row_id_1, row_id_3) < row_id_2 &&
        std::max(row_id_1, row_id_3) > row_id_2) {
      // L routing
      for (auto col_id = col_id_1; col_id < col_id_2; col_id++)
        grids_[row_id_1 * n_cols_ + col_id]->UpdateCongestionH(net->weight_,
                                                               flag);
      for (auto col_id = col_id_2; col_id < col_id_3; col_id++)
        grids_[row_id_2 * n_cols_ + col_id]->UpdateCongestionH(net->weight_,
                                                               flag);
      for (auto row_id = std::min(row_id_1, row_id_2);
           row_id < std::max(row_id_1, row_id_2); row_id++)
        grids_[row_id * n_cols_ + col_id_2]->UpdateCongestionV(net->weight_,
                                                               flag);
      for (auto row_id = std::min(row_id_2, row_id_3);
           row_id < std::max(row_id_2, row_id_3); row_id++)
        grids_[row_id * n_cols_ + col_id_3]->UpdateCongestionV(net->weight_,
                                                               flag);
      return;
    } else if (col_id_2 == col_id_3 && col_id_1 < col_id_2 &&
               row_id_1 < std::min(row_id_2, row_id_3)) {
      // check if condition 2
      for (auto col_id = col_id_1; col_id < col_id_2; col_id++)
        grids_[row_id_1 * n_cols_ + col_id]->UpdateCongestionH(net->weight_,
                                                               flag);
      for (auto row_id = row_id_1; row_id < std::max(row_id_2, row_id_3);
           row_id++)
        grids_[row_id * n_cols_ + col_id_2]->UpdateCongestionV(net->weight_,
                                                               flag);
      return;
    } else if (row_id_2 == row_id_3) {
      // check if condition 3
      for (auto col_id = col_id_1; col_id < col_id_2; col_id++)
        grids_[row_id_1 * n_cols_ + col_id]->UpdateCongestionH(net->weight_,
                                                               flag);
      for (auto col_id = col_id_2; col_id < col_id_3; col_id++)
        grids_[row_id_2 * n_cols_ + col_id]->UpdateCongestionH(net->weight_,
                                                               flag);
      for (auto row_id = std::min(row_id_1, row_id_2);
           row_id < std::max(row_id_1, row_id_2); row_id++)
        grids_[row_id * n_cols_ + col_id_2]->UpdateCongestionV(net->weight_,
                                                               flag);
      return;
    } else {
      // sort pins based on row_id
      std::sort(pin_locs.begin(), pin_locs.end(),
                [](const LOC &a, const LOC &b) { return a.y_id < b.y_id; });
      int col_id_1 = pin_locs[0].x_id;
      int col_id_2 = pin_locs[1].x_id;
      int col_id_3 = pin_locs[2].x_id;
      int row_id_1 = pin_locs[0].y_id;
      int row_id_2 = pin_locs[1].y_id;
      int row_id_3 = pin_locs[2].y_id;
      int min_col_id = std::numeric_limits<int>::max();
      int max_col_id = -1 * std::numeric_limits<int>::max();
      for (auto &pin : net->pins_) {
        min_col_id = std::min(min_col_id, pin->grid_bbox_.lx_id);
        max_col_id = std::max(max_col_id, pin->grid_bbox_.lx_id);
      }
      for (auto col_id = min_col_id; col_id < max_col_id; col_id++)
        grids_[row_id_2 * n_cols_ + col_id]->UpdateCongestionH(net->weight_,
                                                               flag);
      for (auto row_id = std::min(row_id_1, row_id_2);
           row_id < std::max(row_id_1, row_id_2); row_id++)
        grids_[row_id * n_cols_ + col_id_1]->UpdateCongestionV(net->weight_,
                                                               flag);
      for (auto row_id = std::min(row_id_2, row_id_3);
           row_id < std::max(row_id_2, row_id_3); row_id++)
        grids_[row_id * n_cols_ + col_id_3]->UpdateCongestionV(net->weight_,
                                                               flag);
      return;
    }
  }
    return;
  default: {
    // multi-pin nets are decomposed into multiple two-pin nets using star model
    LOC src_loc =
        LOC(net->pins_[0]->grid_bbox_.lx_id, net->pins_[0]->grid_bbox_.ly_id);
    for (auto &loc : pin_set) {
      if (src_loc.IsEqual(loc) == false) {
        TwoPinNetRouting(src_loc, loc, net->weight_, flag);
      }
    }
  }
  return;
  }
}

void PBFNetlist::TwoPinNetRouting(LOC src_loc, LOC sink_loc, float weight,
                                  bool flag) {
  const int min_col_id = std::min(src_loc.x_id, sink_loc.x_id);
  const int max_col_id = std::max(src_loc.x_id, sink_loc.x_id);
  const int min_row_id = std::min(src_loc.y_id, sink_loc.y_id);
  const int max_row_id = std::max(src_loc.y_id, sink_loc.y_id);
  // update horizontal congestion
  for (int col_id = min_col_id; col_id < max_col_id; col_id++) {
    grids_[src_loc.y_id * n_cols_ + col_id]->UpdateCongestionH(weight, flag);
  }
  // update vertical congestion
  for (int row_id = min_row_id; row_id < max_row_id; row_id++) {
    grids_[row_id * n_cols_ + sink_loc.x_id]->UpdateCongestionV(weight, flag);
  }
}

// Update the congestion caused by macro
// true for add and false for reduce
void PBFNetlist::UpdateMacroCongestion(std::shared_ptr<PlcObject> plc_object,
                                      bool flag) {
  const GridRect& grid_bbox = plc_object->grid_bbox_;
  bool partial_overlap_v = false, partial_overlap_h = false;
  
  // Loop includes both lower and upper boundaries
  for (int row_id = grid_bbox.ly_id; row_id <= grid_bbox.uy_id; row_id++) {
    float v_overlap = std::min(grid_height_, plc_object->height_);
    // Adjust for lower boundary cell
    if (grid_bbox.ly_id != grid_bbox.uy_id) {
      if (row_id == grid_bbox.ly_id)
        v_overlap = (row_id + 1) * grid_height_ - plc_object->bbox_.ly;
      // Adjust for upper boundary cell
      else if (row_id == grid_bbox.uy_id)
        v_overlap = plc_object->bbox_.uy - row_id * grid_height_;
      
      if ( row_id == grid_bbox.ly_id || row_id == grid_bbox.uy_id ) {
        if ( std::abs(v_overlap - grid_height_) > 0.0 )
          partial_overlap_v = true;
      }
    }

    for (int col_id = grid_bbox.lx_id; col_id <= grid_bbox.ux_id; col_id++) {
      float h_overlap = std::min(grid_width_, plc_object->width_);
      // Adjust for left boundary cell
      if ( grid_bbox.lx_id != grid_bbox.ux_id ) {
        if (col_id == grid_bbox.lx_id)
          h_overlap = (col_id + 1) * grid_width_ - plc_object->bbox_.lx;
        // Adjust for right boundary cell
        else if (col_id == grid_bbox.ux_id)
          h_overlap = plc_object->bbox_.ux - col_id * grid_width_;
        
        if ( col_id == grid_bbox.lx_id || col_id == grid_bbox.ux_id ) {
          if ( std::abs(h_overlap - grid_width_) > 0.0 )
            partial_overlap_h = true;
        }
      }
      
      auto& grid = grids_[row_id * n_cols_ + col_id];
      grid->UpdateMacroCongestionH(v_overlap * hrouting_alloc_, flag);
      grid->UpdateMacroCongestionV(h_overlap * vrouting_alloc_, flag);
    }
  }

  if ( partial_overlap_v ) {
    int row_id = grid_bbox.uy_id;
    for ( int col_id = grid_bbox.lx_id; col_id <= grid_bbox.ux_id; col_id++) {
      float h_overlap = std::min(grid_width_, plc_object->width_);
      if ( grid_bbox.lx_id != grid_bbox.ux_id ) {
        // Adjust for left boundary cell
        if (col_id == grid_bbox.lx_id)
          h_overlap = (col_id + 1) * grid_width_ - plc_object->bbox_.lx;
        // Adjust for right boundary cell
        else if (col_id == grid_bbox.ux_id)
          h_overlap = plc_object->bbox_.ux - col_id * grid_width_;
      }
      
      auto& grid = grids_[row_id * n_cols_ + col_id];
      grid->UpdateMacroCongestionV(h_overlap * vrouting_alloc_, !flag);
    }
  }

  if ( partial_overlap_h ) {
    int col_id = grid_bbox.ux_id;
    for ( int row_id = grid_bbox.ly_id; row_id <= grid_bbox.uy_id; row_id++) {
      float v_overlap = std::min(grid_height_, plc_object->height_);
      if (grid_bbox.ly_id != grid_bbox.uy_id) {
        // Adjust for lower boundary cell
        if (row_id == grid_bbox.ly_id)
          v_overlap = (row_id + 1) * grid_height_ - plc_object->bbox_.ly;
        // Adjust for upper boundary cell
        else if (row_id == grid_bbox.uy_id)
          v_overlap = plc_object->bbox_.uy - row_id * grid_height_;
      }
      
      auto& grid = grids_[row_id * n_cols_ + col_id];
      grid->UpdateMacroCongestionH(v_overlap * hrouting_alloc_, !flag);
    }
  }
}
