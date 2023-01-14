#include <iostream>
#include <map>
#include <vector>
#include <string>
#include <fstream>
#include <iomanip>
#include <algorithm>
#include <cmath>
#include <numeric>

#include "FD.h"

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


void PlcObject::SetPos(float x, float y, float grid_width, float grid_height, int num_cols, int num_rows) {
      if (pb_type_ == MACROPIN || pb_type_ == GRPPIN)
        return;
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
      grid_bbox_.lx_id = static_cast<int>(std::floor(bbox_.lx / grid_width));
      grid_bbox_.ly_id = static_cast<int>(std::floor(bbox_.ly / grid_height));
      grid_bbox_.ux_id = static_cast<int>(std::floor(bbox_.ux / grid_width));
      grid_bbox_.uy_id = static_cast<int>(std::floor(bbox_.uy / grid_height));
      if (grid_bbox_.lx_id < 0)
        grid_bbox_.lx_id = 0;
      if (grid_bbox_.ly_id < 0)
        grid_bbox_.ly_id = 0;
      if (grid_bbox_.ux_id >= num_cols)
        grid_bbox_.ux_id = num_cols - 1;
      if (grid_bbox_.uy_id >= num_rows)
        grid_bbox_.uy_id = num_rows - 1;      
      assert(grid_bbox_.lx_id >= 0);
      assert(grid_bbox_.ly_id >= 0);
      assert(grid_bbox_.ux_id < num_cols);
      assert(grid_bbox_.uy_id < num_rows); 
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

// Class PBFNetlist
// read netlist file for all the plc objects
void PBFNetlist::ParseNetlistFile(std::string netlist_pbf_file) {
  // we need this std::string related to map to map macro_pin to macro
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
        (*objects_.rbegin())->macro_name_ = items[1];
      } else if (key == placeholders[1]) {
        (*objects_.rbegin())->orient_ = ORIENT_MAP.at(items[1]);
      } else if (key == placeholders[2]) {
        (*objects_.rbegin())->side_ = items[1];
      } else if (key == placeholders[3]) {
        (*objects_.rbegin())->pb_type_ = PBTYPE_MAP.at(items[1]);
      }
    } else if (items[0] == std::string("f:")) {
      if (key == float_values[0]) {
        (*objects_.rbegin())->height_N_ = std::stof(items[1]);
      } else if (key == float_values[1]) {
        (*objects_.rbegin())->weight_ = std::stof(items[1]);
      } else if (key == float_values[2]) {
        (*objects_.rbegin())->width_N_ = std::stof(items[1]);
      } else if (key == float_values[3]) {
        (*objects_.rbegin())->x_ = std::stof(items[1]);
      } else if (key == float_values[4]) {
        (*objects_.rbegin())->x_offset_N_ = std::stof(items[1]);
      } else if (key == float_values[5]) {
        (*objects_.rbegin())->y_ = std::stof(items[1]);
      } else if (key == float_values[6]) {
        (*objects_.rbegin())->y_offset_N_ =std::stof(items[1]);
      }
    }
  }
  // Get all the macros, standard-cell clusters and IO ports
  for (auto& plc_object : objects_) {
    plc_object_id_map[plc_object->name_] = plc_object->node_id_;
    if (plc_object->IsHardMacro() == true)  {
      plc_object->UpdateOrientation(grid_width_, grid_height_, n_cols_, n_rows_);
      macros_.push_back(plc_object->node_id_);
    } else if (plc_object->IsSoftMacro() == true)  {
      plc_object->UpdateOrientation(grid_width_, grid_height_, n_cols_, n_rows_);
      stdcell_clusters_.push_back(plc_object->node_id_);
      plc_object->MakeSquare(); // convert standard-cell clusters to square shape
    } else if (plc_object->IsPort() == true)  {
      ports_.push_back(plc_object->node_id_);
    }
  }
  // map each plc object to its corresponding macro
  for (auto& plc_object : objects_) {
    if (plc_object->IsHardMacroPin() == true || plc_object->IsSoftMacroPin() == true) {
      auto& macro_id = plc_object_id_map[plc_object->macro_name_];
      plc_object->macro_ptr_ = objects_[macro_id];
      plc_object->macro_ptr_->macro_pins_.push_back(plc_object);
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
  // sort macro_clusters.
  // We need this beacuse the FD placer calculates the repulsive force
  // following this order
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
        smooth_factor_ = static_cast<int>(std::floor(std::stof(items[4])));
      } else if (items.size() == 5 && items[1] == std::string("Overlap")) {
        overlap_threshold_ = std::floor(std::stof(items[4]));
      }
    } else if (items.size() == 5) {
      size_t node_id = static_cast<size_t>(std::stoi(items[0]));
      objects_[node_id]->x_ = std::stof(items[1]);
      objects_[node_id]->y_ = std::stof(items[2]);
      objects_[node_id]->orient_ = ORIENT_MAP.at(items[3]);
    }    
  }  
  // grid info and create grids
  grid_width_ = canvas_width_ / n_cols_;
  grid_height_ = canvas_height_ / n_rows_;
  for (int y_id = 0; y_id < n_rows_; y_id++) {
    for (int x_id = 0; x_id < n_cols_; x_id++) {
      grids_.push_back(std::make_shared<Grid>(grid_width_, 
                                              grid_height_,
                                              n_cols_,
                                              n_rows_,
                                              x_id, y_id, 
                                              smooth_factor_)); 
    }
  }
  // update the information about plc object
  for (auto& plc_object : objects_) {
    if (plc_object->IsHardMacro() == true) 
      plc_object->UpdateOrientation(grid_width_, grid_height_, n_cols_, n_rows_);
    plc_object->SetPos(plc_object->x_, plc_object->y_, grid_width_, grid_height_, n_cols_, n_rows_);
  }
  // calculate norm HPWL
  norm_HPWL_ = 0.0;
  for (auto& net : nets_) 
    norm_HPWL_ += net->weight_;
  norm_HPWL_ *= (canvas_width_ + canvas_height_);
  // top k grids
  top_k_ = std::max(1, static_cast<int>(std::floor(n_cols_ * n_rows_ * 0.1)));
  top_k_congestion_ = std::max(1, static_cast<int>(std::floor(n_cols_ * n_rows_ * 0.1)));
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

