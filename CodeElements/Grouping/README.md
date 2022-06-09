# **Grouping**
The grouping step in Circuit Training requires as inputs:
the post-synthesis gate-level netlist (standard cells and hard macros)
placed IOs (ports, or terminals), typically at the borders of the chip canvas
the grid of n_rows rows and n_cols columns of gridcells, which defines the gridded layout canvas
The purpose of grouping, to our understanding, is to ensure that closely-related logic is kept close to hard macros and to clumps of IOs. The clumps of IOs are induced by IO locations with respect to the row and column coordinates in the gridded layout canvas.
   The Grouping Process
In the Circuit Training approach, a given SRAM’s immediate fanins and immediate fanouts (with respect to all of the SRAM’s pins) comprise a group. One group is created for each SRAM in the design.

Then, all of the IOs (ports) that are in each row-grid or column-grid of the boundary of the layout canvas are put into clumps.  There is one clump for each row-grid or column-grid of the boundary that contains at least one IO. A group is then comprised of the union of immediate fanins and immediate fanouts of a given clump. 

Note that “immediate fanins” is equivalent to “transitive fanins up to level Kin = 1”, and that “immediate fanouts” is equivalent to “transitive fanouts up to level Kout = 1”. It is our understanding that both Kin and Kout are always set to a default value of 1 in Circuit Training. However, other values might be applied.
   A Simple “Cartoon”
The following cartoon was recently provided by a Google engineer to explain the grouping process. In the cartoon, there are three rows and four columns of gridcells. There are also three clumps of IOs and two hard macros. As a result, in the cartoon we see a total of five groups. To our understanding, a given SRAM hard macro is not part of the group (of standard cells) that it induces.  And, a given clump of (placed, fixed) IO ports is not part of the group (of standard cells) that it induces. 

 
## **How Groups Are Used**
Each group is recorded in the “.fix file” that is part of the input to the hMETIS hypergraph partitioner when the gate-level netlist is clustered into soft macros.

# Thanks
We thank Google engineers for Q&A in a shared document, as well as live discussions on May 19, 2022, that explained the grouping method used in Circuit Training. All errors of understanding and implementation are the authors'. We will rectify such errors as soon as possible after being made aware of them.



