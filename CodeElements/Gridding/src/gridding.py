### Implement the gridding component
### Input:  a list of macros (each macro has a width and a height)
### Output: best choice of n_rows and n_cols

import os
from math import floor
from math import ceil
import shutil
import sys
sys.path.append('./utils')

# Note that we use the center point of an object (macro, grid)
# to represent the position of that object
# Define the grid class
class Grid:
    def __init__(self, grid_id, width, height, x, y):
        self.grid_id_ = grid_id
        self.width_   = width
        self.height_  = height
        self.x_       = x
        self.y_       = y
        self.placed_  = False  # if there is macro placed on the center of this grid
        self.macros_id_ = [] # the id of macros intersecting with this grid
        self.macro_area = 0.0

# Check if there is an overlap with other placed macros
def CheckOverlap(lx, ly, ux, uy, macro_box):
    # macro_box : bounding boxes for all the placed macros
    # lx, ly, ux, uy for current macro
    for bbox in macro_box:
        bbox_lx, bbox_ly, bbox_ux, bbox_uy = bbox
        if (lx >= bbox_ux or ly >= bbox_uy or ux <= bbox_lx or uy <= bbox_ly):
            pass
        else:
            return True  # there is an overlap
    return False


# Get overlap area
def GetOverlapArea(box_a, box_b):
    box_a_lx, box_a_ly, box_a_ux, box_a_uy = box_a
    box_b_lx, box_b_ly, box_b_ux, box_b_uy = box_b
    if (box_a_lx >= box_b_ux or box_a_ly >= box_b_uy or box_a_ux <= box_b_lx or box_a_uy <= box_b_ly):
        return 0.0
    else:
        width = min(box_a_ux, box_b_ux) - max(box_a_lx, box_b_lx)
        height = min(box_a_uy, box_b_uy) - max(box_a_ly, box_b_ly)
        return width * height

# Place macros one by one
# n = num_cols
def PlaceMacros(macro_map, grid_list, chip_width, chip_height, n):
    ### All the macro must be placed on the center of one grid
    #Initialize the position of macros
    ver_sum = 0.0
    ver_span_sum = 0.0
    hor_sum = 0.0
    hor_span_sum = 0.0
    macro_bbox = []
    # Place macro one by one
    for key, value in macro_map.items():
        width = value[0]
        height = value[1]
        macro_id = key
        placed_flag = False
        for grid in grid_list:
            if (grid.placed_ == True):
                continue # this grid has been occupied
            # if the macro is placed on this
            x = grid.x_
            y = grid.y_
            lx = x - width / 2.0
            ly = y - height / 2.0
            ux = lx + width
            uy = ly + height

            # check if the macro is within the outline
            if (ux > chip_width or uy > chip_height):
                continue
            # check if there is an overlap with other macros
            if (CheckOverlap(lx, ly, ux, uy, macro_bbox) == True):
                continue

            # place current macro on this grid
            grid.placed_ = True
            placed_flag  = True

            # update the canvas status
            macro_bbox.append([lx, ly, ux, uy])

            grid_width = grid.width_
            grid_height = grid.height_
            # update covered grids
            min_col_id = floor(lx / grid_width)
            max_col_id = floor(ux / grid_width)
            min_row_id = floor(ly / grid_height)
            max_row_id = floor(uy / grid_height)
            for i in range(min_row_id, max_row_id + 1):
                for j in range(min_col_id, max_col_id + 1):
                    grid_id = i * n + j # n is the num_cols
                    grid_list[grid_id].macros_id_.append(macro_id)
                    grid_box = [i * grid_width, j * grid_height, (i + 1) * grid_width, (j + 1) * grid_height]
                    overlap_area = GetOverlapArea(grid_box, [lx, ly, ux, uy])
                    grid_list[grid_id].macro_area += overlap_area

            ver_sum += height
            ver_span_sum += (max_row_id + 1 - min_row_id) * grid_height
            hor_sum += width
            hor_span_sum += (max_col_id + 1 - min_col_id) * grid_width
            break # stop search remaining candidates

        # cannot find a valid position for the macro
        if (placed_flag == False):
            return False, [0.0, 0.0, 0.0, 0.0]

    return  True, [ver_sum, ver_span_sum, hor_sum, hor_span_sum]

