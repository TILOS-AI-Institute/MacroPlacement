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
# Date: 21.03.2019
# Description: Makefile for the interconnect testbench.

#
eval-root      := $(shell pwd)

results-dir    ?= sim-results
library        := work
top-sim        := tb
top-synth      := tcdm_interconnect_wrap

batch-list     ?= scripts/batch.list
src-list       := scripts/src.list
tb-src-list    := scripts/tb-src.list

matlab-ver     ?= matlab-2018b
questa-ver     ?= -10.5c
vcs-ver        ?= -2017.03

compile_flag   += -suppress 13262 -suppress 2583
compile-flag-vcs   += -full64 -sverilog +systemverilogext+.sv -timescale=1ps/1ps
# +cover+i_dut -incr -64 -nologo -quiet
sim_opts       += -64 -voptargs="+acc"
sim_opts_batch += -64
#-voptargs="+acc" -64
#-coverage -classdebug -voptargs="+acc"
incdir         +="$(shell pwd)/../common/"+"$(shell pwd)/../../rtl/low_latency_interco"+"$(shell pwd)/../../rtl/low_latency_interco"+"$(shell pwd)/hdl/"

# points to DC folder
dc-ver         ?= synopsys-2018.06 dc_shell
synth-dir      := /usr/scratch2/toscana/michscha/projects/cluster_interconnect/tech/gf22/synopsys
synth-script   := scripts/synth.tcl


# get sources
src            := $(addprefix $(eval-root)/,$(shell xargs printf '\n%s' < $(src-list)  | cut -b 1-))
tb-src         := $(addprefix $(eval-root)/,$(shell xargs printf '\n%s' < $(tb-src-list)  | cut -b 1-))

# filter the batch-list first
batch-name   := $(shell cat $(batch-list) | grep -v '\#' | cut -d - -f 1)
batch-config := $(shell cat $(batch-list) | grep -v '\#' | cut -d - -f 1-)

build: clean
	vlib${questa-ver} $(library)
	vlog${questa-ver} -work $(library) -pedanticerrors $(src) $(tb-src) $(compile_flag) +incdir+$(incdir)

# this starts modelsim with gui
sim: build
	vsim${questa-ver} -lib $(library) $(top-sim) -do "do wave.do" $(sim_opts)

# batch mode without gui
simc: build
	vsim${questa-ver} -lib $(library) $(top-sim) -c -do "run -all; exit" $(sim_opts_batch)

build-vcs: clean
	vcs${vcs-ver} vcs $(src) $(tb-src) $(compile-flag-vcs) +incdir+$(incdir)

# TODO: implement VCS runs
# this starts vcs with gui
# sim-vcs: build-vcs
# 	vsim${questa-ver} -lib $(library) $(top-sim) -do "do wave.do" $(sim_opts)

# # batch mode without gui
# simc-vcs: build-vcs
# 	vsim${questa-ver} -lib $(library) $(top-sim) -c -do "run -all; exit" $(sim_opts_batch)

clean:
	rm -rf $(library)
	rm -rf transcript statistics.log vsim.wlf modelsim.ini

batch-clean-sim:
	rm -rf $(addprefix $(results-dir)/, $(addsuffix _transcript.log, $(batch-name)))
	rm -rf $(addprefix $(results-dir)/, $(addsuffix _statistics.log, $(batch-name)))

batch-clean-synth:
	rm -rf $(addprefix $(results-dir)/, $(addsuffix _synth.log, $(batch-name)))
	rm -rf $(addprefix $(results-dir)/, $(addsuffix _timing.rpt, $(batch-name)))
	rm -rf $(addprefix $(results-dir)/, $(addsuffix _power.rpt, $(batch-name)))
	rm -rf $(addprefix $(results-dir)/, $(addsuffix _area.rpt, $(batch-name)))


batch-clean:
	rm -rf $(batch-name)

clean-all: clean batch-clean batch-clean-synth batch-clean-sim
	rm -rf $(results-dir)

# runs the configurations defined in the batch-list file and gathers the statistics logs
$(results-dir)/%_statistics.log:
	$(eval $@: name := $(subst _statistics.log,,$(subst $(results-dir)/,, $@)))
	mkdir -p $(name)
	vlib${questa-ver} $(name)/$(library)
	vlog${questa-ver} -work $(name)/$(library) -pedanticerrors $(src) $(tb-src) $(compile_flag) +incdir+$(incdir) $(addprefix +define+,$(subst $(name)-, , $(filter $(name)-%, $(batch-config)))) > $(name)/compile.log
	@echo $(name) started
	cd $(name) && vsim${questa-ver} -lib $(library) $(top-sim) -c -do "run -all; exit" $(sim_opts_batch) > /dev/null
	@echo $(name) finished
	cp $(name)/transcript     $(results-dir)/$(name)_transcript.log
	cp $(name)/statistics.log $(results-dir)/$(name)_statistics.log

batch-sim:
	mkdir -p $(results-dir)
	$(MAKE) $(addprefix $(results-dir)/, $(addsuffix _statistics.log, $(batch-name)))

# mini prep script for DC that sets the required variables and calls a generic synthesis script
dc-cmd = "set SRC {$(src)};                                                        \
	        set TOP_ENTITY $(top-synth);                                           \
	        set NAME $(name);                                                      \
	        set INCDIR $(incdir);                                                  \
	        set OUTDIR $(eval-root)/$(name)/ ;                                     \
	        set LIB $(eval-root)/$(name)/$(library)-synth ;                        \
	        set DEFINE {$(subst +, ,$(subst $(name)-, , $(filter $(name)-%, $(batch-config)))) } ; \
	        source $(eval-root)/$(synth-script)                                    \
	         "

# synthesizes the configurations defined in the batch-list file and gathers the statistics logs
$(results-dir)/%_area.rpt:
	$(eval $@: name := $(subst _area.rpt,,$(subst $(results-dir)/,, $@)))
	mkdir -p $(name)
	@echo $(name) started
	cd $(synth-dir)	&& $(dc-ver) -x $(dc-cmd)  > $(eval-root)/$(name)/synth.log
	@echo $(name) finished
	cp $(name)/synth.log   $(results-dir)/$(name)_synth.log
	cp $(name)/timing.rpt  $(results-dir)/$(name)_timing.rpt
	cp $(name)/power.rpt   $(results-dir)/$(name)_power.rpt
	cp $(name)/area.rpt    $(results-dir)/$(name)_area.rpt

batch-synth:
	mkdir -p $(results-dir)
	$(MAKE) $(addprefix $(results-dir)/, $(addsuffix _area.rpt, $(batch-name)))

batch-plot:
	$(matlab-ver) -nosplash -nodesktop -r "addpath(genpath('./matlab')); run evaluation.m"

batch-eval: batch-synth batch-sim
	$(MAKE) batch-plot

.PHONY: build sim simc clean batch-clean clean-all batch-sim batch-synth batch-plot batch-eval
