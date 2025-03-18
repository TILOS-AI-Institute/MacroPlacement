// If there is no valid result, the output will be empty file
#include <iostream>
#include <string>
#include <vector>
#include <algorithm>
#include <sstream>
#include <algorithm>
#include <fstream>
#include <iterator>
#include <cmath>
#include <chrono>
#include <iomanip>

// Using hMetis library
extern "C" {
  void HMETIS_PartRecursive(int nvtxs, int nhedges, int *vwgts,
                             int *eptr, int *eind, int *hewgts,
                             int nparts, int ubfactor,
                             int *options, int *part, int *edgecut);
};


int main(int argc, char* argv[]) {
  std::string hypergraph_file = "";
  std::string fixed_file = "";
  int Nparts = 2;
  int UBfactor = 5;
  int Nruns = 10;
  int CType = 1;
  int RType = 1;
  int Vcycle = 1;
  int Reconst = 0;
  int dbglvl = 16;
  int seed = 0;

  if(argc == 4) {
    hypergraph_file = std::string(argv[1]);
    Nparts = std::stoi(std::string(argv[2]));
    UBfactor = std::stoi(std::string(argv[3]));
  } else if(argc == 5) {
    hypergraph_file = std::string(argv[1]);
    fixed_file = std::string(argv[2]);
    Nparts = std::stoi(std::string(argv[3]));
    UBfactor = std::stoi(std::string(argv[4]));
  } else if(argc == 10) {
    hypergraph_file = std::string(argv[1]);
    Nparts = std::stoi(std::string(argv[2]));
    UBfactor = std::stoi(std::string(argv[3]));
    Nruns = std::stoi(std::string(argv[4]));
    CType = std::stoi(std::string(argv[5]));
    RType = std::stoi(std::string(argv[6]));
    Vcycle = std::stoi(std::string(argv[7]));
    Reconst = std::stoi(std::string(argv[8]));
    dbglvl = std::stoi(std::string(argv[9]));
   } else if(argc == 11) {
    hypergraph_file = std::string(argv[1]);
    Nparts = std::stoi(std::string(argv[2]));
    UBfactor = std::stoi(std::string(argv[3]));
    Nruns = std::stoi(std::string(argv[4]));
    CType = std::stoi(std::string(argv[5]));
    RType = std::stoi(std::string(argv[6]));
    Vcycle = std::stoi(std::string(argv[7]));
    Reconst = std::stoi(std::string(argv[8]));
    dbglvl = std::stoi(std::string(argv[9]));
    seed = std::stoi(std::string(argv[10]));
  } else if(argc == 12) {
    hypergraph_file = std::string(argv[1]);
    fixed_file = std::string(argv[2]);
    Nparts = std::stoi(std::string(argv[3]));
    UBfactor = std::stoi(std::string(argv[4]));
    Nruns = std::stoi(std::string(argv[5]));
    CType = std::stoi(std::string(argv[6]));
    RType = std::stoi(std::string(argv[7]));
    Vcycle = std::stoi(std::string(argv[8]));
    Reconst = std::stoi(std::string(argv[9]));
    dbglvl = std::stoi(std::string(argv[10]));
    seed = std::stoi(std::string(argv[11]));
  } else {
    std::cout << std::string(80, '*') << std::endl;
    std::cout << "Usage of hMetis:  " << std::endl;
    std::cout << "[Option1]:  hmetis HGraphFile Nparts UBfactor" << std::endl;
    std::cout << "[Option2]:  hmetis HGraphFile FixFile Nparts UBfactor" << std::endl;
    std::cout << "[Option3]:  hmetis HGraphFile Nparts UBfactor Nruns ";
    std::cout << "CType RType Vcycle Reconst dbglvl" << std::endl;
    std::cout << "[Option4]:  hmetis HGraphFile FixFile Nparts UBfactor Nruns ";
    std::cout << "CType RType Vcycle Reconst dbglvl" << std::endl;
  }

  // print options
  std::cout << "[INFO] HGraphFile : " << hypergraph_file << std::endl;
  std::cout << "[INFO] FixFile : " << fixed_file << std::endl;
  std::cout << "[INFO] Nparts : " << Nparts << std::endl;
  std::cout << "[INFO] UBfactor : " << UBfactor << std::endl;
  std::cout << "[INFO] Nruns : " << Nruns << std::endl;
  std::cout << "[INFO] CType : " << CType << std::endl;
  std::cout << "[INFO] RType : " << RType << std::endl;
  std::cout << "[INFO] Vcycle : " << Vcycle << std::endl;
  std::cout << "[INFO] Reconst : " << Reconst << std::endl;
  std::cout << "[INFO] dbglvl : " << dbglvl << std::endl;
  std::cout << "[INFO] seed : "   << seed << std::endl;




  std::string solution_file = hypergraph_file + std::string(".part.") + std::to_string(Nparts);
  
  auto start_timestamp = std::chrono::high_resolution_clock::now();


  // *******************************************
  // Read hypergraph and fixed vertices
  // ******************************************
  int edgecut = -1;
  int num_vertices = 4;
  int num_hyperedges = 7;
  int flag = 0;
  
  std::vector<int> vertices_weight;
  std::vector<int> hyperedges_weight;
  std::vector<int> hyperedges_ind;
  std::vector<int> hyperedges_ptr;
  std::vector<int> vertices_part;

  std::cout << "[INFO] Reading hypergraph file: " << hypergraph_file << std::endl;
  std::ifstream hypergraph_file_input(hypergraph_file);
  if(!hypergraph_file_input.is_open()) {                                 
    std::cout << "Can not open " << hypergraph_file << std::endl;        
    std::ofstream solution_file_output;
    solution_file_output.open(solution_file);
    solution_file_output.close();
    return 1;                                                                           
  }

  std::string cur_line;
  std::getline(hypergraph_file_input, cur_line);
  std::istringstream cur_line_buf(cur_line);
  std::vector<int> stats {std::istream_iterator<int>(cur_line_buf), std::istream_iterator<int>()};
  num_hyperedges = stats[0];
  num_vertices = stats[1];
  if(stats.size() == 3) {
    flag = stats[2];
  }
  std::cout << "[INFO] Starting to read " << num_hyperedges << " hyperedges for " << num_vertices << " vertices" << std::endl;
  for(int i = 0; i < num_hyperedges; i++) {
    std::getline(hypergraph_file_input, cur_line);
    std::istringstream cur_line_buf(cur_line);
    std::vector<int> net { std::istream_iterator<int>(cur_line_buf),                                
                           std::istream_iterator<int>() };
    hyperedges_ptr.push_back(hyperedges_ind.size());
    if((flag % 10) == 1) {
      hyperedges_weight.push_back(net[0]);
      for(int j = 1; j < net.size(); j++) 
        hyperedges_ind.push_back(net[j] - 1);
    } else {
      for(auto& vertex : net)
        hyperedges_ind.push_back(vertex - 1);
    }
  }

  hyperedges_ptr.push_back(hyperedges_ind.size());
  
  if(flag >= 10) {
    std::cout << "[INFO] Reading vertex weights..." << std::endl;
    for(int i = 0; i < num_vertices; i++) {
      std::getline(hypergraph_file_input, cur_line);
      vertices_weight.push_back(std::stoi(cur_line));
    }  
  }

  hypergraph_file_input.close();
  std::cout << "[INFO] Finished reading hypergraph file" << std::endl;

  if(fixed_file.size() != 0) {
    std::cout << "[INFO] Reading fixed vertices file: " << fixed_file << std::endl;
    std::ifstream fixed_file_input(fixed_file);
    if(!fixed_file_input.is_open()) {                                 
      std::cout << "Can not open " << fixed_file << std::endl;        
      std::ofstream solution_file_output;
      solution_file_output.open(solution_file);
      solution_file_output.close();
      return 1;                                                                           
    }
    
    int part_id = -1;
    while(fixed_file_input >> part_id)
      vertices_part.push_back(part_id);
    
    fixed_file_input.close();
    std::cout << "[INFO] Finished reading fixed vertices file" << std::endl;
  }

  std::cout << "[INFO] Initializing data structures for hMETIS..." << std::endl;

  int* vwgts = nullptr;
  if(vertices_weight.size() > 0) {
    vwgts = (int*) malloc((unsigned) num_vertices * sizeof(int));
    for(int i = 0; i < vertices_weight.size(); i++)
      vwgts[i] = vertices_weight[i];
  }

  
  int* hewgts = nullptr;
  if(hyperedges_weight.size() > 0) {
    hewgts = (int*) malloc((unsigned) num_hyperedges * sizeof(int));
    for(int i = 0; i < hyperedges_weight.size(); i++)
      hewgts[i] = hyperedges_weight[i];
  }

  int* eind = (int*) malloc((unsigned) hyperedges_ind.size() * sizeof(int));
  for(int i = 0; i < hyperedges_ind.size(); i++)
    eind[i] = hyperedges_ind[i];

  int* eptr = (int*) malloc((unsigned) hyperedges_ptr.size() * sizeof(int));
  for(int i = 0; i < hyperedges_ptr.size(); i++)
    eptr[i] = hyperedges_ptr[i];

  int* part = (int*) malloc((unsigned) num_vertices * sizeof(int));
  if(vertices_part.size() == num_vertices) {
    for(int i = 0; i < num_vertices; i++)
      part[i] = vertices_part[i];
  }


  int options[9] = { 0 };
  options[0] = 1;
  options[1] = Nruns;
  options[2] = CType;
  options[3] = RType;
  options[4] = Vcycle;
  options[5] = Reconst;
  options[6] = 0;  // Initialize to 0 (no fixed vertices)
  options[7] = seed;  // Set seed value
  options[8] = 0;  // Set verbosity to 0
  
  if(vertices_part.size() == num_vertices) {
    options[6] = 1;  // Set fixed vertices flag if fixed file was provided and read correctly
    std::cout << "[INFO] Using fixed vertices from file" << std::endl;
  }
  
  // Debug output to verify options
  std::cout << "[INFO] Fixed vertices flag (option 6): " << options[6] << std::endl;
  std::cout << "[INFO] Random seed (option 7): " << options[7] << std::endl;
  std::cout << "[INFO] Verbosity (option 8): " << options[8] << std::endl;

  std::cout << "[INFO] Initialization complete, calling hMETIS partitioning algorithm..." << std::endl;
  
  // ******************************************************************
  // Call hMetis and handle resources properly
  // ******************************************************************
  try {
    // Create a backup of fixed vertices before calling hMETIS
    std::vector<int> fixed_vertices_backup;
    if(options[6] == 1) {
      fixed_vertices_backup.resize(num_vertices);
      for(int i = 0; i < num_vertices; i++) {
        if(vertices_part[i] >= 0) {
          fixed_vertices_backup[i] = vertices_part[i];
        } else {
          fixed_vertices_backup[i] = -1;  // Mark as not fixed
        }
      }
      std::cout << "[INFO] Fixed vertices backup created" << std::endl;
    }
    std::cout << "[INFO] Pre-Assign Part of Vertices 0" << part[0] << std::endl;
    std::cout << "[INFO] Starting hMETIS partitioning..." << std::endl;
    HMETIS_PartRecursive(num_vertices, num_hyperedges, vwgts,
                          eptr, eind, hewgts, Nparts, UBfactor,
                          options, part, &edgecut);
    std::cout << "[INFO] hMETIS partitioning completed" << std::endl;
    
    // Restore any fixed vertices that may have been changed by hMETIS
    if(options[6] == 1) {
      int fixed_changes = 0;
      for(int i = 0; i < num_vertices; i++) {
        if(fixed_vertices_backup[i] >= 0 && part[i] != fixed_vertices_backup[i]) {
          // Add print statement to check the fixed vertices
          std::cout << "[INFO] Fixed vertex " << i << " was moved from " << fixed_vertices_backup[i] << " to " << part[i] << std::endl;
          part[i] = fixed_vertices_backup[i];
          fixed_changes++;
        }
      }
      if(fixed_changes > 0) {
        std::cout << "[WARNING] Restored " << fixed_changes << " fixed vertices that were moved" << std::endl;
      }
    }
    
    std::cout << "[INFO] Final CutSize : " << edgecut << std::endl;
    
    float total_weight = 0.0;
    std::vector<float> blocks_balance(Nparts, 0.0);
    for (int i = 0; i < num_vertices; i++) {
      float weight = (vertices_weight.size() == 0) ? 1.0 : vertices_weight[i];
      total_weight += weight;
      blocks_balance[part[i]] += weight;
    }
    
    float max_balance = (100.0 / Nparts + UBfactor) * 0.01;
    
    bool balance_violated = false;
    // std::cout << "[INFO] Final Balance :  ";
    // for (int i = 0; i < blocks_balance.size(); i++) {
    //   blocks_balance[i] = blocks_balance[i] / total_weight;
    //   std::cout << std::fixed << std::setprecision(5) << blocks_balance[i] << "   ";
      
    //   // Check if any partition exceeds the balance constraint
    //   if (blocks_balance[i] > max_balance) {
    //     balance_violated = true;
    //   }
    // }
    // std::cout << std::endl;
    
    if (balance_violated) {
      std::cout << "[ERROR] Balance constraint violated (max allowed: " << max_balance << ")" << std::endl;
      std::ofstream solution_file_output;
      solution_file_output.open(solution_file);
      solution_file_output.close();
    } else {
      // Write solution to file
      std::ofstream solution_file_output;
      solution_file_output.open(solution_file);
      std::cout << "[INFO] Writing solution to file: " << solution_file << std::endl;
      for (int i = 0; i < num_vertices; i++)
        solution_file_output << part[i] << std::endl;
      solution_file_output.close();
      std::cout << "[INFO] Solution file written successfully" << std::endl;
    }
  }
  catch (const std::exception& e) {
    std::cerr << "[ERROR] Exception: " << e.what() << std::endl;
    return 1;
  }
  
  // Clean up allocated memory
  free(vwgts);
  free(hewgts);
  free(eind);
  free(eptr);
  free(part);
  
  auto end_timestamp = std::chrono::high_resolution_clock::now();
  double time_taken = std::chrono::duration_cast<std::chrono::nanoseconds>(end_timestamp - start_timestamp).count();
  time_taken *= 1e-9;
  std::cout << "[INFO] Runtime:  " << std::fixed << std::setprecision(2) << time_taken << " sec" << std::endl;
  return 0;
}













