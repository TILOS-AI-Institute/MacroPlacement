###############################################################################
### Author:  Zhiang, May, 2022
### Uses OpenROAD API to generate clustered netlist (in def format)
### This file cannot be used directly.  It will be called by
### generate_cluster.py
### The Basic Idea:
###     We set the pin position of each cluster to the center of each cluster
###############################################################################
#-------------------------------------------------------
# Step 1 - Traverse all instances, check cluster id, 
# compute total instance area in each cluster
# ------------------------------------------------------
array set clusters_area {}
set all_insts [$block getInsts]
set dbu [$block getDefUnits]
puts "\[INFO\] def units: $dbu"

set unclustered 0
set total_unclustered_area 0

set total_instance_area 0
set num_clusters 0

foreach inst $all_insts {
    set master [$inst getMaster]
    set type   [$master getType]
    if { $type == "BLOCK"} {
        continue
    }
    
    set width [$master getWidth]
    set height [$master getHeight]
    set area [expr $width * $height]
    set total_instance_area [expr $total_instance_area + $area]

    set cluster_prop [odb::dbStringProperty_find $inst "cluster_id"]
    if { $cluster_prop == "NULL"} {
        set unclustered [expr $unclustered + 1]
        set total_unclustered_area [expr $total_unclustered_area + $area]
        puts "\[INFO\] unclustered instance:    [$inst getConstName]"
        continue
    }
    set cluster_id [$cluster_prop getValue]
    
    if {![info exists clusters_area($cluster_id)]} {
        set clusters_area($cluster_id) 0
        set num_clusters [expr $num_clusters + 1]
    }
    set clusters_area($cluster_id) [expr $clusters_area($cluster_id) + $area]
}

puts "\[INFO\] Num clusters: $num_clusters" 
puts "\[INFO\] Num unclustered instances: $unclustered"
puts "\[INFO\] Tot. unsclustered area: [expr $total_unclustered_area / ($dbu * $dbu)]"
puts "\[INFO\] Tot. inst area: [expr $total_instance_area / ($dbu * $dbu) ]"
#foreach {cluster_id cluster_area} [array get clusters_area] {
#    puts "\[INFO\] area of cluster_${cluster_id} : [expr $clusters_area($cluster_id) / ($dbu * $dbu) ]"
#}


#-------------------------------------------------------------------
# Step 2 - Create fake nets
#-------------------------------------------------------------------
puts "\[INFO\] Creating fake nets ..."
set fake_nets []
array set clusters_terms {  }
foreach {cluster_id cluster_area} [array get clusters_area] {
    set clusters_terms($cluster_id) []
}

set num_nets 0
foreach net [$block getNets] {
    set terms []
    set std_cell_clusters [  ]
    foreach bterm [$net getBTerms] {
        lappend terms [$bterm getConstName]
    }

    foreach iterm [$net getITerms] {
        set inst [$iterm getInst]
        set inst_name [$inst getName]
        set master [$inst getMaster]
        set type   [$master getType]
        if { $type == "BLOCK"} {
            set pin_name [[$iterm getMTerm] getName]
            lappend terms "${inst_name} ${pin_name}"
        } else {
            set cluster_prop [odb::dbStringProperty_find $inst "cluster_id"]
            if { $cluster_prop == "NULL" } {
                continue
            }
            set cluster_id [$cluster_prop getValue]
            lappend std_cell_clusters $cluster_id
            #set pin_id [llength $clusters_terms($cluster_id)]
            #set term_name "p_${pin_id}"
            #lappend clusters_terms($cluster_id) ${term_name}
            #lappend terms "cluster_${cluster_id} ${term_name}"
        }
    }
    
    set std_cell_clusters [lsort -unique $std_cell_clusters]
    foreach cluster_id $std_cell_clusters {
        set pin_id [llength $clusters_terms($cluster_id)]
        set term_name "p_${pin_id}"
        lappend clusters_terms($cluster_id) ${term_name}
        lappend terms "cluster_${cluster_id} ${term_name}"
    }

    set terms [lsort -unique $terms]
    if { [llength $terms] > 1 } {
        lappend fake_nets $terms
    }

    set num_nets [expr $num_nets + 1]
}

