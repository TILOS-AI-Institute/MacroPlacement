# Gridding

10 <= n_rows , n_cols <= 100
n_rows * n_cols <= 3000

Grid is comprised of n_rows * n_cols gridcells.

Pack blocks in order of decreasing area

Each block is placed at the FIRST (according to row-major order) gridcell that does not result in **any** overlap

Placed means center of block is placed at center of the gridcell.

Overlap (horizontal) means (pessimistically defined, note) that the x-spans of two placed blocks that intersect gridcells of a given row have a nonempty intersection.
Overlap (vertical) is similarly defined.


Loss is well-defined after all blocks have been packed into the grid, according to the above process, with no overlap.

Loss_tot = loss_h + loss_v

Loss_h = width_tot_blocks / width_tot_gridcells   sum of widths of gridcells that have 
loss_opt = min_{r,c} of loss_tot




