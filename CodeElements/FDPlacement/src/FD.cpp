#include <iostream>
#include <map>
#include <vector>
#include <string>
#include <fstream>
#include <iomanip>
#include <algorithm>
#include <cmath>

#include "FD.h"

// Plc Object class
bool PlcObject::IsHardMacro() const {
  return pb_type_ == std::string("MACRO") ? true : false;
}

bool PlcObject::IsSoftMacro() const {
  return pb_type_ == std::string("macro") ? true : false;
}

bool PlcObject::IsHardMacroPin() const {
  return pb_type_ == std::string("MACRO_PIN") ? true : false;
}

bool PlcObject::IsSoftMacroPin() const {
  return pb_type_ == std::string("macro_pin") ? true : false;
}

bool PlcObject::IsPort() const {
  return pb_type_ == std::string("PORT") ? true : false;
}

void PlcObject::MakeSquare() {
  const float area = width_ * height_;
  width_ = std::sqrt(area);
  height_ = width_;
}

const std::pair<float, float> PlcObject::GetPos() const {
  if (IsHardMacroPin() == false)
    return std::pair<float, float>(x_, y_);
  float x = x_;
  float y = y_;
  // get the absolute location for macro pins
  if (macro_ptr_->orient_ == std::string("N")) {
    x = macro_ptr_->x_ + x_offset_;
    y = macro_ptr_->y_ + y_offset_;
  } else if (macro_ptr_->orient_ == std::string("FN")) {
    x = macro_ptr_->x_ - x_offset_;
    y = macro_ptr_->y_ + y_offset_;
  } else if (macro_ptr_->orient_ == std::string("S")) {
    x = macro_ptr_->x_ - x_offset_;
    y = macro_ptr_->y_ - y_offset_;
  } else if (macro_ptr_->orient_ == std::string("FS")) {
    x = macro_ptr_->x_ + x_offset_;
    y = macro_ptr_->x_ - y_offset_;
  } else if (macro_ptr_->orient_ == std::string("E")) {
    x = macro_ptr_->x_ + y_offset_;
    y = macro_ptr_->y_ - x_offset_;
  } else if (macro_ptr_->orient_ == std::string("FE")) {
    x = macro_ptr_->x_ - y_offset_;
    y = macro_ptr_->y_ - x_offset_;
  } else if (macro_ptr_->orient_ == std::string("FW")) {
    x = macro_ptr_->x_ - y_offset_;
    y = macro_ptr_->y_ + x_offset_;
  } else if (macro_ptr_->orient_ == std::string("W")) {
    x = macro_ptr_->x_ + x_offset_;
    y = macro_ptr_->y_ + y_offset_;
  } else {
    x = macro_ptr_->x_ + x_offset_;
    y = macro_ptr_->y_ + y_offset_;
  }
  return std::pair<float, float>(x, y);  
}

float PlcObject::GetX() const {
  return GetPos().first;
}

float PlcObject::GetY() const {
  return GetPos().second;
}

const Rect PlcObject::GetBBox() const {
  const std::pair<float, float> pos = GetPos();
  const std::vector<std::string> normal_orients {
    std::string("N"), std::string("FN"), 
    std::string("S"), std::string("FS")
  };
  float width = width_;
  float height = height_;
  if (std::find(normal_orients.begin(), normal_orients.end(), orient_) == normal_orients.end()) {
    width = height_;
    height = width_;
  }  
  return Rect(pos.first - width / 2.0, pos.second - height / 2.0,
              pos.first + width / 2.0, pos.second + height / 2.0);
}

void PlcObject::SetPos(float x, float y) {
  x_ = x;
  y_ = y;
}

void PlcObject::ResetForce() {
  f_x_ = 0.0;
  f_y_ = 0.0; 
}

void PlcObject::AddForce(float f_x, float f_y) {
  f_x_ += f_x;
  f_y_ += f_y;
}

void PlcObject::NormalForce(float max_f_x, float max_f_y) {
  if (max_f_x > 0.0)
    f_x_ = f_x_ / max_f_x;
  if (max_f_y > 0.0)
    f_y_ = f_y_ / max_f_y;
}

std::pair<float, float> PlcObject::GetForce() const {
  return std::pair<float, float>(f_x_, f_y_);
}

