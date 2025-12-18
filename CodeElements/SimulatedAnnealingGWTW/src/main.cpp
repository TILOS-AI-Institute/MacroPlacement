#include <chrono>
#include <iostream>
#include <omp.h>
#include <sstream>
#include "plc_netlist.h"

int main(int argc, char *argv[]) {
  auto start_timestamp_global = std::chrono::high_resolution_clock::now();
  std::string netlist_file = argv[1];
  std::string plc_file = argv[2];
  std::vector<float> action_probs;
  unsigned int num_actions = std::stoul(std::string(argv[3]));
  float max_temp = std::stof(std::string(argv[4]));
  unsigned int num_iters = std::stoul(std::string(argv[5]));
  int seed = std::stoi(std::string(argv[6]));
  bool spiral_flag;
  std::istringstream(argv[7]) >> spiral_flag;
  for (int i = 0; i < 5; i++) {
    action_probs.push_back(std::stof(std::string(argv[i + 8])));
  }
  std::string design_name = std::string(argv[13]);
  std::string run_dir = std::string(argv[14]);
  float hpwl_weight = std::stof(std::string(argv[15]));
  float density_weight = std::stof(std::string(argv[16]));
  float congestion_weight = std::stof(std::string(argv[17]));
  float syncup_freq = std::stof(std::string(argv[18]));
  float sqync_count = 1 / syncup_freq - 1;
  int num_workers = std::stoi(std::string(argv[19]));
  int top_k = std::stoi(std::string(argv[20]));
  bool fast_sync = (std::stoi(argv[21]) != 0);
  bool save_cp = false;
  bool load_cp = false;
  if (argc > 22) {
    save_cp = (std::stoi(argv[22]) != 0);
    load_cp = (std::stoi(argv[23]) != 0);
  }
  // if load_cp is true then get cp_dir as well
  std::string cp_dir = "";
  if (load_cp && argc > 24) {
    cp_dir = std::string(argv[24]);
  } else {
    load_cp = false;
    // Print cp wont be loaded
    std::cout << "Checkpoint wont be loaded as cp dir is missing" << std::endl;
  }
  const float min_temp = 1e-8;
  const float cooling_rate =
      std::exp(std::log(min_temp / max_temp) / num_iters);
  std::cout << std::string(80, '*') << std::endl;
  std::cout << "The Parameters for Simulated Annealing" << std::endl;
  std::cout << "[PARAMS] num_actions = " << num_actions << std::endl;
  std::cout << "[PARAMS] max_temperature = " << max_temp << std::endl;
  // Print cooling rate
  std::cout << "[PARAMS] cooling_rate = " << cooling_rate << std::endl;
  std::cout << "[PARAMS] num_iters = " << num_iters << std::endl;
  std::cout << "[PARAMS] seed = " << seed << std::endl;
  std::cout << "[PARAMS] spiral_flag = " << spiral_flag << std::endl;

  std::cout << "[PARAMS] action_probs =  { ";
  for (auto &value : action_probs)
    std::cout << value << " ";
  std::cout << " } " << std::endl;

  // Print the weights
  std::cout << "[PARAMS] hpwl_weight = " << hpwl_weight << std::endl;
  std::cout << "[PARAMS] density_weight = " << density_weight << std::endl;
  std::cout << "[PARAMS] congestion_weight = " << congestion_weight
            << std::endl;
  // number of workers
  std::cout << "[PARAMS] num_workers = " << num_workers << std::endl;
  std::cout << "[PARAMS] syncup_freq = " << syncup_freq << std::endl;
  std::cout << "[PARAMS] top_k = " << top_k << std::endl;
  // If fast sync is true then report results may not be reproducible
  std::cout << "[PARAMS] fast_sync = " << fast_sync << std::endl;
  omp_set_num_threads(num_workers);

  std::vector<int> resource_assingment(num_workers, 0);

  // top k resource distribute equaly
  std::vector<int> top_k_resource;
  int equal_resource = num_workers / top_k;
  int total_resource = equal_resource * num_workers;
  int worker_id = top_k;
  for (int i = 0; i < top_k; i++) {
    resource_assingment[i] = i;
    top_k_resource.push_back(equal_resource);
    if (total_resource < num_workers) {
      top_k_resource[i] += 1;
      total_resource++;
    }
    for (int j = 0; j < top_k_resource[i] - 1; j++) {
      resource_assingment[worker_id] = i;
      worker_id++;
    }
  }

  // Print the top k resource
  std::cout << "[PARAMS] top_k_resource = { ";
  for (auto &value : top_k_resource)
    std::cout << value << " ";
  std::cout << " } " << std::endl;

  // Initialize the workers
  // print starting initialization
  std::cout << "Starting Initialization" << std::endl;
  auto start_timestamp_initialize = std::chrono::high_resolution_clock::now();
  unsigned int sync_iter = static_cast<unsigned int>(num_iters * syncup_freq);
  std::vector<std::unique_ptr<PBFNetlist>> workers;

#pragma omp parallel for schedule(dynamic)
  for (worker_id = 0; worker_id < num_workers; worker_id++) {
    std::unique_ptr<PBFNetlist> worker =
        std::make_unique<PBFNetlist>(netlist_file);
    bool worker_spiral_flag = worker_id % 2 == 0 ? spiral_flag : !spiral_flag;

    worker->RestorePlacement(plc_file);
    // If Worker count is 1 then run FD placer and report the cost
    if (num_workers == 1) {
      worker->setWeight(hpwl_weight, density_weight, congestion_weight);
      worker->CallFDPlacer();
      float cost = worker->CalcCost();
      // Report the cost and action details
      std::cout << "Initial Placement Cost : " << cost
                << std::endl;
      // Add new lines
      std::cout << std::string(80, '-') << std::endl;
    }
    std::string summary_file = run_dir + "/" + design_name + "_" +
                               std::to_string(worker_id) + ".summary";
    worker->initWorker(worker_id, action_probs, num_actions, max_temp,
                       cooling_rate, sync_iter, seed + worker_id,
                       worker_spiral_flag, summary_file);

    worker->setWeight(hpwl_weight, density_weight, congestion_weight);
    worker->CallFDPlacer();
    float scratch_cost = worker->CalcCost();
    // Save Check Point
    if (save_cp) {
      std::string cp_file = run_dir + "/" + design_name + "_" +
                            std::to_string(worker_id) + ".cp";
      worker->saveCheckpoint(cp_file);
    }

#pragma omp critical
    { workers.push_back(std::move(worker));
    // Initialized the worker print
    std::cout << "Initialized Worker ID : " << worker_id
              << " Cost: " << scratch_cost << std::endl;
    }
  }

  // Print Initialization is done and runtime in seconds
  auto end_timestamp_initialize = std::chrono::high_resolution_clock::now();
  double total_initialize_time =
      std::chrono::duration_cast<std::chrono::nanoseconds>(
          end_timestamp_initialize - start_timestamp_initialize)
          .count() * 1e-9;
  std::cout << "Initialization is done in " << total_initialize_time 
            << " seconds" << std::endl;
  
  // Start the Simulated Annealing
  if (load_cp) {
    for (auto &worker : workers) {
      int worker_id = worker->getWorkerID();
      std::string cp_file = cp_dir + "/" + "checkpoint_" +
                            std::to_string(worker_id) + ".cp";
      worker->loadCheckpoint(cp_file);
      // Report the cost and action details
      std::cout << "Loaded Checkpoint Worker ID : " << worker_id
                << " Cost : " << worker->getCost() << std::endl;
    }
  }

  int current_sync_count = 0;
  bool track_best = false;
  for (int iter = 0; iter < num_iters;) {
    bool is_sync = false;
    std::cout << "Starting Simulated Annealing" << std::endl;
    // set max iterations as iter + sync_iter or num_iters which ever is minimum
    int max_iter = std::min(iter + sync_iter, num_iters);
#pragma omp parallel for schedule(dynamic)
    for (auto &worker : workers) {
      try {
        worker->SimulatedAnnealing(is_sync, false, iter, max_iter);
      } catch (const std::exception &e) {
        #pragma omp critical
        {
        std::cerr << "Worker ID : " << worker->getWorkerID()
                  << " Exception caught: " << e.what() << std::endl;
        }
      }
      // Print the worker id and cost
#pragma omp critical
      {
      if (fast_sync)
        is_sync = true;
      // Print the worker id and cost
      std::cout << "Worker ID : " << worker->getWorkerID()
                << " Cost : " << worker->getCost() << std::endl;
      }
    }
    std::cout << "Starting Synchronization" << std::endl;
    // Keep track of the sync time
    auto start_timestamp_sync = std::chrono::high_resolution_clock::now();
    iter += sync_iter;
    current_sync_count++;
    // Sort the workers based on the cost
    std::sort(workers.begin(), workers.end(),
              [](const std::unique_ptr<PBFNetlist> &a,
                 const std::unique_ptr<PBFNetlist> &b) {
                return a->getCost() < b->getCost();
              });

    if (iter >= num_iters) {
      // At the end there is no need of syncup
      continue;
    }
    
    if ( current_sync_count > sqync_count/2 ) {
      track_best = true;
    }

    // Sync up the workers
    // int worker_sync_id = top_k;
    std::cout << "Starting copying the best locations and orientations" << std::endl;
    #pragma omp parallel for schedule(dynamic)
    for ( int i = top_k; i < num_workers; i++ ) {
      std::unordered_map<size_t, std::pair<float, float>> locs;
      std::unordered_map<size_t, ORIENTATION> orients;
      workers[resource_assingment[i]]->getLocAndOrient(locs, orients, false);
      workers[i]->LocAndOrrientUpdate(locs, orients);
      workers[i]->setTrackBest(track_best);
      float ref_cost = workers[resource_assingment[i]]->getCost();
      int ref_worker_id = workers[resource_assingment[i]]->getWorkerID();
      float prev_cost = workers[i]->getCost();
      workers[i]->LocAndOrrientUpdate(locs, orients);
      // workers[i]->CallFDPlacer();
      float temp_cost = workers[i]->CalcCost();
      // Printing the cost is critical pragma
#pragma omp critical
      {
      std::cout << "Worker ID : " << workers[i]->getWorkerID()
                << " Cost : " << temp_cost << " " << ref_cost << " "
                << prev_cost << std::endl;
      }
    }

    // Report the top_k cost
    std::cout << "Iteration : " << iter << " Sync count: " << current_sync_count << std::endl;
#pragma omp parallel for schedule(dynamic)
    for (int i = 0; i < top_k; i++) {
      workers[i]->setTrackBest(track_best);
      float cost = workers[i]->getCost();
      // Save the plc file
      std::string plc_file = run_dir + "/" + design_name + "_" +
                             std::to_string(cost) + "_" +
                             std::to_string(workers[i]->getWorkerID()) + ".plc";
      workers[i]->WritePlcFile(plc_file);
#pragma omp critical
      {
      std::cout << "Worker ID : " << workers[i]->getWorkerID()
                << " Cost : " << cost << std::endl;
      workers[i]->reportActoinDetails();
      // Add new lines
      std::cout << std::string(80, '-') << std::endl;
      }
    }
    auto end_timestamp_sync = std::chrono::high_resolution_clock::now();
    double total_sync_time =
        std::chrono::duration_cast<std::chrono::nanoseconds>(
            end_timestamp_sync - start_timestamp_sync)
            .count() * 1e-9;
    std::cout << "Sync up: " << current_sync_count << " is done in " 
              << total_sync_time << " seconds" << std::endl;
  }
  auto start_timestamp_rpt = std::chrono::high_resolution_clock::now();
  // Print the final cost of all the workers
  std::cout << std::string(80, '-') << std::endl;

  std::cout << "Final Cost of all the workers" << std::endl;
  // Write the summary file for each worker
#pragma omp parallel for schedule(dynamic)
  for (auto &worker : workers) {
    worker->UpdateBest();
    worker->CallFDPlacer();
    worker->CalcCost();
    // worker->writeCostSummary();
    // Write the plc file
    float cost = worker->getCost();
    std::string plc_file = run_dir + "/" + design_name + "_" +
                           std::to_string(cost) + "_" +
                           std::to_string(worker->getWorkerID()) + "_final.plc";
    worker->WritePlcFile(plc_file);
#pragma omp critical
    {
    // Report the cost and action details
    std::cout << "Worker ID : " << worker->getWorkerID() << " Cost : " << cost
              << std::endl;
    worker->reportActoinDetails();
    // Add new lines
    std::cout << std::string(80, '-') << std::endl;
    }
  }

  auto end_timestamp_global = std::chrono::high_resolution_clock::now();
  double total_global_time =
      std::chrono::duration_cast<std::chrono::nanoseconds>(
          end_timestamp_global - start_timestamp_global)
          .count();
  // Report reporting runtime
  double total_rpt_time =
      std::chrono::duration_cast<std::chrono::nanoseconds>(
          end_timestamp_global - start_timestamp_rpt)
          .count() * 1e-9;
  std::cout << "Reporting is done in " << total_rpt_time << " seconds"
            << std::endl;
  total_global_time *= 1e-9;
  std::cout << "Runtime of simulated annealing : " << total_global_time
            << std::endl;
  
  std::cout << std::string(80, '*') << std::endl;
  std::cout << "Writing Summary Files" << std::endl;
  // Write the summary file for each worker
#pragma omp parallel for schedule(dynamic)
  for (auto &worker : workers) {
    worker->writeCostSummary();
  }

  return 0;
}
