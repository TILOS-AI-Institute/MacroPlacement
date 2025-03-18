## Simulated Annealing with Go With The Winners (GWTW)

This repository provides code to run **Simulated Annealing (SA)** wrapped
with **Go With The Winners (GWTW)** meta-heuristic to minimize the **proxy cost**
for a given **clustered netlist**.

### Generating the Clustered Netlist
1. First, generate the protobuf netlist from Innovus using this [script](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/Flows/util/gen_pb.tcl) available in the **TILOS/MacroPlacement** repository for a placed design.
2. Next, use the Circuit Training grouping code to generate the clustered netlist.

### Code Overview
- The SA code is implemented in **C++**.  
- Follow the steps below to build and test the code.

[Here](./doc/MP_SA.pdf) is a brief description of our SA implementation.
<!-- <iframe src="./doc/MP_SA.pdf" width="100%" height="500px" style="border: none;"></iframe> -->

---
### Pre-requisites
Ensure the following dependencies are installed:
- **CMake**: [3.25.1](https://github.com/Kitware/CMake/archive/refs/tags/v3.25.1.tar.gz)  
- **GCC-Toolset**: [11.2.0](https://ftp.gnu.org/gnu/gcc/gcc-11.2.0)  
- **Cereal**: [1.3.2](https://github.com/USCiLab/cereal/archive/refs/tags/v1.3.2.tar.gz)  

---
### Docker / Singularity Image
We provide recipie files to build a Docker/Singularity image for the code.
Here are the steps to build the image:
```bash
cd tools
docker build --no-cache  --tag mp_sa:rocky8 -f ./docker_mp_sa .
```

If you do not have root access to your server, then you can create a Singularity
image from the Docker image in your local machine using the following command:
```bash
## The following code creates singularity image: mp_sa_rocky8.sif
singularity build mp_sa_rocky8.sif docker-daemon://mp_sa:rocky8
```
Our SA code is deterministic, meaning that if you run it twice with the same 
input (and `IS_ASYNC=0`), you will get the same output. We have tested our
code in an identical environment on both an Intel(R) Xeon(R) Gold and an AMD
EPYC 7763 CPU, and both produced the exact same results for our testcases.
  
Therefore, we expect that using a Singularity image or Docker image will ensure
the reproducibility of our experimental results for the given testcases.

---
### Steps to Build
Execute the following commands:
```bash
mkdir build
cd build
cmake ..
make -j 10
```

---
### Testcases
All nine testcases and corresponding run scripts are available in the `test` directory. The testcases span three enablements: **NG45**, **ASAP7**, and **GF12**.  
> **Note:** GF12 testcases are not uploaded due to NDA restrictions.

#### Available Testcases:
- **Ariane**: [NG45](./test/ariane133_ng45), [ASAP7](./test/ariane_asap7/)
- **BlackParrot (Quad-Core)**: [NG45](./test/bp_ng45/), [ASAP7](./test/bp_asap7/)
- **MemPoolGroup**: [NG45](./test/mempool_group_ng45/), [ASAP7](./test/mempool_group_asap7/)

#### Scaled Versions of Ariane (from Circuit Training):
- [Ariane](./test/ariane/)  
- [Ariane_X2](./test/ariane_X2_xflip/)  
- [Ariane_X4](./test/ariane_X4_xflip_yflip/)

For more details, refer to the [RDF-2024](https://vlsicad.ucsd.edu/Publications/Conferences/412/c412.pdf) paper.

---
### Steps to Run
Follow these steps to run the code:
```bash
## 1. Update the following parameters in ./util/run.sh:
##    - REPO_DIR: Path to the repository
##    - DESIGN: Design name (e.g., ariane, bp, mempool_group)
##       Please ensure the NETLIST and PLC file paths are correctly set.
##    - IS_ASYNC: Set to 1 for asynchronous mode (non-deterministic)
##    - ITER: Iteration count based on the design

## 2. Run the script:
REPO_DIR=<real_path_to_repo>
cp ${REPO_DIR}/util/run.sh .
chmod +x run.sh
./run.sh

## OR To laucn using singularity image
singularity exec -B ${REPO_DIR},/tmp mp_sa_rocky8.sif ./run.sh

## OR To launch using docker image (Ensure that the REPO_DIR is mounted and the current directory is the workdir)
## For this case in run.sh set REPO_DIR=/mp_sa
docker run -v $(pwd):/workdir -v ${REPO_DIR}:/mp_sa mp_sa:rocky8 /workdir/run.sh
```

#### Recommended Iterations
To ensure runtime stays within 12 hours, use the following iteration counts:
- Ariane (18K), BlackParrot (5K), MemPoolGroup (4K), Ariane_X2 (6K), Ariane_X4 (4.5K)

#### Asynchronous Mode
Set `IS_ASYNC=1` in the run script to enable asynchronous mode.  
> **Note:**  
> - The SA code becomes **non-deterministic** in this mode.  
> - It will run **faster**, allowing for more iterations.

### Results of SA on Our Testcases
We run our SA for `IS_ASYNC=0` on all testcases. In the table below, we
provide two **proxy cost** values per testcase: (i) the proxy cost from our FD
placer/evaluator that yields the best result when evaluated by the golden
Circuit Training evaluator, and (ii) the golden proxy cost value from the 
Circuit Training evaluator. Our FD placers do not yield the same results
as the Circuit Training FD placer. Although our evaluator computes proxy cost
exactly as the Circuit Training evaluator, discrepancies in the FD placers
lead to different proxy cost outcomes.

<table><thead>
  <tr>
    <th rowspan="2">Design</th>
    <th colspan="4">Proxy Cost Based on SA Evaluator</th>
    <th colspan="4">Proxy Cost Based on CT (Golden) Evaluator</th>
  </tr>
  <tr>
    <th>WL</th>
    <th>Den.</th>
    <th>Cong.</th>
    <th>Proxy.</th>
    <th>WL</th>
    <th>Den.</th>
    <th>Cong.</th>
    <th>Proxy.</th>
  </tr></thead>
<tbody>
  <tr>
    <td>Ariane-NG45</td>
    <td>0.0879</td>
    <td>0.5019</td>
    <td>0.8917</td>
    <td>0.7847</td>
    <td>0.0898</td>
    <td>0.5146</td>
    <td>0.9068</td>
    <td>0.8005</td>
  </tr>
  <tr>
    <td>BlackParrot-NG45</td>
    <td>0.0550</td>
    <td>0.6992</td>
    <td>0.9433</td>
    <td>0.8763</td>
    <td>0.0543</td>
    <td>0.7114</td>
    <td>0.9361</td>
    <td>0.8781</td>
  </tr>
  <tr>
    <td>MemPoolGroup-NG45</td>
    <td>0.0604</td>
    <td>1.2112</td>
    <td>1.0540</td>
    <td>1.1930</td>
    <td>0.0616</td>
    <td>1.1308</td>
    <td>1.0948</td>
    <td>1.1744</td>
  </tr>
  <tr>
    <td>Ariane-ASAP7</td>
    <td>0.1001</td>
    <td>0.8168</td>
    <td>0.7580</td>
    <td>0.8875</td>
    <td>0.1081</td>
    <td>0.8169</td>
    <td>0.8216</td>
    <td>0.9274</td>
  </tr>
  <tr>
    <td>BlackParrot-ASAP7</td>
    <td>0.0533</td>
    <td>0.7622</td>
    <td>0.7466</td>
    <td>0.8077</td>
    <td>0.0529</td>
    <td>0.7584</td>
    <td>0.7505</td>
    <td>0.8074</td>
  </tr>
  <tr>
    <td>MemPoolGroup-ASAP7</td>
    <td>0.0675</td>
    <td>1.3271</td>
    <td>0.8235</td>
    <td>1.1429</td>
    <td>0.0690</td>
    <td>1.3050</td>
    <td>0.8338</td>
    <td>1.1384</td>
  </tr>
  <tr>
    <td>CT-Ariane</td>
    <td>0.0760</td>
    <td>0.5048</td>
    <td>0.8027</td>
    <td>0.7297</td>
    <td>0.0811</td>
    <td>0.5246</td>
    <td>0.8138</td>
    <td>0.7503</td>
  </tr>
  <tr>
    <td>CT-Ariane-X2</td>
    <td>0.0681</td>
    <td>0.4880</td>
    <td>0.8272</td>
    <td>0.7257</td>
    <td>0.0672</td>
    <td>0.4898</td>
    <td>0.8341</td>
    <td>0.7292</td>
  </tr>
  <tr>
    <td>CT-Ariane-X4</td>
    <td>0.0539</td>
    <td>0.4635</td>
    <td>0.8076</td>
    <td>0.6895</td>
    <td>0.0522</td>
    <td>0.4668</td>
    <td>0.8146</td>
    <td>0.6929</td>
  </tr>
</tbody></table>


---
### Running Evaluation
Once you have the final plc files from the SA run, you can run evaluation using 
the Circuit Training plc\_client. Where you will place the soft macros using the
CT-FD placer and report the proxy cost value. The evaluation code is located in
the [util](./util/) directory.

#### Prerequisites:
- Download the **[Circuit Training](https://github.com/google-research/circuit_training)** repository.  
- Download **[plc_wrapper_main](https://storage.googleapis.com/rl-infra-public/circuit-training/placement_cost/plc_wrapper_main_0.0.4)**.  
- Set up the **[Python environment](https://storage.googleapis.com/rl-infra-public/circuit-training/placement_cost/plc_wrapper_main_)**.

#### Running the Evaluation:
```bash
python ./util/golden_eval.py <design> <netlist> <plc_file> <output_dir>
```

#### Evaluation Output:
- Places soft macros using the **CT-FD placer**.  
- Reports the **proxy cost** value.  
- Generates:
  - A new `.plc` file with updated soft macro locations.  
  - A `.tcl` file for placing macros in Innovus.
---
