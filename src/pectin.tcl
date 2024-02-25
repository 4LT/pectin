package require Tk 8.6

variable ::maps {}
variable ::paths {}
variable ::config {
    failureOnly 0
}

variable ::MAP_TYPES {
    {{Quake Map} {.bsp .BSP}}
}

proc configureBackground {win} {
    $win configure -background [ttk::style lookup Frame -background]
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

proc chooseDir {} {
    set dir [tk_chooseDirectory -mustexist 1]

    if {$dir != ""} {
        set ::paths [glob -nocomplain -types {f l} -join $dir {*.[Bb][Ss][Pp]}]
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

proc scaleDim {dim} {
    return [expr int(floor($dim / [tk scaling]))]
}

proc createAbout {} {
    toplevel .about -padx 10

    variable heading1 [font create -size 24]
    variable heading2 [font create -size 18]
    variable heading3 [font create -size 14]

    ttk::label .about.title -text "Licenses" -font $heading1 -anchor center
    grid .about.title -sticky ew -pady 14 -columnspan 3

    ttk::frame .about.f -relief sunken
    variable textArea [text .about.f.text -tabs {1c 2c} -wrap word] 

    if {[llength $::licenses] > 0} {
        variable titleSpace [scaleDim 24]
        variable usedBySpace [scaleDim 12]
        $textArea tag configure title -font $heading2 -spacing1 $titleSpace\
            -spacing3 $titleSpace
        $textArea tag configure usedBy -font $heading3 -spacing1 $usedBySpace\
            -spacing3 $usedBySpace
        $textArea tag configure usedByItem -font $heading3
        $textArea tag configure href -foreground #1010ff -underline 1

        foreach license $::licenses {
            variable name [dict get $license name]
            variable text [dict get $license text]
            variable usedBy [dict get $license usedBy]

            $textArea insert end "$name\n" title
            $textArea insert end "$text\n"
            $textArea insert end "Used by\n" usedBy

            foreach pkg $usedBy {
                variable crate [dict get $pkg crate]
                variable v [dict get $pkg version]
                variable href  [dict get $pkg href]

                $textArea insert end "\t$crate $v\n" usedByItem
                $textArea insert end "\t\t$href\n" href
            }
        }
    } else {
        $textArea insert end "No licenses found.\n"
    }

    $textArea configure -state disabled

    grid $textArea -sticky nesw
    grid columnconfigure .about.f 0 -weight 1
    grid rowconfigure .about.f 0 -weight 1
    grid .about.f -sticky nesw -columnspan 2

    ttk::scrollbar .about.scroll -orient vertical\
        -command [list $textArea yview]
    grid .about.scroll -sticky nesw -row 1 -column 2
    $textArea configure -yscrollcommand {.about.scroll set}

    ttk::button .about.ok -text "Ok" -command closeAbout
    grid .about.ok -column 1 -columnspan 2 -pady 10

    grid columnconfigure .about 0 -weight 1
    grid rowconfigure .about 1 -weight 1
    configureBackground .about
    
    closeAbout

    return [list .about $textArea]
}

proc closeAbout {} {
    wm forget .about
}

proc openAbout {} {
    wm manage .about
    wm protocol .about WM_DELETE_WINDOW closeAbout
    wm minsize .about [scaleDim 820] [scaleDim 800]
}

option add *Menu.tearOff 0
menu .m
menu .m.file 
menu .m.help

.m.file add command -label "Open Map(s)..." -underline 0 -accelerator "Ctrl+O"\
    -command chooseFiles
.m.file add command -label "Open Folder..." -accelerator "Ctrl+L"\
    -command chooseDir
.m.file add separator
.m.file add command -label "Exit" -underline 1 -accelerator "Alt+F4"\
    -command closePectin

.m.help add command -label About -underline 0 -accelerator "F1"\
    -command openAbout

.m add cascade -label File -underline 0 -menu .m.file
.m add cascade -label Help -underline 0 -menu .m.help
. configure -menu .m

bind all <Control-KeyPress-o> chooseFiles
bind all <Control-KeyPress-l> chooseDir
bind . <KeyPress-F1> openAbout
bind all <Alt-KeyPress-F4> {
    closePectin
    break
}

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

createAbout

wm title . Pectin
wm client . Pectin

wm protocol . WM_DELETE_WINDOW {
    closePectin
}