// Get routing information
// 2-pin net routing 
// flag = true for adding and flag = false for reducing
void PBFNetlist::TwoPinNetRouting(std::shared_ptr<Net> net, bool flag) {
  // calculate horizontal congestion
  // This function will only be called when both src and sink are Port or Pins, so lx_id = ux_id
  std::shared_ptr<PlcObject>& src = net->pins_[0];
  std::shared_ptr<PlcObject>& sink = net->pins_[1];
  const int min_col_id = std::min(src->grid_bbox_.lx_id, sink->grid_bbox_.lx_id);
  const int max_col_id = std::max(src->grid_bbox_.lx_id, sink->grid_bbox_.lx_id);
  for (int col_id = min_col_id;  col_id < max_col_id; col_id++) {
    grids_[src->grid_bbox_.ly_id * n_cols_ + col_id]->UpdateCongestionH(net->weight_, flag);
  }
  const int min_row_id = std::min(src->grid_bbox_.ly_id, sink->grid_bbox_.ly_id);
  const int max_row_id = std::max(src->grid_bbox_.ly_id, sink->grid_bbox_.ly_id);
  for (int row_id = min_row_id; row_id < max_row_id; row_id++) {
    grids_[row_id * n_cols_ + sink->grid_bbox_.ly_id]->UpdateCongestionV(net->weight_, flag);
  }  
}

void PBFNetlist::TwoPinNetRouting(std::shared_ptr<PlcObject> src, std::shared_ptr<PlcObject> sink,
                                  float weight, bool flag) {
  // calculate horizontal congestion
  // This function will only be called when both src and sink are Port or Pins, so lx_id = ux_id
  const int min_col_id = std::min(src->grid_bbox_.lx_id, sink->grid_bbox_.lx_id);
  const int max_col_id = std::max(src->grid_bbox_.lx_id, sink->grid_bbox_.lx_id);
  for (int col_id = min_col_id;  col_id < max_col_id; col_id++) {
    grids_[src->grid_bbox_.ly_id * n_cols_ + col_id]->UpdateCongestionH(weight, flag);
  }
  const int min_row_id = std::min(src->grid_bbox_.ly_id, sink->grid_bbox_.ly_id);
  const int max_row_id = std::max(src->grid_bbox_.ly_id, sink->grid_bbox_.ly_id);
  for (int row_id = min_row_id; row_id < max_row_id; row_id++) {
    grids_[row_id * n_cols_ + sink->grid_bbox_.ly_id]->UpdateCongestionV(weight, flag);
  }  
}

