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
#include <stdexcept>
#include <cereal/archives/binary.hpp>

#include "plc_netlist.h"

// **************************************************************************
// IO for class PBFNetlist
// **************************************************************************
// read netlist file for all the plc objects
void PBFNetlist::ParseNetlistFile(std::string netlist_pbf_file) {
  // we need this std::string related to map to map macro_pin to macro
  std::unordered_map<std::string, size_t> plc_object_id_map = {}; // map name to node_id
  // read protocol buffer netlist
  // Note that the order is specified by the Circuit Training
  // You cannot change the order
  const std::vector<std::string> float_values{
      std::string("height"),  std::string("weight"),   std::string("width"),
      std::string("x"),       std::string("x_offset"), std::string("y"),
      std::string("y_offset")};
  const std::vector<std::string> placeholders{
      std::string("macro_name"), std::string("orientation"),
      std::string("side"), std::string("type")};

  // read the files and parse the files
  std::string cur_line;
  std::vector<std::string> header; // trace the header file
  std::ifstream file_input(netlist_pbf_file);
  if (!file_input.is_open()) {
    std::cout << "[ERROR] We cannot open netlist file " << netlist_pbf_file
              << std::endl;
  }
  // define lamda function to remove qoutes
  auto RemoveQuotes = [&](std::string word) {
    std::string new_word = "";
    for (auto &ch : word)
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
      if (objects_.empty() == false &&
          (*objects_.rbegin())->name_ == std::string("__metadata__")) {
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
        (*objects_.rbegin())->y_offset_N_ = std::stof(items[1]);
      }
    }
  }
  // Get all the macros, standard-cell clusters and IO ports
  for (auto &plc_object : objects_) {
    plc_object_id_map[plc_object->name_] = plc_object->node_id_;
    if (plc_object->IsHardMacro() == true) {
      plc_object->UpdateOrientation(grid_width_, grid_height_, n_cols_,
                                    n_rows_);
      macros_.push_back(plc_object->node_id_);
    } else if (plc_object->IsSoftMacro() == true) {
      plc_object->UpdateOrientation(grid_width_, grid_height_, n_cols_,
                                    n_rows_);
      stdcell_clusters_.push_back(plc_object->node_id_);
      plc_object
          ->MakeSquare(); // convert standard-cell clusters to square shape
    } else if (plc_object->IsPort() == true) {
      ports_.push_back(plc_object->node_id_);
    }
  }
  // map each plc object to its corresponding macro
  for (auto &plc_object : objects_) {
    if (plc_object->IsHardMacroPin() == true ||
        plc_object->IsSoftMacroPin() == true) {
      auto &macro_id = plc_object_id_map[plc_object->macro_name_];
      plc_object->macro_ptr_ = objects_[macro_id];
      plc_object->macro_ptr_->macro_pins_.push_back(plc_object);
    }
  }
  // create nets
  for (auto &plc_object : objects_) {
    if (plc_object->IsHardMacroPin() == true ||
        plc_object->IsSoftMacroPin() == true || plc_object->IsPort() == true) {
      std::vector<std::shared_ptr<PlcObject>> pins{plc_object};
      for (auto &input_pin : plc_object->inputs_) {
        pins.push_back(objects_[plc_object_id_map[input_pin]]);
      }
      if (pins.size() > 1) {
        for (auto &pin : pins) {
          pin->nets_.push_back(nets_.size());
        }
        nets_.push_back(std::make_shared<Net>(pins, plc_object->weight_));
      }
    }
  }
  // merge macros and stdcell_clusters
  macro_clusters_.insert(macro_clusters_.end(), macros_.begin(), macros_.end());
  macro_clusters_.insert(macro_clusters_.end(), stdcell_clusters_.begin(),
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
        n_cols_ = std::stoi(items[3]);
        n_rows_ = std::stoi(items[6]);
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
      grids_.push_back(std::make_shared<Grid>(grid_width_, grid_height_,
                                              n_cols_, n_rows_, x_id, y_id));
    }
  }

  if ( debug_mode_ ) {
    std::cout << "In restore design : " << std::endl;
    std::cout << "CANVAS_WIDTH = " << canvas_width_ << std::endl;
    std::cout << "CANVAS_HEIGHT = " << canvas_height_ << std::endl;
    std::cout << "GRID_WIDTH = " << grid_width_ << std::endl;
    std::cout << "GRID_HEIGHT = " << grid_height_ << std::endl;
    std::cout << "NUM_COLS = " << n_cols_ << std::endl;
    std::cout << "NUM_ROWS = " << n_rows_ << std::endl;
    std::cout << "Routes per micro, hor : " << hrouting_alloc_ << "  "
              << " ver : " << vrouting_alloc_ << std::endl;
    std::cout << "Routes used by macros, hor : " << hroute_per_micro_ << "  "
              << " ver : " << vroute_per_micro_ << std::endl;
    std::cout << "Smoothing_factor = " << smooth_factor_ << std::endl;
  }
  // update the information about plc object
  for (auto &plc_object : objects_) {
    if (plc_object->IsHardMacro() == true)
      plc_object->UpdateOrientation(grid_width_, grid_height_, n_cols_,
                                    n_rows_);
    plc_object->SetPos(plc_object->x_, plc_object->y_, grid_width_,
                       grid_height_, n_cols_, n_rows_);
  }

  // calculate norm HPWL
  norm_HPWL_ = 0.0;
  for (auto &net : nets_)
    norm_HPWL_ += net->weight_;
  norm_HPWL_ *= (canvas_width_ + canvas_height_);
  // top k grids
  top_k_ = std::max(1, static_cast<int>(std::floor(n_cols_ * n_rows_ * 0.1)));
  top_k_congestion_ =
      std::max(1, static_cast<int>(std::floor(n_cols_ * n_rows_ * 0.1)));
}

// Write netlist
void PBFNetlist::WriteNetlist(std::string file_name) {
  std::ofstream f;
  f.open(file_name);
  f << pb_netlist_header_;
  for (auto &plc_object : objects_)
    f << *plc_object;
  f.close();
}

void PBFNetlist::WritePlcFile(std::string file_name) {
  std::ofstream f;
  f.open(file_name);
  f << plc_header_;
  for (auto &plc_object : objects_)
    if (plc_object->IsHardMacro() == true ||
        plc_object->IsSoftMacro() == true || plc_object->IsPort() == true) {
      f << plc_object->SimpleStr();
    }
  f.close();
}

void PBFNetlist::saveCheckpoint(const std::string &file_name) {
  std::ofstream ofs(file_name, std::ios::binary);
  if (!ofs)
    throw std::runtime_error("Cannot open file for writing: " + file_name);
  cereal::BinaryOutputArchive archive(ofs);
  archive(*this);
}

void PBFNetlist::loadCheckpoint(const std::string &file_name) {
  std::ifstream ifs(file_name, std::ios::binary);
  if (!ifs)
    throw std::runtime_error("Cannot open file for reading: " + file_name);
  cereal::BinaryInputArchive archive(ifs);
  archive(*this);
}