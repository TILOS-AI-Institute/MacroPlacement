# **Hypergraph clustering (soft macro definition)**
**Hypergraph clustering** is, in our view, one of the most crucial undocumented 
portions of Circuit Training. 


## **I. Information provided by Google.**
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



## **II. What *exactly* is the Hypergraph, and how is it partitioned?**
From the above information sources, the description of the [Grouping](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Grouping/README.md) process, and information provided by Google engineers, we are fairly certain of the following.
* (1) Clustering uses the hMETIS partitioner, which is run in “multiway” mode. 
More specifically, hMETIS is **always** invoked with *npart* more than 500, with unit vertex weights. 
The hyperparameters given in Extended Data Table 3 of the [Nature paper](https://www.nature.com/articles/s41586-021-03544-w.epdf?sharing_token=tYaxh2mR5EozfsSL0WHZLdRgN0jAjWel9jnR3ZoTv0PW0K0NmVrRsFPaMa9Y5We9O4Hqf_liatg-lvhiVcYpHL_YQpqkurA31sxqtmA-E1yNUWVMMVSBxWSp7ZFFIWawYQYnEXoBE4esRDSWqubhDFWUPyI5wK_5B_YIO-D_kS8%3D) are used. 
(Additionally, Circuit Training explicitly sets reconst=1 and dbglvl=0.)

* (2) The hypergraph that is fed to hMETIS consists of macros, macro pins, IO ports and standard cells.
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
200,000 + 100 + 1000 + 100 * 64 = 207, 500 vertices.  Although there are both macro pins and macros in the hypergraph, all the nets related to macros are connected to macro pins and there is no hyperedges related to macros. Each hyperedge in the hypergraph cooresponds to a net in the netlist. Note that Circuit Training assumes that there is only one output pin for each standard cell, thus there is only one hyperedge {**A**, **B**, **C**, **D**, **E**} for the following case.  
<p align="center">
<img src="./net_model.png" width= "600"/>
</p>
<p align="center">
 Figure 1.  Illustration of net model in Circuit Training.  
</p>
                                     

* *nparts* = 500 + 120 = 620 is used when applying hMETIS to this hypergraph.


## **III. Break up clusters that span a distance larger than *breakup_threshold***
After partitioning the hypergraph, we can have *nparts* clusters.
Then Circuit Training break up clusters that span a distance larger than *breakup_threshold*.
Here *breakup_threshold = sqrt(canvas_width * canvas_height / 16)*.
For each cluster *c*, the breakup process is as following:
* *cluster_lx, cluster_ly, cluster_ux, cluster_uy = c.GetBoundingBox()*
*  If ((*cluster_ux - cluster_lx) <= breakup_threshold*) && (*cluster_uy - cluster_ly) <= breakup_threshold*))
    * Return
* *cluster_x, cluster_y = c.GetWeightedCenter()*.  Here the weighted center of cluster *c* is the average location of all the standard cells in the cluster, weighted according to their area. 
* Use (*cluster_x*, *cluster_y*) as the origin and *breakup_threshold* as the step, to divide the bounding box of *c* into different regions.
* The elements (macro pins, macros, ports and standard cells) in each region form a new cluster.
The following figure shows an example: the left part shows the cluster *c<sub>1</sub>* before breakup process and the blue dot is the weighted center of *c<sub>1</sub>*; the right part shows the clusters after breakupup process.  The "center" cluster still has the cluster id of 1.
<p align="center">
<img src="./breakup.png" width= "1600"/>
</p>
<p align="center">
 Figure 2.  Illustration of breaking up a cluster.  
</p>
Note that the netlist is generated by physical-aware synthesis, we know the (x, y) coordinate for each instance. 


## **IV. Recursively merge small adjacent clusters**
After breaking up clusters which span large distance,  there may be some small clusters with only tens of standard cells.
In this step, Circuit Training recursively merges small clusters to the most adjacent cluster if they are within a certain 
distance *closeness* (*breakup_threshold* / 2.0),  thus reducing number of clusters.  A cluster is claimed as a small cluster 
if the number of elements (macro pins, 
macros, IO ports and standard cells) is less than or equal to *max_num_nodes*, where *max_num_nodes* = *number_of_vertices* // *number_of_clusters_after_breakup* // 4.  The merging process is as following:
* flag = True
* While (flag == True):
   * Create adjacency matrix *adj_matrix* where *adj_matrix\[i\]\[j\]* represents the number of connections between cluster *c<sub>i</sub>* and cluster *c<sub>j</sub>*. For example, in the Figure 1, suppose *A*, *B*, *C*, *D* and *E* respectively belong to cluster *c<sub>1</sub>*, ..., *c<sub>5</sub>*, we have *adj_matrix\[1\]\[2\]* = 1, *adj_matrix\[1\]\[3\]* = 1, ...., *adj_matrix\[5\]\[3\]* = 1 and *adj_matrix\[5\]\[4\]* = 1. We want to emphasize that although there is no hyperedges related to macros in the hypergraph, *adj_matrix* considers the "virtual" connections between macros and macro pins. That is to say, if a macro and its macros pins belong to different clusters, for example, macro A in cluster *c<sub>1</sub>* and its macro pins in cluster *c<sub>2</sub>*, we have *adj_matrix\[1\]\[2\]* = 1 and *adj_matrix\[2\]\[1\]* = 1.
   * Calculate the weighted center for each cluster. (see the breakup section for details)
   * For each cluster *c*
      * If *c* is not a small cluster
         * Continue
      * Find all the clusters *close_clusters* which is close to *c*, i.e., the Manhattan distance between their weighted centers and the weighted center of *c* is less than or equal to *closeness*
      * If there is no clusters close to *c*
         * Continue
      * Find the most adjacent cluster *adj_cluster* of *c* in *close_clusters*, i.e., maximize *adj_matrix\[c\]\[adj_cluster\]*
      * Merge *c* to *adj_cluster*
      * If *adj_cluster* is a small cluster
         * flag = False



