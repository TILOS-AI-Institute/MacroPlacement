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

## Adjacency Matrix Computation
The adjacency matrix is represented as an array of $[N_{hardmacros} + N_{softmacros} + N_{ports}] \times [N_{hardmacros} + N_{softmacros} + N_{ports}]$ elements.
For each entry of the adjacency matrix, it represents the total number of connections between module $i$ and module $j$ subject to all corresponding pins.


