This document presents our evaluation of Circuit Training with DREAMPlace (CT-AC-DP) on modern benchmarks. We use CT-AC-DP to denote the fine-tuning of AlphaChip starting from the pre-trained checkpoint released in August 2024, while using DREAMPlace to place the soft macros. We evaluate CT-AC-DP on the ASAP7 Ariane and MemPoolGroup designs, as well as on the CT-Ariane-X4 design. We first describe the challenges encountered while setting up CT-DREAMPlace and the solutions we developed, and then present our experimental results comparing various macro placement approaches.

## Running Circuit Training with DREAMPlace
We ran Circuit Training with DREAMPlace (CT-AC-DP) on a few of our testcases, but encountered many challenges in setting CT-AC-DP up and running it. Below, we first list the challenges and then describe in detail how we overcame them to successfully run CT-AC-DP on our testcases.

### Challenges in setting up Circuit Training with DREAMPlace
The [steps](https://github.com/google-research/circuit_training/tree/main?tab=readme-ov-file#installation) given in Circuit Training repo to run Circuit Training with DREAMPlace (CT-AC-DP) do not work. The problems are as follows:
1. The provided Docker environment fails to run CT-AC-DP. The Docker setup does not include required packages such as gin and gym. We have added these missing packages. In addition, within the Docker environment, the numpy and PyTorch versions are incompatible with each other; as a result, running DREAMPlace produces the following error message: “AttributeError: module dreamplace.PlaceDB has no attribute INT_MAX”. So, we abandoned the Docker setup and focused on a local setup to run CT-AC-DP. To install CT-AC-DP as we did, follow the detailed steps given [here](#setting-up-circuit-training-with-dreamplace).
2. “_regioning = self. plc.has_area_constraint()_” ([here](https://github.com/google-research/circuit_training/blob/main/circuit_training/environment/environment.py#L345) and [here](https://github.com/google-research/circuit_training/blob/main/circuit_training/environment/environment.py#L349)) errors out because this function does not exist in the plc client. In December 2024, we raised [GitHub issue #74](https://github.com/google-research/circuit_training/issues/74) in the CircuitTraining repo, but Nature authors have not responded in over a year since then. To bypass this error please see the first bullet [here](#before-ct-fix).
3. It is unclear whether DREAMPlace is run on a CPU or a GPU. CT-AC-DP as seen in the CT repo uses a [300 second timeout decorator](https://github.com/google-research/circuit_training/blob/e7b2fcfc54c5173e2114ffb8b472293e47565b16/circuit_training/dreamplace/dreamplace_core.py#L60-L62) on all DREAMPlace calls. If this timeout is reached, the placement is aborted and the sample may be discarded. While the number of movable objects in any clustered netlist (i.e., consisting of soft and hard macros) that we study is small (at most 1662), a CPU-based DREAMPlace would be inherently slower and more likely to trigger this timeout. In our CT-AC-DP setup, we increase the timeout to 3000 seconds. However, we are unsure if the timeout is somehow intended to discard bad macro placements that typically lead to DREAMPlace divergence. See also the next items (#4 and #5).
4. In the [environment.py](https://github.com/google-research/circuit_training/blob/e7b2fcfc54c5173e2114ffb8b472293e47565b16/circuit_training/environment/environment.py), the default target density is set to [0.425](https://github.com/google-research/circuit_training/blob/e7b2fcfc54c5173e2114ffb8b472293e47565b16/circuit_training/environment/environment.py#L161), which is incorrect, as the target density should be greater than the design utilization, and the utilization of each of our testcases is ∼0.68. To avoid extra runtime due to the incorrect target density, we set the target density to 1.0.
5. Given that the Nature authors refer to the running of collector jobs solely on CPU servers, we use DREAMPlace with CPU. I.e., we run DREAMPlace data collection jobs on CPU servers. See also the next item (\#6).
6. We have observed that DREAMPlace consumes significantly more computing resources than the FD placer, which slows down training for most of the testcases (except for CT-Ariane-X4). For example, the FD placer trains Ariane ASAP7 at 0.78 steps per second, whereas DREAMPlace achieves only 0.08 steps per second – a nearly 10× decrease on the exact same server. Although we use the computational resources recommended by the CT repo, we believe that more powerful resources are required to run CT-AC-DP efficiently – a fact not noted by either the CT repo or the Nature authors.

### Setting up Circuit Training with DREAMPlace:
Below is a detailed description of the changes we made to run Circuit Training with DREAMPlace (CT-AC-DP) on our end. The description was confirmed to be valid and reproducible as of November 11, 2025 when we submitted our second revision to IEEE Trans. on CAD.
1. First install the linux environment packages (except python and pytorch) given [here](https://github.com/esonghori/DREAMPlace/tree/circuit_training?tab=readme-ov-file#dependency).
2. **Creating conda environment:** Our installation is based on Python3.9 as “AlphaChip requires Python 3.9 or greater” and the official installation uses Python3.9 for [DREAMPlace installation](https://github.com/google-research/circuit_training?tab=readme-ov-file#install-dreamplace-2).
```bash
conda create -y -p <your_env> python=3.9
conda activate <your_env>
```
3. **Building DREAMPlace (CT fork) and installing dependencies:** Our attempts to install Circuit Training with DREAMPlace using the official Docker environment were unsuccessful. Instead, we built the Circuit Training fork of DREAMPlace directly from source. Please refer to the instructions available [here](https://github.com/google-research/circuit_training?tab=readme-ov-file#install-dreamplace-2), but we recommend the following settings for a more reliable setup.  
   a. Environment setup
   ```bash
   pip install torch==1.13.1 ## Do NOT install PyTorch via conda
   conda install itsmeludo::pyunpack
   conda install conda-forge::patool
   conda install matplotlib
   conda install shapely
   conda install absl-py
   conda install gin-config ## Not mentioned in CT report
   conda install cairocffi
   conda install pkgconfig
   conda install setuptools
   conda install scipy
   pip install timeout-decorator
   pip install numpy==1.26.4 ## to avoid mismatches with TF/Torch
   pip install dm-reverb[tensorflow] ## install this first to match tensorflow version
   pip install tf_keras==2.18.0
   pip install tf-agents[reverb]==0.19.0	 ## not mentioned by CT Repo
   pip install gym  ## Not mentioned in CT report
   ```  
   b. Fork the CT version of DREAMPlace from [here](https://github.com/esonghori/DREAMPlace/tree/circuit_training) and follow the build instructions given [here](https://github.com/esonghori/DREAMPlace/tree/circuit_training?tab=readme-ov-file#build-without-docker).  
   c. To ensure CT can correctly call DREAMPlace, make sure your file structure matches the following:
   ```bash
   circuit_training/ 	## Run all commands under this main folder
   ├─ dreamplace/
   │  ├─ Placer.py
   │  ├─ BasicPlace.py
   │  ├─ EvalMetrics.py
   │  ├─ NesterovAcceleratedGradientOptimizer.py
   │  ├─ NonLinearPlace.py/
   │  ├─ Params.py
   │  ├─ *.py
   ├─ circuit_training/
   │  ├─ dreamplace/
   │  ├─ environment/
   │  ├─ grouping/
   │  ├─ .../
   ```
   d.  `circuit_training/dreamplace` contains the installation of the CT-specific DREAMPlace fork, while `circuit_training/circuit_training` contains the core Circuit Training code. The directory `circuit_training/circuit_training/dreamplace` provides the function calls that interface with `circuit_training/dreamplace` to perform placement operations.  
   e. When running Circuit Training, always execute commands from the `circuit_training` directory using the syntax:
    ```bash
    python -m <module>.py
    ```
  
<a name="before-ct-fix"></a>
After we have the fixed environment, we make the following changes in Circuit Training code to fix the error we get while running CT-AC-DP.
1. The [plc_wrapper_main](https://github.com/google-research/circuit_training/tree/e7b2fcfc54c5173e2114ffb8b472293e47565b16?tab=readme-ov-file#install-tf-agents-and-the-placement-cost-binary) binary (used in plc_client) lacks the HasAreaConstraint function. We confirmed this issue with CT_VERSION=0.0.4, 0.0.3, and 0.0.2. Consequently, calls to this function in circuit_training/circuit_training/environment.py (lines [345](https://github.com/google-research/circuit_training/blob/e7b2fcfc54c5173e2114ffb8b472293e47565b16/circuit_training/environment/environment.py#L345) and [349](https://github.com/google-research/circuit_training/blob/e7b2fcfc54c5173e2114ffb8b472293e47565b16/circuit_training/environment/environment.py#L349)) result in errors. Our workaround is to comment out these calls and manually set regioning = False, as shown below:  
```bash
# regioning = self._plc.has_area_constraint()  
regioning = False
```
2. In circuit_training/circuit_training/environment.py (line [161](https://github.com/google-research/circuit_training/blob/e7b2fcfc54c5173e2114ffb8b472293e47565b16/circuit_training/environment/environment.py#L161)), Circuit Training sets the default target density to 0.425. This is incorrect when the floorplan utilization exceeds 42.5%. To avoid any error for our CT-AC-DP runs, we update this value to 1.0:
`dp_target_density: float = 1.0`
3. On CPUs, DREAMPlace runs much slower than on GPUs. Circuit Training enforces a timeout on all DREAMPlace calls (circuit_training/circuit_training/dreamplace/dreamplace_util.py, lines [60–62](https://github.com/google-research/circuit_training/blob/main/circuit_training/dreamplace/dreamplace_core.py#L60-L62)) with a default of 300 seconds. In practice, this limit is too short for larger testcases and causes premature termination. To avoid this issue with CPU-based placement, we recommend increasing the timeout, for example:
```
@timeout_decorator.timeout( 
        seconds=5 * 600, exception_message='SoftMacroPlacer place() timed out.'  
    )
```


## Results

The following sections present results comparing various macro placement approaches on our modern benchmarks. During review of our IEEE Trans. on CAD submission, reviewers requested data from running Circuit Training with DREAMPlace. Due to the challenges outlined above and the significantly longer runtime of CT with DREAMPlace relative to CT with FD placer, we ran experiments on a subset of three designs -- Ariane and MemPool Group in ASAP7, as well as CT-Ariane-X4 -- to balance satisfaction of the reviewers' request with completion of experiments within the revision timeline.

### NanGate45 and ASAP7 Results

The following table presents PPA (Power, Performance, Area), proxy cost, runtime, and resource details of different macro placement solutions on our benchmarks across NanGate45 and ASAP7 enablements.

**Notes:**
- All Circuit Training (CT) runs use 400 iterations for training
- Best rWL, TNS, and proxy cost values for each design are highlighted in **bold**
- Runtime format: Hours (#GPUs, #CPUs)
- CMP (Commercial Macro Placer) results are not published; however, you can run our scripts to generate them

**Comparison between CT-AC and CT-AC-DP (ASAP7 Ariane and MemPool Group):**
From the table below, we observe that, compared with CT-AC, CT-AC-DP improves routed wirelength and yields similar or improved power, but results in degraded WNS, TNS, and final proxy cost.

<table border="1" cellpadding="5" cellspacing="0">
<thead>
  <tr>
    <th rowspan="2">Design<br>Tech</th>
    <th rowspan="2">Macro Placer</th>
    <th colspan="5">PostRouteOpt PPA (From Innovus)</th>
    <th colspan="4">Proxy Cost Details</th>
    <th rowspan="2">Runtime (Hrs)<br>(#G, #C)</th>
  </tr>
  <tr>
    <th>Area (um<sup>2</sup>)</th>
    <th>rWL (um)</th>
    <th>Power (mW)</th>
    <th>WNS (ps)</th>
    <th>TNS (ns)</th>
    <th>WL</th>
    <th>Den.</th>
    <th>Cong.</th>
    <th>Proxy</th>
  </tr>
</thead>
<tbody>
  <!-- Ariane NG45 -->
  <tr>
    <td rowspan="7">Ariane<br>NG45</td>
    <td><a href="../../Flows/NanGate45/ariane133/def/refs/CT_Scratch/">CT-Scratch</a></td>
    <td>246303</td>
    <td>4648156</td>
    <td>832</td>
    <td>-140</td>
    <td>-119.1</td>
    <td>0.102</td>
    <td>0.518</td>
    <td>0.973</td>
    <td>0.848</td>
    <td>36.26<br>(8, 576)</td>
  </tr>
  <tr>
    <td><a href="../../Flows/NanGate45/ariane133/def/refs/CT_AC/">CT-AC</a></td>
    <td>248382</td>
    <td>4995968</td>
    <td>836</td>
    <td>-88</td>
    <td>-52.2</td>
    <td>0.101</td>
    <td><b>0.508</b></td>
    <td>0.931</td>
    <td>0.820</td>
    <td>36.18<br>(8, 576)</td>
  </tr>
  <tr>
    <td><a href="../../Flows/NanGate45/ariane133/def/refs/CT_Ours/">CT-Ours</a></td>
    <td>245703</td>
    <td>4898125</td>
    <td>831</td>
    <td>-86</td>
    <td>-57.8</td>
    <td>0.108</td>
    <td>0.538</td>
    <td>0.966</td>
    <td>0.860</td>
    <td>38.79<br>(8, 576)</td>
  </tr>
  <tr>
    <td><i><a href="../../Flows/NanGate45/ariane133/def/refs/SA/">SA</a></i></td>
    <td>247777</td>
    <td><b>3976569</b></td>
    <td>827</td>
    <td>-126</td>
    <td>-116.8</td>
    <td>0.090</td>
    <td>0.515</td>
    <td><b>0.907</b></td>
    <td><b>0.801</b></td>
    <td>11.52<br>(0, 80)</td>
  </tr>
  <tr>
    <td><a href="../../Flows/NanGate45/ariane133/def/refs/RePlAce/">RePlAce</a></td>
    <td>251117</td>
    <td>5131963</td>
    <td>842</td>
    <td>-99</td>
    <td>-94.0</td>
    <td>0.092</td>
    <td>0.998</td>
    <td>1.748</td>
    <td>1.465</td>
    <td>0.04<br>(0, 1)</td>
  </tr>
  <tr>
    <td>CMP</td>
    <td>256230</td>
    <td>4057140</td>
    <td>852</td>
    <td>-154</td>
    <td>-196.5</td>
    <td><b>0.088</b></td>
    <td>0.909</td>
    <td>1.455</td>
    <td>1.270</td>
    <td>0.05<br>(0, 8)</td>
  </tr>
  <tr>
    <td><a href="../../Flows/NanGate45/ariane133/def/refs/Human/">Human</a></td>
    <td>249034</td>
    <td>4681178</td>
    <td>832</td>
    <td>-88</td>
    <td><b>-46.8</b></td>
    <td>0.107</td>
    <td>0.738</td>
    <td>1.376</td>
    <td>1.164</td>
    <td>NA</td>
  </tr>
  <!-- BlackParrot NG45 -->
  <tr>
    <td rowspan="6">BlackParrot<br>NG45</td>
    <td><a href="../../Flows/NanGate45/bp_quad/def/refs/CT_Scratch/">CT-Scratch</a></td>
    <td>1990312</td>
    <td>47785761</td>
    <td>4822</td>
    <td>-205</td>
    <td>-1203.4</td>
    <td>0.096</td>
    <td>0.790</td>
    <td>1.132</td>
    <td>1.057</td>
    <td>56.76<br>(8, 576)</td>
  </tr>
  <tr>
    <td><a href="../../Flows/NanGate45/bp_quad/def/refs/CT_AC/">CT-AC</a></td>
    <td>1944272</td>
    <td>33165774</td>
    <td>4569</td>
    <td>-230</td>
    <td>-1486.5</td>
    <td>0.066</td>
    <td>0.755</td>
    <td>1.053</td>
    <td>0.970</td>
    <td>64.01<br>(8, 576)</td>
  </tr>
  <tr>
    <td><i><a href="../../Flows/NanGate45/bp_quad/def/refs/SA/">SA</a></i></td>
    <td>1938779</td>
    <td>28937792</td>
    <td>4512</td>
    <td>-230</td>
    <td>-3012.8</td>
    <td>0.054</td>
    <td><b>0.711</b></td>
    <td><b>0.936</b></td>
    <td><b>0.878</b></td>
    <td>11.20<br>(0, 80)</td>
  </tr>
  <tr>
    <td><a href="../../Flows/NanGate45/bp_quad/def/refs/RePlAce/">RePlAce</a></td>
    <td>1930960</td>
    <td>26854143</td>
    <td>4485</td>
    <td>-191</td>
    <td>-868.0</td>
    <td>0.050</td>
    <td>1.049</td>
    <td>1.153</td>
    <td>1.151</td>
    <td>0.31<br>(0, 1)</td>
  </tr>
  <tr>
    <td>CMP</td>
    <td>1916166</td>
    <td><b>23144317</b></td>
    <td>4429</td>
    <td>-144</td>
    <td>-356.2</td>
    <td><b>0.050</b></td>
    <td>0.882</td>
    <td>1.066</td>
    <td>1.024</td>
    <td>0.33<br>(0, 8)</td>
  </tr>
  <tr>
    <td><a href="../../Flows/NanGate45/bp_quad/def/refs/Human/">Human</a></td>
    <td>1919928</td>
    <td>25915520</td>
    <td>4470</td>
    <td>-97</td>
    <td><b>-321.9</b></td>
    <td>0.054</td>
    <td>1.158</td>
    <td>1.260</td>
    <td>1.263</td>
    <td>NA</td>
  </tr>
  <!-- MemPool Group NG45 -->
  <tr>
    <td rowspan="6">MemPool<br>Group<br>NG45</td>
    <td><a href="../../Flows/NanGate45/mempool_group/def/refs/CT_Scratch/">CT-Scratch</a></td>
    <td>4915555</td>
    <td>119607588</td>
    <td>2754</td>
    <td>-163</td>
    <td>-47.7</td>
    <td>0.064</td>
    <td>1.200</td>
    <td>1.232</td>
    <td>1.280</td>
    <td>91.77<br>(8, 576)</td>
  </tr>
  <tr>
    <td><a href="../../Flows/NanGate45/mempool_group/def/refs/CT_AC/">CT-AC</a></td>
    <td>4871665</td>
    <td>112486298</td>
    <td>2683</td>
    <td>-51</td>
    <td>-32.1</td>
    <td>0.062</td>
    <td><b>1.006</b></td>
    <td><b>1.086</b></td>
    <td><b>1.108</b></td>
    <td>91.39<br>(8, 576)</td>
  </tr>
  <tr>
    <td><i><a href="../../Flows/NanGate45/mempool_group/def/refs/SA/">SA</a></i></td>
    <td>4915598</td>
    <td>115229509</td>
    <td>2720</td>
    <td>-32</td>
    <td>-5.9</td>
    <td>0.062</td>
    <td>1.131</td>
    <td>1.095</td>
    <td>1.175</td>
    <td>11.90<br>(0, 80)</td>
  </tr>
  <tr>
    <td><a href="../../Flows/NanGate45/mempool_group/def/refs/RePlAce/">RePlAce</a></td>
    <td>4930394</td>
    <td>113315081</td>
    <td>2688</td>
    <td>-96</td>
    <td>-7.3</td>
    <td><b>0.056</b></td>
    <td>1.621</td>
    <td>1.652</td>
    <td>1.693</td>
    <td>0.88<br>(0, 1)</td>
  </tr>
  <tr>
    <td>CMP</td>
    <td>4837150</td>
    <td><b>102907484</b></td>
    <td>2587</td>
    <td>-20</td>
    <td><b>-1.0</b></td>
    <td>0.057</td>
    <td>1.495</td>
    <td>1.554</td>
    <td>1.581</td>
    <td>1.97<br>(0, 8)</td>
  </tr>
  <tr>
    <td><a href="../../Flows/NanGate45/mempool_group/def/refs/Human/">Human</a></td>
    <td>4873872</td>
    <td>107597894</td>
    <td>2640</td>
    <td>-49</td>
    <td>-11.9</td>
    <td>0.067</td>
    <td>1.586</td>
    <td>1.710</td>
    <td>1.715</td>
    <td>NA</td>
  </tr>
  <!-- Ariane ASAP7 -->
  <tr>
    <td rowspan="8">Ariane<br>ASAP7</td>
    <td><a href="../../Flows/ASAP7/ariane133/def/refs/CT_Scratch/">CT-Scratch</a></td>
    <td>16570</td>
    <td>1026239</td>
    <td>505</td>
    <td>-142</td>
    <td>-184.2</td>
    <td>0.119</td>
    <td>0.821</td>
    <td>0.871</td>
    <td>0.965</td>
    <td>36.53<br>(8, 576)</td>
  </tr>
  <tr>
    <td><a href="../../Flows/ASAP7/ariane133/def/refs/CT_AC/">CT-AC</a></td>
    <td>16524</td>
    <td>1014938</td>
    <td>505</td>
    <td>-108</td>
    <td>-105.0</td>
    <td>0.122</td>
    <td>0.804</td>
    <td>0.850</td>
    <td>0.950</td>
    <td>36.35<br>(8, 576)</td>
  </tr>
  <tr>
    <td><b style="color: red;"><a href="../../Flows/ASAP7/ariane133/def/refs/CT_AC_DP/" style="color: red;">CT-AC-DP</a></b></td>
    <td>16557</td>
    <td>1000443</td>
    <td>505</td>
    <td>-128</td>
    <td>-138.7</td>
    <td>0.105</td>
    <td>1.200</td>
    <td>1.095</td>
    <td>1.253</td>
    <td>184.51<br>(8, 576)</td>
  </tr>
  <tr>
    <td><a href="../../Flows/ASAP7/ariane133/def/refs/CT_Ours/">CT-Ours</a></td>
    <td>16612</td>
    <td>1033863</td>
    <td>505</td>
    <td>-144</td>
    <td>-204.1</td>
    <td>0.126</td>
    <td>0.824</td>
    <td>0.893</td>
    <td>0.984</td>
    <td>39.95<br>(8, 576)</td>
  </tr>
  <tr>
    <td><i><a href="../../Flows/ASAP7/ariane133/def/refs/SA/">SA</a></i></td>
    <td>16467</td>
    <td>886776</td>
    <td>503</td>
    <td>-124</td>
    <td>-141.1</td>
    <td>0.108</td>
    <td>0.817</td>
    <td><b>0.822</b></td>
    <td><b>0.928</b></td>
    <td>10.87<br>(0, 80)</td>
  </tr>
  <tr>
    <td><a href="../../Flows/ASAP7/ariane133/def/refs/RePlAce/">RePlAce</a></td>
    <td>16410</td>
    <td>917539</td>
    <td>504</td>
    <td>-108</td>
    <td>-124.0</td>
    <td><b>0.102</b></td>
    <td>1.169</td>
    <td>1.160</td>
    <td>1.266</td>
    <td>0.02<br>(0, 1)</td>
  </tr>
  <tr>
    <td>CMP</td>
    <td>16350</td>
    <td><b>843757</b></td>
    <td>504</td>
    <td>-124</td>
    <td>-146.1</td>
    <td>0.102</td>
    <td>1.122</td>
    <td>1.141</td>
    <td>1.233</td>
    <td>0.04<br>(0, 8)</td>
  </tr>
  <tr>
    <td><a href="../../Flows/ASAP7/ariane133/def/refs/Human/">Human</a></td>
    <td>16613</td>
    <td>1182350</td>
    <td>508</td>
    <td>-104</td>
    <td><b>-81.8</b></td>
    <td>0.131</td>
    <td>1.177</td>
    <td>1.484</td>
    <td>1.461</td>
    <td>NA</td>
  </tr>
  <!-- BlackParrot ASAP7 -->
  <tr>
    <td rowspan="6">BlackParrot<br>ASAP7</td>
    <td><a href="../../Flows/ASAP7/bp_quad/def/refs/CT_Scratch/">CT-Scratch</a></td>
    <td>126524</td>
    <td>11380551</td>
    <td>1609</td>
    <td>-226</td>
    <td>-2043.7</td>
    <td>0.089</td>
    <td>0.908</td>
    <td>1.002</td>
    <td>1.044</td>
    <td>55.87<br>(8, 576)</td>
  </tr>
  <tr>
    <td><a href="../../Flows/ASAP7/bp_quad/def/refs/CT_AC/">CT-AC</a></td>
    <td>124987</td>
    <td>8880315</td>
    <td>1569</td>
    <td>-201</td>
    <td>-1448.6</td>
    <td>0.067</td>
    <td>0.848</td>
    <td>0.833</td>
    <td>0.908</td>
    <td>58.27<br>(8, 576)</td>
  </tr>
  <tr>
    <td><i><a href="../../Flows/ASAP7/bp_quad/def/refs/SA/">SA</a></i></td>
    <td>123141</td>
    <td>7266869</td>
    <td>1547</td>
    <td>-120</td>
    <td>-424.8</td>
    <td><b>0.053</b></td>
    <td><b>0.758</b></td>
    <td><b>0.751</b></td>
    <td><b>0.808</b></td>
    <td>9.78<br>(0, 80)</td>
  </tr>
  <tr>
    <td><a href="../../Flows/ASAP7/bp_quad/def/refs/RePlAce/">RePlAce</a></td>
    <td>123205</td>
    <td>6718623</td>
    <td>1540</td>
    <td>-96</td>
    <td>-590.0</td>
    <td>0.064</td>
    <td>1.097</td>
    <td>1.066</td>
    <td>1.145</td>
    <td>0.20<br>(0, 1)</td>
  </tr>
  <tr>
    <td>CMP</td>
    <td>122603</td>
    <td><b>6104230</b></td>
    <td>1529</td>
    <td>-111</td>
    <td><b>-240.4</b></td>
    <td>0.058</td>
    <td>1.058</td>
    <td>0.936</td>
    <td>1.055</td>
    <td>0.65<br>(0, 8)</td>
  </tr>
  <tr>
    <td><a href="../../Flows/ASAP7/bp_quad/def/refs/Human/">Human</a></td>
    <td>122914</td>
    <td>6521501</td>
    <td>1536</td>
    <td>-89</td>
    <td>-356.6</td>
    <td>0.057</td>
    <td>1.204</td>
    <td>1.053</td>
    <td>1.186</td>
    <td>NA</td>
  </tr>
  <!-- MemPool Group ASAP7 -->
  <tr>
    <td rowspan="7">MemPool<br>Group<br>ASAP7</td>
    <td>CT-Scratch</td>
    <td colspan="10">Divergence</td>
  </tr>
  <tr>
    <td><a href="../../Flows/ASAP7/mempool_group/def/refs/CT_AC/">CT-AC</a></td>
    <td>339535</td>
    <td>27208664</td>
    <td>1402</td>
    <td>-122</td>
    <td>-629.0</td>
    <td>0.072</td>
    <td><b>1.170</b></td>
    <td><b>0.812</b></td>
    <td><b>1.063</b></td>
    <td>112.87<br>(8, 576)</td>
  </tr>
  <tr>
    <td><b style="color: red;"><a href="../../Flows/ASAP7/mempool_group/def/refs/CT_AC_DP/" style="color: red;">CT-AC-DP</a></b></td>
    <td>338454</td>
    <td>26288842</td>
    <td>1397</td>
    <td>-133</td>
    <td>-657.6</td>
    <td>0.066</td>
    <td>1.573</td>
    <td>0.989</td>
    <td>1.347</td>
    <td>300.48<br>(8, 576)</td>
  </tr>
  <tr>
    <td><i><a href="../../Flows/ASAP7/mempool_group/def/refs/SA/">SA</a></i></td>
    <td>338798</td>
    <td>26898162</td>
    <td>1402</td>
    <td>-169</td>
    <td>-941.0</td>
    <td>0.069</td>
    <td>1.305</td>
    <td>0.834</td>
    <td>1.139</td>
    <td>10.19<br>(0, 80)</td>
  </tr>
  <tr>
    <td><a href="../../Flows/ASAP7/mempool_group/def/refs/RePlAce/">RePlAce</a></td>
    <td>338781</td>
    <td>26239567</td>
    <td>1387</td>
    <td>-152</td>
    <td>-819.9</td>
    <td>0.063</td>
    <td>1.740</td>
    <td>1.319</td>
    <td>1.593</td>
    <td>0.60<br>(0, 1)</td>
  </tr>
  <tr>
    <td>CMP</td>
    <td>338559</td>
    <td><b>23259139</b></td>
    <td>1343</td>
    <td>-88</td>
    <td>-224.9</td>
    <td><b>0.060</b></td>
    <td>1.756</td>
    <td>1.207</td>
    <td>1.541</td>
    <td>1.09<br>(0, 8)</td>
  </tr>
  <tr>
    <td><a href="../../Flows/ASAP7/mempool_group/def/refs/Human/">Human</a></td>
    <td>338457</td>
    <td>24573102</td>
    <td>1354</td>
    <td>-84</td>
    <td><b>-193.4</b></td>
    <td>0.073</td>
    <td>1.758</td>
    <td>1.326</td>
    <td>1.614</td>
    <td>NA</td>
  </tr>
</tbody>
</table>

### CT-Ariane Results

The following table presents DP-HPWL (DREAMPlace Half-Perimeter Wirelength), proxy cost, runtime, and resource details of different macro placement solutions on Google's TSMC 7nm Ariane testcase (CT-Ariane) and its scaled (x2, x4) versions.

**Notes:**
- All Circuit Training (CT) runs use 400 iterations for training
- Best DP-HPWL and proxy cost values for each design are highlighted in **bold**
- Runtime format: Hours (#GPUs, #CPUs)

<table border="1" cellpadding="5" cellspacing="0">
<thead>
  <tr>
    <th rowspan="2">Design</th>
    <th rowspan="2">Macro Placer</th>
    <th rowspan="2">DP-HPWL (um)</th>
    <th colspan="4">Proxy Cost Details</th>
    <th rowspan="2">Runtime (Hrs)<br>(#G, #C)</th>
  </tr>
  <tr>
    <th>WL</th>
    <th>Den.</th>
    <th>Cong.</th>
    <th>Proxy</th>
  </tr>
</thead>
<tbody>
  <!-- CT-Ariane -->
  <tr>
    <td rowspan="7">CT-Ariane</td>
    <td>CT repo</td>
    <td>NA</td>
    <td>0.098</td>
    <td><b>0.511</b></td>
    <td>0.868</td>
    <td>0.787*</td>
    <td>NA</td>
  </tr>
  <tr>
    <td><a href="CT_Results/CT_Ariane/CT_Scratch/">CT-Scratch</a></td>
    <td>958137</td>
    <td>0.094</td>
    <td><b>0.503</b></td>
    <td>0.854</td>
    <td>0.772</td>
    <td>37.89 (8, 576)</td>
  </tr>
  <tr>
    <td><a href="CT_Results/CT_Ariane/CT_AC/">CT-AC</a></td>
    <td>938528</td>
    <td>0.092</td>
    <td>0.509</td>
    <td>0.829</td>
    <td>0.761</td>
    <td>55.16 (8, 576)</td>
  </tr>
  <tr>
    <td><i><a href="CT_Results/CT_Ariane/SA/">SA</a></i></td>
    <td>804228</td>
    <td><b>0.081</b></td>
    <td>0.525</td>
    <td><b>0.814</b></td>
    <td><b>0.750</b></td>
    <td>11.13 (0, 80)</td>
  </tr>
  <tr>
    <td><a href="CT_Results/CT_Ariane/RePlAce/">RePlAce</a></td>
    <td>952429</td>
    <td><b>0.081</b></td>
    <td>0.992</td>
    <td>1.285</td>
    <td>1.219</td>
    <td>0.03 (0, 1)</td>
  </tr>
  <tr>
    <td>CMP</td>
    <td><b>745370</b></td>
    <td>0.075</td>
    <td>0.743</td>
    <td>0.999</td>
    <td>0.946</td>
    <td>0.02 (0, 16)</td>
  </tr>
  <tr>
    <td><a href="CT_Results/CT_Ariane/Human/">Human</a></td>
    <td>931105</td>
    <td>0.093</td>
    <td>0.824</td>
    <td>1.241</td>
    <td>1.126</td>
    <td>NA</td>
  </tr>
  <!-- CT-Ariane-X2 -->
  <tr>
    <td rowspan="6">CT-Ariane<br>-X2</td>
    <td><a href="CT_Results/CT_Ariane_X2/CT_Scratch/">CT-Scratch</a></td>
    <td>2910809</td>
    <td>0.101</td>
    <td>0.533</td>
    <td>1.015</td>
    <td>0.876</td>
    <td>38.90 (8, 576)</td>
  </tr>
  <tr>
    <td><a href="CT_Results/CT_Ariane_X2/CT_AC/">CT-AC</a></td>
    <td>1876365</td>
    <td>0.071</td>
    <td>0.493</td>
    <td>0.836</td>
    <td>0.735</td>
    <td>86.45 (8, 576)</td>
  </tr>
  <tr>
    <td><i><a href="CT_Results/CT_Ariane_X2/SA/">SA</a></i></td>
    <td><b>1623056</b></td>
    <td><b>0.067</b></td>
    <td><b>0.490</b></td>
    <td><b>0.834</b></td>
    <td><b>0.729</b></td>
    <td>6.93 (0, 80)</td>
  </tr>
  <tr>
    <td><a href="CT_Results/CT_Ariane_X2/RePlAce/">RePlAce</a></td>
    <td>1913954</td>
    <td>0.078</td>
    <td>0.754</td>
    <td>1.091</td>
    <td>1.000</td>
    <td>0.06 (0, 1)</td>
  </tr>
  <tr>
    <td>CMP</td>
    <td><b>1510219</b></td>
    <td>0.074</td>
    <td>0.620</td>
    <td>1.134</td>
    <td>0.951</td>
    <td>0.04 (0, 16)</td>
  </tr>
  <tr>
    <td><a href="CT_Results/CT_Ariane_X2/Human/">Human</a></td>
    <td>1868380</td>
    <td>0.081</td>
    <td>0.832</td>
    <td>1.227</td>
    <td>1.111</td>
    <td>NA</td>
  </tr>
  <!-- CT-Ariane-X4 -->
  <tr>
    <td rowspan="8">CT-Ariane<br>-X4</td>
    <td>CT-Scratch</td>
    <td colspan="6">Divergence</td>
  </tr>
  <tr>
    <td><a href="CT_Results/CT_Ariane_X4/CT_AC/">CT-AC</a></td>
    <td>3893091</td>
    <td>0.056</td>
    <td><b>0.466</b></td>
    <td>0.836</td>
    <td>0.707</td>
    <td>188.69 (8, 576)</td>
  </tr>
  <tr>
    <td><b style="color: red;"><a href="CT_Results/CT_Ariane_X4/CT_AC_DP/" style="color: red;">CT-AC-DP</a></b></td>
    <td>3878653</td>
    <td>0.057</td>
    <td>0.864</td>
    <td>1.068</td>
    <td>1.023</td>
    <td>205.82 (8, 576)</td>
  </tr>
  <tr>
    <td><a href="CT_Results/CT_Ariane_X4/CT_Ours/">CT-Ours</a></td>
    <td>5525222</td>
    <td>0.075</td>
    <td>0.473</td>
    <td>0.922</td>
    <td>0.772</td>
    <td>174.07 (8, 576)</td>
  </tr>
  <tr>
    <td><i><a href="CT_Results/CT_Ariane_X4/SA/">SA</a></i></td>
    <td>3423907</td>
    <td><b>0.052</b></td>
    <td>0.467</td>
    <td><b>0.815</b></td>
    <td><b>0.693</b></td>
    <td>9.97 (0, 80)</td>
  </tr>
  <tr>
    <td><a href="CT_Results/CT_Ariane_X4/RePlAce/">RePlAce</a></td>
    <td>3726672</td>
    <td>0.055</td>
    <td>0.730</td>
    <td>1.062</td>
    <td>0.950</td>
    <td>0.17 (0, 1)</td>
  </tr>
  <tr>
    <td>CMP</td>
    <td><b>3049402</b></td>
    <td>0.055</td>
    <td>0.735</td>
    <td>1.139</td>
    <td>0.992</td>
    <td>0.08 (0, 16)</td>
  </tr>
  <tr>
    <td><a href="CT_Results/CT_Ariane_X4/Human/">Human</a></td>
    <td>3827163</td>
    <td>0.060</td>
    <td>0.757</td>
    <td>1.590</td>
    <td>1.233</td>
    <td>NA</td>
  </tr>
</tbody>
</table>

*We compute the proxy cost for CT-Ariane using the cost components reported in the CT repo, with weights of 1.0 for wirelength and 0.5 for both density and congestion.

### Macro Placer Abbreviations
- **CT repo**: Circuit Training repository baseline result
- **CT-Scratch**: Circuit Training trained from scratch
- **CT-AC**: Circuit Training with AlphaChip pre-trained checkpoint
- **CT-AC-DP**: Circuit Training with AlphaChip pre-trained checkpoint (August 2024) + DREAMPlace (instead of FD placer)
- **CT-Ours**: Circuit Training with our improvements
- **SA**: Simulated Annealing
- **RePlAce**: RePlAce analytical placer
- **CMP**: Commercial Macro Placer
- **Human**: Human expert placement
