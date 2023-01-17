# ---------------------------------------------------------------------------
# Run Simulated Annealing in parallel with multiple cores
# You must set up the environment correctly before you run this script
# Please check Circuit Training for environment setup
# --------------------------------------------------------------------------
import sys
import os
import subprocess
import multiprocessing
import time
from datetime import datetime
import json
import glob

sa_path = "/home/zf4_projects/macro_placer/TILOS_repo/new_repo/MacroPlacement/CodeElements/SimulatedAnnealing/build/sa"

### Wrapper function for calling Simulated Annealing
def RunSA(run_id, dir, netlist, plc_file, action_probs, num_actions, max_temperature, num_iters, seed, spiral_flag):
    run_dir = dir + "/run_" + str(run_id)
    os.mkdir(run_dir)

    # create param_map
    param_map = { }
    param_map["id"] = run_id
    param_map["dir"] = dir
    param_map["netlist"] = netlist
    param_map["plc_file"] = plc_file
    param_map["action_probs"] = action_probs
    param_map["num_actions"] = num_actions
    param_map["max_temperature"] = max_temperature
    param_map["num_iters"] = num_iters
    param_map["seed"] = seed
    param_map["spiral_flag"] = spiral_flag

    param_file = run_dir + "/params.json"
    f = open(param_file, "w")
    f.write(json.dumps(param_map, indent = 4))
    f.close()

    design = netlist.split('/')[-1].split('.')[0]

    cmd = sa_path + " " + netlist + " " + plc_file + " " + str(num_actions) + " "
    cmd += str(max_temperature) + " " + str(num_iters) + " " + str(seed) + " "
    if (spiral_flag == True):
        cmd += str(1) + " "
    else:
        cmd += str(0) + " "
    for action_prob in action_probs:
        cmd += str(action_prob) + " "
    cmd += design + " " + run_dir
    print(cmd)
    os.system(cmd)

### Run Simulated Annealing with multiple threads
def RunParallelSA(config_json_file):
    # parse the configuration json file
    f = open(config_json_file)
    params = json.load(f)
    f.close()

    netlist = params["netlist"]
    plc_file = params["plc_file"]
    action_probs_list = params["action_probs"]
    num_actions_list = params["num_actions(xn)"]
    max_temperature_list = params["max_temperature"]
    num_iters_list = params["num_iters"]
    seed_list = params["seed"]
    num_cores = params["num_cores"]
    spiral_flag_list = params["spiral_flag"]

    time_str = str(datetime.fromtimestamp(time.time()))
    new_time_str = ""
    for item in time_str.split():
        new_time_str += "_" + item
    result_dir ="./result" + new_time_str
    os.mkdir(result_dir)
    params_file = result_dir + "/params.json"
    f = open(params_file, "w")
    f.write(json.dumps(params, indent = 4))
    f.close()

    param_list = []
    for action_probs in action_probs_list:
        for num_actions in num_actions_list:
            for max_temperature in max_temperature_list:
                for num_iters in num_iters_list:
                    for seed in seed_list:
                        for spiral_flag in spiral_flag_list:
                            param_map = { }
                            param_map["id"] = len(param_list)
                            param_map["dir"] = result_dir
                            param_map["netlist"] = netlist
                            param_map["plc_file"] = plc_file
                            param_map["action_probs"] =  action_probs
                            param_map["num_actions"] = num_actions
                            param_map["max_temperature"] = max_temperature
                            param_map["num_iters"] = num_iters
                            param_map["seed"] = seed
                            param_map["spiral_flag"] = (spiral_flag == 'True' or spiral_flag == 'TRUE')
                            param_list.append(param_map)

    with multiprocessing.Manager() as manager:
        # create lists in server memory
        runtime_list = manager.list([])
        cut_list = manager.list([])
        remaining_runs = len(param_list)
        run_id = 0
        while (remaining_runs > 0):
            num_thread = min(num_cores, remaining_runs)
            process_list = []
            for i in range(num_thread):
                param_map = param_list[run_id]
                p = multiprocessing.Process(target = RunSA,
                                            args = (param_map["id"],
                                                    param_map["dir"],
                                                    param_map["netlist"],
                                                    param_map["plc_file"],
                                                    param_map["action_probs"],
                                                    param_map["num_actions"],
                                                    param_map["max_temperature"],
                                                    param_map["num_iters"],
                                                    param_map["seed"],
                                                    param_map["spiral_flag"]))
                run_id = run_id + 1
                p.start()
                process_list.append(p)

            for process in process_list:
                process.join()

            remaining_runs -= num_thread

    summary_files = glob.glob(result_dir + "/*/*.summary")
    cost_list = []
    for summary_file in summary_files:
        with open(summary_file) as f:
            content = f.read().splitlines()
        f.close()
        # find the start_idx
        start_idx = 0
        for i in range(len(content)):
            items = content[i].split()
            if (len(items) == 1):
                start_idx = i
                break

        if (len(cost_list) == 0):
            for i in range(start_idx, len(content)):
                cost_list.append(float(content[i]))
        else:
            for i in range(start_idx, len(content)):
                idx = i - start_idx
                if (idx >= len(cost_list)):
                    cost_list.append(float(content[i]))
                else:
                    cost_list[idx] = min(cost_list[idx], float(content[i]))

    f = open(result_dir + "/cost_summary.txt", "w")
    for cost in cost_list:
        f.write(str(cost) + "\n")
    f.close()

if __name__ == "__main__":
    config_file  = "config.json"
    RunParallelSA(config_file)










