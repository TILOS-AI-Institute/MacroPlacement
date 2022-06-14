# Copyright 2019 ETH Zurich and University of Bologna.
# Copyright and related rights are licensed under the Solderpad Hardware
# License, Version 0.51 (the "License"); you may not use this file except in
# compliance with the License.  You may obtain a copy of the License at
# http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
# or agreed to in writing, software, hardware and materials distributed under
# this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied. See the License for the
# specific language governing permissions and limitations under the License.
#
# Author: Michael Schaffner <schaffner@iis.ee.ethz.ch>, ETH Zurich
# Date: 06.03.2019
# Description: Synthesis script for TCDM interconnect

#####################
##   SETUP         ##
#####################

echo "----------------------------------"
echo "--- Synthesis Script Arguments ---"
echo "----------------------------------"
echo "SRC:         $SRC                 "
echo "TOP_ENTITY:  $TOP_ENTITY          "
echo "NAME:        $NAME                "
echo "INCDIR:      $INCDIR              "
echo "OUTDIR:      $OUTDIR              "
echo "DEFINE:      $DEFINE              "
echo "LIB:         $LIB                 "
echo "----------------------------------"

set CPUS        1
set VARIANT     "hp"
set TCK         1000
set CORNER_TRIM 0

#####################
##   SET LIBRARY   ##
#####################

# TODO: set library and operating point here

# TODO: define the following variables
# set driving_cell
# set driving_cell_clk
# set load_cell
# set load_lib

######################
##   CLOCK GATING   ##
######################

set_clock_gating_style -num_stages 1                   \
                       -positive_edge_logic integrated \
                       -control_point before           \
                       -control_signal scan_enable

###########################
##   ELABORATE DESIGN    ##
###########################

# make library
sh mkdir -p $LIB
define_design_lib WORK -path $LIB

# delete previous designs.
remove_design -designs
sh rm -rf $LIB/*

set CLK_PIN clk_i
set RST_PIN rst_ni

analyze -format sv $SRC -define $DEFINE

elaborate  ${TOP_ENTITY}

###########################
##   APPLY CONSTRAINTS   ##
###########################

set IN_DEL  0.0
set OUT_DEL 0.0
set DELAY   $TCK

create_clock ${CLK_PIN} -period ${TCK}

set_ideal_network ${CLK_PIN}
set_ideal_network ${RST_PIN}

set_max_delay ${DELAY} -from [all_inputs] -to [all_outputs]
set_input_delay ${IN_DEL} [remove_from_collection [all_inputs] {${CLK_PIN}}] -clock ${CLK_PIN}
set_output_delay ${OUT_DEL}  [all_outputs] -clock ${CLK_PIN}

set_driving_cell  -no_design_rule -lib_cell ${driving_cell} -pin Z [all_inputs]
set_load [load_of ${load_lib}/${load_cell}/A] [all_outputs]

#######################
##   COMPILE ULTRA   ##
#######################

compile_ultra -gate_clock -scan

#################
##   NETLIST   ##
#################

change_names -rules verilog -hierarchy
define_name_rules fixbackslashes -allowed "A-Za-z0-9_" -first_restricted "\\" -remove_chars
change_names -rule fixbackslashes -h
write_file -format ddc -hierarchy -output $OUTDIR/design.ddc
write_file -format verilog -hierarchy -output $OUTDIR/design.v

#################
##   REPORTS   ##
#################

report_power  -hierarchy > $OUTDIR/power.rpt
report_timing            > $OUTDIR/timing.rpt
report_area   -hierarchy > $OUTDIR/area.rpt

exit