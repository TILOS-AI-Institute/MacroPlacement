# Gridding


The purpose of "gridding" is to assess potential choices of number of rows (n_rows) and number of columns (n_cols) in the gridded layout canvas.

The choice of n_rows and n_cols is made once for each design.  Once (n_rows, n_cols) is chosen, these values remain fixed throughout Circuit Training for the given design.


Input: a list of blocks.  Each block has a width and a height.  The area of a block is its width * height.

We pack (i.e., place) all blocks into the _grid_, in order of decreasing (non-increasing) block area.

There are constraints 
10 <= **n_rows** , **n_cols** <= 100
**n_rows** *** n_cols** <= 3000

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




