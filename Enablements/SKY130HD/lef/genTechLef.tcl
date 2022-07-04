#!/usr/bin/tclsh

# SKY130HD

set results_dir [lindex $argv 0]
set libname [lindex $argv 1]
set beol [lindex $argv 2]

set results_dir "./"
set libname ""
set beol "9M_li_2Ma_2Mb_2Mc_2Md_1Me"


set num_stack [string range [lindex [split $beol "_"] 0] 0 end-1]


for {set i 2} {$i < [llength [split $beol "_"]]} {incr i} {
  dict set metal_map [string range [lindex [split $beol "_"] $i] 1 end] [string range [lindex [split $beol "_"] $i] 0 0]
}

set i 1
dict for {k v} $metal_map {
  for {set j 0} {$j < $v} {incr j} {
    dict set metal_type_map $i $k
    incr i
  }
}



set outputFile_lef "./${results_dir}/${beol}.tlef"
set output_lef [open $outputFile_lef "w"]


puts $output_lef "VERSION 5.7 ;"
puts $output_lef ""
puts $output_lef "BUSBITCHARS \"\[\]\" ;"
puts $output_lef "DIVIDERCHAR \"/\" ;"
puts $output_lef ""
puts $output_lef "UNITS"
puts $output_lef "  TIME NANOSECONDS 1 ;"
puts $output_lef "  CAPACITANCE PICOFARADS 1 ;"
puts $output_lef "  RESISTANCE OHMS 1 ;"
puts $output_lef "  DATABASE MICRONS 1000 ;"
puts $output_lef "END UNITS"
puts $output_lef ""
puts $output_lef "MANUFACTURINGGRID 0.005 ;"
puts $output_lef ""
puts $output_lef "PROPERTYDEFINITIONS"
puts $output_lef "  LAYER LEF58_TYPE STRING ;"
puts $output_lef "END PROPERTYDEFINITIONS"
puts $output_lef ""
puts $output_lef "SITE unithd"
puts $output_lef "  SYMMETRY Y ;"
puts $output_lef "  CLASS CORE ;"
puts $output_lef "  SIZE 0.46 BY 2.72 ;"
puts $output_lef "END unithd"
puts $output_lef ""
puts $output_lef "SITE unithddbl"
puts $output_lef "  SYMMETRY Y ;"
puts $output_lef "  CLASS CORE ;"
puts $output_lef "  SIZE 0.46 BY 5.44 ;"
puts $output_lef "END unithddbl"
puts $output_lef ""
puts $output_lef "LAYER nwell"
puts $output_lef "  TYPE MASTERSLICE ;"
puts $output_lef "  PROPERTY LEF58_TYPE \"TYPE NWELL ;\" ;"
puts $output_lef "END nwell"
puts $output_lef ""
puts $output_lef "LAYER pwell"
puts $output_lef "  TYPE MASTERSLICE ;"
puts $output_lef "  PROPERTY LEF58_TYPE \"TYPE PWELL ;\" ;"
puts $output_lef "END pwell"
puts $output_lef "LAYER Gate"
puts $output_lef "  TYPE MASTERSLICE ;"
puts $output_lef "END Gate"
puts $output_lef ""
puts $output_lef "LAYER Active"
puts $output_lef "  TYPE MASTERSLICE ;"
puts $output_lef "END Active"
puts $output_lef ""
puts $output_lef "LAYER li1"
puts $output_lef "  TYPE ROUTING ;"
puts $output_lef "  DIRECTION VERTICAL ;"
puts $output_lef ""
puts $output_lef "  PITCH 0.46 0.34 ;"
puts $output_lef "  OFFSET 0.23 0.17 ;"
puts $output_lef ""
puts $output_lef "  WIDTH 0.17 ;"
puts $output_lef "  SPACINGTABLE"
puts $output_lef "     PARALLELRUNLENGTH 0"
puts $output_lef "     WIDTH 0 0.17 ;"
puts $output_lef "  AREA 0.0561 ;"
puts $output_lef "  THICKNESS 0.1 ;"
puts $output_lef "  EDGECAPACITANCE 40.697E-6 ;"
puts $output_lef "  CAPACITANCE CPERSQDIST 36.9866E-6 ;"
puts $output_lef "  RESISTANCE RPERSQ 12.2 ;"
puts $output_lef ""
puts $output_lef "  ANTENNAMODEL OXIDE1 ;"
puts $output_lef "  ANTENNADIFFSIDEAREARATIO PWL ( ( 0 75 ) ( 0.0125 75 ) ( 0.0225 85.125 ) ( 22.5 10200 ) ) ;"
puts $output_lef "END li1"
puts $output_lef ""
puts $output_lef "LAYER mcon"
puts $output_lef "  TYPE CUT ;"
puts $output_lef ""
puts $output_lef "  WIDTH 0.17 ;"
puts $output_lef "  SPACING 0.19 ;"
puts $output_lef "  ENCLOSURE BELOW 0 0 ;"
puts $output_lef "  ENCLOSURE ABOVE 0.03 0.06 ;"
puts $output_lef ""
puts $output_lef "  ANTENNADIFFAREARATIO PWL ( ( 0 3 ) ( 0.0125 3 ) ( 0.0225 3.405 ) ( 22.5 408 ) ) ;"
puts $output_lef "  DCCURRENTDENSITY AVERAGE 0.36 ;"
puts $output_lef ""
puts $output_lef "END mcon"

