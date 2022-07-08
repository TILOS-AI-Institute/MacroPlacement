# Utility function to visualize placement in image format using plc_client from Google Circuit Training

This utlity script uses the plc_client binary provided with the Google Circuit Training to plot the placement of macros and standard cells in an image format. 

### Install Google Circuit Training plc_wrapper_main library
```
# Install TF-Agents with nightly versions of Reverb and TensorFlow 2.x
$  pip install tf-agents-nightly[reverb]
# Copy the placement cost binary to /usr/local/bin and makes it executable.
$  sudo curl https://storage.googleapis.com/rl-infra-public/circuit-training/placement_cost/plc_wrapper_main \
     -o  /usr/local/bin/plc_wrapper_main
$ sudo chmod 555 /usr/local/bin/plc_wrapper_main
$ Clone the circuit-training repo.
$  git clone https://github.com/google-research/circuit-training.git
```
### Place the placement_viewer in circuit_training/circuit_training/

## Testing: 
$ python3 -m circuit_training.placement_viewer.placement_viewer_test 

## Execution: 
$ python3 -m circuit_training.placement_viewer.placement_viewer \
  --img_name: Prefix of the name of output image file. 
  --init_file: Path to the init file.
  --netlist_file: Path to the input netlist file.

