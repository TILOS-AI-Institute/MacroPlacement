# Force-directed placement
**Force-directed placement** is used to place center of standard cell clusters onto
the center of the grid cells.

## **Information provided by Google.**
The Methods section of the [Nature paper](https://www.nature.com/articles/s41586-021-03544-w.epdf?sharing_token=tYaxh2mR5EozfsSL0WHZLdRgN0jAjWel9jnR3ZoTv0PW0K0NmVrRsFPaMa9Y5We9O4Hqf_liatg-lvhiVcYpHL_YQpqkurA31sxqtmA-E1yNUWVMMVSBxWSp7ZFFIWawYQYnEXoBE4esRDSWqubhDFWUPyI5wK_5B_YIO-D_kS8%3D) provides the following information.

* “(1) We group millions of standard cells into a few thousand clusters using hMETIS, a partitioning technique based 
on the minimum cut objective. Once all macros are placed, we use an FD method to place the standard cell clusters. 
Doing so enables us to generate an approximate but fast standard cell placement that facilitates policy network optimization.”

* “We discretize the grid to a few thousand grid cells and place the centre of macros and standard cell clusters onto the centre of the grid cells.”

* **“Placement of standard cells.** To place standard cell clusters, we use an approach similar to classic FD methods. 
We represent the netlist as a system of springs that apply force to each node, 
according to the weight×distance formula, causing tightly connected nodes to be attracted to one another. 
We also introduce a repulsive force between overlapping nodes to reduce placement density. 
After applying all forces, we move nodes in the direction of their force vector. To reduce oscillations, we set a maximum distance for each move.”

For each pair of nodes $(u, v)$, there are two types of forces between them : attractive force $f_a(u,v)$ and repulsive force $f_r(u,v)$. The magnitude of attractive force can be expressed as $f_a(u, v) = k_a * distance(u, v)$, where $k_a$ is the attractive factor and $distance$ is the euclidean distance between node $u$ and node $v$; the magnitude of repulsive force can be expressed as $f_r(u, v) = k_r$.  Both attracive force and repulsive force are along the straight line joining the node $u$ and node $v$.

During force-directed placement, all the hard macros and IO ports are fixed. Only the stanard-cell clusters can be moved.  Note that we need to consider the contribution from hard macros and IO ports when we calculate the total force exerted on a standard-cell cluster.  

The standard-cell clusters are not placed onto the centers of gridcells.










