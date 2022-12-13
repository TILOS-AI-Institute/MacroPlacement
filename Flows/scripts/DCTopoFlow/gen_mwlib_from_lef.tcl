##################################################################
# Portions Copyright 2022 Synopsys, Inc. All rights reserved.
# Portions of these TCL scripts are proprietary to and owned
# by Synopsys, Inc. and may only be used for internal use by
# educational institutions (including United States government
# labs, research institutes and federally funded research and
# development centers) on Synopsys tools for non-profit research,
# development, instruction, and other non-commercial uses or as
# otherwise specifically set forth by written agreement with
# Synopsys. All other use, reproduction, modification, or
# distribution of these TCL scripts is strictly prohibited.
##################################################################
# The following script generates milkyway (mw) library. This
# library contains the physical information for the standard cells
# macros and the technology node. This is a input to DC Topo.
# To run this script the required inputs are the tech lef and 
# lef for which you need the milkyway library.
##################################################################

# Inputs 
set tech_lef ""
set lef_list ""

# Outputs
set mw_lib_name ""
set tech_tf ""

read_lef -lib_name ${mw_lib_name} -tech_lef_files $tech_lef -cell_lef_files $lef_list
cmDumpTech
setFormField "Dump Technology File" "Library Name" "$mw_lib_name"
setFormField "Dump Technology File" "Technology File Name" "$tech_tf"
formOK "Dump Technology File"
exit