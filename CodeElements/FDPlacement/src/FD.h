#include <vector>
#include <map>
#include <iostream>
#include <string>
#include <fstream>
#include <sstream>
#include <memory>

// Define the class to handle netlist in Protocol Buffer Format
// Basic data structure
// OrientMap : map the orientation
// PlcObject : a superset of attributes for different types of plc objects
// PBFNetlist: the top-level class for handling netlist in protocol buffer netlist

// ***************************************************************
// Define basic classes
// ***************************************************************

// Define the orientation map
static const std::map<std::string, std::string> OrientMap = {
  { std::string("N"), std::string("R0") },
  { std::string("S"), std::string("R180") },
  { std::string("W"), std::string("R90") },
  { std::string("E"), std::string("R270") },
  { std::string("FN"), std::string("MY") },
  { std::string("FS"), std::string("MX") },
  { std::string("FW"), std::string("MX90") },
  { std::string("FE"), std::string("MY90") }  
};

struct Rect {
  float lx = 0.0;
  float ly = 0.0;
  float ux = 0.0;
  float uy = 0.0;
  
  Rect(float lx_, float ly_, float ux_, float uy_) {
    lx = lx_;
    ly = ly_;
    ux = ux_;
    uy = uy_;
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
    bool IsHardMacro() const;
    bool IsSoftMacro() const;
    bool IsSoftMacroPin() const;
    bool IsHardMacroPin() const;
    bool IsPort() const;
    // Make Square
    void MakeSquare();
    // Get real location instead of relative position
    const std::pair<float, float> GetPos() const;
    float GetX() const;
    float GetY() const;
    const Rect GetBBox() const;
    void SetPos(float x, float y);
    // Force related functions
    void ResetForce();
    void AddForce(float f_x, float f_y);
    void NormalForce(float max_f_x, float max_f_y);
    std::pair<float, float> GetForce() const;
    // Flip operation
    // if x_flag == true, flip across x axis
    // else, flip across y axis
    void Flip(bool x_flag);
    // string representation
    friend std::ostream& operator <<(std::ostream &out, PlcObject& object); // for protocol buffer netlist
    std::string SimpleStr() const; // for plc file    
  private:
    std::string name_ = "";
    size_t node_id_ = 0;  
    float height_ = 0.0;
    float width_ = 0.0;
    float weight_ = 1.0;
    std::string pb_type_ = "MACRO"; // hard macro
    float x_ = 0.0; // center of the object
    float y_ = 0.0; // center of the object
    std::string orient_ = "N"; // orientation
    // PBPORT
    std::string side_ = "LEFT"; // attribute for IOPORT (LEFT, RIGHT, TOP, BOTTOM)
    // PBMACROPIN, PBGRPPIN
    float x_offset_ = 0.0; // pin offset relative to the center of macro ("N")
    float y_offset_ = 0.0; // pin offset relative to the center of macro ("N")
    size_t macro_id_ = 0;  // the corresponding node id of macro which the pin belongs to
    std::string m_name_ = "";
    std::shared_ptr<PlcObject> macro_ptr_ = nullptr; 
    std::vector<size_t> nets_; // nets (id) connecte to this node
    std::vector<std::string> inputs_;
    // the forces applied to this node
    float f_x_ = 0.0;
    float f_y_ = 0.0;   

    // utility function
    friend class PBFNetlist;
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
  private:
    std::vector<std::shared_ptr<PlcObject> > pins_;
    float weight_ = 1.0;
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

    void WriteNetlist(std::string file_name);
    void RestorePlacement(std::string file_name);
    void WritePlcFile(std::string file_name);
  private:
    // information from protocol buffer netlist
    std::string pb_netlist_header_ = "";
    std::vector<std::shared_ptr<PlcObject> > objects_;
    std::vector<size_t> macros_;
    std::vector<size_t> stdcell_clusters_;
    std::vector<size_t> macro_clusters_;
    std::vector<size_t> ports_;
    std::vector<std::shared_ptr<Net> > nets_;
    // information from plc file
    std::string plc_header_ = "";
    int n_cols_ = -1;
    int n_rows_ = -1;
    float canvas_width_ = 0.0;
    float canvas_height_ = 0.0;
    float grid_width_ = 0.0;
    float grid_height_ = 0.0;
    // routing information
    float smooth_factor_ = 2;
    float overlap_threshold_ = 0.0;
    float vrouting_alloc_ = 0.0;
    float hrouting_alloc_ = 0.0;
    float hroute_per_micro_ = 0.0;
    float vroute_per_micro_ = 0.0;
    // utility functions
    void ParseNetlistFile(std::string netlist_pbf_file);
    // Force-directed placement
    void InitSoftMacros(); // put all the soft macros to the center of canvas
    void CalcAttractiveForce(float attractive_factor, float io_factor, float max_displacement);
    void CalcRepulsiveForce(float repulsive_factor, float max_displacement);
    void MoveSoftMacros(float attractive_factor, float repulsive_factor, 
                        float io_factor, float max_displacement);
    void MoveNode(size_t node_id, float x_dist, float y_dist);
};






















