import os
import sys
import imageio
sys.path.append('../VisualPlacement/')
from visual_placement import VisualPlacement

iter_list = [i for i in range(0, 1500, 100)]

print(iter_list)

image_files = []
for iter in iter_list:
    netlist_file = "./ariane133/ariane.pb.txt." + str(iter)
    plc_file = "./ariane133/ariane.plc." + str(iter)
    VisualPlacement(netlist_file, plc_file)
    image_files.append(plc_file + ".png")

images = []
for filename in image_files:
    images.append(imageio.imread(filename))
imageio.mimsave('movie.gif', images, fps=1)





