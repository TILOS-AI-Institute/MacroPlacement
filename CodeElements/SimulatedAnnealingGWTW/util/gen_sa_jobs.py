import os

ns = [2, 5]
iters = [5000, 10000, 15000, 20000, 25000]
sync_freqs = [0.1, 0.2, 0.5, 1.0]

sa_bin = "/home/scratch/sakundu/SA/MP-SA/build/sa"
arg1 = "./CT_Netlist/ariane/netlist.pb.txt ./CT_Netlist/ariane/initial.plc"
temp = 10
run_dir="./Ariane_X1"
arg2 = f"1 1 0.24 0.24 0.04 0.24 0.24 ariane {run_dir}/run_"
arg3 = "1.0 0.5 0.5"
arg4 = "20 4"

i = 0
for n in ns:
    for iter in iters:
        for sync_freq in sync_freqs:
            if not os.path.exists(f"{run_dir}/run_{i}"):
                os.makedirs(f"{run_dir}/run_{i}")
            args = f"{arg1} {n} {temp} {iter} {arg2}{i} {arg3} {sync_freq} {arg4}"
            cmd = f"{sa_bin} {args} | tee {run_dir}/run_{i}/run.log"
            print(cmd)
            i += 1
