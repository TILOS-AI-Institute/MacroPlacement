# Gridding

In Circuit Training, the purpose of gridding is to control the size of the macro placement solution space, thus allowing RL to train within reasonable
runtimes. Gridding enables hard macros to find locations consistent with high solution quality, while allowing soft macros (standard-cell clusters) to also find good locations.

Gridding determines a dissection of the layout canvas into some number of rows (**n_rows**) and some number of columns (**n_cols**) of _gridcells_.

The choice of **n_rows** and **n_cols** is made **once** for each design.  Once the dimensions **(n_rows, n_cols)** have been chosen, their values define a gridded canvas, or _grid_, and remain fixed throughout Circuit Training for the given design.

The gridding process starts with the dimensions **H_canvas** and **W_canvas** of the layout canvas, as well as a list of hard **macro blocks**, where each block has a width and a height. Blocks are not rotatable. The area of a block is the product of its width and height. 

Then, the gridding searches over combinations **(n_rows, n_cols)**, with constraints
- 10 <= **n_rows** , **n_cols** <= 100
- **n_rows** * **n_cols** <= 3000   

Note that **n_rows** * **n_cols** is the number of _gridcells_ in the canvas. Each _gridcell_ has width **W_canvas / n_cols** and height **H_canvas / n_rows**.

The main idea is to search for a particular **(n_rows, n_cols)** combination that minimizes a metric called _loss_.

To evaluate _loss_ for a given _grid_, all blocks are packed into the _grid_, and several terms that reflect wasted space are evaluated. 

## Packing

Packing is performed as follows.
- All blocks are placed, one by one, into the **(n_rows, n_cols)** _grid_.  If the current block cannot be placed, then the _grid_ is infeasible and the next candidate _grid_ is considered.
- Blocks are placed in order of decreasing (i.e., non-increasing) block **area**.
- A block is placed at the **first** (according to row-major order) gridcell where it can be legally placed.
- Placement of a block means placing that block's **center** at the **center** of some gridcell.
- The placement of a block's center at the center of some gridcell is _legal_ if (1) no part of the block is outside of the canvas, and (2) no overlap of the block with any previously-placed block is induced. 
- If two placed blocks intersect gridcells of the same row in the _grid_, and the x-spans of the blocks intersect, then the two blocks have _horizontal overlap_. (Note that this definition achieves simplicity at the cost of pessimism - but, the goal is to have a quick-and-dirty packing that feeds evaluation of _loss_.) Then, _vertical overlap_ is similarly defined.

## Loss

_Loss_ is well-defined once all blocks have been legally packed (i.e., placed) into the grid, according to the above process, with no overlap.   

We search for the pair **(n_rows_opt, n_cols_opt)** that satisfies constraints above and minimizes total loss, which is defined as **loss_tot = loss_h + loss_v + loss_2d**. Currently, we are unclear on the definition of the **loss_2d** term and for now do not implement it. (However, we believe this term must somehow be based on the ratio between total "used gridcells" (i.e., having nonzero area of placed macro blocks) and "total gridcells" (i.e., **n_rows** * **n_cols**).)

To evaluate horizontal loss, **loss_h**, we calculate
- **width_tot_blocks** = the sum of widths of all blocks in the design 
- **width_tot__used_gridcells** = the sum of widths of all gridcells in the grid that have nonempty intersection with some placed block

Then, **loss_h = 1 - (width_tot_blocks / width_tot_used_gridcells)**

Vertical loss, **loss_v**, is similarly evaluated.

## Grid Simplification

Once we have found **n_rows_opt** and **n_cols_opt** as described above, we seek a smaller grid that has similar _loss_ properties.
Specifically, we find  values of **n_rows_actual** and **n_cols_actual** such that the above constraints are satisfied, **loss_h_actual + loss_v_actual** is within some _tolerance_ (e.g., 5% or 10%) of the optimal **loss_tot**, and **n_rows_actual * n_cols_actual** is minimized.  This is the grid that is used in Circuit Training.
To our understanding, the foregoing procedure results in grids that are of similar sizes, e.g., with ~25 <= **n_rows_actual** , **n_cols_actual** <= ~40. 

## Thanks
We thank Google engineers for May 19, 2022 discussions that explained the gridding method used in Circuit Training.
All errors of understanding and implementation are the authors'. We will rectify such errors as soon as possible after being made aware of them.

