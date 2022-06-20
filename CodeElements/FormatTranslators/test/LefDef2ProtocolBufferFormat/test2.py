import os
import sys
sys.path.append('../../src')
from FormatTranslators import LefDef2ProBufFormat

if __name__ == '__main__':
    design = "ariane"
    output_file = design + ".plc"
    openroad_exe = "../../src/utils/openroad"
    net_size_threshold = 300
    def_file = "./design/ariane.def"
    lef_list = ["./lefs/NangateOpenCellLibrary.tech.lef",  "./lefs/NangateOpenCellLibrary.macro.mod.lef", "./lefs/fakeram45_256x16.lef"]
    LefDef2ProBufFormat(lef_list, def_file, design, openroad_exe, net_size_threshold)



