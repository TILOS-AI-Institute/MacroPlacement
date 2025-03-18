import os
import sys
import numpy as np
import matplotlib.pyplot as plt

def gen_plot(sum_file):
    if not os.path.exists(sum_file):
        print("File does not exist: %s" % sum_file)
        sys.exit(1)
    
    ## Ensure the summary file ends with .summary
    if not sum_file.endswith(".summary"):
        print("File does not end with .summary: %s" % sum_file)
        sys.exit(1)
    
    ## Replace .summary with .png
    png_file = sum_file.replace(".summary", ".png")
    
    fp = open(sum_file, "r")
    costs = []
    for line in fp:
        costs.append(float(line.strip()))
    fp.close()

    # Compute min and max cost
    min_cost = min(costs)
    max_cost = max(costs)
    
    plt.plot(costs)
    # Set y-ticks: from min_cost - 0.1 to max_cost + 0.1 with 0.1 intervals
    yticks = np.arange(min_cost - 0.1, max_cost + 0.1 + 0.05, 0.1)
    plt.yticks(yticks.tolist())

    # Add a dotted red line at min cost
    plt.axhline(y=min_cost, color='r', linestyle=':')
    
    ## X label: #moves
    plt.xlabel("#moves")
    ## Y label: cost
    plt.ylabel("Cost")
    
    ## Save the plot
    plt.savefig(png_file)
    plt.close()
    print("Plot saved as %s" % png_file)
    # Report the min cost value
    print("Minimum cost: {}".format(min_cost))
    
if __name__ == "__main__":
    summary_file = sys.argv[1]
    gen_plot(summary_file)