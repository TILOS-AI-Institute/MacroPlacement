#pragma once
#include <algorithm>
#include <cassert>
#include <cmath>
#include <fstream>
#include <iostream>
#include <map>
#include <memory>
#include <random>
#include <set>
#include <sstream>
#include <string>
#include <vector>

#include "basic_object.h"
class PBFNetlist;

// Define the class to handle netlist in Protocol Buffer Format
// Basic data structure
// PlcObject : a superset of attributes for different types of plc objects
// This is a superset of attributes for different types of plc objects
// A plc object can only have some or all the attributes
// Please check Circuit Training repo
// (https://github.com/google-research/circuit_training/blob/main/docs/NETLIST_FORMAT.md)
// for detailed explanation
class PlcObject {
public:
  // constructor
  PlcObject(size_t node_id) : node_id_(node_id) {}
  // functions
  // GetType Information
  inline bool IsHardMacro() const { return pb_type_ == MACRO; }

  inline bool IsSoftMacro() const { return pb_type_ == GRP; }

  inline bool IsSoftMacroPin() const { return pb_type_ == GRPPIN; }

  inline bool IsHardMacroPin() const { return pb_type_ == MACROPIN; }

  inline bool IsPort() const { return pb_type_ == PORT; }

  // Function to compare two PlcObject instances
  void Compare(const PlcObject &other) const;

  // Make Square
  inline void MakeSquare() {
    const float area = width_N_ * height_N_;
    width_N_ = std::sqrt(area);
    height_N_ = width_N_;
    width_ = width_N_;
    height_ = height_N_;
  }

  // Get real location instead of relative position
  inline const std::pair<float, float> GetPos() const {
    return std::pair<float, float>(x_, y_);
  }

  size_t GetNodeId() const { return node_id_; }

  inline float GetX() const { return x_; }

  inline float GetY() const { return y_; }

  inline const Rect GetBBox() const { return bbox_; }

  inline const GridRect GetGridBBox() const { return grid_bbox_; }

  // we need grid_width and grid_height to calculate the grid_bbox
  // We cannot set the location of MACROPIN and GRPPIN.
  // Because the locations of MACROPIN and GRPPIN are determined by MACRO and
  // GRP. When you specify the location of MACRO and GRP, the locations of
  // coorepsonding MACROPINs and GRPPINs will also be updated. We only call this
  // function after reading plc file
  void SetPos(float x, float y, float grid_width, float grid_height,
              int num_cols, int num_rows);

  // Force related functions
  inline void ResetForce() {
    f_x_ = 0.0;
    f_y_ = 0.0;
  }

  inline void AddForce(float f_x, float f_y) {
    f_x_ += f_x;
    f_y_ += f_y;
  }

  inline void NormalForce(float max_f_x, float max_f_y) {
    if (max_f_x > 0.0)
      f_x_ = f_x_ / max_f_x;
    if (max_f_y > 0.0)
      f_y_ = f_y_ / max_f_y;
  }

  inline std::pair<float, float> GetForce() const {
    return std::pair<float, float>(f_x_, f_y_);
  }

  // Flip operation
  // Flop operation can only be applied to hard macro
  // if x_flag == true, flip across x axis
  // else, flip across y axis
  void Flip(bool x_flag, float grid_width, float grid_height, int num_cols,
            int num_rows) {
    if (pb_type_ != MACRO)
      return;
    if (x_flag == true) { // flip around x axis
      switch (orient_) {
      case N:
        orient_ = FS;
        break;
      case FN:
        orient_ = S;
        break;
      case S:
        orient_ = FN;
        break;
      case FS:
        orient_ = N;
        break;
      case E:
        orient_ = FW;
        break;
      case FE:
        orient_ = W;
        break;
      case FW:
        orient_ = E;
        break;
      case W:
        orient_ = FE;
        break;
      default:
        orient_ = N;
        break;
      }
    } else { // flip around y axis
      switch (orient_) {
      case N:
        orient_ = FN;
        break;
      case FN:
        orient_ = N;
        break;
      case S:
        orient_ = FS;
        break;
      case FS:
        orient_ = S;
        break;
      case E:
        orient_ = FE;
        break;
      case FE:
        orient_ = E;
        break;
      case FW:
        orient_ = W;
        break;
      case W:
        orient_ = FW;
        break;
      default:
        orient_ = N;
        break;
      }
    }
    // we need update cooresponding items after orientation change
    UpdateOrientation(grid_width, grid_height, num_cols, num_rows);
  }

