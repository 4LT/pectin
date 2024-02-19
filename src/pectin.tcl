package require Tk 8.5
package require platform

set ::maps {}
set ::paths {}
set ::config {
    failureOnly 0
}

set ::MAP_TYPES {
    {{Quake Map} {.bsp .BSP}}
}

proc closePectin {} {
    destroy .
}

proc populateMaps {treeView config mapList} {
    foreach child [$treeView children {}] {
        $treeView delete $child
    }

    foreach map $mapList {
        set failureOnly [dict get $config failureOnly]

        if {[dict exists $map error]} {
            set label [dict get $map filename]
            set error [dict get $map error]
            set errorType [lindex $error 0]
            set errorMsg [lindex $error 1]
            set item [$treeView insert {} end -text $label -tags {error parent}]
            $treeView item $item -values [list "Error: $errorType" $errorMsg]
        } else {
            set report [dict get $map report]
            set parent [$treeView insert {} end -text [dict get $map filename]]
            set anyFail 0

            dict for {key val} $report {
                set condition [lindex $val 0]

                if {$failureOnly && $condition != "fail"} {
                    continue
                }

                set state [lindex $val 1]
                set item [$treeView insert $parent end -text $key -values\
                    [list $state {}]\
                ]

                if {$condition == "fail"} {
                    set anyFail 1
                    $treeView item $item -tags error -values [lrange $val 1 2]
                }
            }

            if {$anyFail} {
                $treeView item $parent -tags {error parent}
            } elseif {$failureOnly} {
                $treeView delete $parent
            }
        }
    }
}

proc refreshConfig {} {
    populateMaps .maps $::config $::maps
}

proc refreshPaths {} {
    set ::maps [lmap path $::paths { build_report $path }]
    sortReports ::maps
    populateMaps .maps $::config $::maps
}

proc failureFilterUpdate {} {
    if {[lsearch -exact [.filter state] selected] == -1} {
        dict set ::config failureOnly 0
    } else {
        dict set ::config failureOnly 1
    }

    refreshConfig
}

proc chooseFiles {} {
    set paths [tk_getOpenFile -filetypes $::MAP_TYPES -multiple 1]
    
    if {[llength $paths] > 0} {
        set ::paths $paths
        refreshPaths
    }
}

proc sortDict {d} {
    set newDict {}
    set keys [lsort -dictionary [dict keys $d]]

    foreach key $keys {
        dict append newDict $key [dict get $d $key]
    }

    return $newDict
}

proc sortMapReport {mapReport} {
    if {[dict exists $mapReport report]} {
        dict set mapReport report [sortDict [dict get $mapReport report]]
    }

    return $mapReport
}

proc sortReports {mapsVar} {
    set $mapsVar [lmap report [subst $$mapsVar] { sortMapReport $report }]
    set $mapsVar [lsort -command mapCmp [subst $$mapsVar]]
}

proc mapCmp {left right} {
    return [string compare -nocase\
        [dict get $left filename] [dict get $right filename]\
    ]
}

option add *Menu.tearOff 0
menu .m
menu .m.file
.m.file add command -label "Open Map(s)..." -command chooseFiles
.m.file add command -label "Open Folder..."
.m.file add separator
.m.file add command -label "Exit" -command closePectin
.m add cascade -label File -menu .m.file
. configure -menu .m

ttk::scrollbar .scrolly -orient vertical

ttk::treeview .maps -columns {state failure}\
    -yscrollcommand {.scrolly set}
.maps heading #0 -text Report
.maps heading state -text State
.maps heading failure -text "Failure details"
.maps tag configure error -foreground red

.scrolly configure -command {.maps yview}

ttk::checkbutton .filter -text "Show failures only" -padding {8 8 8 8}\
    -command failureFilterUpdate

grid .filter -sticky ew -columnspan 2
grid .maps .scrolly -sticky nesw
grid columnconfigure . 0 -weight 1
grid rowconfigure . 1 -weight 1

wm title . Pectin

wm protocol . WM_DELETE_WINDOW {
    closePectin
}
