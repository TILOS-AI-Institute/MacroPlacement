#############################################################################
# This script was written and developed by Dr. Jinwook Jung of IBM Research.
# However, the underlying commands and reports are copyrighted by Cadence. 
# We thank Cadence for granting permission to share our research to help 
# promote and foster the next generation of innovators.
#############################################################################
set fp_llx [dbGet top.fPlan.coreBox_llx]
set fp_lly [dbGet top.fPlan.coreBox_lly]
set fp_urx [dbGet top.fPlan.coreBox_urx]
set fp_ury [dbGet top.fPlan.coreBox_ury]
set fp_cx [expr [dbGet top.fPlan.coreBox_urx]/2]
set fp_cy [expr [dbGet top.fPlan.coreBox_ury]/2]

set site_width [dbGet head.sites.size_x]  ;# 0.19
set site_height [dbGet head.sites.size_y] ;# 1.4

set halo_size_x 5
set halo_size_y 5

set spacing_x [expr $halo_size_x * 4]
set spacing_y [expr $halo_size_y * 4]

set l2_data_size_x [dbGet [dbGet head.libCells.name fakeram45_512x64 -p].size_x]

set fp_x_offset [expr floor(($fp_urx - 4*(6*$l2_data_size_x + 3*$spacing_x))/2)]
set fp_y_offset 0