  // string representation
  friend std::ostream &
  operator<<(std::ostream &out,
             PlcObject &object); // for protocol buffer netlist
  std::string SimpleStr() const; // for plc file
private:
  // inherient attributes
  std::string name_ = "";
  size_t node_id_ = 0;
  float weight_ = 1.0;
  PBTYPE pb_type_ = MACRO; // hard macro
  // we define xx_N_ becuase the Portocol buffer netlist required these values
  // to generate the netlist file
  float width_N_ = 0.0;
  float height_N_ = 0.0;
  float x_offset_N_ = 0.0;
  float y_offset_N_ = 0.0;
  std::string macro_name_ = ""; // the correponding macro names
  std::shared_ptr<PlcObject> macro_ptr_ = nullptr;
  std::vector<std::shared_ptr<PlcObject>>
      macro_pins_;           // pins connnected to this macro
  std::vector<size_t> nets_; // nets (id) connecte to this node (src and sink)
  std::vector<std::string> inputs_; // sinks driven by this node
  std::string side_ = "LEFT"; // attribute for IOPORT (LEFT, RIGHT, TOP, BOTTOM)
  // real information  (can be updated)
  float x_ = 0.0; // center of the object
  float y_ = 0.0; // center of the object
  float height_ = 0.0;
  float width_ = 0.0;
  float x_offset_ = 0.0;
  float y_offset_ = 0.0;
  ORIENTATION orient_ = N; // orientation
  Rect bbox_;
  GridRect grid_bbox_; // gridding box
  // the forces applied to this node
  float f_x_ = 0.0;
  float f_y_ = 0.0;
  // utility function
  void UpdateBBox(float grid_width, float grid_height, int num_cols,
                  int num_rows);
  // update the orientation
  void UpdateOrientation(float grid_width, float grid_height, int num_cols,
                         int num_rows) {
    // update the hard macro information first
    if (orient_ == E || orient_ == FE || orient_ == W || orient_ == FW) {
      width_ = height_N_;
      height_ = width_N_;
    } else {
      width_ = width_N_;
      height_ = height_N_;
    }
    // As we are not allowed to rotate macros so, there is no need to update
    // the bbox of Macros
    // UpdateBBox(grid_width, grid_height, num_cols, num_rows);
    // update the cooresponding bboxes of pins
    for (auto &pin : macro_pins_) {
      switch (orient_) {
      case N:
        pin->x_offset_ = pin->x_offset_N_;
        pin->y_offset_ = pin->y_offset_N_;
        break;
      case FN:
        pin->x_offset_ = -1 * pin->x_offset_N_;
        pin->y_offset_ = pin->y_offset_N_;
        break;
      case S:
        pin->x_offset_ = -1 * pin->x_offset_N_;
        pin->y_offset_ = -1 * pin->y_offset_N_;
        break;
      case FS:
        pin->x_offset_ = pin->x_offset_N_;
        pin->y_offset_ = -1 * pin->y_offset_N_;
        break;
      case E:
        pin->x_offset_ = pin->y_offset_N_;
        pin->y_offset_ = -1 * pin->x_offset_N_;
        break;
      case FE:
        pin->x_offset_ = -1 * pin->y_offset_N_;
        pin->y_offset_ = -1 * pin->x_offset_N_;
        break;
      case FW:
        pin->x_offset_ = -1 * pin->y_offset_N_;
        pin->y_offset_ = pin->x_offset_N_;
        break;
      case W:
        pin->x_offset_ = pin->y_offset_N_;
        pin->y_offset_ = pin->x_offset_N_;
        break;
      default:
        break;
      }
      pin->x_ = x_ + pin->x_offset_;
      pin->y_ = y_ + pin->y_offset_;
      pin->UpdateBBox(grid_width, grid_height, num_cols, num_rows);
    }
  }

  // utility function
  friend class PBFNetlist;
  friend class Net;
};

// Utility functions
std::string PrintPlaceholder(std::string key, std::string value);
std::string PrintPlaceholder(std::string key, float value);