# Define the gridding function
def Gridding(macro_width_list, macro_height_list,
             chip_width, chip_height,
             min_n_rows = 10,  min_n_cols = 10,
             max_n_rows = 128, max_n_cols = 128,
             min_num_grid_cells = 500,
             max_num_grid_cells = 2500,
             max_aspect_ratio = 1.5,
             tolerance = 0.05):
    """
    Arguments:
        macro_width_list, macro_height_list :  macro information
        chip_width, chip_height : canvas size or core size of the chip
        min_n_rows, min_n_cols : mininum number of rows/cols sweep
        max_n_rows, max_n_rows : maximum number of rows/cols sweep
        min_num_grid_cells, max_num_grid_cells :  mininum or maxinum grid cells
        max_aspect_ratio : maximum aspect ratio of a grid cell (either w/h or h/w)
        tolerance : tolerance to choose lower number of grids
    Return:
      the best number of rows and cols
    """
    ### Sort all the macros in a non-decreasing order
    if (len(macro_width_list) != len(macro_height_list)):
      print("[Error] The macro information is wrong!!!")
      exit()

    ### Sort all the macros based on area in a non-decreasing order
    macro_map = {  }
    for i in range(len(macro_width_list)):
        macro_map[i] = [macro_width_list[i], macro_height_list[i]]
    macro_map = dict(sorted(macro_map.items(), key=lambda item: item[1][0] * item[1][1], reverse = True))

    ### Print information
    print("*"*80)
    print("[INFO] Canvas Information :  canvas_width =", chip_width,  "canvas_height =", chip_height)
    print("\n")
    print("[INFO] Sorted Macro Information")
    for key, value in macro_map.items():
        line = "macro_" + str(key) + " "
        line += "macro_width = " + str(round(value[0], 2)) + " "
        line += "macro_height = " + str(round(value[1], 2)) + " "
        line += "macro_area = " + str(round(value[0] * value[1], 2))
        print(line)
    print("\n")

    ### Sweep the n_rows (m) and n_cols (n) in a row-based manner
    macro_bbox = [] # (lx, ly, ux, uy) for each bounding box
    # we use m for max_n_rows and n for max_n_cols
    m_best = -1
    n_best = -1
    best_metric = -1.0
    choice_map = {  }  # [m][n] : (ver_cost, hor_cost, empty_ratio)
    for m in range(min_n_rows, max_n_rows):
        choice_map[m] = {  }
        for n in range(min_n_cols, max_n_cols):
            if (m * n > max_num_grid_cells):
                break
            if (m * n < min_num_grid_cells):
                continue

            ### Step1:  Divide the canvas into grids
            ### We arrange all the grids in a row-major manner
            grid_height = chip_height / m
            grid_width  = chip_width / n
            if (grid_height / grid_width > max_aspect_ratio):
                continue
            if (grid_width / grid_height > max_aspect_ratio):
                continue

            ### Step2:  Try to place macros on canvas
            grid_list = []
            for i in range(m):
                for j in range(n):
                    x = (j + 0.5) * grid_width
                    y = (i + 0.5) * grid_height
                    grid_id = len(grid_list)
                    grid_list.append(Grid(grid_id, grid_width, grid_height, x, y))

            value = [0.0, 0.0, 0.0, 0.0]
            ### Place macros one by one
            result_flag, value = PlaceMacros(macro_map, grid_list, chip_width, chip_height, n)
            if (result_flag == False):
                continue
            else:
                ### compute the empty ratio
                used_threshold = 1e-5
                num_empty_grids = 0
                for grid in grid_list:
                    if (grid.macro_area / (grid_width * grid_height) < used_threshold):
                        num_empty_grids += 1
                metric = 1.0 - value[0] / value[1]
                metric += 1.0 - value[2] / value[3]
                metric += num_empty_grids / len(grid_list)
                choice_map[m][n] = metric
                if (metric > best_metric):
                    best_metric = metric
                    m_best = m
                    n_best = n
    m_opt = m_best
    n_opt = n_best
    num_grids_opt = m_opt * n_opt

    print("m_best = ", m_best)
    print("n_best = ", n_best)
    print("tolerance = ", tolerance)
    for [m, m_map] in choice_map.items():
        for [n, metric] in m_map.items():
            print("m = ", m , "  n = ", n, "  metric = ", metric)
            if ((metric >= (1.0 - tolerance) * best_metric) and (m * n < num_grids_opt)):
                m_opt = m
                n_opt = n
                num_grids_opt = m * n

    print("[INFO] Optimal configuration :  num_rows = ", m_opt, " num_cols = ", n_opt)
    return m_opt, n_opt


