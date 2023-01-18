# Code Elements in Circuit Training

The code elements below are the most crucial undocumented portions of Circuit Training. 
We thank Google engineers for Q&A in a shared document, as well as live discussions on May 19, 2022, 
that have explained aspects of several of the following code elements used in Circuit Training. 
All errors of understanding and implementation are the authors'. 
We will rectify such errors as soon as possible after being made aware of them.
- [Gridding](../../CodeElements/Gridding/) determines a dissection of the layout canvas into some number of rows (*n_rows*) and some number of columns (*n_cols*) of _gridcells_. In Circuit Training, the purpose of gridding is to control the size of the macro placement solution space, 
thus allowing RL to train within reasonable runtimes. Gridding enables hard macros to find locations consistent with high solution quality, while allowing soft macros (standard-cell clusters) to also find good locations. 
- [Grouping](../../CodeElements/Grouping/)  ensures that closely-related standard-cell logic elements,
which connect to the same macro or the same clump of IOs (denoted as an IO cluster), belong to the same standard-cell clusters.
- [Hypergraph clustering](../../CodeElements/Clustering/) clusters millions of standard cells into a few thousand clusters.  In Circuit Training, the purpose of clustering is to enable an approximate but fast standard-cell placement that facilitates policy network optimization.

We are glad to see [grouping (clustering)](https://github.com/google-research/circuit_training/tree/main/circuit_training/grouping) added to the Circuit Training GitHub.
However, these [grouping (clustering)](https://github.com/google-research/circuit_training/tree/main/circuit_training/grouping) scripts still rely on the wrapper functions of plc_client, which is a black box for the community.  In this doc, we document the implementation details of gridding, grouping and clustering. We implement all the code elements from scratch using python scripts, and our code produces results that exactly match those of Circuit Training.


Note that we build our implementation on top of the [OpenROAD](https://github.com/ravi-varadarajan/OpenROAD.git) application. You will need to build your own OpenROAD binary before you can run our scripts.  We also provide the [flow.py](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/CodeFlowIntegration/flow.py), which runs Gridding, Grouping and Hypergraph Clustering in sequence.



## Table of Contents
  - [Gridding](#gridding)
  - [Grouping](#grouping)
  - [Hypergraph Clustering (soft macro definition)](#hypergraph-clustering-soft-macro-definition)


## **Gridding**
In Circuit Training, the purpose of gridding is to control the size of the macro placement solution space, thus allowing RL to train within reasonable
runtimes. Gridding enables hard macros to find locations consistent with high solution quality, while allowing soft macros (standard-cell clusters) to also find good locations.

Gridding determines a dissection of the layout canvas into some number of rows (*n_rows*) and some number of columns (*n_cols*) of _gridcells_.

The choice of *n_rows* and *n_cols* is made **once** for each design.  Once the dimensions *(n_rows, n_cols)* have been chosen, their values define a gridded canvas, or _grid_, and remain fixed throughout Circuit Training for the given design. The detailed algorithm is as follows (Algorithm 1).
<p align="center">
<img src="./images/Gridding Algorithm.png" width= "1600"/>
</p>

The gridding algorithm starts with the dimensions *canvas_width* and *canvas_height* of the layout canvas, as well as a list of *macros*, where each macro has a width and a height. 
Macros are not rotatable. The area of a macro is the product of its width and height.
Then, the gridding searches over combinations (*n_rows*, *n_cols*), with constraints
- *min_n_rows <= n_rows < max_n_rows* 
- *min_n_cols <= n_cols < max_n_cols* 
- *min_num_gridcells <= n_rows * n_cols <= max_num_grid_cells*
- *grid_w / grid_h <= max_aspect_ratio* 
- *grid_h / grid_w <= max_aspect_ratio* 
- The macros can be packed sequentially on the gridcells. There are *n_rows * n_cols* gridcells in the canvas. \[Algorithm 1 Lines 13-27\]

where each gridcell has width of *grid_w = canvas_width / n_cols*
and height of *grid_h = canvas_height / n_row*.
The main idea is to search for a particular (*n_rows*, *n_cols*) combination
that maximizes the metric related to wasted space.


To evaluate *metric* for a given _grid_ (*n_rows*, *n_cols*), 
all macros are packed into the _gridcells_, 
and several terms (*empty_ratio*, *ver_waste* and *hor_waste*)
that reflect wasted space are evaluated.
#### **Packing**
Macro packing is performed as follows \[Algorithm 1 Lines 13-27\]:
- Macros are placed in order of non-increasing macro area.
- All macros are placed, one by one, into the (*n_rows*, *n_cols*) _gridcells_.
If the current macro cannot be placed, then the _grid_ is infeasible and the next
candidate _grid_ is considered.
- A macro is placed at the **first** (according to row-major order) _gridcell_ where it can be legally placed.
- Placement of a macro means placing that macro's center at the center of some _gridcell_.
- The placement of a macro's center at the center of some _gridcell_ is legal if (1) no part of the macro is outside of the canvas, and (2) no overlap of the macro with any previously-placed macro is induced.
#### **Metric**
After macro packing, we can calculate the *empty_ratio* of current _grid_, i.e., 
the number of empty _gridcells_ over the total number of _gridcells_ (*n_rows * n_cols*).
A _gridcell_ is defined to be an empty _gridcell_ if the intersection area of placed macros with it is less than 0.00001 times its area.  
Next, we calculate the *hor_waste* and *ver_waste* as described in following algorithm.
<p align="center">
<img src="./images/Calculate Waste Ratio.png" width= "1600"/>
</p>

To calculate horizontal waste *hor_waste*, we calculate
- *width_tot_macros* = the sum of widths of all macros in the design.
- *width_tot_used_gridcells* = the sum of widths of all used _gridcells_ if we pack the macros along the x-axis one by one.

Then, *hor_waste = 1.0 - width_tot_macros / width_tot_used_gridcells*.

To calculate vertical waste *ver_waste*, we calculate
- *height_tot_macros* = the sum of heights of all macros in the design.
- *height_tot_used_gridcells* = the sum of heights of all used _gridcells_ if we pack the macros along the y-axis one by one.

Then, *ver_waste = 1.0 - height_tot_macros / height_tot_used_gridcells*.

After calculating *empty_ratio*, *hor_waste* and *ver_waste*, the *metric* is defined as
*metric = empty_ratio + 2.0 - hor_waste - ver_waste*.
The _grid_ with best *metric* is noted as *n_rows_opt* and *n_cols_opt*.

#### **Grid Simplification**
Once we have found *n_rows_opt* and *n_cols_opt* as described above \[Algorithm 1 Lines 34-44\], 
we seek a smaller _grid_ that has similar *metric* properties. \[Algorithm 1 Lines 45-54\]  
Specifically, we find values of *n_rows_actual* and *n_cols_actual* such that 
its *metric* is within some tolerance (5\% in Circuit Training) of the optimal *metric*, 
and *n_rows_actual * n_cols_actual* is minimized. 
This is the _grid_ that is used in Circuit Training.
To our understanding, the foregoing procedure results in grids that are of similar sizes, e.g., with ~25 <= *n_rows_actual* , *n_cols_actual* <= ~40. 



## **Grouping**
Grouping is an important preprocessing step of clustering.
The grouping step in Circuit Training requires as inputs:
the post-synthesis gate-level netlist (standard cells and hard macros),
placed IOs (ports, or terminals), typically at the borders of the chip canvas, and
the grid of *n_rows* rows and *n_cols* columns of _gridcells_, which defines the gridded layout canvas.
The purpose of grouping, to our understanding, is to ensure that closely-related standard-cell logic elements, 
which connect to the same macro or the same clump of IOs (denoted as an IO cluster), belong to the same standard-cell clusters.


#### **The Grouping Process**
The grouping consists of three steps:
- Group the macro pins of the same macro into a cluster.
In Circuit Training, the netlist consists of four types of elements: 
standard cells, IO ports, macro pins, and macros.
The following figure shows an example of netlist representation in Circuit Training.
The left part is the real netlist; the right part is the Netlist Protocol Buffer 
representation in Circuit Training. The solid arrows indicate the real signal net and the dashed
arrows indicate the virtual nets between macro A and its macro pins.
We can see that the macro pins and the related macro are both basic elements in the netlist, whereas there are no pins of standard cells.  Thus, it is necessary to group the macros pins of the same macro into a cluster, because the macro pins of the same macro will always stay together during macro placement. Note that only the macro pins are grouped and the macro itself is not grouped. For example, in this figure, **D\[0\]**, **D\[1\]**, **D\[2\]**, **Q\[0\]**,
**Q\[1\]**, **Q\[2\]** are grouped into **cluster_1**, but **cluster_1** does not include macro A.
<p align="center">
<img src="./images/macro_example.png" width= "1600"/>
</p>
<p align="center">
 Figure 1.  Illustration of the netlist representation in Circuit Training.  
</p>

- Group the IOs that are within close proximity of each other, boundary by boundary, 
following the order of **LEFT** <span>&rarr;</span> **TOP** <span>&rarr;</span>  **RIGHT** <span>&rarr;</span> **BOTTOM**. For the **LEFT**/**RIGHT**(**TOP**/**Bottom**) boundary, we sort the all the ports on the boundary based on their y (x) coordinates in a non-decreasing order. Starting from the first IO port on the boundary, we group the IO ports within each *grid_height* (*grid_width*) into an IO cluster. For example, in following figure, we have three IO clusters on the **TOP** boundary and two IO clusters on the **RIGHT** boundary. The *grid_width* and *grid_height* are calculated based on the *n_cols* and *n_rows*:
  - *grid_width = canvas_width / n_cols*
  - *grid_height = canvas_height / n_rows*
<p align="center">
<img src="./images/IO_Groups.png" width= "1600"/>
</p>
<p align="center">
Figure 2.  Illustration of grouping IO ports.  
</p>

- Group the closely-related standard cells,
which connect to the same macro or the same IO cluster.
Suppose that we have a design with 100 clusters of macro pins (i.e., 100 macros) and 20 clusters of IOs.
Before grouping the closely-related standard cells to these clusters of macro pins or IOs,
we assign each cluster a cluster id from 0 to 119.
Then, for each cluster, we traverse the netlist and assign the same cluster id to the "immediate fanins" and "immediate fanouts" of its element (macro pin or IO).
Note that "immediate fanin" is equivalent to "transitive fanins up to level K_in = 1", and that "immediate fanouts" is equivalent to "transitive fanouts up to level K_out = 1".
It is our understanding that both K_in and K_out are always set to a default value of 1 
in Circuit Training. However, other values might be applied. 
In our implementation, we traverse the netlist in a depth-first-search manner.
All the elements (standard cell, macro pin or IO ports) with the same cluster id form a cluster.  Each cluster is recorded in the ".fix file" that is part of the input to the hMETIS hypergraph partitioner when the standard cells are grouped into soft macros. 
The part id of each cluster is the same as its cluster id.
Note that a macro does not belong to any cluster, and thus is not fixed 
when we call the hMETIS hypergraph partitioner.

 
#### **How Groups Are Used**
Each group is recorded in the “.fix file” that is part of the input to the hMETIS hypergraph partitioner when the gate-level netlist is clustered into soft macros.

#### **How Grouping Scripts Are used**
We provide [(an example)](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Grouping/test/test.py) about the usage of our grouping scripts.
Basically, our grouping scripts take the following as inputs: (i) [(setup_file)](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Grouping/test/setup.tcl)
including enablement information (lefs/libs), synthesized gate-level netlist (*.v*), and def file with placed IOs (*.def*); (ii) *n_rows* and *n_cols* determined by the [(Gridding)](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/CodeElements/Gridding) step; (iii) K_in and K_out parameters; and (iv) global_net_threshold for ignoring global nets. If a net has more than global_net_threshold instances, we ignore such this net when we search "transitive" fanins and fanouts. After
running grouping scripts,  you will get the **.fix** file.  


## **Hypergraph clustering (soft macro definition)**
**Hypergraph clustering** is, in our view, one of the most crucial undocumented 
portions of Circuit Training. 

#### **Information provided by Google.**
The Methods section of the [Nature paper](https://www.nature.com/articles/s41586-021-03544-w.epdf?sharing_token=tYaxh2mR5EozfsSL0WHZLdRgN0jAjWel9jnR3ZoTv0PW0K0NmVrRsFPaMa9Y5We9O4Hqf_liatg-lvhiVcYpHL_YQpqkurA31sxqtmA-E1yNUWVMMVSBxWSp7ZFFIWawYQYnEXoBE4esRDSWqubhDFWUPyI5wK_5B_YIO-D_kS8%3D) provides the following information.

* “(1) We group millions of standard cells into a few thousand clusters using hMETIS, a partitioning technique based 
on the minimum cut objective. Once all macros are placed, we use an FD method to place the standard cell clusters. 
Doing so enables us to generate an approximate but fast standard cell placement that facilitates policy network optimization.”

* **“Clustering of standard cells.** To quickly place standard cells to provide a signal to our RL policy, 
we first cluster millions of standard cells into a few thousand clusters. 
There has been a large body of work on clustering for chip netlists. 
As has been suggested in the literature, such clustering helps not only with reducing the problem size, 
but also helps to ‘prevent mistakes’ (for example, prevents timing paths from being split apart). 
We also provide the clustered netlist to each of the baseline methods with which we compare. 
To perform this clustering, we employed a standard open-source library, hMETIS, 
which is based on multilevel hypergraph partitioning schemes with two important phases: 
(1) coarsening phase, and 2) uncoarsening and refinement phase.”

Therefore, at least one purpose of clustering is to enable fast placement of standard cells to 
provide a signal to the RL policy. The Methods section subsequently explains how the clusters 
are placed using a [force-directed](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/FDPlacement/README.md) approach:

* **“Placement of standard cells.** To place standard cell clusters, we use an approach similar to classic FD methods. 
We represent the netlist as a system of springs that apply force to each node, 
according to the weight×distance formula, causing tightly connected nodes to be attracted to one another. 
We also introduce a repulsive force between overlapping nodes to reduce placement density. 
After applying all forces, we move nodes in the direction of their force vector. To reduce oscillations, we set a maximum distance for each move.”



The [Circuit Training FAQ](https://github.com/google-research/circuit_training/blob/main/README.md) adds:

* **"How do we perform clustering of standard cells?**  In our Nature paper, we describe how to use hMETIS to cluster standard cells, 
including all necessary settings. For detailed settings, please see Extended Data Table 3 from our [Nature article](https://www.nature.com/articles/s41586-021-03544-w.epdf?sharing_token=tYaxh2mR5EozfsSL0WHZLdRgN0jAjWel9jnR3ZoTv0PW0K0NmVrRsFPaMa9Y5We9O4Hqf_liatg-lvhiVcYpHL_YQpqkurA31sxqtmA-E1yNUWVMMVSBxWSp7ZFFIWawYQYnEXoBE4esRDSWqubhDFWUPyI5wK_5B_YIO-D_kS8%3D). 
Internally, Google pays for a commercial license, but non-commercial entities are welcome to use a free open-source license."

Finally, the Methods section of the [Nature paper](https://www.nature.com/articles/s41586-021-03544-w.epdf?sharing_token=tYaxh2mR5EozfsSL0WHZLdRgN0jAjWel9jnR3ZoTv0PW0K0NmVrRsFPaMa9Y5We9O4Hqf_liatg-lvhiVcYpHL_YQpqkurA31sxqtmA-E1yNUWVMMVSBxWSp7ZFFIWawYQYnEXoBE4esRDSWqubhDFWUPyI5wK_5B_YIO-D_kS8%3D) also explains the provenance of the netlist hypergraph:

* **"Synthesis of the input netlist.** We use a commercial tool to synthesize the netlist from RTL. Synthesis is physical-aware, in the sense that it has access to the floorplan size and the locations of the input/output pins, which were informed by inter- and intra-block-level information."



#### **What *exactly* is the Hypergraph, and how is it partitioned?**
From the above information sources, the description of the [Grouping](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Grouping/README.md) process, and information provided by Google engineers, we are fairly certain of the following.
* (1) Clustering uses the hMETIS partitioner, which is run in “multiway” mode. 
More specifically, hMETIS is **always** invoked with *npart* more than 500, with unit vertex weights. 
The hyperparameters given in Extended Data Table 3 of the [Nature paper](https://www.nature.com/articles/s41586-021-03544-w.epdf?sharing_token=tYaxh2mR5EozfsSL0WHZLdRgN0jAjWel9jnR3ZoTv0PW0K0NmVrRsFPaMa9Y5We9O4Hqf_liatg-lvhiVcYpHL_YQpqkurA31sxqtmA-E1yNUWVMMVSBxWSp7ZFFIWawYQYnEXoBE4esRDSWqubhDFWUPyI5wK_5B_YIO-D_kS8%3D) are used. 
(Additionally, Circuit Training explicitly sets reconst=1 and dbglvl=0.)

* (2) The hypergraph that is fed to hMETIS consists of macros, macro pins, IO ports, and standard cells.
The "fixed" file generated by [Grouping](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Grouping/README.md) process, is also fed as  .fix input file to hMETIS.


* (3) All hypergraph partitioning applications in physical design (of which we are aware) perform some kind of thresholding to ignore large hyperedges.
Circuit Training ignores all hyperedges of size greater than 500.



Before going further, we provide a **concrete example** for (2).

* Suppose that we have a design with 200,000 standard cells, 100 macros, and 1,000 IO ports. 

* Furthermore, using terms defined in [Grouping](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Grouping/README.md), suppose 
that each of the 100 macros induces a *cluster* of 300 standard cells, and that the IO ports collectively induce 20 *IO clusters*, 
each of which induces a cluster of 50 standard cells.

* Then, there will be 100 + 20 = 120 clusters. Each element (macro pin, IO port or standard cell)
in these clusters corresponds to an entry of the .fix file. The cluster id starts from 0 to 119.

* The number of individual standard cells in the hypergraph that is actually partitioned by hMETIS is 200,000 - (100 * 300) - (20 * 50) = 169,000.

* Suppose that each macro has 64 macro pins. The hypergraph that is actually partitioned by hMETIS has
200,000 + 100 + 1000 + 100 * 64 = 207,500 vertices.  Although there are both macro pins and macros in the hypergraph, all the nets related to macros are connected to macro pins and there are no hyperedges incident to macros. Each hyperedge in the hypergraph corresponds to a net in the netlist. Note that Circuit Training assumes that there is only one output pin for each standard cell, thus there is only one hyperedge {**A**, **B**, **C**, **D**, **E**} for the following case.  
<p align="center">
<img src="./images/net_model.png" width= "600"/>
</p>
<p align="center">
 Figure 3.  Illustration of net model used in Circuit Training.  
</p>
                                     

* *nparts* = 500 + 120 = 620 is used when applying hMETIS to this hypergraph.


#### **Break up clusters that span a distance larger than *breakup_threshold***
After partitioning the hypergraph, we can have *nparts* clusters.
Then Circuit Training breaks up clusters that span a distance larger than *breakup_threshold*.
Here *breakup_threshold = sqrt(canvas_width * canvas_height / 16)*.
For each cluster *c*, the breakup process is as follows:
* *cluster_lx, cluster_ly, cluster_ux, cluster_uy = c.GetBoundingBox()*
*  if ((*cluster_ux - cluster_lx) <= breakup_threshold*) && (*cluster_uy - cluster_ly) <= breakup_threshold*))
    * Return
* *cluster_x, cluster_y = c.GetWeightedCenter()*.  Here the weighted center of cluster *c* is the average location of all the *standard cells* in the cluster, weighted according to their area. 
* use (*cluster_x*, *cluster_y*) as the origin and *breakup_threshold* as the step, to divide the bounding box of *c* into different regions.
* the elements (macro pins, macros, ports and standard cells) in each region form a new cluster.
The following figure shows an example: the left part shows the cluster *c<sub>1</sub>* before the breakup process, and the blue dot is the weighted center of *c<sub>1</sub>*; the right part shows the clusters after the breakup process.  The "center" cluster still has the cluster id of 1.
<p align="center">
<img src="./images/breakup.png" width= "1600"/>
</p>
<p align="center">
Figure 4.  Illustration of breaking up a cluster.  
</p>
Note that since the netlist is generated by physical-aware synthesis, we know the (x, y) coordinate for each instance. This was confirmed in July 2022 by Google, [here](https://github.com/google-research/circuit_training/tree/main/circuit_training/grouping#faq).


#### **Recursively merge small adjacent clusters**
After breaking up clusters which span large distance,  there may be some small clusters with only tens of standard cells.
In this step, Circuit Training recursively merges small clusters to the most adjacent cluster if they are within a certain 
distance *closeness* (*breakup_threshold* / 2.0),  thus reducing number of clusters.  A cluster is defined to be a small cluster 
if the number of elements (macro pins, 
macros, IO ports and standard cells) is less than or equal to *max_num_nodes*, where *max_num_nodes* = *number_of_vertices* // *number_of_clusters_after_breakup* // 4.  The merging process is as following:
* flag = False
* while (flag == False):
   * create adjacency matrix *adj_matrix* where *adj_matrix\[i\]\[j\]* represents the number of connections between cluster *c<sub>i</sub>* and cluster *c<sub>j</sub>*. For example, in the Figure 1, suppose *A*, *B*, *C*, *D* and *E* respectively belong to cluster *c<sub>1</sub>*, ..., *c<sub>5</sub>*, we have *adj_matrix\[1\]\[2\]* = 1, *adj_matrix\[1\]\[3\]* = 1, ...., *adj_matrix\[5\]\[3\]* = 1 and *adj_matrix\[5\]\[4\]* = 1. We want to emphasize that although there are  no hyperedges incident to macros in the hypergraph, *adj_matrix* considers the "virtual" connections between macros and macro pins. That is to say, if a macro and its macros pins belong to different clusters, for example, macro A in cluster *c<sub>1</sub>* and its macro pins in cluster *c<sub>2</sub>*, we have *adj_matrix\[1\]\[2\]* = 1 and *adj_matrix\[2\]\[1\]* = 1.
   * calculate the weighted center for each cluster. (See "Break Up Clusters" above for details.)
   * flag = True
   * for each cluster *c*
      * if *c* is not a small cluster
         * Continue
      * find all the clusters *close_clusters* which are close to *c*, i.e., the Manhattan distance between their weighted centers and the weighted center of *c* is less than or equal to *closeness*
      * if there is no cluster close to *c*
         * Continue
      * find the most adjacent cluster *adj_cluster* of *c* in *close_clusters*, i.e., maximize *adj_matrix\[c\]\[adj_cluster\]*
      * merge *c* to *adj_cluster*
      * if *adj_cluster* is a small cluster
         * flag = False



#### **Pending Clarifications**
We call readers’ attention to the existence of significant aspects that are still pending clarification here.  
While [Gridding](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Gridding/README.md) and 
[Grouping](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Grouping/README.md) are hopefully well-understood, 
we are still in the process of documenting and implementing such aspects as the following.

* ***Pending clarification #1: Is the output netlist from synthesis modified before it enters (hypergraph clustering and) placement?***
All methodologies that span synthesis and placement (of which we are aware) must make a fundamental decision with respect to the netlist that is produced by logic synthesis, as that netlist is passed on to placement: (A) delete buffers and inverters to avoid biasing the ensuing placement (spatial embedding) with the synthesis tool’s fanout clustering, or (B) leave these buffers and inverters in the netlist to maintain netlist area and electrical rules (load, fanout) sensibility.  We do not yet know Google’s choice in this regard. (However, Google's [public Ariane netlist](https://storage.googleapis.com/rl-infra-public/circuit-training/netlist/ariane.circuit_graph.pb.txt.gz) does contain buffers and inverters.) Our experimental runscripts support both (A) and (B).


* **[June 13]** ***Update to Pending clarification #3:*** We are glad to see [grouping (clustering)](https://github.com/google-research/circuit_training/tree/main/circuit_training/grouping) added to the Circuit Training GitHub. The new scripts refer to (x,y) coordinates of nodes in the netlist, which leads to further pending clarifications (noted [here](https://github.com/google-research/circuit_training/issues/25)). The solution space for how the input to hypergraph clustering is obtained has expanded. A first level of options is whether **(A) a non-physical synthesis tool** (e.g., Genus, DesignCompiler or Yosys), or **(B) a physical synthesis tool** (e.g., Genus iSpatial or DesignCompiler Topological (Yosys cannot perform physical synthesis)), is used to obtain the netlist from starting RTL and constraints. In the regime of (B), to our understanding the commercial physical synthesis tools are invoked with a starting .def that includes macro placement. Thus, we plan to also enable a second level of sub-options for determining this macro placement: **(B.1)** use the auto-macro placement result from the physical synthesis tool, and **(B.2)** use a human PD expert (or, [OpenROAD RTL-MP](https://github.com/The-OpenROAD-Project/OpenROAD/tree/master/src/mpl2)) macro placement. We have posted a chronology of progress as we clarify these issues, in [Our Progress](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/Docs/OurProgress). Based on [netlist](https://storage.googleapis.com/rl-infra-public/circuit-training/netlist/ariane.circuit_graph.pb.txt.gz) instance names, we believe that Google Brain used the DC-Topo tool for physical synthesis. 


#### **Our Implementation of Hypergraph Clustering.**
Our implementation of hypergraph clustering takes the synthesized netlist and a .def file with placed IO ports as input, 
then generates the clustered netlist (in lef/def format) using hMETIS (1998 binary). 
In default mode, our implementation will generate the clustered netlist in protocol buffer format and cooresponding plc file.
We implement the entire flow based on [OpenROAD APIs](https://github.com/ravi-varadarajan/OpenROAD.git).
**Please refer to [the OpenROAD repo](https://github.com/ravi-varadarajan/OpenROAD.git) for explanation of each Tcl command.**

Please note that [The OpenROAD Project](https://github.com/ravi-varadarajan/OpenROAD.git) does not 
distribute any compiled binaries. You need to build your own OpenROAD binary before you run our scripts.

Input file: [setup.tcl](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Clustering/test/setup.tcl) (you can follow the example to set up your own design) and [FixFile](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Clustering/test/fix_files_grouping/ariane.fix.old) (This file is generated by our [Grouping](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/CodeElements/Grouping) scripts)

Output_files: the clustered netlist in protocol buffer format and cooresponding plc file.

Note that the [example](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/CodeElements/Clustering/test) that we provide is the ariane design implemented in NanGate45.  The netlist and corresponding def file with placed instances are generated by [Genus iSpatial](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/Flows/NanGate45/ariane133) flow. Here the macro placement is automatically done by the Genus and Innovus tools,
i.e., according to Flow **(B.1)** above.

## **Thanks**
 
We thank Google engineers for Q&A in a shared document, as well as live discussions on May 19, 20

, that explained the hypergraph clustering method used in Circuit Training. All errors of understanding and implementation are the authors'. We will rectify such errors as soon as possible after being made aware of them.

