import os
import sys
sys.path.append('../../src')
from FormatTranslators import Bookshelf2LefDef2ProBufFormat

if __name__ == '__main__':
    # set up inputs
    benchmark_dir = './DAC_testcases'
    design = 'superblue19'

    # other parameters
    file_dir = benchmark_dir + '/' + design
    output_file = design + ".plc"
    src_dir = "../../src"
    openroad_exe = "../../src/utils/openroad"
    lef_list = ["./lefs/NangateOpenCellLibrary.tech.lef",
                "./lefs/NangateOpenCellLibrary.macro.mod.lef"]
    tech = "NanGate45"
    net_size_threshold = 300

    Bookshelf2LefDef2ProBufFormat(lef_list, openroad_exe, file_dir, design, tech, src_dir, net_size_threshold)









