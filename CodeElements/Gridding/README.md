# Gridding

In Circuit Training, the purpose of gridding is to control the size of the macro placement solution space, thus allowing RL to train within reasonable
runtimes. Gridding enables hard macros to find locations consistent with high solution quality, while allowing soft macros (standard-cell clusters) to also find good locations.

Gridding determines a dissection of the layout canvas into some number of rows (**n_rows**) and some number of columns (**n_cols**) of _gridcells_.

The choice of **n_rows** and **n_cols** is made **once** for each design.  Once the dimensions **(n_rows, n_cols)** have been chosen, their values define a gridded canvas, or _grid_, and remain fixed throughout Circuit Training for the given design.  
The detailed algorithm is shown as following.
<img src="./Gridding Algorithm.png" width= "1600"/>

The gridding algorithm starts with the dimensions **canvas_width** and **canvas_height** of the layout canvas, as well as a list of **macros**, where each macro has a width and a height. 
Macros are not rotatable. The area of a macro is the product of its width and height.
Then, the gridding searches over combinations (**n_rows**, **n_cols**), with constraints
- **min_n_rows** <= **n_rows** < **max_n_rows** 
- **min_n_cols** <= **n_cols** < **max_n_cols** 
- **min_num_gridcells** <= **n_rows** * **n_cols** <= **max_num_grid_cells**
- **grid_w** / **grid_h** <= **max_aspect_ratio** 
- **grid_h** / **grid_w** <= **max_aspect_ratio** 
- The macros can be packed sequentially on the gridcells. There are **n_rows** * **n_cols** gridcells in the canvas. \[Algorithm 1 Lines 11-22\]


where each gridcell has width of **grid_w** = **canvas_width** / **n_cols**
and height of **grid_h** = **canvas_height** / **n_row**.
The main idea is to search for a particular (**n_rows**, **n_cols**) combination
that maximize the metric related to wasted space.


To evaluate metric for a given _grid_ (**n_rows**, **n_cols**), 
all macros are packed into the _gridcells_, 
and several terms (**empty_ratio**, **ver_waste** and **hor_waste**)
that reflect wasted space are evaluated.
## Packing
Macro packing is performed as follows \[Algorithm 1 Lines 11-22\]:
- Macros are placed in order of non-increasing macro area.
- All macros are placed, one by one, into the (**n_rows**, **n_cols**) _gridcells_.
If the current macro cannot be placed, then the _grid_ is infeasible and the next
candidate _grid_ is considered.
- A macro is placed at the **first** (according to row-major order) _gridcell_ where it can be legally placed.
- Placement of a macro means placing that macro's center at the center of some _gridcell_.
- The placement of a macro's center at the center of some _gridcell_ is legal if (1) no part of the macro is outside of the canvas, and (2) no overlap of the macro with any previously-placed macro is induced.
## Metric
After macro packing, we can calculate the **empty_ratio** of current _grid_, i.e., 
the number of empty _gridcells_ over the total number of _gridcells_ (**n_rows** * **n_cols**).
A _gridcell_ is claimed as an empty _gridcell_ if the intersection area of placed macros with it is less than 0.00001 times its area.  
Next we calculate the **hor_waste** and **ver_waste** as described in following algorithm.
<img src="./Calculate Waste Ratio.png" width= "1600"/>

To calculate horizontal waste **hor_waste**, we calculate
- **width_tot_macros** = the sum of widths of all macros in the design
- **width_tot_used_gridcells** = the sum of widths of all used _gridcells_ if we pack the macros along the x-axis one by one.

Then, **hor_waste** = 1.0 - **width_tot_macros** / **width_tot_used_gridcells**.

To calculate vertical waste **ver_waste**, we calculate
- **height_tot_macros** = the sum of heights of all macros in the design
- **height_tot_used_gridcells** = the sum of heights of all used _gridcells_ if we pack the macros along the y-axis one by one.

Then, **ver_waste** = 1.0 - **height_tot_macros** / **height_tot_used_gridcells**.

After calculating **empty_ratio**, **ver_waste** and **ver_waste**, the **metric** is defined as
**metric** = **empty_ratio** + 2.0 - **ver_waste** - **ver_waste**.
The _grid_ with best **metric** is noted as **n_rows_opt** and **n_cols_opt**.

## Grid Simplification
Once we have found **n_rows_opt** and **n_cols_opt** as described above, 
we seek a smaller _grid_ that has similar metric properties. \[Algorithm 1 Lines 33-39\]  
Specifically, we find values of **n_rows_actual** and **n_cols_actual** such that 
its **metric** is within some tolerance (5\% in Circuit Training) of the optimal **metric**, 
and **n_rows_actual** * **n_cols_actual** is minimized. 
This is the grid that is used in Circuit Training.
To our understanding, the foregoing procedure results in grids that are of similar sizes, e.g., with ~25 <= **n_rows_actual** , **n_cols_actual** <= ~40. 


## Thanks
We thank Google engineers for May 19, 2022 discussions that explained the gridding method used in Circuit Training.
All errors of understanding and implementation are the authors'. We will rectify such errors as soon as possible after being made aware of them.

