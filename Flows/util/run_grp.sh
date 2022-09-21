source /home/tool/anaconda3/etc/profile.d/conda.sh
conda activate /home/zf4_projects/RTML/sakundu/env/sk-py
export PYTHONPATH=$PYTHONPATH:$CT_PATH
python -m circuit_training.grouping.grouper_main \
--output_dir=$OUTPUT_DIR \
--netlist_file=$NETLIST_FILE \
--block_name=$BLOCK_NAME \
--hmetis_dir=$HMETIS_DIR \
--plc_wrapper_main=$PLC_WRAPPER_MAIN
