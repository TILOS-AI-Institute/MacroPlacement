import os
import sys
sys.path.append('../../src')
from FormatTranslators import BookShelf2ProBufFormat

if __name__ == '__main__':
    # set up inputs
    benchmark_dir = './DAC2012_testcases'
    design = 'superblue19'
    if(len(sys.argv)==3):
    	benchmark_dir = sys.argv[1]
    	design = sys.argv[2]
    # other parameters
    file_dir = benchmark_dir + '/' + design
    output_file = design + ".plc"

    BookShelf2ProBufFormat(file_dir, design, output_file)







