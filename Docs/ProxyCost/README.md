# Proxy Cost Computation in Circuit Training
In Circuit Training, *proxy cost* is the weighted sum of wirelength, density, and congestion costs. It is used to determine the overall quality of the macro placement solution. 

$$
Proxy Cost = W_{wirelength} \times Cost_{wirelength} + W_{density} \times Cost_{density} + W_{congestion} \times Cost_{congestion} 
$$ 
  
Where $W_{wirelength}$, $W_{density}$ and $W_{congestion}$ are the weights. From the [Circuit Training repo](https://github.com/google-research/circuit_training/blob/9e7097fa0c2a82030f43b298259941fc8ca6b7ae/circuit_training/environment/environment.py#L61-L65), we found that $W_{wirelength} = 1$, $W_{density} = 1$, and $W_{congestion} = 0.5$. From communication with Google engineers, we learned that in their internal flow, they use $W_{wirelength} = 1$, $W_{density} = 0.5$, and $W_{congestion} = 0.5$.

CircuitTraining repo provides the plc_wrapper_main binary to compute these cost functions. There is no available detailed description, or open-source implementation, of these cost functions. With feedback and confirmations from Google engineers, we have implemented all three cost functions; the source code is available [here](../../CodeElements/Plc_client/plc_client_os.py). In the following section we provide a detailed description of the implementation of these cost functions.

## Table of Content
  - [Wirelength cost computation:](#wirelength-cost-computation)
  - [Density cost computation:](#density-cost-computation)
  - [Congestion cost computation:](#congestion-cost-computation)

## Wirelength cost computation
The wirelength cost function depends on the net (bounding box) half-perimeter wirelength (HPWL). So, first we describe steps to compute HPWL of a net – and then we compute the wirelength cost.  

##### **Procedure to compute net HPWL**
1. Initialize $x_{min} = float_{max}$, $y_{min} = float_{max}$, $x_{max} = 0$, $y_{max} = 0$
2. For each $node$ in net
   1. $x_{min} = min(x_{min}, node \rarr x)$, $y_{min} = min(y_{min}, node \rarr y)$
   2. $x_{max} = max(x_{max}, node \rarr x)$, $y_{max} = max(y_{max}, node \rarr y)$
3. net_hpwl = $(x_{max} - x_{min}) + (x_{max} + x_{min})$
  
A protobuf netlist consists of different types of $node$s. Different possible types of $node$s are macro, standard cell, macro pin and port. A net consists of one source $node$ and one or more sink $node$s. A net can have only standard cell, macro pin and port as its source or sink $node$s. In the following wirelength cost computation procedure, we use the term net weight, which is the weight of the source $node$ of the net. This weight indicates the total number of connections between the source and each sink $node$.  

##### **Procedure to compute wirelength cost**
1. $hpwl = 0$, $net_{count} = 0$
2. For each $net$
   1. Compute $net_{hpwl}$ using the previous procedure
   2. $hpwl += net \rarr weight \times net_{hpwl}$
   3. $net_{count} += net \rarr weight$
3. $Cost_{wirelength} = \frac{hpwl}{net_{count} \times (canvas_{height} + canvas_{width})}$

In the above procedure, $canvas_{height}$ is the height of the canvas and $canvas_{width}$ is the width of the canvas.

## Density cost computation
Density cost function depends on the gridcell density. So, first we describe the steps to compute gridcell density – and then we compute the density cost.

The gridcell density of grid (i, j) is the ratio of the summation of all the overlapped areas (the common area between the node and the grid) of standard cell and macro nodes with the grid (i, j) to the total gridcell area.

##### **Procedure to compute density cost**
1. $n =$ number of rows $\times$ number of columns
2. $k = floor(n \times 0.1)$
3. if $k == 0$
   1. $k = 1$
4. $Cost_{density} =$ (average density of top $k$ densest gridcells) $\times 0.5$

Notice that 0.5 is not the “weight” of this cost function, but simply another factor applied besides the weight factor from the cost function. Google engineers informed us “ the 0.5 is there to correct the [bloating of the std cell clusters](https://github.com/google-research/circuit_training/blob/9e7097fa0c2a82030f43b298259941fc8ca6b7ae/circuit_training/grouping/grouping.py#L370)”.


## Congestion cost computation
We divide the congestion cost computation into six sub-stages:
1. [Compute horizontal and vertical congestion of each grid due to net routing.](#computation-of-grid-congestion-due-to-net-routing)
2. Apply smoothing only to grid congestion due to net routing.
3. Compute congestion of each grid due to macros. When a module overlaps with multiple gridcells, if any part of the module partially overlaps with the gridcell (either vertically, or horizontally), we set the top row (if vertical) or right column (if horizontal) to 0. 
4. **Grid horizontal congestion** = horizontal congestion due to macros + horizontal congestion due to net routing after smoothing. 
5. **Grid vertical congestion** = vertical congestion due to macros + vertical congestion due to net routing after smoothing.
6. Finally, we concatenate the **Grid horizontal congestion** array and the **Grid vertical congestion** array and take the average of the top **5**% of the concatenated list.
  
### Computation of grid congestion due to net routing
We divide this problem into three sub-problems.
1. Congestion due to two-pin nets.
2. Congestion due to three-pin nets.
3. Congestion due to multi-pin nets where the number of pins is greater than three.

A grid location $(i, j)$ is the intersection of the $i^{th}$ column with the $j^{th}$ row.

For these three problems we consider that the horizontal routing cost due to a net-segment from $(i, j)$ grid to $(i+1, j)$ grid applies only to the grid $(i, j)$. Similarly the vertical routing cost due to a net-segment from $(i, j)$ grid to $(i, j+1)$ grid applies only to the grid $(i, j)$. Here the direction of the net does not matter. 

Now we compute the congestion due to different nets:
#### *Congestion due to two-pin nets*
Two-pin net routing depends on the source and sink node. Consider 
1. Source node is $(i_1, j_1)$
2. Sink node is $(i_2, j_2)$

##### **Procedure for congestion computation due to two-pin nets**
1. $i_{min} = min(i_1, i_2)$, $i_{max} = max(i_1, i_2)$
2. $w =$ net weight
3. Add horizontal congestion cost (considering weight $w$) due this net to grids from $(i_{min}, j_1)$ to $(i_{max}-1, j_1)$.
4. $j_{min} = min(j_1, j_2)$, $j_{max} = max(j_1, j_2)$
5. Add vertical congestion cost (considering weight $w$) due to this net to grids from $(i_2, j_{min})$ to $(i_2, j_{max} - 1)$.
  
In the following figure P2 is the source pin and P1 is the sink pin of the net. When the arrow crosses the top edge of the grid cell it contributes to the vertical congestion cost of the grid cell and when it crosses the right edge of the grid cell it contributes to the horizontal congestion cost of the grid cell.
  
<p align="center">
<img width="600" src="./images/image14.png" alg="TwoPin1">
</p>

#### *Congestion due to three-pin nets*
The Congestion cost of three-pin nets does not change when the locations of the pins are interchanged.
  
In the following figure, P3 is the source and P1 and P2 are the sinks. We see that interchanging the position does not change the route.

<p align="center">
<img width="600" src="./images/image13.png" alg="ThreePin1">
</p>
<p align="center">
<img width="600" src="./images/image10.png" alg="ThreePin2">
</p>
<p align="center">
<img width="600" src="./images/image7.png" alg="ThreePin3">
</p>

Consider the three pin locations are $(i_1, j_1)$, $(i_2, j_2)$ and $(i_3, j_3)$.
We compute congestion due to three-pins using two functions:
1. $L_{routing}$
2. $T_{routing}$

In the below function all congestion cost computation takes into account the weight.

First we describe these two functions and then we describe how the congestion due to three pin nets are computed.
##### **Congestion cost update using $L_{routing}$:**
The inputs are three pin grid id and net weight. We consider pin grids are  $(i_1, j_1)$, $(i_2, j_2)$ and $(i_3, j_3)$ where $i_1 < i_2 < i_3$ and $(j_1 < j_2 < j_3)$ or $(j_1 > j_2 > j_3)$.
1. Add horizontal congestion cost due to the net to grids from $(i_1, j_1)$ to $(i_2-1, j_1)$
2. Add horizontal congestion cost due to the net to grids from $(i_2, j_2)$ to $(i_3-1, j_2)$
3. Add vertical congestion cost due to the net to grids from $(i_2, min(j_1, j_2))$ to $(i_2, max(j_1, j_2) - 1)$.
4. Add vertical congestion cost due to the net to grids from $(i3, min(j_2, j_3))$ to $(i_3, max(j_2, j_3) - 1)$.

##### **Congestion cost update using $T_{routing}$:**
The inputs are three pin grid id and net weight. We consider pin grids as $(i_1, j_1)$, $(i_2, j_2)$ and $(i_3, j_3)$ where $(j_1 <= j_2 <= j_3 )$ or $(j_1 >= j_2 >= j_3)$.
1. $i_{min} = min(i_1, i_2, i_3)$, $i_{max} = max(i_1, i_2, i_3)$
2. Add horizontal congestion cost due to the net to grids from $(i_{min}, j_2)$ to $(i_{max} - 1, j_2)$.
3. Add vertical congestion cost due to the net to the grid from $(i_1, min(j_1, j_2))$ to $(i_1, max(j_1, j_2) - 1)$.
4. Add vertical congestion cost due to the net to the grid from $(i_3, min(j_2, j_3))$ to $(i_3, max(j_2, j_3) - 1)$.

##### **Procedure congestion cost computation due to three-pin nets:**
The inputs are three pin grid locations and the net weight.
1. Sort the pin based on the column. After sorting pin locations are $(i_1, j_1)$, $(i_2, j_2)$ and $(i_3, j_3)$. As it is sorted based on column $i_1 <= i_2 <= i_3$.
2. If $i_1 < i_2$ and $i_2 < i_3$ and $min(j_1, j_3) < j_2$ and $max(j_1, j_3) > j_2$:
   1. Update congestion cost using $L_{routing}$.
   2. Return.
3. If $i_2 == i_3$ and $i_1 < i_2$ and $j_1 < min(j_2, j_3)$:
   1. Add horizontal congestion cost due to the net to grids from $(i_1, j_1)$ to $(i_2-1, j_1)$
   2. Add vertical congestion cost due to the net to grids from $(i_2, j_1)$ to $(i_2, max(j_2, j_3) -1)$
   3. Return.
4. If $j_2 == j_3$:
   1. Add horizontal congestion cost due to the net to grids from $(i_1, j_1)$ to $(i_2 -1, j_1)$
   2. Add horizontal congestion cost due to the net to grids from $(i_2, j_2)$ to $(i_3 -1, j_2)$
   3. Add vertical congestion cost due to the net to grids from $(i_2, min(j_2, j_3))$ to $(i_2, max(j_2, j_3) - 1)$.
   4. Return
5. Update congestion cost using $T_{routing}$.


The following four figures represent the four cases mentioned in the above procedure from point two to point five.

<p align="center">
<img width="300" src="./images/image9.png" alg="ThreePin4">
</p>

<p align="center">
Figure corresponding to point two.
</p>

<p align="center">
<img width="300" src="./images/image5.png" alg="ThreePin5">
</p>

<p align="center">
Figure corresponding to point three.
</p>

<p align="center">
<img width="300" src="./images/image4.png" alg="ThreePin6">
</p>

<p align="center">
Figure corresponding to point four.
</p>

<p align="center">
<img width="300" src="./images/image11.png" alg="ThreePin7">
</p>

<p align="center">
Figure corresponding to point five.
</p>

#### *Congestion due to multi-pin nets where the number of pins is greater than three*
1. Consider the net is a n-pin net where $n > 3$. 
2. We break this net into n-1 two pin nets where the source node is the common node.
3. For each two pin nets we update congestion values.

#### *Computation for Smoothing:*
1. **Congestion smoothing = 0.0**
   1. Return the grid congestion that is due to net routing: no smoothing is applied.
2. **Congestion smoothing > 0.0 = k** (k is an integer; both CT and our code appear to use the floor of any non-integer smoothing value)
   1. Take grid congestion due to net routing
   2. For horizontal grid congestion
      1. For each gridcell
         1. If not out-of-bound, take k gridcells on each side (left/right), divide the current cell entry by the total number of gridcells taken and add the value to the corresponding gridcell.
   3. For vertical grid congestion
      1. For each gridcell
         1. If not out-of-bound, take k gridcells on each side (up/down), divide the current cell entry by the total number of gridcells taken and add the value to the corresponding gridcell.
   4. For example, suppose that smoothing = 2 (default value), and we apply it to horizontal grid congestion in four rows of gridcells with respect to the red gridcell highlighted in each row. Then, the blue gridcells in each row show the numbers of gridcells that we divide by (respectively from the top row to the bottom row:  3, 4, 5, 4) when smoothing congestion.

<p align="center">
<img width="300" src="./images/image3.png" alg="CongestionSmooth1">
</p>

#### *Computation for Macro Congestion:*
- For each soft macro + hard MACRO:
   - For each gridcell it overlaps with:
      - For both horizontal and vertical macro routing congestion map:
         1. Find the dimension of overlap, multiply by macro routing allocation
         2. Divide by (the grid_cell dimension multiplied by routing per micron)
         3. Add to the corresponding gridcell

- Example:
  - Given a single hard macro HM_1 (pink rectangle in the figure below), we have two pins instantiated on the top-right and bottom-left, driven by the ports at “P_1” located at the bottom-left of the canvas.

<p align="center">
<img width="300" src="./images/image8.png" alg="MacroCongestion1">
</p>
<p align="center">
<img width="300" src="./images/image6.png" alg="MacroCongestion2">
</p>
<p align="center">
<img width="300" src="./images/image12.png" alg="MacroCongestion3">
</p>

  - Whenever there are gridcells partially overlapped, whether in horizontal or vertical direction, we set the vertical congestion of the top gridcells to 0 (if partially overlapped vertically) and we set the horizontal congestion of the right gridcells to 0 (if partially overlapped horizontally).

#### *Computation of the final congestion cost:*
- Adding the Macro allocation congestion and Net routing congestion together for both Vertical and Horizontal congestion map
- Concat both vertical and horizontal congestion maps together.
- Take the top **5**% of the most congested gridcells **in the concatenation**, and average them out to get the final congestion cost. 