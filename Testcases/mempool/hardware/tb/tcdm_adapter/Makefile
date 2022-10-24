# Copyright 2021 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Author: Marc Gantenbein, ETH Zurich

SHELL = /usr/bin/env bash
ROOT_DIR := $(patsubst %/,%, $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
MEMPOOL_DIR := $(shell git rev-parse --show-toplevel 2>/dev/null || echo $$MEMPOOL_DIR)
INSTALL_DIR := $(abspath $(MEMPOOL_DIR)/install)
TOOLCHAIN_DIR := $(abspath $(MEMPOOL_DIR)/toolchain)

# Include configuration
config_mk := $(abspath $(MEMPOOL_DIR)/config/config.mk)
include $(config_mk)

# build path
buildpath       ?= build
# questa library
library         ?= work
# dpi library
dpi_library     ?= work-dpi
# Top level module to compile
top_level       ?= tcdm_adapter_tb
# QuestaSim Version
questa_version  ?= 2021.2-bt
# QuestaSim command
questa_cmd      ?= questa-$(questa_version)
# QuestaSim arguments
questa_args     ?=
# Bender
bender          ?= $(INSTALL_DIR)/bender/bender

# Check if the specified QuestaSim version exists
ifeq (, $(shell which $(questa_cmd)))
  # Spaces are needed for indentation here!
  $(warning "Specified QuestaSim version ($(questa_cmd)) not found in PATH $(PATH)")
  questa_cmd =
endif

QUESTASIM_HOME ?= /usr/pack/questa-$(questa_version)/questasim

questa_args += -voptargs=+acc

questa_args += -suppress vsim-12070

vlog_args += -suppress vlog-2583 -suppress vlog-13314 -suppress vlog-13233
vlog_args += -work $(library)
# Defines
vlog_defs += -DNUM_CORES=$(num_cores) -DNUM_CORES_PER_TILE=$(num_cores_per_tile)
vlog_defs += -DL2_BASE="32'h$(l2_base)" -DL2_SIZE="32'h$(l2_size)"
vlog_defs += -DBOOT_ADDR="32'h$(boot_addr)" -DXPULPIMG="1'b$(xpulpimg)"

.DEFAULT_GOAL := compile

# Build path
$(buildpath):
	mkdir -p $(buildpath)

################
# Modelsim     #
################
# Library
.PHONY: lib
lib: $(buildpath) $(buildpath)/$(library)
$(buildpath)/$(library):
	cd $(buildpath) && $(questa_cmd) vlib $(library) && chmod +w modelsim.ini; $(questa_cmd) vmap $(library) $(library)

# Compilation
.PHONY: compile_tcdm
compile_tcdm: lib $(buildpath) $(buildpath)/compile.tcl
$(buildpath)/compile.tcl: $(bender) $(config_mk) Makefile Bender.yml $(shell find {../../src,../../tb,../../deps} -type f)
	$(bender) script vsim --vlog-arg="$(vlog_args)" $(vlog_defs) -t rtl -t tcdm_vsim > $(buildpath)/compile.tcl
	echo "exit" >> $(buildpath)/compile.tcl
	cd $(buildpath) && $(questa_cmd) vsim -work $(library) -c -do compile.tcl

.PHONY: sim_tcdm
sim_tcdm: compile_tcdm
	cd $(buildpath) && \
	$(questa_cmd) vsim -voptargs=+acc $(questa_args) $(library).$(top_level) -do ../wave_tcdm.tcl
	./../../scripts/return_status.sh $(buildpath)/transcript

.PHONY: simc_tcdm
simc_tcdm: compile_tcdm
	cd $(buildpath) && \
	$(questa_cmd) vsim -c $(questa_args) $(library).$(top_level) -do "run -a"
	./../../scripts/return_status.sh $(buildpath)/transcript

# Clean targets
.PHONY: clean
clean:
	rm Bender.lock
	rm -rf .bender
	rm -rf $(buildpath)