### LAYER definition
for {set i 1} {$i <= $num_stack} {incr i} {
  set metal_name "met${i}"
  if {$i == 1} {
    set via_name "via"
  } else {
    set via_name "via${i}"
  }

  set metal_type [dict get $metal_type_map $i]

  if {[expr $i % 2] == 1} {
    set dir "HORIZONTAL"
  } else {
    set dir "VERTICAL"
  }

  puts $output_lef "LAYER $metal_name"
  puts $output_lef "  TYPE ROUTING ;"
  puts $output_lef "  DIRECTION $dir ;"
  puts $output_lef ""

  if {[string match $metal_type "Ma"]} {
    puts $output_lef "  PITCH 0.34 ;"
    puts $output_lef "  OFFSET 0.17 ;"
    puts $output_lef ""
    puts $output_lef "  WIDTH 0.14 ;"
    puts $output_lef "  SPACINGTABLE"
    puts $output_lef "     PARALLELRUNLENGTH 0"
    puts $output_lef "     WIDTH 0 0.14"
    puts $output_lef "     WIDTH 3 0.28 ;"
    puts $output_lef "  AREA 0.083 ;"
    puts $output_lef "  THICKNESS 0.35 ;"
    puts $output_lef "  MINENCLOSEDAREA 0.14 ;"
    puts $output_lef ""
    puts $output_lef "  ANTENNAMODEL OXIDE1 ;"
    puts $output_lef "  ANTENNADIFFSIDEAREARATIO PWL ( ( 0 400 ) ( 0.0125 400 ) ( 0.0225 2609 ) ( 22.5 11600 ) ) ;"
    puts $output_lef ""
    puts $output_lef "  EDGECAPACITANCE 40.567E-6 ;"
    puts $output_lef "  CAPACITANCE CPERSQDIST 25.7784E-6 ;"
    puts $output_lef "  DCCURRENTDENSITY AVERAGE 2.8 ;"
    puts $output_lef "  ACCURRENTDENSITY RMS 6.1 ;"
    puts $output_lef "  MAXIMUMDENSITY 70 ;"
    puts $output_lef "  DENSITYCHECKWINDOW 700 700 ;"
    puts $output_lef "  DENSITYCHECKSTEP 70 ;"
    puts $output_lef ""
    puts $output_lef "  RESISTANCE RPERSQ 0.125 ;"
  } elseif {[string match $metal_type "Mb"]} {
    puts $output_lef "  PITCH 0.46 ;"
    puts $output_lef "  OFFSET 0.23 ;"
    puts $output_lef ""
    puts $output_lef "  WIDTH 0.14 ; "
    puts $output_lef "  SPACINGTABLE"
    puts $output_lef "     PARALLELRUNLENGTH 0"
    puts $output_lef "     WIDTH 0 0.14"
    puts $output_lef "     WIDTH 3 0.28 ;"
    puts $output_lef "  AREA 0.0676 ;"
    puts $output_lef "  THICKNESS 0.35 ;"
    puts $output_lef "  MINENCLOSEDAREA 0.14 ;"
    puts $output_lef ""
    puts $output_lef "  EDGECAPACITANCE 37.759E-6 ;"
    puts $output_lef "  CAPACITANCE CPERSQDIST 16.9423E-6 ;"
    puts $output_lef "  RESISTANCE RPERSQ 0.125 ;"
    puts $output_lef "  DCCURRENTDENSITY AVERAGE 2.8 ;"
    puts $output_lef "  ACCURRENTDENSITY RMS 6.1 ;"
    puts $output_lef ""
    puts $output_lef "  ANTENNAMODEL OXIDE1 ;"
    puts $output_lef "  ANTENNADIFFSIDEAREARATIO PWL ( ( 0 400 ) ( 0.0125 400 ) ( 0.0225 2609 ) ( 22.5 11600 ) ) ;"
    puts $output_lef ""
    puts $output_lef "  MAXIMUMDENSITY 70 ;"
    puts $output_lef "  DENSITYCHECKWINDOW 700 700 ;"
    puts $output_lef "  DENSITYCHECKSTEP 70 ;"
  } elseif {[string match $metal_type "Mc"]} {
    puts $output_lef "  PITCH 0.68 ;"
    puts $output_lef "  OFFSET 0.34 ;"
    puts $output_lef ""
    puts $output_lef "  WIDTH 0.3 ;"
    puts $output_lef "  SPACINGTABLE"
    puts $output_lef "     PARALLELRUNLENGTH 0"
    puts $output_lef "     WIDTH 0 0.3"
    puts $output_lef "     WIDTH 3 0.4 ;"
    puts $output_lef "  AREA 0.24 ;              # Met3 6"
    puts $output_lef "  THICKNESS 0.8 ;"
    puts $output_lef ""
    puts $output_lef "  EDGECAPACITANCE 40.989E-6 ;"
    puts $output_lef "  CAPACITANCE CPERSQDIST 12.3729E-6 ;"
    puts $output_lef "  RESISTANCE RPERSQ 0.047 ;"
    puts $output_lef "  DCCURRENTDENSITY AVERAGE 6.8 ;"
    puts $output_lef "  ACCURRENTDENSITY RMS 14.9 ;"
    puts $output_lef ""
    puts $output_lef "  ANTENNAMODEL OXIDE1 ;"
    puts $output_lef "  ANTENNADIFFSIDEAREARATIO PWL ( ( 0 400 ) ( 0.0125 400 ) ( 0.0225 2609 ) ( 22.5 11600 ) ) ;"
    puts $output_lef ""
    puts $output_lef "  MAXIMUMDENSITY 70 ;"
    puts $output_lef "  DENSITYCHECKWINDOW 700 700 ;"
    puts $output_lef "  DENSITYCHECKSTEP 70 ;"
  } elseif {[string match $metal_type "Md"]} {
    puts $output_lef ""
    puts $output_lef "  PITCH 0.92 ;"
    puts $output_lef "  OFFSET 0.46 ;"
    puts $output_lef ""
    puts $output_lef "  WIDTH 0.3 ;"
    puts $output_lef "  SPACINGTABLE"
    puts $output_lef "     PARALLELRUNLENGTH 0"
    puts $output_lef "     WIDTH 0 0.3"
    puts $output_lef "     WIDTH 3 0.4 ;"
    puts $output_lef "  AREA 0.24 ;"
    puts $output_lef ""
    puts $output_lef "  THICKNESS 0.8 ;"
    puts $output_lef ""
    puts $output_lef "  EDGECAPACITANCE 36.676E-6 ;"
    puts $output_lef "  CAPACITANCE CPERSQDIST 8.41537E-6 ;"
    puts $output_lef "  RESISTANCE RPERSQ 0.047 ;"
    puts $output_lef "  DCCURRENTDENSITY AVERAGE 6.8 ;"
    puts $output_lef "  ACCURRENTDENSITY RMS 14.9 ;"
    puts $output_lef ""
    puts $output_lef "  ANTENNAMODEL OXIDE1 ;"
    puts $output_lef "  ANTENNADIFFSIDEAREARATIO PWL ( ( 0 400 ) ( 0.0125 400 ) ( 0.0225 2609 ) ( 22.5 11600 ) ) ;"
    puts $output_lef ""
    puts $output_lef "  MAXIMUMDENSITY 70 ;"
    puts $output_lef "  DENSITYCHECKWINDOW 700 700 ;"
    puts $output_lef "  DENSITYCHECKSTEP 70 ;"
  } elseif {[string match $metal_type "Me"]} {
    puts $output_lef ""
    puts $output_lef "  PITCH 3.4 ;"
    puts $output_lef "  OFFSET 1.7 ;"
    puts $output_lef ""
    puts $output_lef "  WIDTH 1.6 ;"
    puts $output_lef "  SPACINGTABLE"
    puts $output_lef "     PARALLELRUNLENGTH 0"
    puts $output_lef "     WIDTH 0 1.6 ;"
    puts $output_lef "  AREA 4 ;"
    puts $output_lef ""
    puts $output_lef "  THICKNESS 1.2 ;"
    puts $output_lef ""
    puts $output_lef "  EDGECAPACITANCE 38.851E-6 ;"
    puts $output_lef "  CAPACITANCE CPERSQDIST 6.32063E-6 ;"
    puts $output_lef "  RESISTANCE RPERSQ 0.0285 ;"
    puts $output_lef "  DCCURRENTDENSITY AVERAGE 10.17 ;"
    puts $output_lef "  ACCURRENTDENSITY RMS 22.34 ;"
    puts $output_lef ""
    puts $output_lef "  ANTENNAMODEL OXIDE1 ;"
    puts $output_lef "  ANTENNADIFFSIDEAREARATIO PWL ( ( 0 400 ) ( 0.0125 400 ) ( 0.0225 2609 ) ( 22.5 11600 ) ) ;"
  }
  puts $output_lef "END $metal_name"

  if {$i != $num_stack} {
    puts $output_lef "LAYER $via_name"
    puts $output_lef "  TYPE CUT ;"

    if {[string match $metal_type "Ma"]} {
      puts $output_lef "  WIDTH 0.15 ; "
      puts $output_lef "  SPACING 0.17 ;"
      puts $output_lef "  ENCLOSURE BELOW 0.055 0.085 ;"
      puts $output_lef "  ENCLOSURE ABOVE 0.055 0.085 ;"
      puts $output_lef "  ANTENNADIFFAREARATIO PWL ( ( 0 6 ) ( 0.0125 6 ) ( 0.0225 6.81 ) ( 22.5 816 ) ) ;"
      puts $output_lef "  DCCURRENTDENSITY AVERAGE 0.29 ;"
    } elseif {[string match $metal_type "Mb"]} {
      puts $output_lef "  WIDTH 0.2 ;"
      puts $output_lef "  SPACING 0.2 ;"
      puts $output_lef "  ENCLOSURE BELOW 0.04 0.085 ;"
      puts $output_lef "  ENCLOSURE ABOVE 0.065 0.065 ;"
      puts $output_lef "  ANTENNADIFFAREARATIO PWL ( ( 0 6 ) ( 0.0125 6 ) ( 0.0225 6.81 ) ( 22.5 816 ) ) ;"
      puts $output_lef "  DCCURRENTDENSITY AVERAGE 0.48 ;"
    } elseif {[string match $metal_type "Mc"]} {
      puts $output_lef "  WIDTH 0.2 ;"
      puts $output_lef "  SPACING 0.2 ;"
      puts $output_lef "  ENCLOSURE BELOW 0.06 0.09 ;"
      puts $output_lef "  ENCLOSURE ABOVE 0.065 0.065 ;"
      puts $output_lef "  ANTENNADIFFAREARATIO PWL ( ( 0 6 ) ( 0.0125 6 ) ( 0.0225 6.81 ) ( 22.5 816 ) ) ;"
      puts $output_lef "  DCCURRENTDENSITY AVERAGE 0.48 ;"
    } elseif {[string match $metal_type "Md"]} {
      puts $output_lef "  WIDTH 0.8 ;"
      puts $output_lef "  SPACING 0.8 ;"
      puts $output_lef "  ENCLOSURE BELOW 0.19 0.19 ;"
      puts $output_lef "  ENCLOSURE ABOVE 0.31 0.31 ;"
      puts $output_lef "  ANTENNADIFFAREARATIO PWL ( ( 0 6 ) ( 0.0125 6 ) ( 0.0225 6.81 ) ( 22.5 816 ) ) ;"
      puts $output_lef "  DCCURRENTDENSITY AVERAGE 2.49 ;"
    }
    puts $output_lef "END $via_name"
  }

}