// Flip operation
void PlcObject::Flip(bool x_flag) {
  if (IsHardMacro() == false)
    return;
  
  std::map<std::string, std::string> OrientMapFlipX = {
    { std::string("N"), std::string("FS") },
    { std::string("S"), std::string("FN") },
    { std::string("W"), std::string("FE") },
    { std::string("E"), std::string("FW") },
    { std::string("FN"), std::string("S") },
    { std::string("FS"), std::string("N") },
    { std::string("FW"), std::string("E") },
    { std::string("FE"), std::string("W") }  
  };

  std::map<std::string, std::string> OrientMapFlipY = {
    { std::string("N"), std::string("FN") },
    { std::string("S"), std::string("FS") },
    { std::string("W"), std::string("FW") },
    { std::string("E"), std::string("FE") },
    { std::string("FN"), std::string("N") },
    { std::string("FS"), std::string("S") },
    { std::string("FW"), std::string("W") },
    { std::string("FE"), std::string("E") }  
  };
  
  // flip across the x axis
  if (x_flag == true) {
    orient_ = OrientMapFlipX[orient_];
  } else { // flip across the y axis
    orient_ = OrientMapFlipY[orient_];
  }
}

std::string PlcObject::SimpleStr() const {
  std::string str = "";
  str += std::to_string(node_id_) + " ";
  std::stringstream stream;
  stream << std::fixed << std::setprecision(3) << x_ << " ";
  stream << std::fixed << std::setprecision(3) << y_;
  str += stream.str() + " ";
  if (IsPort() == true) {
    str += "_ ";
  } else {
    str += orient_ + " ";
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
  line += "      placeholder: " + stream.str() + "\n";
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
    out << PrintPlaceholder(std::string("type"), object.pb_type_);
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
    out << PrintPlaceholder(std::string("type"), object.pb_type_);
    if (object.weight_ > 1) {
      out << PrintPlaceholder(std::string("weight"), static_cast<int>(object.weight_));
    } 
    out << PrintPlaceholder(std::string("x"), object.x_);
    out << PrintPlaceholder(std::string("x_offset"), object.x_offset_);
    out << PrintPlaceholder(std::string("y"), object.y_);
    out << PrintPlaceholder(std::string("y_offset"), object.y_offset_);
    out << "}\n";
  } else if (object.IsHardMacro() == true) {
    out << "node {\n";
    out << "  name: \"" << object.name_ << "\"\n";
    out << PrintPlaceholder(std::string("type"), object.pb_type_);
    out << PrintPlaceholder(std::string("height"), object.height_);
    out << PrintPlaceholder(std::string("orientation"), object.orient_);
    out << PrintPlaceholder(std::string("width"), object.width_);
    out << PrintPlaceholder(std::string("x"), object.x_);
    out << PrintPlaceholder(std::string("y"), object.y_);
    out << "}\n";
  } else {
    out << "node {\n";
    out << "  name: \"" << object.name_ << "\"\n";
    out << PrintPlaceholder(std::string("height"), object.height_);
    out << PrintPlaceholder(std::string("type"), object.pb_type_);
    out << PrintPlaceholder(std::string("width"), object.width_);
    out << PrintPlaceholder(std::string("x"), object.x_);
    out << PrintPlaceholder(std::string("y"), object.y_);
    out << "}\n";
  }
  return out;
}

/*
std::string PlcObject::SimpleStr() const {
  std::string str = "";
  str += std::to_string(node_id) + " ";
  str += std::to_string(std::round(x_, 12)) + " ";
  str += std::to_string(std::round(y_, 12)) + " ";
  if (IsPort() == true) {
    str += "_ ";
  } else {
    str += orient_ + " ";
  }
  str += "0\n";
  return str;
}
*/

