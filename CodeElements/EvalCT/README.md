# Circuit Training Model Evaulation

## Quick Start
First, make sure you are under `CodeElements/EvalCT/`. To run `eval_ct.py`, we need to download `circuit_training` code under the same directory. Run the following command to get the stable version that we have tested.
```
# Compatible with Revision #90. Latest Version might cause errors
svn export -r 90 --force https://github.com/google-research/circuit_training.git/trunk/circuit_training
```

Next, we need to prepare your trained policy and the testcase you want to evaluate on. Assume you have trained models (which usually can be found under `./logs`), copy the run folder into `saved_model` folder. Make sure your testcase is under `./test`. The `ckptID` is the policy checkpoint ID saved after each iteration.

Finally, run the following command with path to netlist file, initial placement file and model run directory path.
```
$ python3 -m eval_ct --netlist ./test/ariane/netlist.pb.txt\
            --plc ./test/ariane/initial.plc\
            --rundir run_00\
            --ckptID policy_checkpoint_0000103984
```
The placement will be stored under `CodeElements/EvalCT/` and named as `eval_[RUN_DIR]_to_[TESTCASE].plc`.

## Trained Policy
We are providing one of the run we trained from scratch using Google's Ariane testcase. **This should not be taken as representing the potential of Circuit Training**. We are only providing these trained weights here for the sake of testing. Please feel free to load any of your own trained weights. You may find similar file structure under `./logs` after training.

## View Your Result
You can view the result by supplying this placement file into the open-sourced Plc_client testbench and use the `display_canvas` function.
