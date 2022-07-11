# This script was written and developed by ABKGroup students at UCSD. However, the underlying commands and reports are copyrighted by Cadence. 
# We thank Cadence for granting permission to share our research to help promote and foster the next generation of innovators.

create_library_set -name WC_LIB -timing $libworst
create_library_set -name BC_LIB -timing $libbest
 
#create_opcond -name op_cond_wc -process 1.0 -voltage 0.72 -temperature 125
#create_opcond -name op_cond_bc -process 1.0 -voltage 0.88 -temperature -40
 
create_timing_condition -name timing_wc  -library_sets { WC_LIB }
create_timing_condition -name timing_bc  -library_sets { BC_LIB }
 
create_rc_corner -name Cmax -qrc_tech $qrc_max
create_rc_corner -name Cmin -qrc_tech $qrc_min

create_delay_corner -name WC -early_timing_condition { timing_wc } \
                             -late_timing_condition  { timing_wc } \
                             -early_rc_corner          Cmax        \
                             -late_rc_corner           Cmax

create_delay_corner -name BC -early_timing_condition { timing_bc } \
                             -late_timing_condition  { timing_bc } \
                             -early_rc_corner          Cmin        \
                             -late_rc_corner           Cmin


create_constraint_mode -name CON -sdc_file $sdc 
create_analysis_view -name WC_VIEW -delay_corner WC -constraint_mode CON
create_analysis_view -name BC_VIEW -delay_corner BC -constraint_mode CON
 
set_analysis_view -setup WC_VIEW -hold BC_VIEW
