#############################################################################
# This script was written and developed by ABKGroup students at UCSD.
# However, the underlying commands and reports are copyrighted by Cadence. 
# We thank Cadence for granting permission to share our research to help 
# promote and foster the next generation of innovators.
# Author: Sayak Kundu, ABKGroup, UCSD
#################################################################
# minCh:    If channel width is less than minCh it will be filled 
#           with hard blockages.
# layers:   Name of the layers.
# width:    Width of the layer.
# pitch:    Distance b/w two vdd/vss set.
# spacing:  Spacing b/w the stripe of vdd and vss.
# ldir:     Layer direction. 0 is horizontal and 1 is vertical.
# isMacro:  If layer stripe is only above macro.
# isBM:     If layer is below the top layer of macro.
# isAM:     If layer is above the top layer of macro.
# isFP:     If layer is for follow pin.
# soffset:  Start offset of the stripe.
# addch:    Any requierment to add extra layer in the macro
#           channel.
#################################################################

set nets [list VDD VSS]
#### Un Place Global Placed cells and cut Row ####
dbset [dbget top.insts.cell.subClass core -p2 ].pStatus unplaced
finishFloorplan -fillPlaceBlockage hard $minCh
cutRow
finishFloorplan -fillPlaceBlockage hard $minCh 
###################################################

############### Global Net Creation ###############
clearGlobalNets
globalNetConnect VDD -type pgpin -pin VDD -inst *   -override
globalNetConnect VSS -type pgpin -pin VSS -inst *   -override

######################## For SKY130HD  #######################
globalNetConnect VDD -type pgpin -pin VPWR -inst *   -override
globalNetConnect VSS -type pgpin -pin VGND -inst *   -override

# globalNetConnect VDD -type pgpin -pin VDDCE -inst *   -override
# globalNetConnect VDD -type pgpin -pin VDDPE -inst *   -override
# globalNetConnect VSS -type pgpin -pin VSSE -inst *   -override
# 
# globalNetConnect VDD -type pgpin -pin VNW -inst *   -override
# globalNetConnect VSS -type pgpin -pin VPW -inst *   -override

globalNetConnect VDD -type tiehi -all  -override
globalNetConnect VSS -type tielo -all  -override
####################################################

deselectAll
select_obj [dbget top.fplan.pBlkgs.name finishfp_place_blkg_* -p1]
deleteSelectedFromFPlan
deselectAll

setGenerateViaMode -auto true
generateVias
editDelete -type Special -net $nets 
setViaGenMode -ignore_DRC false
setViaGenMode -optimize_cross_via true
setViaGenMode -allow_wire_shape_change false
setViaGenMode -extend_out_wire_end false
setViaGenMode -viarule_preference generated

sroute

setAddStripeMode -orthogonal_only true -ignore_DRC false
setAddStripeMode -over_row_extension true

set prevLayer [lindex $layers 0]
set prevbl ""
set i 1
set lcount [llength $layers]
set flag1 0

while { $i < $lcount } {
    set lname [lindex $layers $i]
    set isfp [lindex $isFP $i]
    set wdth [lindex $width $i]
    set dir "vertical"
    
    if { [lindex $ldir $i] == 0 } {
        set dir "horizontal"
    }

    if { $isfp == 1 } {
        puts "Add follow pin creation script"
        deselectAll
        editSelect -layer [lindex $layers 0] -net $nets
        editDuplicate -layer_horizontal $lname
        deselectAll
        editSelect -layer $lname -net $nets
        editResize -to $wdth -side high -direction y -keep_center_line 1
        deselectAll
    } else {
        set isbm [lindex $isBM $i]
        set ism [lindex $isMacro $i]
        set isam [lindex $isAM $i]
        set spc [lindex $spacing $i]
        set ptch [lindex $pitch $i]
        set sofst [lindex $soffset $i]
        set isch [lindex $addch $i]

        setAddStripeMode -stacked_via_bottom_layer $prevLayer -stacked_via_top_layer $lname
        setAddStripeMode -inside_cell_only false
        setAddStripeMode -route_over_rows_only false
        setAddStripeMode -extend_to_closest_target area_boundary
        if { $isbm == 1 } {
            set prevbl $lname
            setAddStripeMode -route_over_rows_only true
            addStripe -layer $lname -direction $dir -nets $nets -width $wdth -spacing $spc \
                -start_offset $sofst -set_to_set_distance $ptch
            if { $isch == 1 } { 
                setAddStripeMode -extend_to_closest_target same_dir_stripe
                addStripe -layer $lname -direction $dir -nets $nets -width $wdth -spacing $spc \
                    -start_offset $sofst -set_to_set_distance $ptch -narrow_channel 1
            }
        } elseif { $ism == 1 } {
            setAddStripeMode -extend_to_closest_target none 
            setAddStripeMode -inside_cell_only true
            foreach mcell [dbget [dbget top.insts.cell.subClass block -p2 ].cell.name -u -e] {
                addStripe -layer $lname -direction $dir -nets $nets -width $wdth -spacing $spc \
                    -start_offset $sofst -set_to_set_distance $ptch -master $mcell
            }
            foreach inst [dbget [dbget top.insts.cell.subClass block -p2 ].name -e ] {
                createRouteBlk -inst $inst -cover -layer $prevLayer -name mcro_blk
            }
        } elseif { $isam == 1 } {
            if { $flag1 == 0 } {
                set flag1 1
                set prevLayer $prevbl
                setAddStripeMode -stacked_via_bottom_layer $prevLayer -stacked_via_top_layer $lname
            }
            addStripe -layer $lname -direction $dir -nets $nets -width $wdth -spacing $spc \
                -start_offset $sofst -set_to_set_distance $ptch -extend_to design_boundary
            if { $isch == 1 } {
                setAddStripeMode -extend_to_closest_target same_dir_stripe 
                addStripe -layer $lname -direction $dir -nets $nets -width $wdth -spacing $spc \
                    -start_offset $sofst -set_to_set_distance $ptch -narrow_channel 1
            }
        } else {
            puts "Layer:$lname is not routed"
        }
    }
    set prevLayer $lname
    set i [expr $i + 1]
}
deleteRouteBlk -name mcro_blk
# verify_connectivity -net $nets -geom_connect -no_antenna -error 0

# placeDesign -concurrent_macro changes the default placement 
# settings
setPlaceMode -place_opt_run_global_place full
