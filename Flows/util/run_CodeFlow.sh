#!/bin/bash -i
source /home/tool/anaconda3/etc/profile.d/conda.sh
conda activate py-tf
export PROJ_DIR=`pwd | grep -o '\S*/MacroPlacement'`
export PYTHONPATH=$PYTHONPATH:${PROJ_DIR}/Flows/util/
python ${PROJ_DIR}/Flows/util/flow.py $PWD output_CodeElement 2>&1 | tee log/codelement.log
exit
