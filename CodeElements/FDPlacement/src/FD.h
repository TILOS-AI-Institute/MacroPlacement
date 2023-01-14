#include <vector>
#include <map>
#include <iostream>
#include <string>
#include <fstream>
#include <sstream>
#include <algorithm>
#include <cmath>
#include <memory>
#include <random>
#include <set>
#include <cassert>

// Define the class to handle netlist in Protocol Buffer Format
// Basic data structure
// PlcObject : a superset of attributes for different types of plc objects
// PBFNetlist: the top-level class for handling netlist in protocol buffer netlist

// Enumerate Type
// MACROPIN for hard macro pin
// GRPIN for soft macro pin (standard-cell cluster)
// GRP for soft macro (standard-cell cluster)
enum PBTYPE { MACRO, PORT, MACROPIN, GRPPIN, GRP};
// string representation
inline std::string GetString(PBTYPE pb_type) {
  switch (pb_type)
  {
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

static const std::map<std::string, PBTYPE> PBTYPE_MAP = {
  { std::string("MACRO"), MACRO } ,
  { std::string("PORT"), PORT } ,
  { std::string("MACRO_PIN"), MACROPIN } ,
  { std::string("macro_pin"), GRPPIN } ,
  { std::string("macro"), GRP } 
};

enum ORIENTATION { N, S, W, E, FN, FS, FW, FE, NONE};
// string representation
inline std::string GetString(ORIENTATION orient) {
  switch (orient)
  {
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

static const std::map<std::string, ORIENTATION> ORIENT_MAP = {
  { std::string("N"),  N },
  { std::string("S"),  S },
  { std::string("W"),  W },
  { std::string("E"),  E },
  { std::string("FN"), N },
  { std::string("FS"), FS },
  { std::string("FW"), FW },
  { std::string("FE"), FE },
  { std::string("-"), NONE}
};


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


// Define the plc object
// This is a superset of attributes for different types of plc objects
// A plc object can only have some or all the attributes
// Please check Circuit Training repo (https://github.com/google-research/circuit_training/blob/main/docs/NETLIST_FORMAT.md) for detailed explanation
class PlcObject {
  public:
    // constructor
    PlcObject(size_t node_id) : node_id_(node_id) {  }
    // functions
    // GetType Information
    inline bool IsHardMacro() const {
      return pb_type_ == MACRO;
    }
    
    inline bool IsSoftMacro() const {
      return pb_type_ == GRP;
    }
    
    inline bool IsSoftMacroPin() const {
      return pb_type_ == GRPPIN;
    }

    inline bool IsHardMacroPin() const {
      return pb_type_ == MACROPIN;
    }

    inline bool IsPort() const {
      return pb_type_ == PORT;
    }
    
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

    inline float GetX() const {
      return x_;
    }    

    inline float GetY() const {
      return y_;
    }

    inline const Rect GetBBox() const {
      return bbox_;
    }
    
    inline const GridRect GetGridBBox() const {
      return grid_bbox_;
    }
    
    // we need grid_width and grid_height to calculate the grid_bbox
    // We cannot set the location of MACROPIN and GRPPIN.
    // Because the locations of MACROPIN and GRPPIN are determined by MACRO and GRP.
    // When you specify the location of MACRO and GRP, the locations of coorepsonding MACROPINs and
    // GRPPINs will also be updated.
    // We only call this function after reading plc file
    void SetPos(float x, float y, float grid_width, float grid_height, int num_cols, int num_rows);
    
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
    void Flip(bool x_flag, float grid_width, float grid_height, int num_cols, int num_rows) {
      if (pb_type_ != MACRO)
        return;
      if (x_flag == true) { // flip around x axis
        switch (orient_)
        {
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
        switch (orient_)
        {
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
      UpdateOrientation(grid_width, grid_height, num_cols, num_rows); // when the orientation update, we need update cooresponding items           
    }
        
    // string representation
    friend std::ostream& operator <<(std::ostream &out, PlcObject& object); // for protocol buffer netlist
    std::string SimpleStr() const; // for plc file    
  private:
    // inherient attributes
    std::string name_ = "";
    size_t node_id_ = 0;  
    float weight_ = 1.0;
    PBTYPE pb_type_ = MACRO;  // hard macro
    // we define xx_N_ becuase the Portocol buffer netlist required these values to generate the netlist file
    float width_N_ = 0.0;
    float height_N_ = 0.0;
    float x_offset_N_ = 0.0;
    float y_offset_N_ = 0.0;
    std::string macro_name_ = ""; // the correponding macro names
    std::shared_ptr<PlcObject> macro_ptr_ = nullptr; 
    std::vector<std::shared_ptr<PlcObject> > macro_pins_; // pins connnected to this macro
    std::vector<size_t> nets_; // nets (id) connecte to this node
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
    
    void UpdateBBox(float grid_width, float grid_height, int num_cols, int num_rows);
    void UpdateOrientation(float grid_width, float grid_height, int num_cols, int num_rows) {
      // update the hard macro information first
      if (orient_ == E || orient_ == FN || orient_ == W || orient_ == FW) {
        width_ = height_N_;
        height_ = width_N_;
      } else {
        width_ = width_N_;
        height_ = height_N_;
      }
      UpdateBBox(grid_width, grid_height, num_cols, num_rows);
      // update the cooresponding bboxes of pins
      for (auto& pin : macro_pins_) {
        switch (orient_)
        {
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
        pin->UpdateBBox(grid_width, grid_height, num_cols, num_rows);
      }
    }

    // utility function
    friend class PBFNetlist;
    friend class Net;
};

std::string PrintPlaceholder(std::string key, std::string value);
std::string PrintPlaceholder(std::string key, float value);

// Net Class
class Net {
  public:
    // constructor
    Net(std::vector<std::shared_ptr<PlcObject> > pins, float weight) {
      pins_ = pins; // the first pin is always the source pin
      weight_ = weight;
    }

    inline void Reset() {
      HPWL_ = 0.0;
    }

    inline void UpdateHPWL() {
      float x_min = std::numeric_limits<float>::max();
      float y_min = std::numeric_limits<float>::max();
      float x_max = 0.0;
      float y_max = 0.0;
      for (auto& pin : pins_) {
        x_min = std::min(x_min, pin->x_);
        x_max = std::max(x_max, pin->x_);
        y_min = std::min(y_min, pin->y_);
        y_max = std::max(y_max, pin->y_);
      }
      HPWL_ = weight_ * (y_max - y_min + x_max - x_min);
    }

  private:
    std::vector<std::shared_ptr<PlcObject> > pins_;
    float weight_ = 1.0;
    float HPWL_ = 0.0; // wirelength
    friend class PBFNetlist;
};

class Grid {
  public:
    Grid() {  }
    Grid(float grid_width, float grid_height, 
         int num_cols, int num_rows, 
         int x_id, int y_id, 
         int smooth_factor) {
      grid_area_ = grid_width * grid_height;
      num_cols_ = num_cols;
      num_rows_ = num_rows;
      x_id_ = x_id;
      y_id_ = y_id;
      id_ = y_id_ * num_cols + x_id_;
      smooth_factor_ = smooth_factor; 
      bbox_ = Rect(x_id * grid_width,  y_id * grid_height,
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
    inline float CalcOverlap(Rect rect) {
      const float x_overlap = std::min(bbox_.ux, rect.ux) - std::max(bbox_.lx, rect.lx);
      const float y_overlap = std::min(bbox_.uy, rect.uy) - std::max(bbox_.ly, rect.ly);
      if (x_overlap <= 0.0 || y_overlap <= 0.0)
        return 0.0;
      else
        return x_overlap * y_overlap;
    }

    // check overlap threshold 
    inline std::pair<float, float> CalcHVOverlap(Rect rect) {
      const float x_overlap = std::min(bbox_.ux, rect.ux) - std::max(bbox_.lx, rect.lx);
      const float y_overlap = std::min(bbox_.uy, rect.uy) - std::max(bbox_.ly, rect.ly);
      return std::pair<float, float>(std::max(x_overlap, 0.0f),
                                     std::max(y_overlap, 0.0f));      
    }
    
    // For Macro and Standard-cell cluster
    // update overlap:  True for Add and False for Reduce
    inline void UpdateOverlap(Rect rect, bool flag = false) {
      const float x_overlap = std::min(bbox_.ux, rect.ux) - std::max(bbox_.lx, rect.lx);
      const float y_overlap = std::min(bbox_.uy, rect.uy) - std::max(bbox_.ly, rect.ly);
      if (x_overlap <= 0.0 || y_overlap <= 0.0)
        return;
      else if (flag == true) 
        overlap_area_ += x_overlap * y_overlap;
      else if (flag == false)
        overlap_area_ -= x_overlap * y_overlap; 
    }

    // Calculate density
    inline float GetDensity() {
      return overlap_area_ / grid_area_;
    }

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

    // smoothing the congestion
    inline void UpdateSmoothCongestion() {
      // smooth horizontal congestion
      const int h_start = std::max(0, x_id_ - smooth_factor_);
      const int h_end   = std::min(num_cols_ - 1, x_id_ + smooth_factor_);
      smooth_hor_congestion_ = hor_congestion_ * (1.0 + 1.0 / (h_end - h_start));
      const int v_start = std::max(0, y_id_ - smooth_factor_);
      const int v_end   = std::min(num_rows_ - 1, y_id_ + smooth_factor_);
      smooth_ver_congestion_ = ver_congestion_ * (1.0 + 1.0 / (v_end - v_start));
    }
    
  private:
    int x_id_ = 0;
    int y_id_ = 0;
    int id_ = 0.0; // all grids are arranged in a row-based manner
    float grid_area_ = 0.0;
    int num_cols_ = 0;
    int num_rows_ = 0;
    int smooth_factor_ = 0.0; 
    float overlap_area_ = 0.0; // the area of macros overlapped with the current grid
    float hor_congestion_ = 0.0;
    float ver_congestion_ = 0.0; 
    float macro_hor_congestion_ = 0.0;
    float macro_ver_congestion_ = 0.0;
    float smooth_hor_congestion_ = 0.0;
    float smooth_ver_congestion_ = 0.0;
    Rect bbox_; // bounding box of current grid
    float x_ = 0.0;  // center location
    float y_ = 0.0;  // center location
    bool available_ = true;  // if the grid has been occupied by a hard macro
    friend class PBFNetlist;
  };

// Class PBFNetlist representing the netlist
class PBFNetlist {
  public:
    PBFNetlist(std::string netlist_pbf_file) {
      ParseNetlistFile(netlist_pbf_file);
    }
    void FDPlacer(float io_factor, std::vector<int> num_steps,
                  std::vector<float> move_distance_factor,
                  std::vector<float> attract_factor,
                  std::vector<float> repel_factor,
                  bool use_current_loc, 
                  bool debug_mode = true);
    float CalcCost();
    void WriteNetlist(std::string file_name);
    void RestorePlacement(std::string file_name);
    void WritePlcFile(std::string file_name);
  private:
    // information from protocol buffer netlist
    std::string pb_netlist_header_ = "";
    std::vector<std::shared_ptr<PlcObject> > objects_;
    std::vector<std::shared_ptr<PlcObject> > pre_objects_;
    std::vector<size_t> macros_;
    std::vector<size_t> stdcell_clusters_;
    std::vector<size_t> macro_clusters_;
    std::vector<size_t> ports_;
    std::set<size_t> placed_macros_;
    std::vector<std::shared_ptr<Net> > nets_;
    std::vector<std::shared_ptr<Grid> > grids_;
    
    // information from plc file
    std::string plc_header_ = "";
    int n_cols_ = -1;
    int n_rows_ = -1;
    float canvas_width_ = 0.0;
    float canvas_height_ = 0.0;
    float grid_width_ = 0.0;
    float grid_height_ = 0.0;
    // routing information
    int smooth_factor_ = 2;
    float overlap_threshold_ = 0.0;
    float vrouting_alloc_ = 0.0;
    float hrouting_alloc_ = 0.0;
    float hroute_per_micro_ = 0.0;
    float vroute_per_micro_ = 0.0;
    float min_dist_ = 1e-4;

    // random seed setting
    int seed_ = 0;
    std::mt19937 generator_;
    std::uniform_real_distribution<float> distribution_;
    std::default_random_engine rng_;
    // cost function
    float HPWL_ = 0.0;
    float norm_HPWL_ = 1.0;
    int top_k_ = 1;
    float density_ = 0.0;
    int top_k_congestion_ = 1;
    float congestion_ = 0.0;
    
    
    // probabilities
    std::vector<float> action_probs_ { 0.0, 0.0, 0.0, 0.0, 0.0};
    
    // utility functions
    void ParseNetlistFile(std::string netlist_pbf_file);
    // Force-directed placement
    void InitSoftMacros(); // put all the soft macros to the center of canvas
    void CalcAttractiveForce(float attractive_factor, float io_factor, float max_displacement);
    void CalcRepulsiveForce(float repulsive_factor, float max_displacement);
    void MoveSoftMacros(float attractive_factor, float repulsive_factor, 
                        float io_factor, float max_displacement);
    void MoveNode(size_t node_id, float x_dist, float y_dist);
    
    // Cost Related information
    // Routing congestion
    void TwoPinNetRouting(std::shared_ptr<Net> net, bool flag = true);
    void TwoPinNetRouting(std::shared_ptr<PlcObject> src, std::shared_ptr<PlcObject> sink,
                          float weight, bool flag);
    void UpdateRouting(std::shared_ptr<Net> net, bool flag = true);
    void UpdateMacroCongestion(std::shared_ptr<PlcObject> plc_object, bool flag);
    // Simulated Annealing related macros
    void InitMacroPlacement(bool spiral_flag = true);
    bool CheckOverlap(size_t macro);
    bool IsFeasible(size_t macro);
};







