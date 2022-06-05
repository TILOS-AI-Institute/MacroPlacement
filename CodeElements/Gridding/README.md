# Gridding

In Circuit Training, the purpose of gridding is to control the size of the macro placement solution space, thus allowing RL to train within reasonable
runtimes. Gridding enables hard macros to find locations consistent with high solution quality, while allowing soft macros (standard-cell clusters) to also find good locations.

Gridding determines a dissection of the layout canvas into some number of rows (**n_rows**) and some number of columns (**n_cols**) of _gridcells_.

The choice of **n_rows** and **n_cols** is made **once** for each design.  Once **(n_rows, n_cols)** is chosen, these values remain fixed throughout Circuit Training for the given design.

The gridding process starts with the dimensions **H_canvas** and **V_canvas** of the layout canvas, as well as a list of hard **macro blocks**, where each block has a width and a height. Blocks are not rotatable. The area of a block is the product of its width and height. 

Then, the gridding searches over combinations **(n_rows, n_cols)**, with constraints
- 10 <= **n_rows** , **n_cols** <= 100
- **n_rows** * **n_cols** <= 3000   // this product is the number of _gridcells_ in the canvas

For
pack (i.e., place) all blocks into the _grid_, in order of decreasing (non-increasing) block area. This allows us to evaluate the _loss_ induced by a given choice of 

There are constraints 


The gridded canvas, or _grid_, is comprised of **n_rows** * **n_cols** _gridcells_.

Each block is placed at the FIRST AVAILABLE (according to row-major order) gridcell where the block's placement does not result in **any** overlap with previously-placed blocks.  Here, "placed" means that the center of the block is placed at the center of the gridcell.

Overlap (horizontal) means _(pessimistically defined, note)_ that the x-spans of two placed blocks that intersect gridcells of a given row have a nonempty intersection.
Overlap (vertical) is similarly defined.



Loss is well-defined after all blocks have been packed into the grid, according to the above process, with no overlap.  (If not all blocks can be packed into the grid, then the grid (i.e., its (n_rows,n_cols)) is infeasible.

loss_tot = loss_h + loss_v

loss_h = width_tot_blocks / width_tot_gridcells 

width_tot_blocks = sum of widths of all blocks in the design
width_tot_gridcells = sum of widths of all gridcells in the grid that have nonempty intersection with a placed block

loss_v is similarly defined.

of widths of gridcells that have 
loss_opt = min_{r,c} of loss_tot

Input: a list of blocks.  Each block has a width and a height.

 
 

Each block is placed at the FIRST AVAILBLE (according to row-major order) gridcell that does not result in **any** overlap

Placed means center of block is placed at center of the gridcell.

Overlap (horizontal) means (pessimistically defined, note) that the x-spans of two placed blocks that intersect gridcells of a given row have a nonempty intersection.
Overlap (vertical) is similarly defined.



We thank Google engineers for May 19, 2022 discussions that explained the gridding method used in Circuit Training.
All errors of understanding and implementation are the authors'. We will rectify such errors as soon as possible after being made aware of them.


