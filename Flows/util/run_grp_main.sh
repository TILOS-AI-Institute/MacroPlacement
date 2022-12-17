#!/usr/bin/env bash
##########################################################################
# Author: Sayak Kundu                           email: sakundu@ucsd.edu
# This script runs Circuit Training (CT) Grouping to generate clustered 
# netlist from the Protobuf netlist. For more details please see CT 
# Grouping README (Link: 
# https://github.com/google-research/circuit_training/blob/main/circuit_training/grouping/README.md)
#
# Update the following environment variables to run CT Grouping using 
# this script:
#   1. NETLIST_FILE: Provide the path of the input Protobuf netlist
#   2. HMETIS_DIR: Provide the directory path where the hMETIS executable 
#      files exist.
#   3. PLC_WRAPPER_MAIN: Provide the path of the plc_wrapper_main binary. 
#      This binary is downloaded from CT. Link to the binary:
#      https://storage.googleapis.com/rl-infra-public/circuit-training/placement_cost/plc_wrapper_main
#   4. CT_PATH: Provide the directory path where CT is cloned.
#   5. OUTPUT_DIR: Provide the directory path where to save the final 
#      clustered netlist.
#
# Before launching the script make sure that PHY_SYNTH environment variables
# is set to 1.
##########################################################################
if [ $PHY_SYNTH -eq 1 ]; then
    export PROJ_DIR=`pwd | grep -o '\S*/MacroPlacement'`
    export NETLIST_FILE=`readlink -f *.pb.txt`
    export BLOCK_NAME=`basename ${NETLIST_FILE} | sed 's@.pb.txt@@'`
    export TECH=`echo $PWD | awk -F'/' '{print $(NF-3)}'`
    export OUTPUT_DIR="./output_${BLOCK_NAME}_${TECH}"
    export HMETIS_DIR="${PROJ_DIR}/../../../GB/CT/hmetis-1.5-linux"
    export PLC_WRAPPER_MAIN="${PROJ_DIR}/../../../GB/CT/plc_wrapper_main"
    export CT_PATH="${PROJ_DIR}/../../../GB/CT/circuit_training"
    bash -i ${PROJ_DIR}/Flows/util/run_grp.sh 2>&1 | tee log/grouping.log
fi
