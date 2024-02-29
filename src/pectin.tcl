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
            variable expand [dict get $map expand]
            variable report [dict get $map report]
            variable parent [$treeView insert {} end\
                -text [dict get $map filename] -open $expand]
            variable anyFail 0

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
    variable maps [lmap path $::paths { build_report $path }]
    extendReportMetadata maps
    sortReports ::maps
    populateMaps .maps $::config $::maps
}

proc extendReportMetadata {mapsRef} {
    upvar $mapsRef maps
    variable map
    
    for {set idx 0} {$idx < [llength $maps]} {incr idx} {
        set map [lindex $maps $idx]
        dict set map expand 0
        lset maps $idx $map
    }
}

proc cacheMapExpand {treeview expand} {
    variable items [$treeview selection]
    variable count [llength $items]

    if {$count == 1} {
        variable filename [$treeview item [lindex $items 0] -text]
        variable map

        for {set idx 0} {$idx < [llength $::maps]} {incr idx} {
            set map [lindex $::maps $idx]

            if {[dict get $map filename] == $filename} {
                dict set map expand $expand
                lset ::maps $idx $map
                break
            }
        }
    }
}

proc failureFilterUpdate {} {
    if {[.filter instate selected]} {
        dict set ::config failureOnly 1
    } else {
        dict set ::config failureOnly 0
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
    return [expr int(floor($dim * [tk scaling]))]
}

proc createAbout {} {
    toplevel .about -padx 10

    variable heading1 [font create -size 24]
    variable heading2 [font create -size 18]
    variable heading3 [font create -size 14]

    ttk::label .about.bTitle -text "Build Info" -font $heading1 -anchor center
    grid .about.bTitle -sticky ew -pady 14 -columnspan 3

    ttk::frame .about.bFrame -relief sunken
    variable bText [text .about.bFrame.text -wrap word -height 6]

    $bText insert end "Pectin [dict get $::buildinfo version]\n"
    $bText insert end [string cat "Commit " [dict get $::buildinfo commit]\
        [if {[dict get $::buildinfo dirty]} {\
            string cat " DIRTY"\
        } {\
            string cat\
        }]\
    "\n"]
    $bText insert end "Branch [dict get $::buildinfo branch]\n"
    $bText insert end [string cat "Target " [dict get $::buildinfo target]\
        " (" [dict get $::buildinfo profile] ")\n"\
    ]
    $bText insert end "Repository [dict get $::buildinfo repo]\n"

    $bText configure -state disabled
    grid $bText -sticky nesw
    grid columnconfigure .about.bFrame 0 -weight 1
    grid rowconfigure .about.bFrame 0 -weight 1
    grid .about.bFrame -sticky nesw -columnspan 3

    ttk::button .about.copy -text "Copy to clipboard" -command {
        $bText tag add sel 1.0 end
        tk_textCopy $bText
    }
    grid .about.copy -column 1 -columnspan 2 -pady 10 -sticky e

    ttk::label .about.lTitle -text "Licenses" -font $heading1 -anchor center
    grid .about.lTitle -sticky ew -pady 14 -columnspan 3

    ttk::frame .about.lFrame -relief sunken
    variable lText [text .about.lFrame.text -tabs {1c 2c} -wrap word] 

    if {[llength $::licenses] > 0} {
        variable titleSpace [scaleDim 24]
        variable usedBySpace [scaleDim 12]
        variable usedByItemSpace [scaleDim 6]
        $lText tag configure title -font $heading2 -spacing1 $titleSpace\
            -spacing3 $titleSpace
        $lText tag configure usedBy -font $heading3 -spacing1 $usedBySpace\
            -spacing3 $usedBySpace
        $lText tag configure usedByItem -font $heading3\
            -spacing1 $usedByItemSpace -spacing3 $usedByItemSpace
        # $lText tag configure href -foreground #1010ff -underline 1

        foreach license $::licenses {
            variable name [dict get $license name]
            variable text [dict get $license text]
            variable usedBy [dict get $license usedBy]

            $lText insert end "$name\n" title
            $lText insert end "$text\n"
            $lText insert end "Used by\n" usedBy

            foreach pkg $usedBy {
                variable crate [dict get $pkg crate]
                variable v [dict get $pkg version]
                variable href  [dict get $pkg href]

                $lText insert end "\t$crate $v\n" usedByItem
                $lText insert end "\t\t$href\n" href
            }
        }
    } else {
        $lText insert end "No licenses found.\n"
    }

    $lText configure -state disabled
    grid $lText -sticky nesw
    grid columnconfigure .about.lFrame 0 -weight 1
    grid rowconfigure .about.lFrame 0 -weight 1
    grid .about.lFrame -sticky nesw -columnspan 2

    ttk::scrollbar .about.scroll -orient vertical\
        -command [list $lText yview]
    grid .about.scroll -sticky nesw -row 4 -column 2
    $lText configure -yscrollcommand {.about.scroll set}

    ttk::button .about.ok -text "Ok" -command closeAbout
    grid .about.ok -column 1 -columnspan 2 -pady 10 -sticky e

    grid columnconfigure .about 0 -weight 1
    grid rowconfigure .about 4 -weight 1
    configureBackground .about
    
    update
    closeAbout
}

proc closeAbout {} {
    wm forget .about
}

proc openAbout {} {
    wm manage .about
    wm title .about "Pectin - About"
    wm protocol .about WM_DELETE_WINDOW closeAbout
    wm minsize .about [scaleDim 500] [scaleDim 600]
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
bind .maps <<TreeviewOpen>> {cacheMapExpand .maps 1}
bind .maps <<TreeviewClose>> {cacheMapExpand .maps 0}

.scrolly configure -command {.maps yview}

ttk::checkbutton .filter -text "Show failures only" -padding {8 8 8 8}\
    -command failureFilterUpdate
.filter state !alternate

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
