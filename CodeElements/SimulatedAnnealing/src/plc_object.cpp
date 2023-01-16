#include <iostream>
#include <map>
#include <vector>
#include <string>
#include <fstream>
#include <iomanip>
#include <algorithm>
#include <cmath>
#include <numeric>

#include "plc_object.h"

// Main member functions for PlcObject
void PlcObject::SetPos(float x, float y, float grid_width, float grid_height, int num_cols, int num_rows) {
  // We cannot the location for MACROPIN and GRPPIN
  if (pb_type_ == MACROPIN || pb_type_ == GRPPIN)
    return;
  // update the location
  x_ = x;
  y_ = y;
  UpdateBBox(grid_width, grid_height, num_cols, num_rows);
  if (pb_type_ == GRP || pb_type_ == MACRO) { // update corresponding bbox
    for (auto& pin : macro_pins_) {
      pin->x_ = x + x_offset_;
      pin->y_ = y + y_offset_;
      pin->UpdateBBox(grid_width, grid_height, num_cols, num_rows);
    }
  }       
}

void PlcObject::UpdateBBox(float grid_width, float grid_height, int num_cols, int num_rows) {
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
  grid_bbox_.ux_id = static_cast<int>(std::floor(bbox_.ux / grid_width));
  grid_bbox_.uy_id = static_cast<int>(std::floor(bbox_.uy / grid_height));
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
  line  = "  attr {\n";
  line += "    key: \"" + key + "\"\n";
  line += "    value {\n";
  line += "      placeholder: \"" + value + "\"\n";
  line += "    }\n";
  line += "  }\n";
  return line;
}

std::string PrintPlaceholder(std::string key, float value) {
  std::string line = "";
  line  = "  attr {\n";
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
std::ostream& operator <<(std::ostream &out, PlcObject& object) {
  if (object.IsPort() == true) {
    out << "node {\n";
    out << "  name: \"" << object.name_ << "\"\n";
    for (auto& sink : object.inputs_) {
      out << "  input: \"" << sink << "\"\n";
    }
    out << PrintPlaceholder(std::string("side"), object.side_);
    out << PrintPlaceholder(std::string("type"), GetString(object.pb_type_));
    out << PrintPlaceholder(std::string("x"), object.x_);
    out << PrintPlaceholder(std::string("y"), object.y_);
    out << "}\n";
  } else if (object.IsSoftMacroPin() == true || object.IsHardMacroPin() == true) {
    out << "node {\n";
    out << "  name: \"" << object.name_ << "\"\n";
    for (auto& sink : object.inputs_) {
      out << "  input: \"" << sink << "\"\n";
    }
    out << PrintPlaceholder(std::string("macro_name"), object.macro_ptr_->name_);
    out << PrintPlaceholder(std::string("type"), GetString(object.pb_type_));
    if (object.weight_ > 1) {
      out << PrintPlaceholder(std::string("weight"), static_cast<int>(object.weight_));
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
    out << PrintPlaceholder(std::string("orientation"), GetString(object.orient_));
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
