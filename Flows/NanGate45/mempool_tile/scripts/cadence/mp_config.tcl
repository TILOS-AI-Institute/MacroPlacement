## This script was written and developed by UCSD ABKGroup, 
## however, the underlying commands and reports are copyrighted
## by Cadence. We thank Cadence for granting permission to share
## our research to help promote and foster the next generation of
## innovators.

VERSION 1.0
BEGIN SEED
name=i_tile/gen_banks_0__mem_bank
name=i_tile/gen_banks_10__mem_bank
name=i_tile/gen_banks_11__mem_bank
name=i_tile/gen_banks_12__mem_bank
name=i_tile/gen_banks_13__mem_bank
name=i_tile/gen_banks_14__mem_bank
name=i_tile/gen_banks_15__mem_bank
name=i_tile/gen_banks_1__mem_bank
name=i_tile/gen_banks_2__mem_bank
name=i_tile/gen_banks_3__mem_bank
name=i_tile/gen_banks_4__mem_bank
name=i_tile/gen_banks_5__mem_bank
name=i_tile/gen_banks_6__mem_bank
name=i_tile/gen_banks_7__mem_bank
name=i_tile/gen_banks_8__mem_bank
name=i_tile/gen_banks_9__mem_bank
name=i_tile/gen_caches_0__i_snitch_icache/i_lookup/i_data
END SEED
BEGIN MACRO
name=fakeram45_64x64  orient={R0} isCell=true minRightSpace=10 minLeftSpace=10 minTopSpace=5 minBottomSpace=5
name=fakeram45_256x32  orient={R0} isCell=true minRightSpace=10 minLeftSpace=10 minTopSpace=5 minBottomSpace=5
END MACRO
BEGIN CONSTRAINT
END CONSTRAINT
