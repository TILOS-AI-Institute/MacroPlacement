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

// Define the class to handle netlist in Protocol Buffer Format
// Basic data structure
// Enumerate Type
// MACROPIN for hard macro pin
// GRPIN for soft macro pin (standard-cell cluster)
// GRP for soft macro (standard-cell cluster)
enum PBTYPE { MACRO, PORT, MACROPIN, GRPPIN, GRP };
// string representation
inline std::string GetString(PBTYPE pb_type) {
  switch (pb_type) {
  case MACRO:
    return std::string("MACRO");
  case PORT:
    return std::string("PORT");
  case MACROPIN:
    return std::string("MACRO_PIN");
  case GRPPIN:
    return std::string("macro_pin");
  case GRP:
    return std::string("macro");
  default:
    return std::string("MACRO");
  }
}

static const std::unordered_map<std::string, PBTYPE> PBTYPE_MAP = {
  {"MACRO", MACRO},
  {"PORT", PORT},
  {"MACRO_PIN", MACROPIN},
  {"macro_pin", GRPPIN},
  {"macro", GRP}
};

enum ORIENTATION { N, S, W, E, FN, FS, FW, FE, NONE };
// string representation
inline std::string GetString(ORIENTATION orient) {
  switch (orient) {
  case N:
    return std::string("N");
  case S:
    return std::string("S");
  case W:
    return std::string("W");
  case E:
    return std::string("E");
  case FN:
    return std::string("FN");
  case FS:
    return std::string("FS");
  case FW:
    return std::string("FW");
  case FE:
    return std::string("FE");
  default:
    return std::string("-");
  }
}

static const std::unordered_map<std::string, ORIENTATION> ORIENT_MAP = {
    {std::string("N"), N},   {std::string("S"), S},   {std::string("W"), W},
    {std::string("E"), E},   {std::string("FN"), N},  {std::string("FS"), FS},
    {std::string("FW"), FW}, {std::string("FE"), FE}, {std::string("-"), NONE}};

// ***************************************************************
// Define basic classes
// ***************************************************************
struct Rect {
  float lx = 0.0;
  float ly = 0.0;
  float ux = 0.0;
  float uy = 0.0;

  Rect() {
    lx = 0.0;
    ly = 0.0;
    ux = 0.0;
    uy = 0.0;
  }

  Rect(float lx_, float ly_, float ux_, float uy_) {
    lx = lx_;
    ly = ly_;
    ux = ux_;
    uy = uy_;
  }
};

struct GridRect {
  int lx_id = 0;
  int ly_id = 0;
  int ux_id = 0;
  int uy_id = 0;

  GridRect() {
    lx_id = 0;
    ly_id = 0;
    ux_id = 0;
    uy_id = 0;
  }

  GridRect(int lx_id_, int ly_id_, int ux_id_, int uy_id_) {
    lx_id = lx_id_;
    ly_id = ly_id_;
    ux_id = ux_id_;
    uy_id = uy_id_;
  }
};

struct LOC {
  int x_id = 0;
  int y_id = 0;

  LOC() {}

  LOC(int x_id_, int y_id_) {
    x_id = x_id_;
    y_id = y_id_;
  }

  bool IsEqual(const LOC &loc) const {
    if (this->x_id == loc.x_id && this->y_id == loc.y_id)
      return true;
    else
      return false;
  }

  bool operator<(const LOC &loc) const {
    if (this->x_id < loc.x_id)
      return true;
    else if (this->x_id == loc.x_id && this->y_id < loc.y_id)
      return true;
    else
      return false;
  }
};