// Get routing information (general case)
// multi-pin nets are decomposed into multiple two-pin nets
void PBFNetlist::UpdateRouting(std::shared_ptr<Net> net, bool flag) {
  // check the conditions using switch clauses
  switch(net->pins_.size()) {
    case 1:
      return; // ignore all single-pin net
    case 2: {
        TwoPinNetRouting(net, flag);
      }
      return;
    case 3:  {
        // sort pins based on col_id
        std::sort(net->pins_.begin(), net->pins_.end(), 
                  [&](std::shared_ptr<PlcObject> src, std::shared_ptr<PlcObject> sink) {
                    return src->grid_bbox_.lx_id < sink->grid_bbox_.lx_id;
                  });      
        // define alias for better understanding
        int& col_id_1 = net->pins_[0]->grid_bbox_.lx_id;
        int& col_id_2 = net->pins_[1]->grid_bbox_.lx_id;
        int& col_id_3 = net->pins_[2]->grid_bbox_.lx_id;
        int& row_id_1 = net->pins_[0]->grid_bbox_.ly_id;
        int& row_id_2 = net->pins_[1]->grid_bbox_.ly_id;
        int& row_id_3 = net->pins_[2]->grid_bbox_.ly_id;
        // checking L Routing condition
        if (col_id_1 < col_id_2 && col_id_2 < col_id_3 && 
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
          for (auto row_id = std::min(row_id_2, row_id_3); row_id < std::max(row_id_2, row_id_3); row_id++) 
            grids_[row_id * n_cols_ + col_id_2]->UpdateCongestionV(net->weight_, flag);
          return;
        } else {
          // T routing   
          // when we come to T routing, we already have
          // col_id_min = col_id_1
          // col_id_max = col_id_2
          for (auto col_id = col_id_1;  col_id < col_id_3; col_id++) 
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
        for (size_t i = 1; i < net->pins_.size(); i++) {
          TwoPinNetRouting(net->pins_[0], net->pins_[i], net->weight_, flag);
        }
      }
      return;
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
      grid->UpdateMacroCongestionH(h_overlap * hrouting_alloc_, flag);
      grid->UpdateMacroCongestionV(v_overlap * vrouting_alloc_, flag);
    }
  }
} 

// Calculate the cost from scratch
float PBFNetlist::CalcCost() {
  // reset
  for (auto& grid : grids_)
    grid->Reset();
  // calculate wirelength cost
  HPWL_ = 0.0;
  for (auto& net : nets_) {
    net->UpdateHPWL();
    HPWL_ += net->HPWL_;
  }
  HPWL_ = HPWL_ / norm_HPWL_;
  std::cout << "[Calculate Cost] wirelength cost :  " << HPWL_ << std::endl;
  // calculate the density
  for (auto& node_id : macro_clusters_) {
    Rect rect = objects_[node_id]->GetBBox();
    const int lx_id = std::floor(rect.lx / grid_width_);
    const int ly_id = std::floor(rect.ly / grid_height_);
    int ux_id = std::floor(rect.ux / grid_width_);
    int uy_id = std::floor(rect.uy / grid_height_);
    if (ux_id == n_cols_)
      ux_id = n_cols_ - 1;
    if (uy_id == n_rows_)
      uy_id = n_rows_ - 1;
    for (int y_id = ly_id; y_id <= uy_id; y_id++) {
      for (int x_id = lx_id; x_id <= ux_id; x_id++) {
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
  std::cout << "[Calculate Cost] Density cost : " << density_ << std::endl;
  // calculate the congestion cost
  // update the congestion caused by net
  for (auto& net : nets_) 
    UpdateRouting(net, true);
  // update the congestion caused by macro
  for (auto& macro : macros_)
    UpdateMacroCongestion(objects_[macro], true);
  // smooth the congestion by net
  for (auto& grid : grids_)
    grid->UpdateSmoothCongestion();
  std::vector<float> congestion_list;
  for (auto& grid : grids_) {
    congestion_list.push_back(
      (grid->smooth_ver_congestion_ + grid->macro_ver_congestion_) / (grid_width_ * vroute_per_micro_) +
      (grid->smooth_hor_congestion_ + grid->macro_hor_congestion_) / (grid_height_ * hroute_per_micro_)
    );
    congestion_list.push_back((grid->macro_ver_congestion_) / (grid_width_ * vroute_per_micro_));
    congestion_list.push_back((grid->macro_hor_congestion_) / (grid_height_ * hroute_per_micro_));
  }
  std::sort(congestion_list.begin(), congestion_list.end(), std::greater<float>());
  congestion_ = 0.0;
  for (int i = 0; i < top_k_congestion_; i++)
    congestion_ += congestion_list[i];
  congestion_ = congestion_ / top_k_congestion_; 
  std::cout << "[Calculate Cost] Congestion cost : " << congestion_ << std::endl;
  return HPWL_ + density_ * 0.5 + congestion_ * 0.5;
}

// Simulated Annealing related functions
void PBFNetlist::InitMacroPlacement(bool spiral_flag) {
  // determine the order of grids
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
      if (rect.lx < 0.0 || rect.ly < 0.0 || 
          rect.ux > canvas_width_ || rect.uy > canvas_height_) 
        continue;
      // check if there is an overlap with other macros
      if (CheckOverlap(macro) == true)
        continue; // This is some overlap with other placed macros
      // place macro on this grid
      grids_[grid_id]->available_ = true;
      placed_macros_.insert(macro);
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
    if (rect1.lx >= rect2.ux || rect1.ly >= rect2.uy ||
        rect1.ux <= rect2.lx || rect1.uy <= rect2.ly)
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





