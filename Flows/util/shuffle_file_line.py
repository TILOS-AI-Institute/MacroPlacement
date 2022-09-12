import random
import sys

file_name = sys.argv[1]
if len(sys.argv) > 2:
    seed = sys.argv[2]
else:
    seed = 42

fp = open(file_name, 'r')
lines = fp.readlines()
fp.close()

random.seed(seed)
random.shuffle(lines)

fp = open(file_name, 'w')
for line in lines:
    fp.write(f'{line}')
fp.close()