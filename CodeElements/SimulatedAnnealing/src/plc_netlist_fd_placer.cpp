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

// ***************************************************************************
// Force-directed placement
// **************************************************************************

void PBFNetlist::InitSoftMacros() {
  const float x = canvas_width_ / 2.0;
  const float y = canvas_height_ / 2.0;
  for (auto& node_id : stdcell_clusters_)  {
    objects_[node_id]->SetPos(x, y, grid_width_, grid_height_, n_cols_, n_rows_);
  }
}

void PBFNetlist::CalcAttractiveForce(float attractive_factor, 
                                     float io_factor, 
                                     float max_displacement) {
  // traverse the nets to calculate the attractive force
  for (auto& net : nets_) {
    std::shared_ptr<PlcObject>& src_pin = net->pins_[0];
    // convert multi-pin nets to two-pin nets using star model
    auto iter = net->pins_.begin();
    iter++;
    while (iter != net->pins_.end()) {
      std::shared_ptr<PlcObject>& target_pin = *iter;
      // check the distance between src_pin and target_pin
      std::pair<float, float> src_pos = src_pin->GetPos();
      std::pair<float, float> target_pos = target_pin->GetPos();
      const float x_dist = -1.0 * (src_pos.first - target_pos.first);
      const float y_dist = -1.0 * (src_pos.second - target_pos.second);
      if (x_dist != 0.0 || y_dist != 0.0) {
      float k = net->weight_; // spring constant
      if (src_pin->IsPort() == true || target_pin->IsPort() == true)
        k = k * io_factor * attractive_factor;
      else
        k = k * attractive_factor;
      const float f_x = k * x_dist;
      const float f_y = k * y_dist;
      if (src_pin->IsSoftMacroPin() == true)
        src_pin->macro_ptr_->AddForce(f_x, f_y);
      if (target_pin->IsSoftMacroPin() == true)
        target_pin->macro_ptr_->AddForce(-1.0 * f_x, -1.0 * f_y);      
      }
      iter++;
    } // finish current net     
  } // finish traversing nets
}

void PBFNetlist::CalcRepulsiveForce(float repulsive_factor,
                                    float max_displacement) {
  std::sort(macro_clusters_.begin(), macro_clusters_.end(), 
            [&](size_t src, size_t target) {
              return objects_[src]->bbox_.lx < objects_[target]->bbox_.lx;  
            });
  // traverse the soft macros and hard macros to check possible overlap
  auto iter = macro_clusters_.begin();
  while (iter != macro_clusters_.end()) {
    size_t init_src_macro = *iter;
    for (auto iter_loop = ++iter; 
         iter_loop != macro_clusters_.end(); iter_loop++) {
      size_t target_macro = *iter_loop;
      size_t src_macro = init_src_macro;
      if (src_macro > target_macro) {
        std::swap(src_macro, target_macro);
      }
      const Rect src_bbox = objects_[src_macro]->GetBBox();
      const Rect target_bbox = objects_[target_macro]->GetBBox();
      if (src_bbox.ux <= target_bbox.lx) 
        break;
      if (src_bbox.ly >= target_bbox.uy || src_bbox.uy <= target_bbox.ly)
        continue;
      // check the overlap
      float x_dir = 0.0; // overlap on x direction
      float y_dir = 0.0; // overlap on y direction
      const float src_width = src_bbox.ux - src_bbox.lx;
      const float src_height = src_bbox.uy - src_bbox.ly;
      const float target_width = target_bbox.ux - target_bbox.lx;
      const float target_height = target_bbox.uy - target_bbox.ly;
      const float src_cx = (src_bbox.lx + src_bbox.ux) / 2.0;
      const float src_cy = (src_bbox.ly + src_bbox.uy) / 2.0;
      const float target_cx = (target_bbox.lx + target_bbox.ux) / 2.0;
      const float target_cy = (target_bbox.ly + target_bbox.uy) / 2.0;

      const float x_min_dist = (src_width + target_width) / 2.0 - min_dist_;
      const float y_min_dist = (src_height + target_height) / 2.0 - min_dist_;
      // if there is no overlap
      if (std::abs(target_cx - src_cx) > x_min_dist)
        continue;
      if (std::abs(target_cy - src_cy) > y_min_dist)
        continue;
      // fully overlap
      if (src_cx == target_cx && src_cy == target_cy) {
        x_dir = -1;
        y_dir = -1;
      } else {
        x_dir = src_cx - target_cx;
        y_dir = src_cy - target_cy;
        const float dist = std::sqrt(x_dir * x_dir + y_dir * y_dir);
        x_dir = x_dir / dist;
        y_dir = y_dir / dist;
      }
      // calculate the force
      const float f_x = repulsive_factor * max_displacement * x_dir;
      const float f_y = repulsive_factor * max_displacement * y_dir;
        objects_[src_macro]->AddForce(f_x, f_y);
        objects_[target_macro]->AddForce(-1.0 * f_x, -1.0 * f_y);
    }
  } // finish traverse all the macros and stdcell_clusters
}

