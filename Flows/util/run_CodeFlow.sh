#!/bin/bash -i
source /home/tool/anaconda3/etc/profile.d/conda.sh
conda activate py-tf
export PROJ_DIR=`pwd | grep -o '\S*/MacroPlacement'`
export PYTHONPATH=$PYTHONPATH:${PROJ_DIR}/Flows/util/
cd $1
python ${PROJ_DIR}/Flows/util/flow.py $1 output_CodeElement_run1 2>&1 | tee log/codelement_run1.log
exit
