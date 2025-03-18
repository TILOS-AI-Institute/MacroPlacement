#include <algorithm>
#include <cmath>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <numeric>
#include <string>
#include <vector>

#include "plc_object.h"

// Main member functions for PlcObject
void PlcObject::SetPos(float x, float y, float grid_width, float grid_height,
                       int num_cols, int num_rows) {
  // We cannot update the location for MACROPIN and GRPPIN
  if (pb_type_ == MACROPIN || pb_type_ == GRPPIN)
    return;
  // update the location
  x_ = x;
  y_ = y;
  UpdateBBox(grid_width, grid_height, num_cols, num_rows);
  if (pb_type_ == GRP || pb_type_ == MACRO) { // update corresponding bbox
    for (auto &pin : macro_pins_) {
      pin->x_ = x_ + pin->x_offset_;
      pin->y_ = y_ + pin->y_offset_;
      pin->UpdateBBox(grid_width, grid_height, num_cols, num_rows);
    }
  }
}

void PlcObject::UpdateBBox(float grid_width, float grid_height, int num_cols,
                           int num_rows) {
  // update bounding box
  bbox_.lx = x_ - width_ / 2.0;
  bbox_.ly = y_ - height_ / 2.0;
  bbox_.ux = x_ + width_ / 2.0;
  bbox_.uy = y_ + height_ / 2.0;
  // If the canvas is not specified
  if (grid_width <= 0.0 || grid_height <= 0.0) {
    return;
  }
  grid_bbox_.lx_id = static_cast<int>(std::floor(bbox_.lx / grid_width));
  grid_bbox_.ly_id = static_cast<int>(std::floor(bbox_.ly / grid_height));

  // If GRPPIN or MACROPIN, ux and uy id are the same as lx and ly
  if (pb_type_ == GRPPIN || pb_type_ == MACROPIN) {
    grid_bbox_.ux_id = grid_bbox_.lx_id;
    grid_bbox_.uy_id = grid_bbox_.ly_id;
    return;
  }
  int ux_id = 0, uy_id = 0;
  // For x: if bbox_.ux is exactly divisible by grid_width, subtract 1.
  if (std::fabs(std::fmod(bbox_.ux, grid_width)) < 1e-6 && bbox_.ux >= grid_width)
    ux_id = static_cast<int>(bbox_.ux / grid_width) - 1;
  else
    ux_id = static_cast<int>(std::floor(bbox_.ux / grid_width));

  // For y: if bbox_.uy is exactly divisible by grid_height, subtract 1.
  if (std::fabs(std::fmod(bbox_.uy, grid_height)) < 1e-6 && bbox_.uy >= grid_height)
    uy_id = static_cast<int>(bbox_.uy / grid_height) - 1;
  else
    uy_id = static_cast<int>(std::floor(bbox_.uy / grid_height));

  grid_bbox_.ux_id = std::min(ux_id, num_cols - 1);
  grid_bbox_.uy_id = std::min(uy_id, num_rows - 1);
}

void PlcObject::Compare(const PlcObject &other) const {
  if (name_ != other.name_) {
    std::cout << "Node names are different: " << name_ << " vs " << other.name_
              << std::endl;
    return;
  }

  if (pb_type_ != other.pb_type_) {
    std::cout << "Node " << name_
              << ": types are different: " << GetString(pb_type_) << " vs "
              << GetString(other.pb_type_) << std::endl;
    return;
  }

  if (height_ != other.height_) {
    std::cout << "Node " << name_ << ": height is different: " << height_
              << " vs " << other.height_ << std::endl;
  }

  if (width_ != other.width_) {
    std::cout << "Node " << name_ << ": width is different: " << width_
              << " vs " << other.width_ << std::endl;
  }

  if (x_ != other.x_) {
    std::cout << "Node " << name_ << ": X position is different: " << x_
              << " vs " << other.x_ << std::endl;
  }

  if (y_ != other.y_) {
    std::cout << "Node " << name_ << ": Y position is different: " << y_
              << " vs " << other.y_ << std::endl;
  }

  if (x_offset_ != other.x_offset_) {
    std::cout << "Node " << name_ << ": X offset is different: " << x_offset_
              << " vs " << other.x_offset_ << std::endl;
  }

  if (y_offset_ != other.y_offset_) {
    std::cout << "Node " << name_ << ": Y offset is different: " << y_offset_
              << " vs " << other.y_offset_ << std::endl;
  }
}

