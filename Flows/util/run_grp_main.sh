#!/usr/bin/env bash
if [ $PHY_SYNTH -eq 1 ]; then
    export BLOCK_NAME=`echo $PWD | awk -F'/' '{print $(NF-2)}'`
    export TECH=`echo $PWD | awk -F'/' '{print $(NF-3)}'`
    export OUTPUT_DIR="./output_${BLOCK_NAME}_${TECH}"
    export NETLIST_FILE=`readlink -f *.pb.txt`
    export HMETIS_DIR="/home/zf4_projects/DREAMPlace/sakundu/GB/CT/hmetis-1.5-linux"
    export PLC_WRAPPER_MAIN="/home/zf4_projects/DREAMPlace/sakundu/GB/CT/plc_wrapper_main"
    export CT_PATH="/home/zf4_projects/DREAMPlace/sakundu/GB/CT/circuit_training"
    bash -i ../../../../util/run_grp.sh 2>&1 | tee log/grouping.log
fi