puts $output_lef "### Routing via cells section   ###"
puts $output_lef "# Plus via rule, metals are along the prefered direction"
puts $output_lef "VIA L1M1_PR DEFAULT"
puts $output_lef "  LAYER mcon ;"
puts $output_lef "  RECT -0.085 -0.085 0.085 0.085 ;"
puts $output_lef "  LAYER li1 ;"
puts $output_lef "  RECT -0.085 -0.085 0.085 0.085 ;"
puts $output_lef "  LAYER met1 ;"
puts $output_lef "  RECT -0.145 -0.115 0.145 0.115 ;"
puts $output_lef "END L1M1_PR"
puts $output_lef ""
puts $output_lef "VIARULE L1M1_PR GENERATE"
puts $output_lef "  LAYER li1 ;"
puts $output_lef "  ENCLOSURE 0 0 ;"
puts $output_lef "  LAYER met1 ;"
puts $output_lef "  ENCLOSURE 0.06 0.03 ;"
puts $output_lef "  LAYER mcon ;"
puts $output_lef "  RECT -0.085 -0.085 0.085 0.085 ;"
puts $output_lef "  SPACING 0.36 BY 0.36 ;"
puts $output_lef "END L1M1_PR"
puts $output_lef ""
puts $output_lef "# Plus via rule, metals are along the non prefered direction"
puts $output_lef "VIA L1M1_PR_R DEFAULT"
puts $output_lef "  LAYER mcon ;"
puts $output_lef "  RECT -0.085 -0.085 0.085 0.085 ;"
puts $output_lef "  LAYER li1 ;"
puts $output_lef "  RECT -0.085 -0.085 0.085 0.085 ;"
puts $output_lef "  LAYER met1 ;"
puts $output_lef "  RECT -0.115 -0.145 0.115 0.145 ;"
puts $output_lef "END L1M1_PR_R"
puts $output_lef ""
puts $output_lef "VIARULE L1M1_PR_R GENERATE"
puts $output_lef "  LAYER li1 ;"
puts $output_lef "  ENCLOSURE 0 0 ;"
puts $output_lef "  LAYER met1 ;"
puts $output_lef "  ENCLOSURE 0.03 0.06 ;"
puts $output_lef "  LAYER mcon ;"
puts $output_lef "  RECT -0.085 -0.085 0.085 0.085 ;"
puts $output_lef "  SPACING 0.36 BY 0.36 ;"
puts $output_lef "END L1M1_PR_R"
puts $output_lef ""
puts $output_lef "# Minus via rule, lower layer metal is along prefered direction"
puts $output_lef "VIA L1M1_PR_M DEFAULT"
puts $output_lef "  LAYER mcon ;"
puts $output_lef "  RECT -0.085 -0.085 0.085 0.085 ;"
puts $output_lef "  LAYER li1 ;"
puts $output_lef "  RECT -0.085 -0.085 0.085 0.085 ;"
puts $output_lef "  LAYER met1 ;"
puts $output_lef "  RECT -0.115 -0.145 0.115 0.145 ;"
puts $output_lef "END L1M1_PR_M"
puts $output_lef ""
puts $output_lef "VIARULE L1M1_PR_M GENERATE"
puts $output_lef "  LAYER li1 ;"
puts $output_lef "  ENCLOSURE 0 0 ;"
puts $output_lef "  LAYER met1 ;"
puts $output_lef "  ENCLOSURE 0.03 0.06 ;"
puts $output_lef "  LAYER mcon ;"
puts $output_lef "  RECT -0.085 -0.085 0.085 0.085 ;"
puts $output_lef "  SPACING 0.36 BY 0.36 ;"
puts $output_lef "END L1M1_PR_M"
puts $output_lef ""
puts $output_lef "# Minus via rule, upper layer metal is along prefered direction"
puts $output_lef "VIA L1M1_PR_MR DEFAULT"
puts $output_lef "  LAYER mcon ;"
puts $output_lef "  RECT -0.085 -0.085 0.085 0.085 ;"
puts $output_lef "  LAYER li1 ;"
puts $output_lef "  RECT -0.085 -0.085 0.085 0.085 ;"
puts $output_lef "  LAYER met1 ;"
puts $output_lef "  RECT -0.145 -0.115 0.145 0.115 ;"
puts $output_lef "END L1M1_PR_MR"
puts $output_lef ""
puts $output_lef "VIARULE L1M1_PR_MR GENERATE"
puts $output_lef "  LAYER li1 ;"
puts $output_lef "  ENCLOSURE 0 0 ;"
puts $output_lef "  LAYER met1 ;"
puts $output_lef "  ENCLOSURE 0.06 0.03 ;"
puts $output_lef "  LAYER mcon ;"
puts $output_lef "  RECT -0.085 -0.085 0.085 0.085 ;"
puts $output_lef "  SPACING 0.36 BY 0.36 ;"
puts $output_lef "END L1M1_PR_MR"
puts $output_lef ""
puts $output_lef "# Centered via rule, we really do not want to use it"
puts $output_lef "VIA L1M1_PR_C DEFAULT"
puts $output_lef "  LAYER mcon ;"
puts $output_lef "  RECT -0.085 -0.085 0.085 0.085 ;"
puts $output_lef "  LAYER li1 ;"
puts $output_lef "  RECT -0.085 -0.085 0.085 0.085 ;"
puts $output_lef "  LAYER met1 ;"
puts $output_lef "  RECT -0.145 -0.145 0.145 0.145 ;"
puts $output_lef "END L1M1_PR_C"
puts $output_lef ""
puts $output_lef "VIARULE L1M1_PR_C GENERATE"
puts $output_lef "  LAYER li1 ;"
puts $output_lef "  ENCLOSURE 0 0 ;"
puts $output_lef "  LAYER met1 ;"
puts $output_lef "  ENCLOSURE 0.06 0.06 ;"
puts $output_lef "  LAYER mcon ;"
puts $output_lef "  RECT -0.085 -0.085 0.085 0.085 ;"
puts $output_lef "  SPACING 0.36 BY 0.36 ;"
puts $output_lef "END L1M1_PR_C"


