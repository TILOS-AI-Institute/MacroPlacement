We implement [Ariane design with 133 macros](../../../Testcases/ariane133) on the [ASAP7](../../../Enablements/ASAP7) platform using the proprietary (commercial) tools **Cadence Genus** (Synthesis) and **Cadence Innovus** (P&R).

To reproduce Innovus CMP results, follow the steps below.
```bash
cd run
cp ../scripts/cadence run_eval_cmp
cd run_eval_cmp
./run.sh
```
<!-- The screenshot of the design using ORFS on ASAP7 enablement is shown below  
<img src="./screenshots/Ariane136_ORFS_SPNR.png" alt="ariane136_orfs" width="400"/> -->
