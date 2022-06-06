### Implement the gridding component
### Input:  a list of macros (each macro has a width and a hight)
### Output: best choice of n_rows and n_cols


import os
from math import floor
from math import ceil

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



# Place macros one by one
# n = num_cols
def PlaceMacros(macro_map, grid_list, chip_width, chip_height, n):
    ### All the macro must be placed on the center of one grid

    #Initialize the position of macros
    macro_bbox = []

    # Place macro one by one
    for key, value in macro_map.items():
        width = value[0]
        height = value[0]
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
            max_col_id = ceil(ux / grid_width)
            min_row_id = floor(ly / grid_height)
            max_row_id = ceil(uy / grid_height)
            for i in range(min_row_id, max_row_id + 1):
                for j in range(min_col_id, max_col_id + 1):
                    grid_id = i * n + j # n is the num_cols
                    grid_list[grid_id].macros_id_.append(macro_id)
            break # stop search remaining candidates

        # cannot find a valid position for the macro
        if (placed_flag == False):
            return False

    return  True

# Define the gridding function
def Gridding(macro_width_list, macro_height_list,
             chip_width, chip_height, tolerance = 0.1,
             min_n_rows = 10, min_n_cols = 10,
             max_n_rows = 100, max_n_cols = 100,
             max_rows_times_cols = 3000):
    ### Sort all the macros in a non-decreasing order
    if (len(macro_width_list) != len(macro_height_list)):
      print("[Error] The macro information is wrong!!!")
      exit()

    ### Sort all the macros based on area in a non-decreasing order
    macro_map = {  }
    for i in range(len(macro_width_list)):
        macro_map[i] = [macro_width_list[i], macro_height_list[i]]

    macro_map = dict(sorted(macro_map.items(), key=lambda item: item[1][0] * item[1][1], reverse = True))
    macro_bbox = [] # (lx, ly, ux, uy) for each bounding box

    # we use m for max_n_rows and n for max_n_cols
    m_best = -1
    n_best = -1
    best_cost = 2.0 # cost should be less than 2.0 based on definition
    choice_map = {  }

    for m in range(min_n_rows, max_n_rows + 1):
        choice_map[m] = {  }
        for n in range(min_n_cols, max_n_cols + 1):
            if (m * n > max_rows_times_cols):
                break

            ### Step1:  Divide the canvas into grids
            ### We arrange all the grids in a row-major manner
            grid_height = chip_height / m
            grid_width  = chip_width / n
            grid_list = []
            for i in range(m):
                for j in range(n):
                    x = (j + 0.5) * grid_width
                    y = (i + 0.5) * grid_height
                    grid_id = len(grid_list)
                    grid_list.append(Grid(grid_id, grid_width, grid_height, x, y))

            ### Place macros one by one
            if (PlaceMacros(macro_map, grid_list, chip_width, chip_height, n) == False):
                continue
            else:
                ### Calculate the cost
                total_grid_width = 0.0
                total_grid_height = 0.0
                for grid in grid_list:
                    if (len(grid.macros_id_) > 0):
                        total_grid_width += grid.width_
                        total_grid_height += grid.height_

                # calculate h_cost
                cost = 1.0 - sum(macro_width_list) / total_grid_width
                cost += 1.0 - sum(macro_height_list) / total_grid_height
                choice_map[m][n] = cost
                if (cost < best_cost):
                    best_cost = cost
                    m_best = m
                    n_best = n
    m_opt = m_best
    n_opt = n_best
    num_grids_opt = m_opt * n_opt

    for [m, m_map] in choice_map.items():
        for [n, cost] in m_map.items():
            if ((cost <= (1.0 + tolerance) * best_cost) and (m * n < num_grids_opt)):
                m_opt = m
                n_opt = n
                num_grids_opt = m * n

    print("[INFO] Optimial configuration :  num_rows = ", m_opt, " num_cols = ", n_opt)
    return m_opt, n_opt


if __name__ == "__main__":
    # Just test
    macro_width_list = [1, 2, 3.5, 3.5, 2.5]
    macro_height_list = [1, 2, 3.5, 3.5, 2.5]
    chip_width = 10
    chip_height = 10
    tolerance = 0.01
    Gridding(macro_width_list, macro_height_list, chip_width, chip_height, tolerance)























