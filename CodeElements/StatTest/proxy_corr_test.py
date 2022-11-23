import re
import os, sys
import math
import numpy as np
import logging
import matplotlib.pyplot as plt
import pandas as pd
import pandas as pd

SHEET_ID = '1dtG4uHzdw-Lfe_Vcm5uBRNjjxXNA4gmVarTr86hjYVo'
SHEET_NAME = 'Proxy_Cost_Comparison'
url = f'https://docs.google.com/spreadsheets/d/{SHEET_ID}/gviz/tq?tqx=out:csv&sheet={SHEET_NAME}'
proxy_df = pd.read_csv(url)
proxy_df = proxy_df.loc[:, ~proxy_df.isnull().all()]
print(proxy_df.columns)
proxy_df['postCTS_Congestion (V)'] = proxy_df['postCTS_Congestion (V)'].str.rstrip('%').astype('float') / 100.0
# compute correlation between postRouteOpt_std_cell_area and density_cost
print("postRoute_std_cell_area VS. Density_Cost", 
        proxy_df["postRoute_std_cell_area (um^2)"].corr(proxy_df["Density_Cost"]))
print("postRouteOpt_std_cell_area VS. Density_Cost", 
        proxy_df["postRouteOpt_std_cell_area (um^2)"].corr(proxy_df["Density_Cost"]))

# compute correlation between postRouteOpt_wirelength (um) and wirelength_cost
print("postRoute_wirelength VS. Wirelength_Cost", 
        proxy_df["postRoute_wirelength (um)"].corr(proxy_df["Wirelength_Cost"]))
print("postRouteOpt_wirelength VS. Wirelength_Cost", 
        proxy_df["postRouteOpt_wirelength (um)"].corr(proxy_df["Wirelength_Cost"]))

# compute correlation between postCTS_Congestion and congestion_cost
print("postCTS_Congestion VS. Congestion_Cost", 
        proxy_df["postCTS_Congestion (V)"].corr(proxy_df["Congestion_Cost"]))