// Class PBFNetlist
// read netlist file for all the plc objects
void PBFNetlist::ParseNetlistFile(std::string netlist_pbf_file) {
  std::map<std::string, size_t> plc_object_id_map = {  };  // map name to node_id
  // read protocol buffer netlist
  const std::vector<std::string> float_values { 
    std::string("height"), std::string("weight"), std::string("width"),
    std::string("x"), std::string("x_offset"), std::string("y"), std::string("y_offset")
  };
  const std::vector<std::string> placeholders {
    std::string("macro_name"), std::string("orientation"), 
    std::string("side"), std::string("type")
  };

  // read the files and parse the files
  std::string cur_line;
  std::vector<std::string> header; // trace the header file
  std::ifstream file_input(netlist_pbf_file);
  if (!file_input.is_open()) {
    std::cout << "[ERROR] We cannot open netlist file " << netlist_pbf_file << std::endl;
  } 
  // define lamda function to remove qoutes
  auto RemoveQuotes = [&](std::string word) {
    std::string new_word = "";
    for (auto& ch : word) 
      if (ch != '\"')
        new_word += std::string(1, ch);
    return new_word;
  };
  // Read lines
  size_t object_id = 0;
  std::string key = "";
  while (std::getline(file_input, cur_line)) {
    header.push_back(cur_line);
    // split the string based on space
    std::string word = "";
    std::vector<std::string> items;
    std::istringstream ss(cur_line);
    while (ss >> word)
      items.push_back(RemoveQuotes(word));
    // check the contents of items
    if (items[0] == std::string("node")) {
      if (objects_.empty() == false && (*objects_.rbegin())->name_ == std::string("__metadata__")) {
        objects_.pop_back();
        object_id--;
        for (size_t i = 0; i < header.size() - 1; i++)
          pb_netlist_header_ += header[i] + "\n";
      }
      objects_.push_back(std::make_shared<PlcObject>(object_id));
      object_id++;
    } else if (items[0] == std::string("name:")) {
      (*objects_.rbegin())->name_ = items[1];
    } else if (items[0] == std::string("input:")) {
      (*objects_.rbegin())->inputs_.push_back(items[1]);
    } else if (items[0] == std::string("key:")) {
      key = items[1]; // the attribute name
    } else if (items[0] == std::string("placeholder:")) {
      if (key == placeholders[0]) {
        (*objects_.rbegin())->m_name_ = items[1];
      } else if (key == placeholders[1]) {
        (*objects_.rbegin())->orient_ = items[1];
      } else if (key == placeholders[2]) {
        (*objects_.rbegin())->side_ = items[1];
      } else if (key == placeholders[3]) {
        (*objects_.rbegin())->pb_type_ = items[1];
      }
    } else if (items[0] == std::string("f:")) {
      if (key == float_values[0]) {
        (*objects_.rbegin())->height_ = std::stof(items[1]);
      } else if (key == float_values[1]) {
        (*objects_.rbegin())->weight_ = std::stof(items[1]);
      } else if (key == float_values[2]) {
        (*objects_.rbegin())->width_ = std::stof(items[1]);
      } else if (key == float_values[3]) {
        (*objects_.rbegin())->x_ = std::stof(items[1]);
      } else if (key == float_values[4]) {
        (*objects_.rbegin())->x_offset_ = std::stof(items[1]);
      } else if (key == float_values[5]) {
        (*objects_.rbegin())->y_ = std::stof(items[1]);
      } else if (key == float_values[6]) {
        (*objects_.rbegin())->y_offset_ =std::stof(items[1]);
      }
    }
  }
  // Get all the macros, standard-cell clusters and IO ports
  for (auto& plc_object : objects_) {
    plc_object_id_map[plc_object->name_] = plc_object->node_id_;
    if (plc_object->IsHardMacro() == true)  {
      macros_.push_back(plc_object->node_id_);
    } else if (plc_object->IsSoftMacro() == true)  {
      stdcell_clusters_.push_back(plc_object->node_id_);
      plc_object->MakeSquare(); // convert standard-cell clusters to square shape
    } else if (plc_object->IsPort() == true)  {
      ports_.push_back(plc_object->node_id_);
    }
  }
  // map each plc object to its corresponding macro
  for (auto& plc_object : objects_) {
    if (plc_object->IsHardMacroPin() == true || plc_object->IsSoftMacroPin() == true) {
      plc_object->macro_id_ = plc_object_id_map[plc_object->m_name_];
      plc_object->macro_ptr_ = objects_[plc_object->macro_id_];
    } else {
      plc_object->macro_id_ = plc_object->node_id_;
    }
  }
  // create nets
  for (auto& plc_object : objects_) {
    if (plc_object->IsHardMacroPin() == true ||
        plc_object->IsSoftMacroPin() == true ||
        plc_object->IsPort() == true) {
      std::vector<std::shared_ptr<PlcObject> > pins { plc_object };
      for (auto& input_pin : plc_object->inputs_) {
        pins.push_back(objects_[plc_object_id_map[input_pin]]);
      }
      if (pins.size() > 1) {
        plc_object->nets_.push_back(pins.size());
        nets_.push_back(std::make_shared<Net>(pins, plc_object->weight_));
      }
    }
  }
  // merge macros and stdcell_clusters
  macro_clusters_.insert(macro_clusters_.end(), 
                         macros_.begin(),
                         macros_.end());
  macro_clusters_.insert(macro_clusters_.end(),
                         stdcell_clusters_.begin(),
                         stdcell_clusters_.end());
  // sort macro_clusters
  std::sort(macro_clusters_.begin(), macro_clusters_.end());
}

