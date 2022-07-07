import os
import shutil
import fileinput
import re
from datetime import datetime

testcases = ['ariane136', 'ariane133', 'mempool_tile', 'nvdla']
enablements = ['NanGate45', 'ASAP7']
flows = [1, 2]
job_file = "all_jobs"
tnow = datetime.now()
suffix = f'{tnow.month}{tnow.day}{tnow.year}_{tnow.hour}{tnow.minute}{tnow.second}'


fp = open(job_file, "w")
for enablement in enablements:
  for testcase in testcases:
    for flow in flows:
      ## Check if the run directory exists
      run_dir = f"./{enablement}/{testcase}/run"
      if not os.path.exists(run_dir):
        os.makedirs(run_dir)
      
      ## Copy the scripts
      scripts_src = f"./{enablement}/{testcase}/scripts/cadence"
      
      if suffix != "":
        scripts_dst = f"./{enablement}/{testcase}/run/flow{flow}_{suffix}"
      else:
        scripts_dst = f"./{enablement}/{testcase}/run/flow{flow}"
      
      if os.path.exists(scripts_dst):
          print(f"For TestCase:{testcase} Enablement:{enablement} Flow:{flow}"
                "already exists. So not generating job for this")
      
      shutil.copytree(scripts_src, scripts_dst)

      ## Update the run.sh for flow
      flow_ip = 0
      if flow == 2:
        flow_ip = 1

      for line in fileinput.input(f"{scripts_dst}/run.sh", inplace=True):
        #line.replace("export PHY_SYNTH.*", f"export PHY_SYNTH={flow_ip}")
        line = re.sub(r"export\s+PHY_SYNTH\s*=.*",
                      f"export PHY_SYNTH={flow_ip}", line)
        print(line, end="")

      ## Add job to the job list
      scripts_dst_abs_path = os.path.abspath(scripts_dst)
      fp.write(f"cd {scripts_dst_abs_path}; sh run.sh;\n")
