#!/bin/bash
REPO_DIR=""
DESIGN="mempool_group"
DESIGN_DIR="${REPO_DIR}/test/${DESIGN}_ng45" ## May need to add _ng45, asap7, _X2_xflip, _X4_xflip_yflip suffixes to the design name
NETLIST_FILE="${DESIGN_DIR}/netlist.pb.txt"
PLC_FILE="${DESIGN_DIR}/initial.plc"
## Iteration values are Ariane (18K), BP_Quad (5K), MemPoolGroup (4K), Ariane_X2 (6K), Ariane_X4 (4.5K)
ITERS=4000
IS_ASYNC=0
N=20
TEMP=0.005
SEED=1
NUM_WORKERS=80
TOP_K=8
INIT_PLACE=1
SYNC_FREQ=0.1
HPWL_WEIGHT=1.0
DENSITY_WEIGHT=0.5
CONG_WEIGHT=0.5
SWAP_PROB=0.24
SHIFT_PROB=0.24
FLIP_PROB=0.04
MOVE_PROB=0.24
SHUFFLE_PROB=0.24
RUN_DIR="."

## Copy the look up table used for exponent computation
cp -rf ${REPO_DIR}/util/safe_exp_table.bin .

${REPO_DIR}/build/sa \
  ${NETLIST_FILE} ${PLC_FILE} $N $TEMP $ITERS ${SEED} \
  ${INIT_PLACE} ${SWAP_PROB} ${SHIFT_PROB} \
  ${FLIP_PROB} ${MOVE_PROB} ${SHUFFLE_PROB} \
  ${DESIGN} ${RUN_DIR} ${HPWL_WEIGHT} ${DENSITY_WEIGHT} ${CONG_WEIGHT} \
  ${SYNC_FREQ} ${NUM_WORKERS} ${TOP_K} ${IS_ASYNC} | tee run.log


## Report top 10 best plc files
for plc in $(ls *.plc |
  awk -F'_' '{print $(NF-2), $0}' |
  sort -n |
  head -n 10 |
  cut -d' ' -f2-); do
  echo "python ${REPO_DIR}/util/golden_eval.py ${DESIGN} ${NETLIST_FILE} ${plc} ."
done
