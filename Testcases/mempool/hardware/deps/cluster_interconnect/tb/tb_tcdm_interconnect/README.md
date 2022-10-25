# TCDM Interconnect - Testing and Exploration Framework

This readme describes the testing and exploration framework that can be used to assess the `tcdm_interconnect` module.

Make sure the toolversions configured in the Makefile exist on your machine. 
You can simulate the current default configuration as defined in `./hdl/defaults.svh` with the following command:

```
make sim
```

This invokes `make build` first and then runs simulation in questasim with gui. If you want to run this in console-only mode, do 

```
make simc
```
 
In order to run the full evaluation in batch mode, you can call:

```
make batch-sim
```

This is a separate target that runs in several subfolders (one for each network configuration, as specified in `./scripts/batch.list`) and does not touch the standard, single simulation build described above. 

In order to run the batch synthesis, make sure that a valid IIS cockpit for FDX22 exists under the path `cluster_interconnect/tech/gf22`. Then you can synthesize the whole batch using

```
make batch-synth
```

The results of the batch synthesis and simulation are gathered in `sim-results`. You can selectively delete results in that folder and they will be regenerated upon invoking the batch targets above. In order to clean all temporary simulation / synthesis folders, invoke

```
make batch-clean
```

Note that the above command will not touch the  `sim-results` folder.

In order to parse and plot the results, either call

```
make batch-plot
```

or start Matlab in the same folder where this readme lives, open `./matlab/evaluation.m` in the Matlab editor and execute the script cells one by one or selectively.

Note that if you run on a high core-count machine and have enough licenses available, you can parallelize the batch-synthesis and batch-simulation targets with `-jXX` where `XX` is the amount of jobs to start.

For more details on the implementation and evaluation results, please see [this readme](../../rtl/tcdm_interconnect/README.md).
