'''
This script generates OpenDB database from LEF/DEF 
'''
import odb
import sys
import os
import re

design = sys.argv[1]
def_file = sys.argv[2]
output_dir = sys.argv[3]

work_dir = re.search(r'(/\S+/MacroPlacement)', os.getcwd()).group(1)
sys.path.append(f'{work_dir}/Flows/util')

from convert_odb2bookshelf import OdbToBookshelf


lef_dir = '../../../../../Enablements/NanGate45/lef'
lef_list = [f'{lef_dir}/NangateOpenCellLibrary.tech.lef',
            f'{lef_dir}/NangateOpenCellLibrary.macro.mod.lef',
            f'{lef_dir}/fakeram45_256x16.lef']

db = odb.dbDatabase.create()
for lef_file in lef_list:
    odb.read_lef(db, lef_file)

odb.read_def(db, def_file)
chip = db.getChip()
tech = db.getTech()
libs = db.getLibs()

if chip is None:
    exit("ERROR: READ DEF Failed")

if not os.path.exists(f'{output_dir}/RePlAce'):
    os.makedirs(f'{output_dir}/RePlAce')

odb_file = f'{output_dir}/RePlAce/{design}.odb'
export_result = odb.write_db(db, odb_file)

if export_result != 1:
    exit("ERROR: Export failed")


new_db = odb.dbDatabase.create()
odb.read_db(new_db, odb_file)

if new_db is None:
    exit("ERROR: Import failed")

if odb.db_diff(db, new_db):
    exit("ERROR: Difference found in exported and imported DB")

print(f"Successfully generated ODB format from LEF/DEF for {design}")

bs = OdbToBookshelf(
    opendbpy=odb, 
    opendb=db, 
    cellPadding=0,
    modeFormat="ISPD11",
    layerCapacity='layeradjust_empty.tcl')

bs.WriteBookshelf(f'{design}_pad0_ISPD11')
