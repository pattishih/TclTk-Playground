#!/bin/sh
# Run wish from the users PATH \
exec wish -f "$0" ${1+"$@"}

canvas .c -width 400 -height 300 -background {#c0c0c0} \
	-borderwidth 3 -relief solid

if {![info exists ocolor]} {set ocolor {#ffffff}}

#------------------------------------------------------------------------
proc MoveObj {object x y} {
  .c coords $object [expr $x-25] [expr $y-25] [expr $x+25] [expr $y+25]
}
#------------------------------------------------------------------------

#-----------------------------------------------------------------------------
#proc setLabel {color} {
#    .label configure -text $color -background $color
#}

scrollbar .sbar -width 12 -command ".stimlist yview"
listbox .stimlist -height 5 -width 16 -yscroll ".sbar set"

.stimlist insert 0 circle square line
bind .stimlist <ButtonPress-1> {enableDraw [.stimlist get active]}
bind .stimlist <Double-B1-ButtonRelease> {DrawObj [.stimlist get active]}




#-----------------------------------------------------------------------------
set name {no image}
set types {
        {"Image Files"	{.gif .bmp .png} }
        {"All files"	*}
}
proc LoadFile {} {
    global types
    global file
    set file [tk_getOpenFile -filetypes $types -multiple 1 -parent .]
    foreach i $file {
    	.stimlist insert end $i
    	puts stdout $i
    }
}


#------------------------------------------------------------------------


proc DrawObj {stim} {
	global o
	global ocolor
	if {[info exists o]} {.c delete $o}
	
	switch $stim {
		circle {
			set o [.c create oval 0 0 50 50 -fill $ocolor -width 0]
			.c coords $o 175 125 225 175
		}
		square {
			set o [.c create rectangle 0 0 50 50 -fill $ocolor -width 0]
			.c coords $o 175 125 225 175
		}
		line {
			set o [.c create line 0 0 50 50 -fill $ocolor -width 0]
			.c coords $o 175 125 225 175
		}
	}
	.c bind $o <B1-Motion>  {MoveObj $o %x %y}
	
#-- leave @$o in menu name for future use
	menu .menu@$o
	.menu@$o add command -label "Change color" -command "ChangeColor"
	
	if {[tk windowingsystem]=="aqua"} {
		.c bind $o <2> "tk_popup .menu@$o %X %Y"
		.c bind $o <Control-1> "tk_popup .menu@$o %X %Y"
	} else {
		.c bind $o <3> "tk_popup .menu@$o %X %Y"
	}

}


#------------------------------------------------------------------------
proc ChooseColor {} {
	global ocolor
    set ocolor \
        [tk_chooseColor -title "Choose a color" -parent .]
	.cbox configure -background $ocolor
}
proc ChangeColor {} {
	global o
    set ocolor \
        [tk_chooseColor -title "Choose a different color" -parent .]
    .c itemconfigure $o -fill $ocolor
}
#------------------------------------------------------------------------
#========================================================================
if {![info exists selContents]} {set selContents 2}

proc enableDraw {selection} {
	global selContents
	puts stdout "selection: $selection"
	puts stdout "selContents: $selContents"
	set selContents $selection

	.d state !disabled
}

ttk::button .bselect -text "Add stimulus..." -command "LoadFile"
ttk::label .blabel -text "(Default: white)"
button .b -text "Choose color" -command "ChooseColor"
button .cbox -background $ocolor -width 0 -state disabled
#ttk::button .d -text "Draw object" -command "DrawObj $selContents"
#	.d state disabled
ttk::button .q -text "Quit" -command "destroy ."

ttk::labelframe .lf1 -text "Choose object to display"




#========================================================================
grid .c -row 0 -column 0 -rowspan 10
grid .lf1 -row 0 -column 1 -rowspan 4

grid .bselect -row 0 -column 1 -padx {0 2} -pady {2 2} -columnspan 3
grid .stimlist -row 1 -column 1 -sticky news -padx {2 0} -pady {2 2} -columnspan 2
grid .sbar -row 1 -column 3 -sticky news -padx {0 4} -pady {2 2}
grid .b -row 2 -column 1 -padx {0 0} -pady {2 0}
grid .cbox -row 2 -column 2 -padx {0 4} -pady {2 0} -columnspan 2
grid .blabel -row 3 -column 1 -padx {0 0} -pady {0 2} -columnspan 3



grid .d -row 8 -column 1 -padx {2 2} -pady {2 2} -columnspan 3
grid .q -row 9 -column 1 -padx {2 2} -pady {2 2} -columnspan 3