### VIA and VIARULE
for {set i 1} {$i < $num_stack} {incr i} {
  set metal_name "met${i}"
  set metal_name_u "met[expr ${i}+1]"
  if {$i == 1} {
    set via_name "via"
  } else {
    set via_name "via${i}"
  }

  set metal_type [dict get $metal_type_map $i]
  set metal_type_u [dict get $metal_type_map [expr $i+1]]

  if {[expr $i % 2] == 1} {
    set dir "HORIZONTAL"
  } else {
    set dir "VERTICAL"
  }

  if {[string match $metal_type "Ma"]} {
    set via_width 0.150
    set via_spc 0.170
    set enc_l_1 0.055
    set enc_l_2 0.085
    set enc_u_1 0.055
    set enc_u_2 0.085
  } elseif {[string match $metal_type "Mb"]} {
    set via_width 0.2
    set via_spc 0.2
    set enc_l_1 0.04
    set enc_l_2 0.085
    set enc_u_1 0.065
    set enc_u_2 0.065
  } elseif {[string match $metal_type "Mc"]} {
    set via_width 0.2
    set via_spc 0.2
    set enc_l_1 0.06
    set enc_l_2 0.09
    set enc_u_1 0.065
    set enc_u_2 0.065
  } elseif {[string match $metal_type "Md"]} {
    set via_width 0.8
    set via_spc 0.8
    set enc_l_1 0.19
    set enc_l_2 0.19
    set enc_u_1 0.31
    set enc_u_2 0.31
  } 

  #if not transition via
  #if {[string match $metal_type $metal_type_u]} {
  #  set enc_u_1 $enc_l_1
  #  set enc_u_2 $enc_l_2
  #}


  set via_prefix "M${i}M[expr $i+1]"
  set spc [expr $via_width + $via_spc]
  set half_width [format %.3f [expr $via_width/2.0]]
  set rect_l_1 [format %.3f [expr $half_width + $enc_l_1]]
  set rect_l_2 [format %.3f [expr $half_width + $enc_l_2]]
  set rect_u_1 [format %.3f [expr $half_width + $enc_u_1]]
  set rect_u_2 [format %.3f [expr $half_width + $enc_u_2]]

  puts $output_lef "# Plus via rule, metals are along the prefered direction"
  puts $output_lef "VIA ${via_prefix}_PR DEFAULT"
  puts $output_lef "  LAYER ${via_name} ;"
  puts $output_lef "  RECT -${half_width} -${half_width} ${half_width} ${half_width} ;"
  puts $output_lef "  LAYER ${metal_name} ;"
  puts $output_lef "  RECT -${rect_l_2} -${rect_l_1} ${rect_l_2} ${rect_l_1} ;"
  puts $output_lef "  LAYER ${metal_name_u} ;"
  puts $output_lef "  RECT -${rect_u_1} -${rect_u_2} ${rect_u_1} ${rect_u_2} ;"
  puts $output_lef "END ${via_prefix}_PR"
  puts $output_lef ""
  puts $output_lef "VIARULE ${via_prefix}_PR GENERATE"
  puts $output_lef "  LAYER ${metal_name} ;"
  puts $output_lef "  ENCLOSURE ${enc_l_2} ${enc_l_1} ;"
  puts $output_lef "  LAYER ${metal_name_u} ;"
  puts $output_lef "  ENCLOSURE ${enc_u_1} ${enc_u_2} ;"
  puts $output_lef "  LAYER ${via_name} ;"
  puts $output_lef "  RECT -${half_width} -${half_width} ${half_width} ${half_width} ;"
  puts $output_lef "  SPACING $spc BY $spc ;"
  puts $output_lef "END ${via_prefix}_PR"
  puts $output_lef ""
  puts $output_lef "# Plus via rule, metals are along the non prefered direction"
  puts $output_lef "VIA ${via_prefix}_PR_R DEFAULT"
  puts $output_lef "  LAYER ${via_name} ;"
  puts $output_lef "  RECT -${half_width} -${half_width} ${half_width} ${half_width} ;"
  puts $output_lef "  LAYER ${metal_name} ;"
  puts $output_lef "  RECT -${rect_l_1} -${rect_l_2} ${rect_l_1} ${rect_l_2} ;"
  puts $output_lef "  LAYER ${metal_name_u} ;"
  puts $output_lef "  RECT -${rect_u_2} -${rect_u_1} ${rect_u_2} ${rect_u_1} ;"
  puts $output_lef "END ${via_prefix}_PR_R"
  puts $output_lef ""
  puts $output_lef "VIARULE ${via_prefix}_PR_R GENERATE"
  puts $output_lef "  LAYER ${metal_name} ;"
  puts $output_lef "  ENCLOSURE ${enc_l_1} ${enc_l_2} ;"
  puts $output_lef "  LAYER ${metal_name_u} ;"
  puts $output_lef "  ENCLOSURE ${enc_u_2} ${enc_u_1} ;"
  puts $output_lef "  LAYER ${via_name} ;"
  puts $output_lef "  RECT -${half_width} -${half_width} ${half_width} ${half_width} ;"
  puts $output_lef "  SPACING $spc BY $spc ;"
  puts $output_lef "END ${via_prefix}_PR_R"
  puts $output_lef ""
  puts $output_lef "# Minus via rule, lower layer metal is along prefered direction"
  puts $output_lef "VIA ${via_prefix}_PR_M DEFAULT"
  puts $output_lef "  LAYER ${via_name} ;"
  puts $output_lef "  RECT -${half_width} -${half_width} ${half_width} ${half_width} ;"
  puts $output_lef "  LAYER ${metal_name} ;"
  puts $output_lef "  RECT -${rect_l_2} -${rect_l_1} ${rect_l_2} ${rect_l_1} ;"
  puts $output_lef "  LAYER ${metal_name_u} ;"
  puts $output_lef "  RECT -${rect_u_2} -${rect_u_1} ${rect_u_2} ${rect_u_1} ;"
  puts $output_lef "END ${via_prefix}_PR_M"
  puts $output_lef ""
  puts $output_lef "VIARULE ${via_prefix}_PR_M GENERATE"
  puts $output_lef "  LAYER ${metal_name} ;"
  puts $output_lef "  ENCLOSURE ${enc_l_2} ${enc_l_1} ;"
  puts $output_lef "  LAYER ${metal_name_u} ;"
  puts $output_lef "  ENCLOSURE ${enc_u_2} ${enc_u_1} ;"
  puts $output_lef "  LAYER ${via_name} ;"
  puts $output_lef "  RECT -${half_width} -${half_width} ${half_width} ${half_width} ;"
  puts $output_lef "  SPACING $spc BY $spc ;"
  puts $output_lef "END ${via_prefix}_PR_M"
  puts $output_lef ""
  puts $output_lef "# Minus via rule, upper layer metal is along prefered direction"
  puts $output_lef "VIA ${via_prefix}_PR_MR DEFAULT"
  puts $output_lef "  LAYER ${via_name} ;"
  puts $output_lef "  RECT -${half_width} -${half_width} ${half_width} ${half_width} ;"
  puts $output_lef "  LAYER ${metal_name};"
  puts $output_lef "  RECT -${rect_l_1} -${rect_l_2} ${rect_l_1} ${rect_l_2} ;"
  puts $output_lef "  LAYER ${metal_name_u} ;"
  puts $output_lef "  RECT -${rect_u_1} -${rect_u_2} ${rect_u_1} ${rect_u_2} ;"
  puts $output_lef "END ${via_prefix}_PR_MR"
  puts $output_lef ""
  puts $output_lef "VIARULE ${via_prefix}_PR_MR GENERATE"
  puts $output_lef "  LAYER ${metal_name} ;"
  puts $output_lef "  ENCLOSURE ${enc_l_1} ${enc_l_2} ;"
  puts $output_lef "  LAYER ${metal_name_u} ;"
  puts $output_lef "  ENCLOSURE ${enc_u_1} ${enc_u_2} ;"
  puts $output_lef "  LAYER ${via_name} ;"
  puts $output_lef "  RECT -${half_width} -${half_width} ${half_width} ${half_width} ;"
  puts $output_lef "  SPACING $spc BY $spc ;"
  puts $output_lef "END ${via_prefix}_PR_MR"
  puts $output_lef ""
  puts $output_lef "# Centered via rule, we really do not want to use it"
  puts $output_lef "VIA ${via_prefix}_PR_C DEFAULT"
  puts $output_lef "  LAYER ${via_name} ;"
  puts $output_lef "  RECT -${half_width} -${half_width} ${half_width} ${half_width} ;"
  puts $output_lef "  LAYER ${metal_name} ;"
  puts $output_lef "  RECT -${rect_l_2} -${rect_l_2} ${rect_l_2} ${rect_l_2} ;"
  puts $output_lef "  LAYER ${metal_name_u} ;"
  puts $output_lef "  RECT -${rect_u_2} -${rect_u_2} ${rect_u_2} ${rect_u_2} ;"
  puts $output_lef "END ${via_prefix}_PR_C"
  puts $output_lef ""
  puts $output_lef "VIARULE ${via_prefix}_PR_C GENERATE"
  puts $output_lef "  LAYER ${metal_name} ;"
  puts $output_lef "  ENCLOSURE ${enc_l_2} ${enc_l_2} ;"
  puts $output_lef "  LAYER ${metal_name_u} ;"
  puts $output_lef "  ENCLOSURE ${enc_u_2} ${enc_u_2} ;"
  puts $output_lef "  LAYER ${via_name} ;"
  puts $output_lef "  RECT -${half_width} -${half_width} ${half_width} ${half_width} ;"
  puts $output_lef "  SPACING $spc BY $spc ;"
  puts $output_lef "END ${via_prefix}_PR_C"

}
 
puts $output_lef "END LIBRARY"

close $output_lef

