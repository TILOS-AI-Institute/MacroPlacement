## This script was written and developed by UCSD ABKGroup, 
## however, the underlying commands and reports are copyrighted
## by Cadence. We thank Cadence for granting permission to share
## our research to help promote and foster the next generation of
## innovators.

puts "VERSION 1.0"
set mem_hier ""
foreach a [dbget [dbget top.insts.cell.name fakeram45_* -p2 ].name ] {
    regexp {(.*)(/)([^/]*)} $a c b
    lappend mem_hier $b
}
set unique_mem_hier [lsort -unique $mem_hier]
puts "BEGIN SEED"
foreach a $unique_mem_hier {
puts "name=$a"
}
puts "END SEED"

puts "BEGIN MACRO"
foreach a [dbget top.insts.cell.name fakeram45_* -u] {
puts "name=$a  orient={R0} isCell=true minRightSpace=10 minLeftSpace=10 minTopSpace=5 minBottomSpace=5"
}
puts "END MACRO"

puts "BEGIN CONSTRAINT"
puts "END CONSTRAINT"
