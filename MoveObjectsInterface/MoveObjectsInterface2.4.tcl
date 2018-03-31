#!/bin/sh
# Run wish from the users PATH \
exec wish -f "$0" ${1+"$@"}
option add *tearOff 0


set cwidth 400
set cheight 300
set bgcolor {#c0c0c0}
set cpad 4
set cborder 3
set gridPad [expr $cpad + $cborder]
global stimType

set cscreen [canvas .c -width $cwidth -height $cheight -background $bgcolor \
	-borderwidth $cborder -relief solid]

if {![info exists ocolor]} {set ocolor {#ffffff}}

#------------------------------------------------------------------------
proc MoveObj {object type x y} {
	global centerHorz
	global centerVert
	if {$type == "shape"} {
		.c coords $object [expr $x-$centerHorz] [expr $y-$centerVert] [expr $x+$centerHorz] [expr $y+$centerVert]
	} elseif {$type == "image"} {
		.c coords $object $x $y
	} 
	if {[info exists host]} {
	rmt_send $host "translateObj \$poly(0) $centx $centy; redraw"
	}
}


#------------------------------------------------------------------------

proc canvasCreate {shape horz vert} {
	global o
	global im
	global cwidth
	global cheight
	global ocolor
	global gridPad
	global centerHorz
	global centerVert

	set centerHorz [expr $horz/2]
	set centerVert [expr $vert/2]
	set x1 [expr $cwidth/2 - $centerHorz + $gridPad]
	set y1 [expr $cheight/2 - $centerVert + $gridPad]
	set x2 [expr $cwidth/2 + $centerHorz + $gridPad]
	set y2 [expr $cheight/2 + $centerVert + $gridPad]
	set o [.c create $shape $x1 $y1 $x2 $y2 -fill $ocolor -width 0]
}

#------------------------------------------------------------------------
proc DrawObj {stim} {
	global o
	global im
	global cscreen
	global cwidth
	global cheight
	global objSize
	global gridPad
	global stimType
	global stimTypeDetail
	global w
	global h
	
	set stimTypeDetail $stim
	
	puts stdout "objSize: $objSize"
	if {[info exists o]} {.c delete $o}
	if {[info exists im]} {unset $im}
	puts stdout $stim
	
	switch $stim {
		circle {
			set w $objSize
			set h $objSize
			
			set stimType shape
			canvasCreate oval $w $h
		}
		square {
			set w $objSize
			set h $objSize
			
			set stimType shape
			canvasCreate rect $w $h
		}
		horzLine {
			set w $objSize
			set h [expr $w/5]
			
			set stimType shape
			canvasCreate rect $w $h
		}
		vertLine {
			set h $objSize
			set w [expr $h/5]
	
			set stimType shape
			canvasCreate rect $w $h
		}		
		default {
			set img [image create photo -file $stim]
			set w [image width $img]
			set h [image height $img]
			set centerw [expr $w / 2]
			set centerh [expr $h / 2]
			
			set stimType image
			set o [$cscreen create image $centerw $centerh -image $img]
			.c coords $o 175 125
		}
	}


#-- leave @$ stuff in menu name for future use

	if {[info exists o] && $stimType == "shape"} {
		.c bind $o <B1-Motion>  {MoveObj $o $stimType %x %y}

		menu .menuObj@$o
		.menuObj@$o add command -label "Change color" -command "ChangeColor"		

		if {[tk windowingsystem]=="aqua"} {
			.c bind $o <2> "tk_popup .menuObj@$o %X %Y"
			.c bind $o <Control-1> "tk_popup .menuObj@$o %X %Y"
		} else {
			.c bind $o <3> "tk_popup .menuObj@$o %X %Y"
		}
	}
	if {[info exists o] && $stimType == "image"} {
		.c bind $o <B1-Motion> {MoveObj $o $stimType %x %y}

		global img
		menu .menu@$o
		.menu@$o add comm -label "Zoom 3x" -command {scaleImage $img 3}		
		.menu@$o add comm -label "Zoom 2x" -command {scaleImage $img 2}
		.menu@$o add comm -label "Shrink .5x" -command {scaleImage $img 0.5}
		.menu@$o add comm -label "Shrink .33x" -command {scaleImage $img 0.33}
		.menu@$o add separator
		.menu@$o add comm -label "Flip LR" -command {scaleImage $img -1 1}
		.menu@$o add comm -label "Flip TB" -command {scaleImage $img 1 -1}
		.menu@$o add comm -label "Flip both" -command {scaleImage $img -1 -1}	
		
		if {[tk windowingsystem]=="aqua"} {
			.c bind $o <2> "tk_popup .menu@$o %X %Y"
			.c bind $o <Control-1> "tk_popup .menu@$o %X %Y"
		} else {
			.c bind $o <3> "tk_popup .menu@$o %X %Y"
		}
	}
}


#------------------------------------------------------------------------

proc ChooseColor {changeWhat} {
	global ocolor
	global bgcolor
	global o
	global stimType
	
	switch $changeWhat {
		.b {
		    set ocolor \
        		[tk_chooseColor -initialcolor $ocolor -title "Choose a color" -parent .]
			.cbox configure -background $ocolor
			if {[info exists o] && $stimType == "shape"} {.c itemconfigure $o -fill $ocolor}
		}
		.cbg {
		    set bgcolor \
        		[tk_chooseColor -initialcolor $bgcolor -title "Choose a color" -parent .]
			.c configure -background $bgcolor
			.cbgbox configure -background $bgcolor
		}
	}
}

proc ChangeColor {} {
	global o
	global ocolor

    set ocolor \
        [tk_chooseColor -initialcolor $ocolor -title "Choose a different color" -parent .]
    	.c itemconfigure $o -fill $ocolor
}

#------------------------------------------------------------------------

proc dynamicSize {size} {
 	global o
	global stimType
	global centerHorz
	global centerVert
	global stimTypeDetail
	global w
	global h

	if {[info exists stimType] && [info exists o]} {
		if {$stimType == "image"} {return
		} elseif {$stimType == "shape"} {
			set objCoords [.c bbox $o]
			puts stdout "objCoords: $objCoords"
			set x1 [lindex $objCoords 0]
			set y1 [lindex $objCoords 1]
			set x2 [lindex $objCoords 2]
			set y2 [lindex $objCoords 3]
			set changex [expr (abs($x1 - $x2) - $w)/2]
			set changey [expr (abs($y1 - $y2) - $h)/2]
			set centerHorz [expr abs($changex)]
			set centerVert [expr abs($changey)]

			DrawObj $stimTypeDetail		
			.c coords $o [expr $x1 + $changex] [expr $y1 + $changey] [expr $x2 - $changex] [expr $y2 - $changey]

		}
	}
}	


#------------------------------------------------------------------------
scrollbar .sbar -width 12 -command ".stimlist yview"
listbox .stimlist -height 4 -width 15 -yscroll ".sbar set"
	.stimlist insert 0 circle square horzLine vertLine

bind .stimlist <Double-B1-ButtonRelease> {DrawObj [.stimlist get active]}
bind . <Control-h> { console show }

#------------------------------------------------------------------------

set types {
        {"Image Files"	{.gif .ppm .pnm} }
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
proc scaleImage {im xfactor {yfactor 0}} {
    set mode -subsample
    if {abs($xfactor) < 1} {
       set xfactor [expr round(1./$xfactor)]
    } elseif {$xfactor>=0 && $yfactor>=0} {
        set mode -zoom
    }
    if {$yfactor == 0} {set yfactor $xfactor}
    set t [image create photo]
    $t copy $im
    $im blank
    $im copy $t -shrink $mode $xfactor $yfactor
    image delete $t
}

#------------------------------------------------------------------------
#========================================================================

set objSize 50
ttk::button .cbg -text "Bg color" -command "ChooseColor .cbg"
button .cbgbox -background "#c0c0c0" -state disabled
ttk::button .b -text "Shape color" -command "ChooseColor .b"
button .cbox -background "white" -state disabled
ttk::separator .sep1 
scale .slide -orient horizontal  -from 20 -to 140 \
	-variable objSize -tickinterval 40 -command "dynamicSize "
ttk::separator .sep2
ttk::button .bselect -text "Add custom image" -command "LoadFile"
ttk::label .lslide -text "Shape size:"
ttk::label .llist -text "Double-click to draw:"

ttk::button .q -text "Quit" -command "destroy ."

#========================================================================
grid .c -row 0 -column 0 -padx "$cpad 2" -pady "$cpad $cpad" -rowspan 10 

#grid .cbg -row 0 -column 1 -padx {2 4} -pady {2 1} -columnspan 3 -sticky ew
grid .cbg -row 0 -column 1 -padx {2 1} -pady {1 0}  -sticky ew
grid .cbgbox -row 0 -column 2 -padx {6 4} -pady {1 0} -columnspan 2  -sticky ew
grid .b -row 1 -column 1 -padx {2 1} -pady {1 0}  -sticky ew
grid .cbox -row 1 -column 2 -padx {6 4} -pady {1 0} -columnspan 2  -sticky ew
grid .sep1 -row 2 -column 1  -padx {2 4} -pady {1 0} -columnspan 3 -sticky ew
grid .lslide -row 3 -column 1 -padx {2 4} -pady {0 0} -columnspan 3 -sticky ew
grid .slide -row 4 -column 1 -padx {2 4} -pady {0 2} -columnspan 3 -sticky ew
grid .sep2 -row 5 -column 1  -padx {2 4} -pady {0 0} -columnspan 3 -sticky ew
grid .llist -row 6 -column 1 -padx {2 4} -pady {2 0} -columnspan 3 -sticky ew
grid .stimlist -row 7 -column 1 -padx {2 0} -pady {0 2} -columnspan 2 -sticky news
grid .sbar -row 7 -column 3 -sticky news -padx {0 4} -pady {0 2} -sticky nsw

grid .bselect -row 8 -column 1 -padx {2 4} -pady {2 2} -columnspan 3 -sticky ew

grid .q -row 9 -column 1 -padx {2 2} -pady {2 2} -columnspan 3
