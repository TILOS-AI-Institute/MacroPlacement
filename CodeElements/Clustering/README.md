# **Hypergraph clustering (soft macro definition)**
**Hypergraph clustering** is, in our view, one of the most crucial undocumented 
portions of Circuit Training. 


## **I. Information provided by Google.**
The Methods section of the [(Nature paper)](https://www.nature.com/articles/s41586-021-03544-w.epdf?sharing_token=tYaxh2mR5EozfsSL0WHZLdRgN0jAjWel9jnR3ZoTv0PW0K0NmVrRsFPaMa9Y5We9O4Hqf_liatg-lvhiVcYpHL_YQpqkurA31sxqtmA-E1yNUWVMMVSBxWSp7ZFFIWawYQYnEXoBE4esRDSWqubhDFWUPyI5wK_5B_YIO-D_kS8%3D) provides the following information.


* “(1) We group millions of standard cells into a few thousand clusters using hMETIS, a partitioning technique based 
on the minimum cut objective. Once all macros are placed, we use an FD method to place the standard cell clusters. 
Doing so enables us to generate an approximate but fast standard cell placement that facilitates policy network optimization.”

* “ **Clustering of standard cells.** To quickly place standard cells to provide a signal to our RL policy, 
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

* “ **Placement of standard cells.** To place standard cell clusters, we use an approach similar to classic FD methods. 
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