// Parse Plc File
void PBFNetlist::RestorePlacement(std::string file_name) {
  // read the plc file and parse the file
  std::string cur_line;
  std::ifstream file_input(file_name);
  if (!file_input.is_open()) {
    std::cout << "[ERROR] We cannot open plc file " << file_name << std::endl;
  }
  // Read lines
  while (std::getline(file_input, cur_line)) {
    // split the string based on space
    std::string word = "";
    std::vector<std::string> items;
    std::istringstream ss(cur_line);
    while (ss >> word)
      items.push_back(word);
    // check if the current line is related to header
    if (items.empty() == false && items[0] == std::string("#")) {
      plc_header_ += cur_line + "\n";
      if (items.size() > 2 && items[1] == std::string("Columns")) {
        n_rows_ = std::stoi(items[3]);
        n_cols_ = std::stoi(items[6]);
      } else if (items.size() > 2 && items[1] == std::string("Width")) {
        canvas_width_ = std::stof(items[3]);
        canvas_height_ = std::stof(items[6]);
      } else if (items.size() == 10 && items[1] == std::string("Routes")) {
        hroute_per_micro_ = std::stof(items[6]);
        vroute_per_micro_ = std::stof(items[9]);
      } else if (items.size() == 11 && items[1] == std::string("Routes")) {
        hrouting_alloc_ = std::stof(items[7]);
        vrouting_alloc_ = std::stof(items[10]);
      } else if (items.size() == 5 && items[1] == std::string("Smoothing")) {
        smooth_factor_ = std::floor(std::stof(items[4]));
      } else if (items.size() == 5 && items[1] == std::string("Overlap")) {
        overlap_threshold_ = std::floor(std::stof(items[4]));
      }
    } else if (items.size() == 5) {
      size_t node_id = static_cast<size_t>(std::stoi(items[0]));
      objects_[node_id]->x_ = std::stof(items[1]);
      objects_[node_id]->y_ = std::stof(items[2]);
      objects_[node_id]->orient_ = items[3];
    }    
  }
  // grid info
  grid_width_ = canvas_width_ / n_cols_;
  grid_height_ = canvas_height_ / n_rows_;
}


// Write netlist
void PBFNetlist::WriteNetlist(std::string file_name) {
  std::ofstream f;
  f.open(file_name);
  f << pb_netlist_header_;
  for (auto& plc_object : objects_)
    f << *plc_object;
  f.close();
}

void PBFNetlist::WritePlcFile(std::string file_name) {
  std::ofstream f;
  f.open(file_name);
  f << plc_header_;
  for (auto& plc_object : objects_)
    if (plc_object->IsHardMacro() == true ||
        plc_object->IsSoftMacro() == true ||
        plc_object->IsPort() == true) {
      f << plc_object->SimpleStr();
    }
  f.close();
}

// Force-directed placement
void PBFNetlist::InitSoftMacros() {
  const float x = canvas_width_ / 2.0;
  const float y = canvas_height_ / 2.0;
  for (auto& node_id : stdcell_clusters_) 
    objects_[node_id]->SetPos(x, y);
}

