# Gridding

In Circuit Training, the purpose of gridding is to control the size of the macro placement solution space, thus allowing RL to train within reasonable
runtimes. Gridding enables hard macros to find locations consistent with high solution quality, while allowing soft macros (standard-cell clusters) to also find good locations.

Gridding determines a dissection of the layout canvas into some number of rows (**n_rows**) and some number of columns (**n_cols**) of _gridcells_.

The choice of **n_rows** and **n_cols** is made **once** for each design.  Once the dimensions **(n_rows, n_cols)** have been chosen, their values define a gridded canvas, or _grid_, and remain fixed throughout Circuit Training for the given design. The detailed algorithm is shown as following.
<img src="./images/Gridding Algorithm.png" width= "1600"/>

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
<img src="./images/Calculate Waste Ratio.png" width= "1600"/>

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


# **Grouping**
Grouping is an important preprocessing step of clustering.
The grouping step in Circuit Training requires as inputs:
the post-synthesis gate-level netlist (standard cells and hard macros),
placed IOs (ports, or terminals), typically at the borders of the chip canvas,
the grid of **n_rows** rows and **n_cols** columns of _gridcells_, which defines the gridded layout canvas.
The purpose of grouping, to our understanding, is to ensure that closely-related standard-cell logic, 
which connect to the same macro or the same clump of IO (noted as IO cluster), belong to the same standard-cell clusters.



## **The Grouping Process**
The grouping consists of three steps:
- Group the macro pins of the same macro into a cluster.
In Circuit Training, the netlist consists of four building elements: 
standard cells, IO ports, macro pins and macros.
The following figure shows an example of netlist representation in Circuit Training.
The left part is the real netlist; The right part is the Netlist Protocol Buffer 
representation in Circuit Training. The solid arrow means the real signal net and the dashed
arrow means the virtual nets between macro A and its macro pins.
We can see that the macro pins and the related macro are both basic elements in the netlist, whereas there is no pins of standard cells.  Thus, it's necessary to group the macros pins of the same macro into a cluster, because the macro pins of the same macro will always stay together during macro placement. Note that only the macro pins are grouped and the macro itself is not grouped. For example, in this figure, **D\[0\]**, **D\[1\]**, **D\[2\]**, **Q\[0\]**,
**Q\[1\]**, **Q\[2\]** are grouped into **cluster_1**, but **cluster_1** does not include macro A.
<img src="./images/macro_example.png" width= "1600"/>


- Group the IOs that are within close proximity of each other boundary by boundary, 
following the order of **LEFT** <span>&rarr;</span> **TOP** <span>&rarr;</span>  **RIGHT** <span>&rarr;</span> **BOTTOM**. For the **LEFT**/**RIGHT**(**TOP**/**Bottom**) boundary, we sort the all the ports on the boundary based on their y (x) coordinates in a non-decreasing order. Starting from the first IO port on the boundary, we group the IO ports within each **grid_height** (**grid_width**) into an IO cluster. For example, in following figure, we have three IO clusters on **TOP** boundary and two IO clusters on **RIGHT** boundary. The **grid_width** and **grid_height** are calculated based on the **n_cols** and **n_rows**:
  - **grid_width** = **canvas_width** / **n_cols**
  - **grid_height** = **canvas_height** / **n_rows**

<img src="./images/IO_Groups.png" width= "1600"/>




- Group the close-related standard cells,
which connect to the same macro or the same IO cluster.
Suppose that we have a design with 100 clusters of macro pins (i.e., 100 macros) and 10 clusters of IOs.
Before we grouping the close-related standard cells to these clusters of macro pins or IOs,
we assign each cluster with a cluster id from 0 to 119.
Then for each cluster, we traverse the netlist and assign the same cluster id to the "immediate fanins" and "immediate fanouts" of its element (macro pin or IO).
Note that "immediate fanin" is equivalent to "transitive fanins up to level K_in = 1", and that "immediate fanouts" is equivalent to "transitive fanouts up to level K_out = 1".
It is our understanding that both K_in and K_out are always set to a default value of 1 
in Circuit Training. However, other values might be applied. 
In our implementation, we traverse the netlist in a depth-first-search manner.
All the elements (standard cell, macro pin or IO ports) with the same cluster id form a cluster.  Each cluster is recorded in the ".fix file" that is part of the input to the hMETIS hypergraph partitioner when the standard cells are grouped into soft macros. 
The part id of each cluster is the same as its cluster id.
Note that a macro does not belong to any cluster, thus is not fixed 
when we call the hMETIS hypergraph partitioner.

 
## **How Groups Are Used**
Each group is recorded in the “.fix file” that is part of the input to the hMETIS hypergraph partitioner when the gate-level netlist is clustered into soft macros.

## **How Grouping Scripts Are used**
We provide [(an example)](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Grouping/test/test.py) about the usage of our grouping scripts.
Basically our grouping scripts take follows as inputs: (i) [(setup_file)](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Grouping/test/setup.tcl)
including enablement information (lefs/libs), synthesized gate-level netlist (*.v),  def file with placed IOs (*.def); (ii) n_rows and n_cols determined by the [(Gridding)](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/CodeElements/Gridding) step; (iii) K_in and K_out parameters; (iv) global_net_threshold for ignoring global nets. If a net has more than global_net_threshold instances, we ignore such net when we search "transitive" fanins and fanouts. After
running grouping scripts,  you will get the **.fix** file.  

# Thanks
We thank Google engineers for Q&A in a shared document, as well as live discussions on May 19, 2022, that explained the grouping method used in Circuit Training. All errors of understanding and implementation are the authors'. We will rectify such errors as soon as possible after being made aware of them.





