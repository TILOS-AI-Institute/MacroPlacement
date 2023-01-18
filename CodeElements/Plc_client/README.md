# PlacementCost
`plc_client_os` is a reversed-engineered work to provide almost the same functionaility with Google's plc_client API. The codebase is available in Cython for faster runtime while being easily accessible. While Circuit Training repository does provide [documentation](https://github.com/google-research/circuit_training/blob/main/docs/PLACEMENT_COST.md) for their plc_client, we provide complete functions and detailed documentations in our codebase.
## Quick Start
Under `MACROPLACEMENT/CodeElements` directory, run the following command:
```
# Download plc_client from Google's circuit training
curl 'https://raw.githubusercontent.com/google-research/circuit_training/main/circuit_training/environment/plc_client.py' > ./Plc_client/plc_client.py
# Copies the placement cost binary to /usr/local/bin and makes it executable.
sudo curl https://storage.googleapis.com/rl-infra-public/circuit-training/placement_cost/plc_wrapper_main \
  -o  /usr/local/bin/plc_wrapper_main
# Run plc testbench
# python -m Plc_client.plc_client_os_test [-h] [--helpfull] --netlist NETLIST [--plc PLC] --width WIDTH --height HEIGHT --col COL --row ROW [--rpmh RPMH] [--rpmv RPMV] [--marh MARH] [--marv MARV] [--smooth SMOOTH]

# Compile Cython
python Plc_client.setup.py build_ext --inplace

# Example
python -m Plc_client.plc_client_os_test --netlist ./Plc_client/test/ariane/netlist.pb.txt\
          --plc ./Plc_client/test/ariane/initial.plc\
          --width 356.592\
          --height 356.640\
          --col 35\
          --row 33\
          --rpmh 10\
          --rpmv 10\
          --marh 5\
          --marv 5\
          --smooth 2
```

You may uncomment any available tests and even run your own test dataset. We do not handle all corner cases since during RL placement, they are unlikely to occur. Our aim here is to reproduce Google's code as much as possible and be able to plug into Circuit Training Flow.

## Implementation Details
For complete information on how the proxy cost is computed in our code, please refer to [Proxy Cost Documentation](https://tilos-ai-institute.github.io/MacroPlacement/Docs/ProxyCost/).  Below is a quick overview of the formulation.

## HPWL Computation
Given a net $i$, its wirelength can be computed as the following:

$$
HPWL(i) = W_{i\_{source}} \cdot [max_{b\in i}(x_b) - min_{b\in i}(x_b) + max_{b\in i}(y_b) - min_{b\in i}(y_b)]
$$

where $W_{i\_{source}}$ is the weight (default to $1$) defined on the source pin.

The total wirelength of the netlist can be computed as the following:

$$
HPWL(netlist) = \sum_{i}^{N_{netlist}} W_{i\_{source}} \cdot [max_{b\in i}(x_b) - min_{b\in i}(x_b) + max_{b\in i}(y_b) - min_{b\in i}(y_b)]
$$

## Density Cost Computation
Density cost is computed from grid cells density.

By default, any given input will have grid col/row set to 10/10 until user later defines in the .plc file.

Grid cell density is represented as an 1D array where the length is set to be the following:

$$
grid_{col} \cdot grid_{row}
$$

Each entry of this array represents the current occupied precentage within this cell.
Overlaps gets double counted, so it is possible for a cell density to exceed 1.0.

When a Placement Cost object is initialized, coordinate information and dimension information will be read from the netlist input and used to compute an initial grid cell density.

Once grid cell density is obtained, we take the top 10% of the largest grid cells and compute its average. The density cost will be half of the average value.

## Adjacency Matrix Computation
The adjacency matrix is represented as an array of 

$$
[N_{hardmacros} + N_{softmacros} + N_{ports}] \times [N_{hardmacros} + N_{softmacros} + N_{ports}]
$$ 

elements.
For each entry of the adjacency matrix, it represents the total number of connections between module $i$ and module $j$ subject to all corresponding pins. For soft macro pins, weight should be consider a factor to the number of connections.

## Congestion Cost Computation
Congestion cost is computed from the horizontal congestion grid cells array and the vertical congestion grid cells array. After concatenating these two arrays, Google takes the top 5% of the most congested grid cells and compute the average of them to get the final congestion cost.

To compute the congestion for each grid cell, a fast routing technique is applied which is detailed [here](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/Docs/ProxyCost#congestion-cost-computation). After fast routing, we acquire the horizontal/vertical congestion due to net routing. This will be added with horiztonal/vertical congestion due to macro placement.

On a high level, for each grid cell, we compute the following:

$$
\text{Grid horizontal congestion = horizontal congestion due to macros + horizontal congestion due to net routing after smoothing.}
$$

$$
\text{Grid vertical congestion = vertical congestion due to macros + vertical congestion due to net routing after smoothing.}
$$

Notice a smoothing range can be set for congestion. This is only applied to congestion due to net routing which by counting adjacent cells and adding the averaged congestion to these adjacent cells. More details are provided in the document above.

## FD Placement
To enable FD placement, please forward to [FD Placement section](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/CodeElements/FDPlacement) where we provide full implementation in C++ for faster runtime. Our Cython codebase is fully integrated with our FD implementation. Once you generated the FD executable `fd_placer`, move it under the same directory as your `plc_client_os.pyx` source code directory. Then, FD functionailty should be enabled without extra steps.

For Details on how FD works, we provide documentation [here](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/FDPlacement/README.md).

## DISCLAIMER
**We DO NOT own the original content of placement_util_os.py,  observation_extractor_os.py, environment_os.py, environment_ct.py, coordinate_descent_placer.py. All rights belong to Google Authors. These are modified version of the original code and we are including in the repo for the sake of testing. Original Code can be viewed [here](https://github.com/google-research/circuit_training/blob/main/circuit_training/environment/placement_util.py)**.



