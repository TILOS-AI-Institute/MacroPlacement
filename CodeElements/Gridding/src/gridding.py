### Implement the gridding component
### Input:  a list of macros (each macro has a width and a hight)
### Output: best choice of n_rows and n_cols


import os

# Note that we use the center point of an object (macro, grid)
# to represent the position of that object
# Define the grid class
class Grid:
    def __init__(self, grid_id, width, height, x, y, x_id, y_id):
        self.grid_id_ = grid_id
        self.width_   = width
        self.height_  = height
        self.x_       = x
        self.y_       = y
        self.x_id     = x_id # row id
        self.y_id     = y_id # column id
        self.placed_  = False  # if there is macro placed on the center of this grid
        self.macros_id_ = [] # the id of macros intersecting with this grid
        self.macros_boxes_ = [] # (x, y, width, height) of the intersection
                               # part between macros and this grid
                               # the origin is relative to the center of the grid

# Define the gridding function
def Gridding(macro_width_list, macro_height_list, chip_width,
             chip_height, min_n_rows = 10, min_n_cols = 10,
             max_n_rows = 100, max_n_cols = 100, max_rows_times_cols = 3000):
    ### Sort all the macros in a non-decreasing order
    if (len(macro_width_list) != len(macro_height_list)):
      print("[Error] The macro information is wrong!!!")
      exit()

    ### Sort all the macros based on area in a non-decreasing order
    macro_map = {  }
    for i in range(len(macro_width_list)):
        macro_map[i] = [macro_width_list[i], macro_height_list[i]]

    macro_map = dict(sorted(macro_map.items(), key=lambda item: item[1][0] * item[1][1], reverse = True))


    # we use m for max_n_rows and n for max_n_cols
    m_best = -1
    n_best = -1
    best_cost = 2.0 # cost should be less than 2.0 based on definition

    for m in range(min_n_rows, max_n_rows + 1):
        for n in range(min_n_cols, max_n_cols + 1):
            if (m * n > max_rows_times_cols):
                break

            ### Step1:  Divide the canvas into grids
            ### We arrange all the grids in a row-major manner
            grid_width = chip_width / m
            grid_height = chip_height / n
            grid_list = []
            for i in range(m):
                for j in range(n):
                    x = (i + 0.5) * grid_width
                    y = (j + 0.5) * grid_height
                    grid_id = len(grid_list)
                    grid_list.append(Grid(grid_id, grid_width, grid_height, x, y, i, j))

            ### All the macro must be placed on the center of one grid




            ### Calculate the cost
            total_grid_width = 0.0
            total_grid_height = 0.0
            for grid in grid_list:
                if (len(grid.macros_id_) > 0):
                    total_grid_width += grid.width_
                    total_grid_height += grid.height_

            # calculate h_cost
            cost = sum(macro_width_list) / total_grid_width
            cost += sum(macro_height_list) / total_grid_height
            if (cost >= best_cost):
                best_cost = cost
                m_best = m
                n_best = n


    return m_best, n_cost, best_cost



if __name__ == "__main__":
    macro_width_list = [1, 2, 3]
    macro_height_list = [1, 2, 3]
    chip_width = 100
    chip_height = 100
    Gridding(macro_width_list, macro_height_list, chip_width, chip_height)























