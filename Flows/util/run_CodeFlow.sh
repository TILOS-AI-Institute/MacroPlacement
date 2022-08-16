#!/bin/bash -i
if [[ -z $PHY_SYNTH ]];
then
    echo "Not Running Clustering"
    exit
fi

if [ $PHY_SYNTH -eq 0 ]; then
    echo "Not Running Clustering"
    exit
fi

echo "Running Clustering"
source /home/tool/anaconda3/etc/profile.d/conda.sh
conda activate py-tf
export PROJ_DIR=`pwd | grep -o '\S*/MacroPlacement'`
export PYTHONPATH=$PYTHONPATH:${PROJ_DIR}/Flows/util/
python ${PROJ_DIR}/Flows/util/flow.py $PWD output_CodeElement 2>&1 | tee log/codelement.log
exit
