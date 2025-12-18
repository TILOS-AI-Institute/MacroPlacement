We provide a CPP wrapper that uses the hMETIS C API and calls the hMETIS library to cluster the netlist for a given seed, ensuring reproducibility of the clustering results.
To generate the binary, first compile the CPP wrapper using the following command, then use the `hmetis` binary. The I/O format is the same as the hMETIS default binary, and the last argument is the seed.
```bash
cd ./hMETIS_api
./compile.sh
```