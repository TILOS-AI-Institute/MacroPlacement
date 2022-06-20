deselectAll
foreach ptr [dbget top.markers ]  {
    set msg [dbget ${ptr}.message]
    set nets [ regexp -all -inline {(Net\s*\S*)} $msg ]
    foreach net $nets {
        regexp {Net\s+(\S*)} $net tmp net_name
        editDelete -net $net_name
        selectNet $net_name
    }
}
globalDetailRoute -select
ecoRoute -fix_drc
