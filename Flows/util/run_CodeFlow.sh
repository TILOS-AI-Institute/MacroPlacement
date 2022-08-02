source /home/tool/anaconda3/etc/profile.d/conda.sh
conda activate py-tf
export PYTHONPATH=$PYTHONPATH:../../../../util/
cd $1
python ../../../../util/flow.py $1 output_CodeElement 2>&1 | tee log/codelement.log
