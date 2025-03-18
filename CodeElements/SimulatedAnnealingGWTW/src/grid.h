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

#include "basic_object.h"
class PBFNetlist;

// Define the Grid Structure
// The entire floorplan have been dividied into grids

class Grid {
public:
  Grid() {}
  Grid(float grid_width, float grid_height, int num_cols, int num_rows,
       int x_id, int y_id) {
    grid_area_ = grid_width * grid_height;
    x_id_ = x_id;
    y_id_ = y_id;
    id_ = y_id_ * num_cols + x_id_;
    bbox_ = Rect(x_id * grid_width, y_id * grid_height,
                 (x_id_ + 1) * grid_width, (y_id_ + 1) * grid_height);
    x_ = (bbox_.lx + bbox_.ux) / 2.0;
    y_ = (bbox_.ly + bbox_.uy) / 2.0;
  }

  // reset the status of grids
  inline void Reset() {
    overlap_area_ = 0.0;
    hor_congestion_ = 0.0;
    ver_congestion_ = 0.0;
    macro_hor_congestion_ = 0.0;
    macro_ver_congestion_ = 0.0;
    smooth_hor_congestion_ = 0.0;
    smooth_ver_congestion_ = 0.0;
  }

  // Check overlap area
  inline float CalcOverlap(Rect rect) const {
    const float x_overlap =
        std::min(bbox_.ux, rect.ux) - std::max(bbox_.lx, rect.lx);
    const float y_overlap =
        std::min(bbox_.uy, rect.uy) - std::max(bbox_.ly, rect.ly);
    if (x_overlap <= 0.0 || y_overlap <= 0.0)
      return 0.0;
    else
      return x_overlap * y_overlap;
  }

  // check overlap threshold
  inline std::pair<float, float> CalcHVOverlap(Rect rect) const {
    const float x_overlap =
        std::min(bbox_.ux, rect.ux) - std::max(bbox_.lx, rect.lx);
    const float y_overlap =
        std::min(bbox_.uy, rect.uy) - std::max(bbox_.ly, rect.ly);
    return std::pair<float, float>(std::max(x_overlap, 0.0f),
                                   std::max(y_overlap, 0.0f));
  }

  // For Macro and Standard-cell cluster
  // update overlap:  True for Add and False for Reduce
  inline void UpdateOverlap(Rect rect, bool flag = false) {
    const float x_overlap =
        std::min(bbox_.ux, rect.ux) - std::max(bbox_.lx, rect.lx);
    const float y_overlap =
        std::min(bbox_.uy, rect.uy) - std::max(bbox_.ly, rect.ly);
    if (x_overlap <= 0.0 || y_overlap <= 0.0)
      return;
    else if (flag == true)
      overlap_area_ += x_overlap * y_overlap;
    else if (flag == false)
      overlap_area_ -= x_overlap * y_overlap;
  }

  // Calculate density
  inline float GetDensity() const { return overlap_area_ / grid_area_; }

  // Check congestion
  // Update congestion: true for add and false for reduce
  inline void UpdateCongestionH(float congestion, bool flag = false) {
    if (flag == true)
      hor_congestion_ += congestion;
    else
      hor_congestion_ -= congestion;
  }

  inline void UpdateCongestionV(float congestion, bool flag = false) {
    if (flag == true)
      ver_congestion_ += congestion;
    else
      ver_congestion_ -= congestion;
  }

  inline void UpdateMacroCongestionH(float congestion, bool flag = false) {
    if (flag == true)
      macro_hor_congestion_ += congestion;
    else
      macro_hor_congestion_ -= congestion;
  }

  inline void UpdateMacroCongestionV(float congestion, bool flag = false) {
    if (flag == true)
      macro_ver_congestion_ += congestion;
    else
      macro_ver_congestion_ -= congestion;
  }

private:
  int x_id_ = 0;
  int y_id_ = 0;
  int id_ = 0.0; // all grids are arranged in a row-based manner
  float grid_area_ = 0.0;
  float overlap_area_ =
      0.0; // the area of macros overlapped with the current grid
  float hor_congestion_ = 0.0;
  float ver_congestion_ = 0.0;
  float macro_hor_congestion_ = 0.0;
  float macro_ver_congestion_ = 0.0;
  float smooth_hor_congestion_ = 0.0;
  float smooth_ver_congestion_ = 0.0;
  Rect bbox_;             // bounding box of current grid
  float x_ = 0.0;         // center location
  float y_ = 0.0;         // center location
  bool available_ = true; // if the grid has been occupied by a hard macro
  friend class PBFNetlist;
};