class GriddingLefDefInterface:
    def __init__(self, src_dir, design, setup_file = "setup.tcl", tolerance = 0.05,
                 halo_width = 0.0, min_n_rows = 10, min_n_cols = 10, max_n_rows = 128,
                 max_n_cols = 128, max_rows_times_cols = 2500,  min_rows_times_cols = 500,
                 max_aspect_ratio = 1.5):
        self.src_dir = src_dir
        self.design = design
        self.setup_file = setup_file
        self.tolerance = tolerance
        self.halo_width = halo_width
        self.min_n_rows = min_n_rows
        self.min_n_cols = min_n_cols
        self.max_n_rows = max_n_rows
        self.max_n_cols = max_n_cols
        self.max_rows_times_cols = max_rows_times_cols
        self.min_rows_times_cols = min_rows_times_cols
        self.max_aspect_ratio = max_aspect_ratio
        self.macro_width_list = []
        self.macro_height_list = []
        self.chip_width = 0.0
        self.chip_height = 0.0
        self.num_std_cells = 0
        self.extract_hypergraph_file = self.src_dir + '/utils/extract_hypergraph.tcl'
        self.openroad_exe = self.src_dir + "/utils/openroad"

        self.GenerateHypergraph()
        self.ExtractInputs()
        self.m_opt, self.n_opt = Gridding(self.macro_width_list, self.macro_height_list,
                                          self.chip_width, self.chip_height,
                                          self.min_n_rows, self.min_n_cols,
                                          self.max_n_rows, self.max_n_cols,
                                          self.min_rows_times_cols, self.max_rows_times_cols,
                                          self.max_aspect_ratio, self.tolerance)

    def GetNumRows(self):
        return self.m_opt

    def GetNumCols(self):
        return self.n_opt

    def GetChipWidth(self):
        return self.chip_width

    def GetChipHeight(self):
        return self.chip_height

    def GetNumStdCells(self):
        return self.num_std_cells


    def GenerateHypergraph(self):
        # Extract hypergraph from netlist
        temp_file = os.getcwd() + "/extract_hypergraph.tcl"
        cmd = "cp " + self.setup_file + " " + temp_file
        os.system(cmd)

        with open(self.extract_hypergraph_file) as f:
            content = f.read().splitlines()
        f.close()

        f = open(temp_file, "a")
        f.write("\n")
        for line in content:
            f.write(line + "\n")
        f.close()

        cmd = self.openroad_exe + " " + temp_file
        os.system(cmd)

        cmd = "rm " + temp_file
        os.system(cmd)

    def ExtractInputs(self):
        file_name = os.getcwd() + "/rtl_mp/" + self.design + ".hgr.outline"
        with open(file_name) as f:
            content = f.read().splitlines()
        f.close()

        items = content[0].split()
        print(items)
        self.chip_width = float(items[2]) - float(items[0])
        self.chip_height = float(items[3]) - float(items[1])

        file_name = os.getcwd() + "/rtl_mp/" + self.design + ".hgr.instance"
        with open(file_name) as f:
            content = f.read().splitlines()
        f.close()

        for line in content:
            items = line.split()
            if (items[1] == "1"):
                self.macro_width_list.append(float(items[4]) - float(items[2]) + 2 * self.halo_width)
                self.macro_height_list.append(float(items[5]) - float(items[3]) + 2 * self.halo_width)
            else:
                self.num_std_cells += 1

        rpt_dir = os.getcwd() + "/rtl_mp"
        shutil.rmtree(rpt_dir)
























