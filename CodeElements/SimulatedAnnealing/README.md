# Simulated Annealing

Simulated Annealing (SA) is a powerful, but slow, optimization method.
In the [Nature Paper](https://www.nature.com/articles/s41586-021-03544-w), the Simulated Annealing is used as one of the baselines.
We implement the Simulated Annealing approach based on the descriptions in the [Nature Paper](https://www.nature.com/articles/s41586-021-03544-w).

## **Implementation details**
The implementation details of Simulated Annealing is presented as following.
* "All the macros are placed onto the centers of the grid cells."
* **Initialization of macro placements** : we implement two simple packing methods to generate initial macro placements for SA.
  * **Spiral placement** : the macros are sequentially placed around the boundary of the chip canvas in spiral fashion. \[[code](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/aab48da703255548fbb48e27e88674f88e23fd81/CodeElements/SimulatedAnnealing/SA.py#L1339)\]
  * **Greedy packer** : the macros are placed from the bottom-left corner to the top-right corner to minimize the gap between macros. \[[code](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/aab48da703255548fbb48e27e88674f88e23fd81/CodeElements/SimulatedAnnealing/SA.py#L1339)\]
* **Basic description of SA process** : In each SA iteration(step), we perform $2N$ macro actions (where $N$ is the number of macros). A macro action takes one of the five forms: **swap**, **shift**, **mirror**, **move** and **shuffle**.   By default, we apply a uniform probability over the five move types, meaning that at each move, there is a 1/5 chance of swapping, a 1/5 chance of shifting, a 1/5 chance of flipping, a 1/5 chance of moving and a 1/5 chance of shuffling.  Users can change this by updating the ["action_probs"](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/aab48da703255548fbb48e27e88674f88e23fd81/CodeElements/SimulatedAnnealing/config.json#L4) in the [config.json](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/aab48da703255548fbb48e27e88674f88e23fd81/CodeElements/SimulatedAnnealing/config.json).
  * **Swap** selects two macros at random and swaps their locations, if feasible. \[[code](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/aab48da703255548fbb48e27e88674f88e23fd81/CodeElements/SimulatedAnnealing/SA.py#L1441)\]
  * **Shift** selects a macro at random and shifts that macro to a neighboring location (left, right, up or down). \[[code](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/aab48da703255548fbb48e27e88674f88e23fd81/CodeElements/SimulatedAnnealing/SA.py#L1533)\]
  * **Mirror** flips a macro at random across the x axis, across the y axis, or across both the x and y axes. \[[code](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/aab48da703255548fbb48e27e88674f88e23fd81/CodeElements/SimulatedAnnealing/SA.py#L1560)\]
  * **Move** allows a macro to be placed at any legal location. This action is not in the original action set used by the [Nature Paper](https://www.nature.com/articles/s41586-021-03544-w). \[[code](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/aab48da703255548fbb48e27e88674f88e23fd81/CodeElements/SimulatedAnnealing/SA.py#L1472)\]
  * **Shuffle** permutes 4 macros at a time. This action is not in the original action set used by the [Nature Paper](https://www.nature.com/articles/s41586-021-03544-w). \[[code](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/aab48da703255548fbb48e27e88674f88e23fd81/CodeElements/SimulatedAnnealing/SA.py#L1492)\]
  
  "For each macro action, the new state is accepted if it leads to a lower cost. Otherwise, the new state is accepted with a probability of $exp[(prev_{cost} - new_{cost})/t]$, where $t = t_{max}exp(log[(t_{max}/t_{min})(step / steps)])$. Here $pre_{cost}$ refers to the cost at the previous iteration; $new_{cost}$ refers to the cost at the current iteration; $t$ is the temperature, which controls the willingness of the algorithm to accept local degradations in performance, allowing for exploration; and $t_{max}$ and $t_{min}$ coorespond to the maximum and mininum allowable temperature, respectively." \[[code](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/aab48da703255548fbb48e27e88674f88e23fd81/CodeElements/SimulatedAnnealing/SA.py#L1618)\]
  
  After $2N$ macro actions, we use the [circuit training's FD placer](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/aab48da703255548fbb48e27e88674f88e23fd81/CodeElements/SimulatedAnnealing/SA.py#L1401) to place clusters of standard cells while keeping macro locations fixed.

* The **cost** is defined as following:
  * $cost = w_{wirelength} \times cost_{wirelength} + w_{density} \times cost_{density} + w_{congestion} \times cost_{congestion}$
  In our experiments, $w_{wirelength} = 1.0$, $w_{density} = 0.5$ and $w_{congestion} = 0.5$. The detailed explanation for the cost function is available [here](https://tilos-ai-institute.github.io/MacroPlacement/Docs/ProxyCost/).  In our implementation, we use the [circuit training's API](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/aab48da703255548fbb48e27e88674f88e23fd81/CodeElements/SimulatedAnnealing/SA.py#L1390) to calculate the cost.
* **Basic runtime metrics**
  * macro action + cost calculation : 0.006 second per time
  * FD placer : 0.74 second per time
* We enable **lti-threading feature**o run massive SA runs. Multiple SA runs can be launched in parallel. But there is no communication between different SA runs. \[[code](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/aab48da703255548fbb48e27e88674f88e23fd81/CodeElements/SimulatedAnnealing/sa_multicore.py#L88)\]
  


## **How to run the scripts**
We implement the Simulated Annealing based on the APIs of [Circuit Training](https://github.com/google-research/circuit_training.git). Please install Circuit Training before you run our scripts. You also need to update your Circuit Training directory in the [scripts](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/aab48da703255548fbb48e27e88674f88e23fd81/CodeElements/SimulatedAnnealing/SA.py#L32).
You can also change the default configurations by updating the [config.json](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/aab48da703255548fbb48e27e88674f88e23fd81/CodeElements/SimulatedAnnealing/config.json). 
The [config.json](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/aab48da703255548fbb48e27e88674f88e23fd81/CodeElements/SimulatedAnnealing/config.json) has following parameters:
* **netlist** : the protocol buffer netlist
* **plc_file** : the plc file for macro and standard-cell locations
* **action_probs** : the probablity of each action, following the order of swap, shift, mirror, move and shuffle
* **num_actions(xn)** : the number of macro actions \[$\times N$\] in each SA iteration(step)
* **max_temperature** : $t_{max}$
* **num_iters** : $steps$. \[see  $t = t_{max}exp(log[(t_{max}/t_{min})(step / steps)])$ \]
* **seed** : random seed
* **num_cores** : number of cores used
* **spiral_flag** : use **Spiral placement** for initial macro placement if **spiral_flag** = true; otherwise, use **Greedy packer** for initial macro placement

After setting the [config.json](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/aab48da703255548fbb48e27e88674f88e23fd81/CodeElements/SimulatedAnnealing/config.json), the scripts can be run with following command:
```
python sa_multicore.py
```

## **Experimental Results**
We have tested our codes with the [ariane133](https://github.com/TILOS-AI-Institute/MacroPlacement/tree/main/CodeElements/SimulatedAnnealing/ariane133) (NanGate45, utilization = 0.68, clock_period = 1.3ns).  Our configuration is as following:
* **action_probs** : [0.2, 0.2, 0.2, 0.2, 0.2]
* **num_actions(xn)** : 2
* **max_temperature** : 5e-5
* **num_iters** : 20000
* **seed** : 1
* **num_cores** : 8
* **spiral_flag** : [False, True]
The cost curve is shown below.  We can see that **Spiral placement** is better than **Greedy packer**.
<p align="center">
<img src="./images/net_model.png" width= "600"/>
</p>
<p align="center">
 Figure 3.  Illustration of net model used in Circuit Training.  
</p>






  
