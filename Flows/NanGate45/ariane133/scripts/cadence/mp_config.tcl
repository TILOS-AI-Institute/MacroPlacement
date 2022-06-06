# This script was written and developed by ABKGroup students at UCSD; however, the underlying commands and reports are copyrighted by Cadence. 
# We thank Cadence for granting permission to share our research to help promote and foster the next generation of innovators.
##########################################
# Masterplan User Constraint File Template
##########################################

###########################################################
# Syntax Convention:                                      #
# [] means optional                                       #
# <> means filling with real value or name in your design #
# () indicates the unit name for your value               #
# | means OR                                              #
# {} is used to enclose a group of names (one or more)    #
# ... means more similar items                            #
###########################################################


###########################################################
# Version section (required on and after Innovus 10.1)  #
# If not provided, will be parsed as older format         #
# VERSION <N.N>                                           #
# For example:                                            #
###########################################################
VERSION 1.0


######################################################################
# Seed Section (optional) : one single line per seed                 #
# name=<seedName> [util=<float>] [createFence=true]\                 #
#    [minWHRatio=<float>] [maxWHRatio=<float>]\                      #
#    [minFenceToFenceSpace=<(um)>] [minFenceToCoreSpace=<(um)>]\     #
#    [minFenceToInsideMacroSpace=<(um)>]\                            #
#    [minFenceToOutsideMacroSpace=<(um)>]\                           #
#    [minInsideFenceMacroToMacroSpace=<(um)>]\                       #
#    [master=<nameOrOtherName>] [cloneOrient={R0|MX|MY|R180}]        #
# For example:                                                       #
######################################################################
BEGIN SEED
name=i_cache_subsystem/i_icache/sram_block_0__data_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_icache/sram_block_0__data_sram/genblk1_1__i_ram
name=i_cache_subsystem/i_icache/sram_block_0__tag_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_icache/sram_block_1__data_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_icache/sram_block_1__data_sram/genblk1_1__i_ram
name=i_cache_subsystem/i_icache/sram_block_1__tag_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_icache/sram_block_2__data_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_icache/sram_block_2__data_sram/genblk1_1__i_ram
name=i_cache_subsystem/i_icache/sram_block_2__tag_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_icache/sram_block_3__data_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_icache/sram_block_3__data_sram/genblk1_1__i_ram
name=i_cache_subsystem/i_icache/sram_block_3__tag_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_0__data_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_0__data_sram/genblk1_1__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_0__tag_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_1__data_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_1__data_sram/genblk1_1__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_1__tag_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_2__data_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_2__data_sram/genblk1_1__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_2__tag_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_3__data_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_3__data_sram/genblk1_1__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_3__tag_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_4__data_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_4__data_sram/genblk1_1__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_4__tag_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_5__data_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_5__data_sram/genblk1_1__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_5__tag_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_6__data_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_6__data_sram/genblk1_1__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_6__tag_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_7__data_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_7__data_sram/genblk1_1__i_ram
name=i_cache_subsystem/i_nbdcache/sram_block_7__tag_sram/genblk1_0__i_ram
name=i_cache_subsystem/i_nbdcache/valid_dirty_sram/genblk1_0__i_ram
END SEED


######################################################################
# MACRO section syntax  : one single line per macro                  #
# name=<InstOrCell> [minLeftSpace=<(um)>] [minRightSpace=<(um)>]\    #
#                   [minTopSpace=<(um)>] [minBottomSpace=<(um)>]\    #
#                   [orient={R0|MX|MY|R180|MX90|R90|R270|MY90}]\     #
#                   [isCell=true] [minMacroToCoreSpace=<(um)>]       #
# For example:                                                       #
######################################################################
BEGIN MACRO
name=fakeram45_256x16 orient={R0} isCell=true minRightSpace=10 minLeftSpace=10 minTopSpace=5 minBottomSpace=5
END MACRO


#################################################################################
# relative placement CONSTRAINT section syntax                                  #
# name=<HInstOrGroupOrHM> loc=<T|B|R|L|TL|TR|BL|BR|(x,y)>                       #
# name=<NewName> members={<Module1> <Module2> <Module3>..} [strength=Soft|Hard] #
# For example:                                                                  #
#################################################################################
BEGIN CONSTRAINT
END CONSTRAINT