# There may multiple duplicate nets. The replication of each degree represents the weight of the net
puts "\[INFO\] [llength $fake_nets] nets after post-processing."


#--------------------------------------------------------------------------
# Step 3 - Create fake lef for each cluster
# We set the asepct ratio of each cluster to 1.0
# Each cluster only have one pin located at the center of the cluster
# The size of the pin is 100 dbu x 100 dbu
#--------------------------------------------------------------------------
set lib [lindex [$db getLibs] 0]
set all_rows [$block getRows]
set first_row [lindex $all_rows 0]
set site [$first_row getSite]
set site_width [$site getWidth]
set site_height [$site getHeight]
puts "\[INFO\] site_width: ${site_width}  site_height: ${site_height}"
set new_area 0 
set tech [$db getTech]
set first_routing_layer [$tech findRoutingLayer 2]
foreach {cluster_id cluster_area} [array get clusters_area] {
    set cluster_name cluster_${cluster_id}
    set master [odb::dbMaster_create $lib $cluster_name]
    set length [expr round(sqrt($cluster_area))]
    set width  [expr int(ceil($length / $site_width) * $site_width)]
    set height [expr int(ceil($length / $site_height) * $site_height)]
    #puts "\[INFO\] cluster_name:    $cluster_name  width:    $width   height:   $height"
    odb::dbMaster_setWidth $master $width
    odb::dbMaster_setHeight $master $height
    odb::dbMaster_setSite $master $site
    odb::dbMaster_setType $master "BLOCK"    
    set new_area [expr $height * $width + $new_area]
    foreach term $clusters_terms($cluster_id) {
        set mterm [odb::dbMTerm_create $master $term "INOUT"]
        set mpin [odb::dbMPin_create $mterm]
        set lx [expr int(floor($width / 2))]
        set ly [expr int(floor($height /2))]
        set ux [expr $lx + 100]
        set uy [expr $ly + 100]
        odb::dbBox_create $mpin $first_routing_layer $lx $ly $ux $uy
    }
    $master setFrozen
}

odb::write_lef $lib  $cluster_lef_file
puts "\[INFO\] Total cluster area: [expr $new_area / ($dbu * $dbu)]"
puts "\[INFO\] Finish creating fake lefs"

#-----------------------------------------------------------------
# Step 4 - Create fake block, instances and nets
#-----------------------------------------------------------------
# destory all the standard cell instances
foreach inst [$block getInsts] {
    set master [$inst getMaster]
    set inst_name [$inst getName]
    set type   [$master getType]
    if { $type != "BLOCK"} {
        odb::dbInst_destroy $inst
    } else  {
        odb::dbInst_destroy $inst
        odb::dbInst_create $block $master $inst_name
    }
}
 
foreach bterm [$block getBTerms] {
    $bterm disconnect
}
 
foreach net [$block getNets] {
    odb::dbNet_destroy $net
}
 

# create an instance for each standard cell cluster
foreach {cluster_id cluster_area} [array get clusters_area] {
    set cluster_name "cluster_${cluster_id}"
    set master [$db findMaster $cluster_name]
    odb::dbInst_create $block $master $cluster_name
}
 
 
set num_fake_nets 0
foreach net $fake_nets {
    set fake_net_name "n_${num_fake_nets}"
    # change the name of net if the net is connected to an IO pin
    foreach term $net {
        if { [$block findBTerm $term] != "NULL" } {
            set fake_net_name $term
            continue
        }
    }
 
    set fake_net [odb::dbNet_create $block $fake_net_name]
    foreach term $net {
        set bterm [$block findBTerm $term]
        if {$bterm != "NULL"} {
            odb::dbBTerm_connect $bterm $fake_net
        } else {
            lassign  [split $term] inst_name term_name
            set inst [$block findInst $inst_name]
            if {$inst == "NULL"} {
                puts "\[ERROR\] Instance ${inst_name} does not exist"
                continue
            }
            set iterm [$inst findITerm $term_name]
            odb::dbITerm_connect $iterm $fake_net
        }
    }
    set num_fake_nets [expr $num_fake_nets + 1]
}
 
puts "\[INFO\] Finish creating fake def"
odb::write_def $block $cluster_def_file

exit