## **V. Pending Clarifications**
We call readers’ attention to the existence of significant aspects that are still pending clarification here.  
While [Gridding](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Gridding/README.md) and 
[Grouping](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Grouping/README.md) are hopefully well-understood, 
we are still in the process of documenting and implementing such aspects as the following.

* ***Pending clarification #1: Is the output netlist from synthesis modified before it enters (hypergraph clustering and) placement?***
All methodologies that span synthesis and placement (of which we are aware) must make a fundamental decision with respect to the netlist that is produced by logic synthesis, as that netlist is passed on to placement: (A) delete buffers and inverters to avoid biasing the ensuing placement (spatial embedding) with the synthesis tool’s fanout clustering, or (B) leave these buffers and inverters in the netlist to maintain netlist area and electrical rules (load, fanout) sensibility.  We do not yet know Google’s choice in this regard. Our experimental runscripts will therefore support both (A) and (B).


* **[June 13]** ***Update to Pending clarification #3:*** We are glad to see [grouping (clustering)](https://github.com/google-research/circuit_training/tree/main/circuit_training/grouping) added to the Circuit Training GitHub. The new scripts refer to (x,y) coordinates of nodes in the netlist, which leads to further pending clarifications (noted [here](https://github.com/google-research/circuit_training/issues/25)). The solution space for how the input to hypergraph clustering is obtained has expanded. A first level of options is whether **(A) a non-physical synthesis tool** (e.g., Genus, DesignCompiler or Yosys), or **(B) a physical synthesis tool** (e.g., Genus iSpatial or DesignCompiler Topological (Yosys cannot perform physical synthesis)), is used to obtain the netlist from starting RTL and constraints. In the regime of (B), to our understanding the commercial physical synthesis tools are invoked with a starting .def that includes macro placement. Thus, we plan to also enable a second level of sub-options for determining this macro placement: **(B.1)** use the auto-macro placement result from the physical synthesis tool, and **(B.2)** use a human PD expert (or, [OpenROAD RTL-MP](https://github.com/The-OpenROAD-Project/OpenROAD/tree/master/src/mpl2)) macro placement. 


## **VI. Our Implementation of Hypergraph Clustering.**
Our implementation of hypergraph clustering takes the synthesized netlist and a .def file with placed IO ports as input, 
then generates the clustered netlist (in lef/def format) using hMETIS (1998 binary). 
In default mode, our implementation will also run RePlAce in GUI mode automatically to place the clustered netlist. 
We implement the entire flow based on [OpenROAD APIs](https://github.com/the-openroad-project).
**Please refer to [the OpenROAD repo](https://github.com/the-openroad-project) for explanation of each Tcl command.**

We have provided the openroad exe in the [utils](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/CodeElements/Clustering/src/utils) dir. Please note that [The OpenROAD Project](https://github.com/the-openroad-project) does not 
distribute any compiled binaries. While we build our implementation on top of the OpenROAD application, our effort is not associated with the OpenROAD project.


Input file: [setup.tcl](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Clustering/test/setup.tcl) (you can follow the example to set up your own design) and [FixFile](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Clustering/test/fix_files_grouping/ariane.fix.old) (This file is generated by our [Grouping](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/CodeElements/Grouping) scripts)

Output_files: [clusters.lef](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Clustering/test/results/OpenROAD/clusters.lef) and [clustered_netlist.def](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Clustering/test/results/OpenROAD/clustered_netlist.def) for OpenROAD flows; [cluster.tcl](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Clustering/test/results/Cadence/ariane_cluster_500.tcl) for Cadence flows; [ariane.pb.txt](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Clustering/test/results/Protocol_buffer_format/ariane.pb.txt) for clustered netlist in protocol buffer format.

Note that the [example](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/CodeElements/Clustering/test) that we provide is the ariane design implemented in NanGate45.  The netlist and corresponding def file with placed instances are generated by [Genus iSpatial](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/Flows/NanGate45/ariane133) flow. Here the macro placement is automatically done by the Genus and Innovus tools,
i.e., according to Flow **(B.1)** above.

 
## **Thanks**
 
We thank Google engineers for Q&A in a shared document, as well as live discussions on May 19, 2022, that explained the hypergraph clustering method used in Circuit Training. All errors of understanding and implementation are the authors'. We will rectify such errors as soon as possible after being made aware of them.






