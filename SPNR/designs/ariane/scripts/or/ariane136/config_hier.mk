include $(dir $(DESIGN_CONFIG))/config.mk


#export FLOW_VARIANT = hier
export FLOW_VARIANT ?= hier_rtlmp
export SYNTH_HIERARCHICAL = 1
export MAX_UNGROUP_SIZE = 100
export RTLMP_FLOW = True

export SDC_FILE      = ./designs/$(PLATFORM)/$(DESIGN_NICKNAME)/constraint_hier.sdc

export FLOORPLAN_DEF = ./results/$(PLATFORM)/$(DESIGN_NICKNAME)/$(FLOW_VARIANT)/2_2_floorplan_io.def
export ABC_CLOCK_PERIOD_IN_PS = 4000
#
# RTL_MP Settings
export RTLMP_MAX_INST = 5000
export RTLMP_MIN_INST = 1000
export RTLMP_MAX_MACRO = 12
export RTLMP_MIN_MACRO = 4

# These values must be multiples of placement site
export DIE_AREA    = 0 0 2000 2000
export CORE_AREA   = 10 10 1990 1990
export PLACE_PINS_ARGS = -exclude left:0-600 -exclude left:1400-2000 -exclude right:* -exclude top:* -exclude bottom:*

export MACRO_PLACE_HALO = 5 5
export MACRO_PLACE_CHANNEL = 10 10

export PLACE_DENSITY = 0.55
