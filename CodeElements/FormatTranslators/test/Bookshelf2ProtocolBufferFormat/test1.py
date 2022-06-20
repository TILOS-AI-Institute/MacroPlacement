import os
import sys
sys.path.append('../../src')
from FormatTranslators import BookShelf2ProBufFormat

if __name__ == '__main__':
    # set up inputs
    benchmark_dir = './ISPD2012_testcases'
    design = 'superblue19'

    # other parameters
    file_dir = benchmark_dir + '/' + design
    output_file = design + ".plc"

    BookShelf2ProBufFormat(file_dir, design, output_file)







