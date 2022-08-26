# PlacementCost

## Quick Start
Under `MACROPLACEMENT/CodeElements` directory, run the following command:
```
# Download plc_client from Google's circuit training
curl 'https://raw.githubusercontent.com/google-research/circuit_training/main/circuit_training/environment/plc_client.py' > ./Plc_client/plc_client.py
# Copies the placement cost binary to /usr/local/bin and makes it executable.
sudo curl https://storage.googleapis.com/rl-infra-public/circuit-training/placement_cost/plc_wrapper_main \
  -o  /usr/local/bin/plc_wrapper_main
# Run plc testbench
python -m Plc_client.plc_client_os_test
```

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

## Density  Cost Computation
Density cost is computed from grid cells density.

By default, any given input will have grid col/row set to 10/10 until user later defines in the .plc file.

Grid cell density is represented as an 1D array where the length is set to be 

$$
grid_\{col} \cdot grid_\{row}
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

To compute the congestion for each grid cell, a fast routing technique is applied which is detailed [here](https://docs.google.com/document/d/1hM7UbmANkhoGB3-UfFBp8TRDvvVjpmio7cyyjK4a5bI/edit?usp=sharing). After fast routing, we acquire the horizontal/vertical congestion due to net routing. This will be added with horiztonal/vertical congestion due to macro placement.

On a high level, for each grid cell, we compute the following:

$$
Grid horizontal congestion = horizontal congestion due to macros + horizontal congestion due to net routing after smoothing.
$$

$$
Grid vertical congestion = vertical congestion due to macros + vertical congestion due to net routing after smoothing.
$$

Notice a smoothing range can be set for congestion. This is only applied to congestion due to net routing which by counting adjacent cells and adding the averaged congestion to these adjacent cells. More details are provided in the document above.