void PBFNetlist::MoveNode(size_t node_id, float x_dist, float y_dist) {
  float x = objects_[node_id]->x_ + x_dist; 
  float y = objects_[node_id]->y_ + y_dist;
  float width = objects_[node_id]->width_ / 2.0;
  float height = objects_[node_id]->height_ / 2.0;
  if (x - width >= 0.0 && y - height >= 0.0 && x + width <= canvas_width_ && y + height <= canvas_height_) 
    objects_[node_id]->SetPos(x, y, grid_width_, grid_height_, n_cols_, n_rows_);
}

void PBFNetlist::MoveSoftMacros(float attractive_factor, float repulsive_factor, 
                                float io_factor, float max_displacement) {
  // move soft macros based on forces
  // reset forces
  for (auto& cluster_id : stdcell_clusters_)
    objects_[cluster_id]->ResetForce();
  // calculate forces
  if (repulsive_factor == 0 || (attractive_factor / repulsive_factor > 1e-4))
    CalcAttractiveForce(attractive_factor, io_factor, max_displacement);
  if (attractive_factor == 0.0 || (repulsive_factor / attractive_factor > 1e-4))
    CalcRepulsiveForce(repulsive_factor, max_displacement);
  // normalization
  float max_f_x = 0.0;
  float max_f_y = 0.0;
  for (auto& cluster_id : stdcell_clusters_) {
    const std::pair<float, float> forces = objects_[cluster_id]->GetForce();
    max_f_x = std::max(max_f_x, std::abs(forces.first));
    max_f_y = std::max(max_f_y, std::abs(forces.second));
  }
  for (auto& cluster_id : stdcell_clusters_) {
    objects_[cluster_id]->NormalForce(max_f_x, max_f_y);
    const std::pair<float, float> forces = objects_[cluster_id]->GetForce();
    MoveNode(cluster_id, forces.first * max_displacement, forces.second * max_displacement);
  }
}

void PBFNetlist::FDPlacer(float io_factor, std::vector<int> num_steps,
                          std::vector<float> move_distance_factor,
                          std::vector<float> attract_factor,
                          std::vector<float> repel_factor,
                          bool use_current_loc, 
                          bool debug_mode)
{
  // io_factor is a scalar
  // num_steps, max_move_distance, attract_factor, repel_factor are vectors of 
  // the same size
  if (debug_mode == true) {
    std::cout << std::string(80, '*') << std::endl;
    std::cout << "Start Force-directed Placement" << std::endl;
  }
  std::vector<float> max_move_distance;
  const float max_size = std::max(canvas_width_, canvas_height_);
  auto step_iter = num_steps.begin();
  auto move_iter = move_distance_factor.begin();
  while (step_iter != num_steps.end()) {
    max_move_distance.push_back((*move_iter) * max_size / (*step_iter));
    step_iter++;
    move_iter++;
  } 
  // initialize the location
  if (use_current_loc == false)
    InitSoftMacros();
  for (size_t i = 0; i < num_steps.size(); i++) {
    const float attractive_factor = attract_factor[i];
    const float repulsive_factor = repel_factor[i];
    if (attractive_factor == 0.0 && repulsive_factor == 0.0)
      continue;
    int num_step = num_steps[i];
    float max_displacement = max_move_distance[i];
    if (debug_mode == true) {
      std::cout << std::string(80, '-') << std::endl;
      std::cout << "Iteration " << i << std::endl;
      std::cout << "attractive_factor = " << attractive_factor << std::endl;
      std::cout << "repulsive_factor = " << repulsive_factor << std::endl;
      std::cout << "max_displacement = " << max_displacement << std::endl;
      std::cout << "num_step = " << num_step << std::endl;
      std::cout << "io_factor = " << io_factor << std::endl; 
    }
    for (auto j = 0; j < num_step; j++)
      MoveSoftMacros(attractive_factor, repulsive_factor, io_factor, max_displacement);
  } 
}
