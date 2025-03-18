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
#include "plc_object.h"

class PBFNetlist;

// Net Class
class Net {
public:
  // constructor
  Net(std::vector<std::shared_ptr<PlcObject>> pins, float weight) {
    pins_ = pins; // the first pin is always the source pin
    weight_ = weight;
  }

  inline void Reset() { HPWL_ = 0.0; }

  inline void UpdateHPWL() {
    float x_min = std::numeric_limits<float>::max();
    float y_min = std::numeric_limits<float>::max();
    float x_max = -1.0 * x_min;
    float y_max = -1.0 * y_min;
    for (auto &pin : pins_) {
      x_min = std::min(x_min, pin->x_);
      x_max = std::max(x_max, pin->x_);
      y_min = std::min(y_min, pin->y_);
      y_max = std::max(y_max, pin->y_);
    }
    HPWL_ = weight_ * (y_max - y_min + x_max - x_min);
  }

private:
  std::vector<std::shared_ptr<PlcObject>> pins_;
  float weight_ = 1.0;
  float HPWL_ = 0.0; // wirelength
  friend class PBFNetlist;
};
