import sys
sys.path.append('/home/zf4_projects/DREAMPlace/sakundu/GB/CT/circuit_training')
sys.path.append('/home/zf4_projects/DREAMPlace/sakundu/GB/CT/')
from absl import flags
from circuit_training.grouping import grid_size_selection
from circuit_training.environment import plc_client
from circuit_training.grouping import grouper

run_dir = '/home/zf4_projects/DREAMPlace/sakundu/ABK_MP/flow_scripts_run/MacroPlacement'
protobuf_file = '/home/fetzfs_projects/MacroPlacement/flow_scripts_run/MacroPlacement/CodeElements/Plc_client/test/ariane133/netlist.pb.txt' 
plc = plc_client.PlacementCost(protobuf_file)

plc.set_canvas_size(2907.190, 2906.400)

width, height = plc.get_canvas_width_height()
print(width, height)
