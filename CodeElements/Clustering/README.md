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

* **How do we perform clustering of standard cells?**  In our Nature paper, we describe how to use hMETIS to cluster standard cells, 
including all necessary settings. For detailed settings, please see Extended Data Table 3 from our [Nature article](https://www.nature.com/articles/s41586-021-03544-w.epdf?sharing_token=tYaxh2mR5EozfsSL0WHZLdRgN0jAjWel9jnR3ZoTv0PW0K0NmVrRsFPaMa9Y5We9O4Hqf_liatg-lvhiVcYpHL_YQpqkurA31sxqtmA-E1yNUWVMMVSBxWSp7ZFFIWawYQYnEXoBE4esRDSWqubhDFWUPyI5wK_5B_YIO-D_kS8%3D). 
Internally, Google pays for a commercial license, but non-commercial entities are welcome to use a free open-source license.


Finally, the Methods section of the [Nature paper](https://www.nature.com/articles/s41586-021-03544-w.epdf?sharing_token=tYaxh2mR5EozfsSL0WHZLdRgN0jAjWel9jnR3ZoTv0PW0K0NmVrRsFPaMa9Y5We9O4Hqf_liatg-lvhiVcYpHL_YQpqkurA31sxqtmA-E1yNUWVMMVSBxWSp7ZFFIWawYQYnEXoBE4esRDSWqubhDFWUPyI5wK_5B_YIO-D_kS8%3D) also explains the provenance of the netlist hypergraph:

* **Synthesis of the input netlist.** We use a commercial tool to synthesize the netlist from RTL. Synthesis is physical-aware, in the sense that it has access to the floorplan size and the locations of the input/output pins, which were informed by inter- and intra-block-level information.


## **II. What *exactly* is the Hypergraph, and how is it partitioned?**
From the above information sources, the description of the [Grouping](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Grouping/README.md) process, and information provided by Google engineers, we are fairly certain of the following.
* (1) Clustering uses the hMETIS partitioner, which is run in “multiway” mode. 
More specifically, hMETIS is **always** invoked with *nparts*=500, with unit vertex weights. 
The hyperparameters given in Extended Data Table 3 of the [Nature paper](https://www.nature.com/articles/s41586-021-03544-w.epdf?sharing_token=tYaxh2mR5EozfsSL0WHZLdRgN0jAjWel9jnR3ZoTv0PW0K0NmVrRsFPaMa9Y5We9O4Hqf_liatg-lvhiVcYpHL_YQpqkurA31sxqtmA-E1yNUWVMMVSBxWSp7ZFFIWawYQYnEXoBE4esRDSWqubhDFWUPyI5wK_5B_YIO-D_kS8%3D) are used. 
(Additionally, Circuit Training explicitly sets reconst=1 and dbglvl=0.)

* (2) The hypergraph that is fed to hMETIS consists **only** of standard cells and “fixed” 
(i.e., specified as monolithic clusters of vertices, using the .fix input file mechanism of hMETIS) groups of standard cells.


Before going further, we provide a **concrete example** for (2).

* Suppose that we have a design with 200,000 standard cells, 100 macros, and 1,000 ports. 

* Furthermore, using terms defined in [Grouping](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Grouping/README.md), suppose 
that each of the 100 macros induces a *group* of 300 standard cells, and that the ports collectively induce 20 *clumps*, 
each of which induces a group of 50 standard cells.

* Then, there will be 100 + 20 = 120 groups, each corresponding to an entry of the .fix file.

* The number of individual standard cells in the hypergraph that is actually partitioned by hMETIS is 200,000 - (100 * 300) - (20 * 50) = 169,000.

* Note: To our understanding, applying hMETIS with *nparts* = 500 to this hypergraph, with 120 entries in the .fix file, 
will partition 169,000 standard cells into 500 - 120 = 380 clusters.  All of the above understanding is in the process of being reconfirmed.


We call readers’ attention to the existence of significant aspects that are still pending clarification here.  
While [Gridding](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Gridding/README.md) and 
[Grouping](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Grouping/README.md) are hopefully well-understood, 
we are still in the process of documenting and implementing such aspects as the following.

* ***Pending clarification #1: Is the output netlist from synthesis modified before it enters (hypergraph clustering and) placement?***
All methodologies that span synthesis and placement (of which we are aware) must make a fundamental decision with respect to the netlist that is produced by logic synthesis, as that netlist is passed on to placement: (A) delete buffers and inverters to avoid biasing the ensuing placement (spatial embedding) with the synthesis tool’s fanout clustering, or (B) leave these buffers and inverters in the netlist to maintain netlist area and electrical rules (load, fanout) sensibility.  We do not yet know Google’s choice in this regard. Our experimental runscripts will therefore support both (A) and (B).

* ***Pending clarification #2: Are large nets ignored in hypergraph clustering (and hence placement)? If so, at what net size threshold?***
All hypergraph partitioning applications in physical design (of which we are aware) perform some kind of thresholding to ignore large hyperedges. 
Our implementation of hypergraph clustering takes a parameter, *net_size_threshold*, and ignores all hyperedges of size greater 
than or equal to *net_size_threshold*. The default value for this parameter is 300.

* ***Pending clarification #3: How does hMETIS with nparts = 500 and a nonempty .fix file create so many standard-cell clusters (soft macros)? What explains the variation in cluster area, given that hMETIS is run with UBfactor = 5?***  For example, the Ariane example data shown in Circuit Training’s [test_data](https://github.com/google-research/circuit_training/tree/main/circuit_training/environment/test_data/ariane) has 799 soft macros, although in practice Ariane synthesizes to only approximately (100K +/- 20K) standard cells along with its 133 hard macros. Furthermore, in the Circuit Training data, it is easy to see that all hard macros have identical dimensions 19.26(h) x 29.355(w), but that the 799 soft macros have dimensions in the range \[0.008 , 14.46\](h) x 10.18(w), implying areas that vary across a ~1500X range.


## **III. Our Implementation of Hypergraph Clustering.**
Our implementation of hypergraph clustering takes the synthesized netlist and a .def file with placed IO ports as input, 
then generates the clustered netlist (in lef/def format) using hMETIS (1998 binary). 
In default mode, our implementation will also run RePlAce in GUI mode automatically to place the clustered netlist. 
We implement the entire flow based on [OpenROAD APIs](https://github.com/the-openroad-project).
**Please refer to [the OpenROAD repo](https://github.com/the-openroad-project) for explanation of each Tcl command.**

We have provided the openroad exe in the [utils](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/CodeElements/Clustering/src/utils) dir. Please note that [The OpenROAD Project](https://github.com/the-openroad-project) does not 
distribute any compiled binaries. While we build our implementation on top of the OpenROAD application, our effort is not associated with the OpenROAD project.


Input file: [setup.tcl](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Clustering/test/setup.tcl) (you can follow the example to set up your own design) and [FixFile](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Clustering/test/fix_files_grouping/ariane.fix.old) (This file is generated by our [Grouping](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/CodeElements/Grouping) scripts)

Output_files: [clusters.lef](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Clustering/test/results/OpenROAD/clusters.lef) and [clustered_netlist.def](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Clustering/test/results/OpenROAD/clustered_netlist.def) for OpenROAD flows; [cluster.tcl](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/Clustering/test/results/Cadence/ariane_cluster_500.tcl) for Cadence flows.

Note that the [example](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/CodeElements/Clustering/test) that we provide is the ariane design implemented in NanGate45. The netlist is synthesized by Yosys, and the floorplan def is generated by OpenROAD.

 
## **Thanks**
 
We thank Google engineers for Q&A in a shared document, as well as live discussions on May 19, 2022, that explained the hypergraph clustering method used in Circuit Training. All errors of understanding and implementation are the authors'. We will rectify such errors as soon as possible after being made aware of them.






