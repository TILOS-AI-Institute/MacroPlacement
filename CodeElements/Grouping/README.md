# Grouping
**Grouping** is a preprocessing step before
[Placement-guided hypergraph clustering (soft macro definition)](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/CodeElements/Clustering).
In this step, each SRAM (hard macro) is clustered along with its immediate fanins and immediate fanouts 
(w.r.t. all of the SRAM's pins) into a "group" that is recorded in the ".fix file".
Similarly, all of the IOs (ports) that are in each row-grid or column-grid of 
the boundary of the layout canvas are put into groups. Each group includes the union 
of immediate fanins and immediate fanouts of the ports that are in that group.
