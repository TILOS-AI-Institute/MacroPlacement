# Proxy Cost Computation in Circuit Training
In Circuit Training, *proxy cost* is the weighted sum of wirelength, density, and congestion costs. It is used to determine the overall quality of the macro placement solution. 

<p align="center">
<b>Proxy Cost = W<sub>wirelength</sub> <span>&times;</span> Cost<sub>wirelength</sub> + W<sub>density</sub> <span>&times;</span> Cost<sub>density</sub> + W<sub>congestion</sub> <span>&times;</span> Cost<sub>congestion</sub></b>
</p>
 
Where <b>W<sub>wirelength</sub></b>, <b>W<sub>density</sub></b> and <b>W<sub>congestion</sub></b> are the weights. From the [Circuit Training repo](https://github.com/google-research/circuit_training/blob/9e7097fa0c2a82030f43b298259941fc8ca6b7ae/circuit_training/environment/environment.py#L61-L65), we found that <b>W<sub>wirelength</sub> = 1</b>, <b>W<sub>density</sub> = 1</b>, and <b>W<sub>congestion</sub> = 0.5</b>. From communication with Google engineers, we learned that in their internal flow, they use <b>W<sub>wirelength</sub> = 1</b>, <b>W<sub>density</sub> = 0.5</b>, and <b>W<sub>congestion</sub> = 0.5</b>.

Circuit Training repo provides the plc_wrapper_main binary to compute these cost functions. There is no available detailed description, or open-source implementation, of these cost functions. With feedback and confirmations from Google engineers, we have implemented all three cost functions; the source code is available [here](../../CodeElements/Plc_client/plc_client_os.py). In the following section we provide a detailed description of the implementation of these cost functions.

## Table of Content
  - [Wirelength cost computation](#wirelength-cost-computation)
  - [Density cost computation](#density-cost-computation)
  - [Congestion cost computation](#congestion-cost-computation)

## Wirelength cost computation
The wirelength cost function depends on the net (bounding box) half-perimeter wirelength (HPWL). So, first we describe steps to compute HPWL of a net – and then we compute the wirelength cost.  

##### **Procedure to compute net HPWL**
1. Initialize <b>x<sub>min</sub> = float<sub>max</sub></b>, <b>y<sub>min</sub> = float<sub>max</sub></b>, <b>x<sub>max</sub> = 0</b>, <b>y<sub>max</sub> = 0</b>
2. For each <b>node</b> in net
   1. <b>x<sub>min</sub> = min(x<sub>min</sub>, node&rarr;x)</b>, <b>y<sub>min</sub> = min(y<sub>min</sub>, node&rarr;y)</b>
   2. <b>x<sub>max</sub> = max(x<sub>max</sub>, node&rarr;x)</b>, <b>y<sub>max</sub> = max(y<sub>max</sub>, node&rarr;y)</b>
3. <b>net<sub>hpwl</sub> = (x<sub>max</sub> - x<sub>min</sub>) + (y<sub>max</sub> - y<sub>min</sub>)</b>
  
A protobuf netlist consists of different types of <b>node</b>s. Different possible types of <b>node</b>s are macro, standard cell, macro pin and port. A net consists of one source <b>node</b> and one or more sink <b>node</b>s. A net can have only standard cell, macro pin and port as its source or sink <b>node</b>s. In the following wirelength cost computation procedure, we use the term net weight, which is the weight of the source <b>node</b> of the net. This weight indicates the total number of connections between the source and each sink <b>node</b>.  

##### **Procedure to compute wirelength cost**
1. <b>hpwl = 0</b>, <b>net<sub>count</sub> = 0</b>
2. For each <b>net</b>
   1. Compute <b>net<sub>hpwl</sub></b> using the previous procedure
   2. <b>hpwl += net&rarr;weight <span>&times;</span> net<sub>hpwl</sub></b>
   3. <b>net<sub>count</sub> += net&rarr;weight</b>
3. <b>Cost<sub>wirelength</sub> = hpwl &#8260; [net<sub>count</sub> <span>&times;</span> (canvas<sub>height</sub> + canvas<sub>width</sub>)]</b>

In the above procedure, <b>canvas<sub>height</sub></b> is the height of the canvas and <b>canvas<sub>width</sub></b> is the width of the canvas.

## Density cost computation
Density cost function depends on the gridcell density. So, first we describe the steps to compute gridcell density – and then we compute the density cost.

The gridcell density of grid (i, j) is the ratio of the summation of all the overlapped areas (the common area between the node and the grid) of standard cell and macro nodes with the grid (i, j) to the total gridcell area.

##### **Procedure to compute density cost**
1. <b>n =</b> number of rows <b><span>&times;</span></b> number of columns
2. <b>k = floor(n <span>&times;</span> 0.1)</b>
3. if <b>k == 0</b>
   1. <b>k = 1</b>
4. <b>Cost<sub>density<sub> =</b> (average density of top <b>k</b> densest gridcells) <b><span>&times;</span> 0.5</b>

Notice that **0.5** is not the “**weight**” of this cost function, but simply another factor applied besides the weight factor from the cost function. Google engineers informed us “ the 0.5 is there to correct the [bloating of the std cell clusters](https://github.com/google-research/circuit_training/blob/9e7097fa0c2a82030f43b298259941fc8ca6b7ae/circuit_training/grouping/grouping.py#L370)”.


## Congestion cost computation
We divide the congestion cost computation into six sub-stages:
1. [Compute horizontal and vertical congestion of each grid due to net routing.](#computation-of-grid-congestion-due-to-net-routing)
2. [Apply smoothing only to grid congestion due to net routing.](#computation-for-smoothing)
3. [Compute congestion of each grid due to macros.](#computation-for-macro-congestion)
4. **Grid horizontal congestion** = horizontal congestion due to macros + horizontal congestion due to net routing after smoothing. 
5. **Grid vertical congestion** = vertical congestion due to macros + vertical congestion due to net routing after smoothing.
6. [Finally, we concatenate the **Grid horizontal congestion** array and the **Grid vertical congestion** array and take the average of the top **5**% of the concatenated list.](#computation-of-the-final-congestion-cost)
  
### Computation of grid congestion due to net routing
We divide this problem into three sub-problems.
1. [Congestion due to two-pin nets.](#congestion-due-to-two-pin-nets)
2. [Congestion due to three-pin nets.](#congestion-due-to-three-pin-nets)
3. [Congestion due to multi-pin nets where the number of pins is greater than three.](#congestion-due-to-multi-pin-nets-where-the-number-of-pins-is-greater-than-three)

A grid location <b>(i, j)</b> is the intersection of the <b>i<sup>th</sup></b> column with the <b>j<sup>th</sup></b> row.

For these three problems we consider that the horizontal routing cost due to a net-segment from <b>(i, j)</b> grid to <b>(i+1, j)</b> grid applies only to the grid <b>(i, j)</b>. Similarly the vertical routing cost due to a net-segment from <b>(i, j)</b> grid to <b>(i, j+1)</b> grid applies only to the grid <b>(i, j)</b>. Here the direction of the net does not matter. 

Now we compute the congestion due to different nets:
#### *Congestion due to two-pin nets*
Two-pin net routing depends on the source and sink node. Consider 
1. Source node is <b>(i<sub>1</sub>, j<sub>1</sub>)</b>
2. Sink node is <b>(i<sub>2</sub>, j<sub>2</sub>)</b>

##### **Procedure for congestion computation due to two-pin nets**
1. <b>i<sub>min</sub> = min(i<sub>1</sub>, i<sub>2</sub>)</b>, <b>i<sub>max</sub> = max(i<sub>1</sub>, i<sub>2</sub>)</b>
2. <b>w = net<span>&rarr;</span>weight</b>
3. Add horizontal congestion cost (considering weight <b>w</b>) due this net to grids from <b>(i<sub>min</sub>, j<sub>1</sub>)</b> to <b>(i<sub>max</sub>-1, j<sub>1</sub>)</b>.
4. <b>j<sub>min</sub> = min(j<sub>1</sub>, j<sub>2</sub>)</b>, <b>j<sub>max</sub> = max(j<sub>1</sub>, j<sub>2</sub>)</b>
5. Add vertical congestion cost (considering weight <b>w</b>) due to this net to grids from <b>(i<sub>2</sub>, j<sub>min</sub>)</b> to <b>(i<sub>2</sub>, j<sub>max</sub> - 1)</b>.
  
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

Consider the three pin locations are <b>(i<sub>1</sub>, j<sub>1</sub>)</b>, <b>(i<sub>2</sub>, j<sub>2</sub>)</b> and <b>(i<sub>3</sub>, j<sub>3</sub>)</b>.
We compute congestion due to three-pins using two functions:
1. <b>L<sub>routing</sub></b>
2. <b>T<sub>routing</sub></b>

In the below function all congestion cost computation takes into account the weight.

First we describe these two functions and then we describe how the congestion due to three pin nets are computed.
##### **Congestion cost update using <b>L<sub>routing</sub></b>:**
The inputs are three pin grid id and net weight. We consider pin grids are  <b>(i<sub>1</sub>, j<sub>1</sub>)</b>, <b>(i<sub>2</sub>, j<sub>2</sub>)</b> and <b>(i<sub>3</sub>, j<sub>3</sub>)</b> where <b>i<sub>1</sub> < i<sub>2</sub> < i<sub>3</sub></b> and <b>(j<sub>1</sub> < j<sub>2</sub> < j<sub>3</sub>)</b> or <b>(j<sub>1</sub> > j<sub>2</sub> > j<sub>3</sub>)</b>.
1. Add horizontal congestion cost due to the net to grids from <b>(i<sub>1</sub>, j<sub>1</sub>)</b> to <b>(i<sub>2</sub>-1, j<sub>1</sub>)</b>
2. Add horizontal congestion cost due to the net to grids from <b>(i<sub>2</sub>, j<sub>2</sub>)</b> to <b>(i<sub>3</sub>-1, j<sub>2</sub>)</b>
3. Add vertical congestion cost due to the net to grids from <b>(i<sub>2</sub>, min(j<sub>1</sub>, j<sub>2</sub>))</b> to <b>(i<sub>2</sub>, max(j<sub>1</sub>, j<sub>2</sub>) - 1)</b>.
4. Add vertical congestion cost due to the net to grids from <b>(i<sub>3</sub>, min(j<sub>2</sub>, j<sub>3</sub>))</b> to <b>(i<sub>3</sub>, max(j<sub>2</sub>, j<sub>3</sub>) - 1)</b>.

##### **Congestion cost update using <b>T<sub>routing</sub></b>:**
The inputs are three pin grid id and net weight. We consider pin grids as <b>(i<sub>1</sub>, j<sub>1</sub>)</b>, <b>(i<sub>2</sub>, j<sub>2</sub>)</b> and <b>(i<sub>3</sub>, j<sub>3</sub>)</b> where <b>(j<sub>1</sub> <= j<sub>2</sub> <= j<sub>3</sub> )</b> or <b>(j<sub>1</sub> >= j<sub>2</sub> >= j<sub>3</sub>)</b>.
1. <b>i<sub>min</sub> = min(i<sub>1</sub>, i<sub>2</sub>, i<sub>3</sub>)</b>, <b>i<sub>max</sub> = max(i<sub>1</sub>, i<sub>2</sub>, i<sub>3</sub>)</b>
2. Add horizontal congestion cost due to the net to grids from <b>(i<sub>min</sub>, j<sub>2</sub>)</b> to <b>(i<sub>max</sub> - 1, j<sub>2</sub>)</b>.
3. Add vertical congestion cost due to the net to the grid from <b>(i<sub>1</sub>, min(j<sub>1</sub>, j<sub>2</sub>))</b> to <b>(i<sub>1</sub>, max(j<sub>1</sub>, j<sub>2</sub>) - 1)</b>.
4. Add vertical congestion cost due to the net to the grid from <b>(i<sub>3</sub>, min(j<sub>2</sub>, j<sub>3</sub>))</b> to <b>(i<sub>3</sub>, max(j<sub>2</sub>, j<sub>3</sub>) - 1)</b>.

##### **Procedure congestion cost computation due to three-pin nets:**
The inputs are three pin grid locations and the net weight.
1. Sort the pin based on the column. After sorting pin locations are <b>(i<sub>1</sub>, j<sub>1</sub>)</b>, <b>(i<sub>2</sub>, j<sub>2</sub>)</b> and <b>(i<sub>3</sub>, j<sub>3</sub>)</b>. As it is sorted based on column <b>i<sub>1</sub> <= i<sub>2</sub> <= i<sub>3</sub></b>.
2. If <b>i<sub>1</sub> < i<sub>2</sub></b> and <b>i<sub>2</sub> < i<sub>3</sub></b> and <b>min(j<sub>1</sub>, j<sub>3</sub>) < j<sub>2</sub></b> and <b>max(j<sub>1</sub>, j<sub>3</sub>) > j<sub>2</sub></b>:
   1. Update congestion cost using <b>L<sub>routing</sub></b>.
   2. Return.
3. If <b>i<sub>2</sub> == i<sub>3</sub></b> and <b>i<sub>1</sub> < i<sub>2</sub></b> and <b>j<sub>1</sub> < min(j<sub>2</sub>, j<sub>3</sub>)</b>:
   1. Add horizontal congestion cost due to the net to grids from <b>(i<sub>1</sub>, j<sub>1</sub>)</b> to <b>(i<sub>2</sub>-1, j<sub>1</sub>)</b>
   2. Add vertical congestion cost due to the net to grids from <b>(i<sub>2</sub>, j<sub>1</sub>)</b> to <b>(i<sub>2</sub>, max(j<sub>2</sub>, j<sub>3</sub>) -1)</b>
   3. Return.
4. If <b>j<sub>2</sub> == j<sub>3</sub></b>:
   1. Add horizontal congestion cost due to the net to grids from <b>(i<sub>1</sub>, j<sub>1</sub>)</b> to <b>(i<sub>2</sub> -1, j<sub>1</sub>)</b>
   2. Add horizontal congestion cost due to the net to grids from <b>(i<sub>2</sub>, j<sub>2</sub>)</b> to <b>(i<sub>3</sub> -1, j<sub>2</sub>)</b>
   3. Add vertical congestion cost due to the net to grids from <b>(i<sub>2</sub>, min(j<sub>2</sub>, j<sub>3</sub>))</b> to <b>(i<sub>2</sub>, max(j<sub>2</sub>, j<sub>3</sub>) - 1)</b>.
   4. Return
5. Update congestion cost using <b>T<sub>routing</sub></b>.


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
1. Consider the net is a n-pin net where <b>n > 3</b>. 
2. We break this net into **n-1** two pin nets where the source node is the common node.
3. For each two pin nets we update congestion values.

#### *Computation for Smoothing:*
When a macro overlaps with multiple gridcells, if any part of the module partially overlaps with the gridcell (either vertically, or horizontally), we set the top row (if vertical) or right column (if horizontal) to 0.

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
- For each hard MACRO:
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