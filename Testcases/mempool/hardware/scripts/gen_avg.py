#!/usr/bin/env python3

# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# This script takes a set of .csv files in one of the results folders and
# generates the average performances over all the cores used.
# Author: Marco Bertuletti <mbertuletti@iis.ee.ethz.ch>

import os
import pandas as pd
import numpy as np
import argparse

ext = ('.csv')

parser = argparse.ArgumentParser()
parser.add_argument(
    '--folder',
    '-f',
    help='Name of the results folder with traces to be averaged.'
)
args = parser.parse_args()

os.chdir(args.folder)
path = os.getcwd()
print(path)
for files in os.listdir(path):
    if files.endswith(ext):
        csvread = pd.read_csv(files)

        print("\n")
        print("*******************************")
        print("**    AVERAGE PERFORMANCE    **")
        print("*******************************")

        print("")
        for section in set(csvread['section']):
            print("Section %d:\n" % section)
            sectionread = csvread.loc[csvread['section'] == section]
            keys = csvread.columns
            remove_keys = ['core',
                           'section',
                           'start',
                           'end',
                           'snitch_load_latency',
                           'snitch_load_region',
                           'snitch_load_tile',
                           'snitch_store_region',
                           'snitch_store_tile']
            keys = keys.drop(remove_keys, errors='raise')
            for key in keys:
                try:
                    column = sectionread[key].replace(np.nan, 0)
                    column = column.to_numpy()
                    avg = np.average(column)
                except Exception:
                    # Key could not be averaged
                    continue
                print("%-30s %4.4f" % (key, avg))
