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
df = pd.read_csv(url)
print(df.head())

# compute correlation between ???