import os
import time
import shutil
import sys
import argparse
import matplotlib.pyplot as plt
from math import log
import json


file_name = "run.log"
with open(file_name) as f:
    content = f.read().splitlines()
f.close()

cost_list = []
for line in content:
    items = line.split()
    if (len(items) == 6 and items[0] == "step"):
        cost_list.append(float(items[-1]))

plt.figure()
plt.plot([i for i in range(len(cost_list))], cost_list, '-k')
plt.xlabel("moves", fontsize= 30)
plt.ylabel("cost", fontsize= 30)
plt.xticks(fontsize=30)
plt.yticks(fontsize=30)
plt.show()