// IO related functions for PlcObject
std::string PlcObject::SimpleStr() const {
  std::string str = "";
  str += std::to_string(node_id_) + " ";
  std::stringstream stream;
  stream << std::fixed << std::setprecision(3) << x_ << " ";
  stream << std::fixed << std::setprecision(3) << y_;
  str += stream.str() + " ";
  if (IsPort() == true) {
    str += "- ";
  } else {
    str += GetString(orient_) + " ";
  }
  str += "0\n";
  return str;
}

std::string PrintPlaceholder(std::string key, std::string value) {
  std::string line = "";
  line = "  attr {\n";
  line += "    key: \"" + key + "\"\n";
  line += "    value {\n";
  line += "      placeholder: \"" + value + "\"\n";
  line += "    }\n";
  line += "  }\n";
  return line;
}

std::string PrintPlaceholder(std::string key, float value) {
  std::string line = "";
  line = "  attr {\n";
  line += "    key: \"" + key + "\"\n";
  line += "    value {\n";
  std::stringstream stream;
  stream << std::fixed << std::setprecision(6) << value;
  line += "      f: " + stream.str() + "\n";
  line += "    }\n";
  line += "  }\n";
  return line;
}

// for protocol buffer netlist
std::ostream &operator<<(std::ostream &out, PlcObject &object) {
  if (object.IsPort() == true) {
    out << "node {\n";
    out << "  name: \"" << object.name_ << "\"\n";
    for (auto &sink : object.inputs_) {
      out << "  input: \"" << sink << "\"\n";
    }
    out << PrintPlaceholder(std::string("side"), object.side_);
    out << PrintPlaceholder(std::string("type"), GetString(object.pb_type_));
    out << PrintPlaceholder(std::string("x"), object.x_);
    out << PrintPlaceholder(std::string("y"), object.y_);
    out << "}\n";
  } else if (object.IsSoftMacroPin() == true ||
             object.IsHardMacroPin() == true) {
    out << "node {\n";
    out << "  name: \"" << object.name_ << "\"\n";
    for (auto &sink : object.inputs_) {
      out << "  input: \"" << sink << "\"\n";
    }
    out << PrintPlaceholder(std::string("macro_name"),
                            object.macro_ptr_->name_);
    out << PrintPlaceholder(std::string("type"), GetString(object.pb_type_));
    if (object.weight_ > 1) {
      out << PrintPlaceholder(std::string("weight"),
                              static_cast<int>(object.weight_));
    }
    out << PrintPlaceholder(std::string("x"), object.x_);
    out << PrintPlaceholder(std::string("x_offset"), object.x_offset_N_);
    out << PrintPlaceholder(std::string("y"), object.y_);
    out << PrintPlaceholder(std::string("y_offset"), object.y_offset_N_);
    out << "}\n";
  } else if (object.IsHardMacro() == true) {
    out << "node {\n";
    out << "  name: \"" << object.name_ << "\"\n";
    out << PrintPlaceholder(std::string("height"), object.height_N_);
    out << PrintPlaceholder(std::string("orientation"),
                            GetString(object.orient_));
    out << PrintPlaceholder(std::string("type"), GetString(object.pb_type_));
    out << PrintPlaceholder(std::string("width"), object.width_N_);
    out << PrintPlaceholder(std::string("x"), object.x_);
    out << PrintPlaceholder(std::string("y"), object.y_);
    out << "}\n";
  } else {
    out << "node {\n";
    out << "  name: \"" << object.name_ << "\"\n";
    out << PrintPlaceholder(std::string("height"), object.height_N_);
    out << PrintPlaceholder(std::string("type"), GetString(object.pb_type_));
    out << PrintPlaceholder(std::string("width"), object.width_N_);
    out << PrintPlaceholder(std::string("x"), object.x_);
    out << PrintPlaceholder(std::string("y"), object.y_);
    out << "}\n";
  }
  return out;
}
