# Copyright 2021 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Author: Matheus Cavalcante, ETH Zurich
#         Samuel Riedel, ETH Zurich

SHELL = /usr/bin/env bash
ROOT_DIR := $(patsubst %/,%, $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
MEMPOOL_DIR := $(shell git rev-parse --show-toplevel 2>/dev/null || echo $$MEMPOOL_DIR)
INSTALL_DIR := $(abspath $(ROOT_DIR)/../install)
TOOLCHAIN_DIR := $(abspath $(ROOT_DIR)/../toolchain)

# Include configuration
config_mk = $(abspath $(ROOT_DIR)/../config/config.mk)
include $(config_mk)

# build path
buildpath       ?= build
resultpath      ?= results
# questa library
library         ?= work
# dpi library
dpi_library     ?= work-dpi
# Top level module to compile
top_level       ?= mempool_tb
# QuestaSim Version
questa_version  ?= 2021.2-bt
# QuestaSim command
questa_cmd      ?= questa-$(questa_version)
# QuestaSim arguments
questa_args     ?=
# VCS Version
vcs_version     ?= 2020.12-bt
# VCS command
vcs_cmd         ?= vcs-$(vcs_version)
# Path to the binaries
app_path        ?= $(abspath $(ROOT_DIR)/../software/bin)
# Bender
bender          ?= $(INSTALL_DIR)/bender/bender
# Verilator
verilator       ?= $(INSTALL_DIR)/verilator/bin/verilator
verilator_build ?= $(ROOT_DIR)/verilator_build
verilator_files ?= $(verilator_build)/files
verilator_top   ?= mempool_tb_verilator
# Python
python          ?= python3
# Enable tracing
snitch_trace    ?= 0

# Check if the specified QuestaSim version exists
ifeq (, $(shell which $(questa_cmd)))
  # Spaces are needed for indentation here!
  $(warning "Specified QuestaSim version ($(questa_cmd)) not found in PATH $(PATH)")
  questa_cmd =
endif

QUESTASIM_HOME ?= /usr/pack/questa-$(questa_version)/questasim
VCS_HOME       ?= /usr/pack/vcs-$(vcs_version)/vcs

ifdef app
	preload ?= "$(app_path)/$(app)"
endif
ifdef preload
	questa_args += +PRELOAD=$(preload)
endif
questa_args += -sv_lib $(dpi_library)/mempool_dpi -work $(library)
questa_args += -suppress vsim-12070

# VCS options
vlogan_args += -assert svaext +v2k -override_timescale=1ns/1ps -kdb
ifdef preload
	vcs_args += +PRELOAD=$(preload)
endif

# DPI source files
dpi     := $(patsubst tb/dpi/%.cpp,$(buildpath)/$(dpi_library)/%.o,$(wildcard tb/dpi/*.cpp))
dpi_vcs := $(patsubst tb/dpi/%.cpp,$(buildpath)/$(dpi_library)/%_vcs.o,$(wildcard tb/dpi/*.cpp))
# Traces
trace = $(patsubst $(buildpath)/%.dasm,$(buildpath)/%.trace,$(wildcard $(buildpath)/*.dasm))
tracepath ?= $(buildpath)/traces
traceresult ?= $(tracepath)/results.csv
ifndef result_dir
	result_dir := $(resultpath)/$(shell date +"%Y%m%d_%H%M%S_$(app)_$$(git rev-parse --short HEAD)")
endif

vlog_args += -suppress vlog-2583 -suppress vlog-13314 -suppress vlog-13233
vlog_args += -work $(library)
# Defines
vlog_defs += -DNUM_CORES=$(num_cores) -DNUM_CORES_PER_TILE=$(num_cores_per_tile) -DNUM_GROUPS=$(num_groups) -DBANKING_FACTOR=$(banking_factor)
vlog_defs += -DL2_BASE=$(l2_base) -DL2_SIZE=$(l2_size) -DL2_BANKS=$(l2_banks)
vlog_defs += -DBOOT_ADDR=$(boot_addr) -DXPULPIMG=$(xpulpimg)
vlog_defs += -DSNITCH_TRACE=$(snitch_trace)
vlog_defs += -DAXI_DATA_WIDTH=$(axi_data_width)
vlog_defs += -DRO_LINE_WIDTH=$(ro_line_width)
vlog_defs += -DDMAS_PER_GROUP=$(dmas_per_group)
vlog_defs += -DAXI_HIER_RADIX=$(axi_hier_radix) -DAXI_MASTERS_PER_GROUP=$(axi_masters_per_group)
vlog_defs += -DSEQ_MEM_SIZE=$(seq_mem_size) -DXQUEUE_SIZE=$(xqueue_size)

# Traffic generation enabled
ifdef tg
	tg_ncycles ?= 10000

	vlog_defs += -DTRAFFIC_GEN=1
	cpp_defs  += -DTRAFFIC_GEN=1 -DTG_REQ_PROB=$(tg_reqprob) -DTG_SEQ_PROB=$(tg_seqprob) -DTG_NCYCLES=$(tg_ncycles) -DNUM_CORES=$(num_cores)

	# How many cycles should we execute?
	veril_flags := --term-after-cycles=$(tg_ncycles)
else
	tg          := 0
	veril_flags := --meminit=ram,$(preload)
endif

cpp_defs += -DL2_BASE=$(l2_base)
cpp_defs += -DL2_SIZE=$(l2_size)
cpp_defs += -DL2_BANKS=$(l2_banks)
cpp_defs += -DAXI_DATA_WIDTH=$(axi_data_width)

.DEFAULT_GOAL := compile

# Build path
$(buildpath):
	mkdir -p $(buildpath)

# Bender
$(bender):
	make -C $(MEMPOOL_DIR) bender

################
# Modelsim     #
################
# Library
.PHONY: lib
lib: $(buildpath) $(buildpath)/$(library)
$(buildpath)/$(library):
	cd $(buildpath) && $(questa_cmd) vlib $(library) && chmod +w modelsim.ini; $(questa_cmd) vmap $(library) $(library)

# Compilation
.PHONY: compile
compile: dpi lib $(buildpath) $(buildpath)/compile.tcl update_opcodes
$(buildpath)/compile.tcl: $(bender) $(config_mk) Makefile $(MEMPOOL_DIR)/Bender.yml $(shell find {src,tb,deps} -type f)
	$(bender) script vsim --vlog-arg="$(vlog_args)" $(vlog_defs) -t rtl -t mempool_vsim > $(buildpath)/compile.tcl
	echo "exit" >> $(buildpath)/compile.tcl
	cd $(buildpath) && $(questa_cmd) vsim -work $(library) -c -do compile.tcl

# Simulation
.PHONY: sim
sim: clean-dasm compile
	cd $(buildpath) && \
	$(questa_cmd) vsim -voptargs=+acc $(questa_args) $(library).$(top_level) -do ../scripts/questa/run.tcl
	./scripts/return_status.sh $(buildpath)/transcript

.PHONY: simc
simc: clean-dasm compile
	cd $(buildpath) && \
	$(questa_cmd) vsim -c $(questa_args) $(library).$(top_level) -do "run -a"
	./scripts/return_status.sh $(buildpath)/transcript

# DPIs
.PHONY: dpi
dpi: $(buildpath)/$(dpi_library)/mempool_dpi.so

$(buildpath)/$(dpi_library)/%.o: tb/dpi/%.cpp
	mkdir -p $(buildpath)/$(dpi_library)
	$(CXX) -shared -fPIC -std=c++11 -Bsymbolic -c $< -I$(QUESTASIM_HOME)/include -o $@

$(buildpath)/$(dpi_library)/mempool_dpi.so: $(dpi)
	mkdir -p $(buildpath)/$(dpi_library)
	$(CXX) -shared -m64 -o $(buildpath)/$(dpi_library)/mempool_dpi.so $^

################
# VCS          #
################

# Elaboration
.PHONY: elabvcs
elabvcs: dpivcs $(buildpath) $(buildpath)/compilevcs.sh update_opcodes
$(buildpath)/compilevcs.sh: $(bender) $(config_mk) Makefile $(MEMPOOL_DIR)/Bender.yml $(shell find {src,tb,deps} -type f)
	$(bender) script vcs --vlogan-bin="$(vcs_cmd) vlogan" --vlog-arg="$(vlogan_args)" $(vlog_defs) -t rtl -t mempool_vsim > $(buildpath)/compilevcs.sh
	echo "exit" >> $(buildpath)/compilevcs.sh
	# Call VCS
	cd $(buildpath) && \
	chmod +x compilevcs.sh && \
	./compilevcs.sh

# Compilation
.PHONY: compile_vcs_simv compile_vcs_simvopt

compile_vcs_simv: elabvcs $(buildpath)/mempool_simv
$(buildpath)/mempool_simv: $(buildpath)/compilevcs.sh $(buildpath)/$(dpi_library)/mempool_vcs_dpi.so
	cd $(buildpath) && \
	$(vcs_cmd) vcs -full64 $(top_level) $(dpi_library)/mempool_vcs_dpi.so -debug_access=r -kdb -assert disable_cover -o mempool_simv

compile_vcs_simvopt: elabvcs $(buildpath)/mempool_simvopt
$(buildpath)/mempool_simvopt: $(buildpath)/compilevcs.sh $(buildpath)/$(dpi_library)/mempool_vcs_dpi.so
	cd $(buildpath) && \
	$(vcs_cmd) vcs -full64 $(top_level) $(dpi_library)/mempool_vcs_dpi.so -assert disable_cover -o mempool_simvopt

# Simulation
simvcs: compile_vcs_simv
	cd $(buildpath) && \
	./mempool_simv $(vcs_args) -ucli -do ../scripts/vcs/run.tcl -gui

simcvcs: compile_vcs_simvopt
	cd $(buildpath) && \
	./mempool_simvopt $(vcs_args)

# DPIs
.PHONY: dpivcs
dpivcs: $(buildpath)/$(dpi_library)/mempool_vcs_dpi.so

$(buildpath)/$(dpi_library)/%_vcs.o: tb/dpi/%.cpp
	mkdir -p $(buildpath)/$(dpi_library)
	$(CXX) -shared -fPIC -std=c++11 -Bsymbolic -c $< -I$(VCS_HOME)/include -o $@

$(buildpath)/$(dpi_library)/mempool_vcs_dpi.so: $(dpi_vcs)
	mkdir -p $(buildpath)/$(dpi_library)
	$(CXX) -shared -m64 -o $(buildpath)/$(dpi_library)/mempool_vcs_dpi.so $^

################
# Verilator    #
################
VERILATOR_SRC   := $(ROOT_DIR)/tb/verilator
VERILATOR_LIBS  := $(shell find $(VERILATOR_SRC) -name "*.cc" -print | sort)
VERILATOR_INCS  := $(shell find $(VERILATOR_SRC) -name "cpp" -print | sort)
VERILATOR_EXE   := $(verilator_build)/V$(verilator_top)
VERILATOR_MK    := $(VERILATOR_EXE).mk
VERILATOR_WAIVE := $(shell find $(VERILATOR_SRC) -name "*.vlt" -print | sort)
VERILATOR_CONF  := $(VERILATOR_SRC)/verilator.flags

VERILATOR_FLAGS += -CFLAGS "-DTOPLEVEL_NAME=$(verilator_top)"
VERILATOR_FLAGS += --Mdir $(verilator_build)
VERILATOR_FLAGS += -f $(verilator_files)
VERILATOR_FLAGS += -f $(VERILATOR_CONF)
VERILATOR_FLAGS += $(VERILATOR_WAIVE)
# VERILATOR_FLAGS += --trace --trace-fst --trace-structs --trace-params --trace-max-array 1024
# VERILATOR_FLAGS += --debug

# We need to link the verilated model against LLVM's libc++.
# Define CLANG_PATH to be the path of your Clang installation.
# At IIS, check .gitlab/.gitlab-ci.yml for an example CLANG_PATH.

ifneq (${CLANG_PATH},)
  VERILATOR_FLAGS += -CFLAGS "-nostdinc++ -isystem $(CLANG_PATH)/include/c++/v1"
  VERILATOR_FLAGS += -LDFLAGS "-L $(CLANG_PATH)/lib -Wl,-rpath,$(CLANG_PATH)/lib -lc++ -nostdlib++"
endif

$(VERILATOR_MK): $(VERILATOR_CONF) $(VERILATOR_WAIVE) $(MEMPOOL_DIR)/Bender.yml $(shell find {src,tb,deps} -type f) $(bender) $(config_mk) Makefile
	rm -rf $(verilator_build); mkdir -p $(verilator_build)
	# Overwrite Bootaddress to L2 base while we don't have a DPI to write a wake-up
	$(eval boot_addr=$(l2_base))
	# Create Bender script of all RTL files
	$(bender) script verilator $(vlog_defs) -t rtl -t mempool_verilator > $(verilator_files)
	# Append the verilator library files
	@echo '' >> $(verilator_files)
	# Append the verilator library files: Includes
	@echo $(addprefix +incdir+,$(VERILATOR_INCS)) | tr ' ' '\n' >> $(verilator_files)
	for i in $(VERILATOR_INCS); do echo "-CFLAGS -I$${i}" >> $(verilator_files); done
	# Append the CPP defines
	@echo "-CFLAGS \"$(cpp_defs)\"" >> $(verilator_files)
	# Append the verilator library files: source files
	@echo $(VERILATOR_LIBS) | tr ' ' '\n'  >> $(verilator_files)
	# Create Verilator Makefile
	$(verilator) $(VERILATOR_FLAGS) --top-module $(verilator_top)

$(VERILATOR_EXE): $(VERILATOR_MK) $(shell find $(VERILATOR_SRC) -type f) Makefile
	make -j4 -C $(verilator_build) -f $<

verilate: $(VERILATOR_EXE) $(buildpath) Makefile
	cd $(buildpath) && $(VERILATOR_EXE) $(veril_flags) | tee transcript
	# Avoid capturing the return status when running the load-throughput analysis
	if [ $(tg) -ne 1 ]; then ./scripts/return_status.sh $(buildpath)/transcript; fi

#############
# Lint      #
#############
.PHONY: lint spyglass/tmp/files

SNPS_SG ?= spyglass-2022.06
lint: spyglass/tmp/files spyglass/sdc/func.sdc spyglass/scripts/run_lint.tcl
	cd spyglass; $(SNPS_SG) sg_shell -tcl scripts/run_lint.tcl

spyglass/tmp/files: $(bender)
	mkdir -p spyglass/tmp
	$(bender) script verilator $(vlog_defs) -t rtl -t mempool_verilator > spyglass/tmp/files

################
# Tracing      #
################
benchmark: log simcvcs
	# Call `make` again to get variable extension with all traces
	result_dir=$(result_dir) $(MAKE) trace

trace: pre_trace $(trace) post_trace

log:
	mkdir -p "$(result_dir)"
	[ -e "$(preload)" ] && cp "$(preload)"* "$(result_dir)" || \
	([ -e "$(buildpath)/transcript" ] && \
	cp "$$(grep -oP '(?<=\+PRELOAD=)[^ \"]*' $(buildpath)/transcript)"* "$(result_dir)" || \
	echo "No application specified")
	env > "$(result_dir)/env"
	cp $(MEMPOOL_DIR)/config/config.mk $(result_dir)/config
	git rev-parse HEAD > "$(result_dir)/git-info.diff"
	git show --oneline -s >> "$(result_dir)/git-info.diff"
	git diff >> "$(result_dir)/git-info.diff"

pre_trace:
	rm -rf $(tracepath)

post_trace:
	mkdir -p "$(result_dir)"
	cp $(buildpath)/transcript "$(result_dir)/" | true
	cp $(traceresult) "$(result_dir)"
	cp $(trace) "$(result_dir)"
	$(python) $(ROOT_DIR)/scripts/gen_avg.py --folder "$(result_dir)" | tee $(result_dir)/avg.txt

$(buildpath)/%.trace: $(buildpath)/%.dasm
	mkdir -p $(tracepath)
	$(INSTALL_DIR)/riscv-isa-sim/bin/spike-dasm < $< > $(tracepath)/$*
	$(python) $(ROOT_DIR)/scripts/gen_trace.py -p --csv $(traceresult) $(tracepath)/$* > $@

tracevis:
	$(MEMPOOL_DIR)/scripts/tracevis.py $(preload) $(buildpath)/*.trace -o $(buildpath)/tracevis.json

############################
# Unit tests simulation    #
############################
TESTS_DIR := $(abspath $(ROOT_DIR)/../software/riscv-tests/isa)
include $(TESTS_DIR)/snitch_isa.mk

test_result_dir_vsim := $(resultpath)/test_result_vsim
test_result_dir_verilate := $(resultpath)/test_result_verilate

tests_vsim := $(addsuffix .out,$(addprefix $(test_result_dir_vsim)/,$(rtl_mempool_tests)))
tests_verilate := $(addsuffix .out,$(addprefix $(test_result_dir_verilate)/,$(rtl_mempool_tests)))

simc_test: clean-dasm compile $(buildpath) $(tests_vsim)
verilate_test: clean-dasm $(VERILATOR_EXE) $(buildpath) $(tests_verilate)

$(tests_vsim): $(test_result_dir_vsim)/%.out : $(app_path)/%
	mkdir -p $(test_result_dir_vsim)
	cd $(buildpath) && \
	$(questa_cmd) vsim -c $(questa_args) +PRELOAD=$< $(library).$(top_level) -do "run -a"
	./scripts/return_status.sh $(buildpath)/transcript > $@

$(tests_verilate): $(test_result_dir_verilate)/%.out : $(app_path)/%
	mkdir -p $(test_result_dir_verilate)
	cd $(buildpath) && $(VERILATOR_EXE) --meminit=ram,$< | tee transcript
	./scripts/return_status.sh $(buildpath)/transcript > $@

################
# Helper       #
################

# Bootrom
src/bootrom.sv: $(MEMPOOL_DIR)/software/runtime/bootrom.img $(config_mk) Makefile
	$(python) ./scripts/generate_bootrom.py --sv --output src/bootrom --datawidth $(axi_data_width) $<

$(MEMPOOL_DIR)/software/runtime/bootrom.img:
	make -C $(MEMPOOL_DIR)/software runtime/bootrom.img

# Clean targets
.PHONY: clean clean-dasm clean-trace update_opcodes

update_opcodes:
	make -C $(MEMPOOL_DIR) update_opcodes

clean:
	@rm -rf $(buildpath)
	@rm -rf $(verilator_build)

clean-dasm:
	rm -rf $(buildpath)/*.dasm

clean-trace:
	rm -rf $(buildpath)/*.trace
