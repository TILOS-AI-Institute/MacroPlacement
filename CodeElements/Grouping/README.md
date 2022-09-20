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
<img src="./macro_example.png" width= "1600"/>
As shown in above figure, the macro pins and the related macro are both basic elements in the netlist, whereas there is no pins of standard cells.  Thus, it's necessary to group the macros pins of the same macro into a cluster, because the macro pins of the same macro will always stay together during macro placement. Note that only the macro pins are grouped and the macro itself is not grouped. For example, in above figure, **D[0]**, **D[1]**, **D[2]**, **Q[0]**,
**Q[1]**, **Q[2]** are grouped into **cluster_1**, but **cluster_1** does not include macro A.


- Group the IOs that are within close proximity of each other boundary by boundary, 
following the order of **LEFT** &rarr **TOP**  &#8595  **RIGHT** &#8595 **BOTTOM**. 
For the **LEFT**/**RIGHT**(**TOP**/**Bottom**) boundary, 
we sort the all the ports on the boundary based on their
y (x) coordinates in a non-decreasing order. 
Starting from the first IO port on the boundary, we group
the IO ports within each **grid_height** (**grid_width**) into an IO cluster. 
For example, in following figure, 
we have three IO clusters on **TOP** boundary and two IO clusters on **RIGHT** boundary. 
<img src="./IO_Groups.png" width= "1600"/>
The **grid_width** and **grid_height** are calculated based on the **n_cols** and **n_rows**:
-- **grid_width** = **canvas_width** / **n_cols**
-- **grid_height** = **canvas_height** / **n_rows**


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