void PBFNetlist::CalcAttractiveForce(float attractive_factor, 
                                     float io_factor, 
                                     float max_displacement) {
  // traverse the nets to calculate the attractive force
  for (auto& net : nets_) {
    std::shared_ptr<PlcObject> src_pin = net->pins_[0];
    size_t src_macro_node_id = src_pin->node_id_;
    if (src_pin->IsPort() == false)
      src_macro_node_id = src_pin->macro_ptr_->node_id_;
    // convert multi-pin nets to two-pin nets using star model
    auto iter = net->pins_.begin();
    iter++;
    while (iter != net->pins_.end()) {
      std::shared_ptr<PlcObject>& target_pin = *iter;
      size_t target_macro_node_id = target_pin->node_id_;
      if (target_pin->IsPort() == false)
        target_macro_node_id = target_pin->macro_ptr_->node_id_;
      // check the distance between src_pin and target_pin
      std::pair<float, float> src_pos = src_pin->GetPos();
      std::pair<float, float> target_pos = target_pin->GetPos();
      const float x_dist = -1.0 * (src_pos.first - target_pos.first);
      const float y_dist = -1.0 * (src_pos.second - target_pos.second);
      float k = net->weight_; // spring constant
      if (src_pin->IsPort() == true or target_pin->IsPort() == true)
        k = k * io_factor * attractive_factor;
      else
        k = k * attractive_factor;
      const float f_x = k * x_dist;
      const float f_y = k * y_dist;
      if (src_pin->IsSoftMacroPin() == true)
        src_pin->macro_ptr_->AddForce(f_x, f_y);
      if (target_pin->IsSoftMacroPin() == true)
        target_pin->macro_ptr_->AddForce(-1.0 * f_x, -1.0 * f_y);      
      iter++;
    } // finish current net     
  } // finish traversing nets
}

void PBFNetlist::CalcRepulsiveForce(float repulsive_factor,
                                    float max_displacement) {
  // traverse the soft macros and hard macros to check possible overlap
  auto iter = macro_clusters_.begin();
  while (iter != macro_clusters_.end()) {
    size_t src_macro = *iter;
    for (auto iter_loop = ++iter; 
         iter_loop != macro_clusters_.end(); iter_loop++) {
      size_t target_macro = *iter_loop;
      // check the overlap
      float x_dir = 0.0; // overlap on x direction
      float y_dir = 0.0; // overlap on y direction
      const Rect src_bbox = objects_[src_macro]->GetBBox();
      const Rect target_bbox = objects_[target_macro]->GetBBox();
      const float src_width = src_bbox.ux - src_bbox.lx;
      const float src_height = src_bbox.uy - src_bbox.ly;
      const float target_width = target_bbox.ux - target_bbox.lx;
      const float target_height = target_bbox.uy - target_bbox.ly;
      const float src_cx = (src_bbox.lx + src_bbox.ux) / 2.0;
      const float src_cy = (src_bbox.ly + src_bbox.uy) / 2.0;
      const float target_cx = (target_bbox.lx + target_bbox.ux) / 2.0;
      const float target_cy = (target_bbox.ly + target_bbox.uy) / 2.0;
      const float x_min_dist = (src_width + target_width) / 2.0 - overlap_threshold_;
      const float y_min_dist = (src_height + target_height) / 2.0 - overlap_threshold_;
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
  objects_[node_id]->x_ += x_dist;
  objects_[node_id]->y_ += y_dist;
  const Rect bbox = objects_[node_id]->GetBBox();
  if (bbox.lx < 0.0 || bbox.ly < 0.0 
      || bbox.ux > canvas_width_
      || bbox.uy > canvas_height_) {
    objects_[node_id]->x_ -= x_dist;
    objects_[node_id]->y_ -= y_dist;
  }
}

void PBFNetlist::MoveSoftMacros(float attractive_factor, float repulsive_factor, 
                                float io_factor, float max_displacement) {
  // move soft macros based on forces
  // reset forces
  for (auto& cluster_id : stdcell_clusters_)
    objects_[cluster_id]->ResetForce();
  // calculate forces
  CalcAttractiveForce(attractive_factor, io_factor, max_displacement);
  CalcRepulsiveForce(repulsive_factor, max_displacement);
  // normalization
  float max_f_x = 0.0;
  float max_f_y = 0.0;
  for (auto& cluster_id : stdcell_clusters_) {
    const std::pair<float, float> forces = objects_[cluster_id]->GetForce();
    max_f_x = std::max(max_f_x, std::abs(forces.first));
    max_f_y = std::max(max_f_y, std::abs(forces.second));
  }
  max_f_x *= max_displacement;
  max_f_y *= max_displacement;
  for (auto& cluster_id : stdcell_clusters_) {
    objects_[cluster_id]->NormalForce(max_f_x, max_f_y);
    const std::pair<float, float> forces = objects_[cluster_id]->GetForce();
    MoveNode(cluster_id, forces.first, forces.second);
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





