'''
This script generates bookshelf format from odb format
'''
import os
import odb
import sys
import re

work_dir = re.search(r'(/\S+/MacroPlacement)', os.getcwd()).group(1)
sys.path.append(f'{work_dir}/Flows/util')

from convert_odb2bookshelf import OdbToBookshelf

design = sys.argv[1]
odb_file = sys.argv[2]
output_dir = sys.argv[3]

modeFormat = 'ISPD11'
cellPadding = 0
layerCapacity = 'layeradjust_empty.tcl'

def touch(fname, times=None):
    with open(fname, 'a'):
        os.utime(fname, times)

if  not os.path.exists(layerCapacity):
    touch(layerCapacity)

db = odb.dbDatabase.create()
odb.read_db(db, odb_file)
bs = OdbToBookshelf(opendbpy=odb, opendb=db, cellPadding=cellPadding,
                    modeFormat=modeFormat, layerCapacity=layerCapacity)

if not os.path.exists(f'{output_dir}/RePlAce'):
    os.makedirs(f'{output_dir}/RePlAce')

bs.WriteBookshelf(f'{design}.bookshelf')
