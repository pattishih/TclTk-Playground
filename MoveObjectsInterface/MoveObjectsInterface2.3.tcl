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

set cscreen [canvas .c -width $cwidth -height $cheight -background $bgcolor \
	-borderwidth $cborder -relief solid]

if {![info exists ocolor]} {set ocolor {#ffffff}}

#-----------------------------------------------------------------------------
scrollbar .sbar -width 12 -command ".stimlist yview"
listbox .stimlist -height 4 -width 16 -yscroll ".sbar set"

.stimlist insert 0 circle square horzLine vertLine
bind .stimlist <Double-B1-ButtonRelease> {DrawObj [.stimlist get active]}

#-----------------------------------------------------------------------------
set name {no image}
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
#------------------------------------------------------------------------
proc MoveObj {object x y} {
	global horz2
	global vert2
	.c coords $object [expr $x-$horz2] [expr $y-$vert2] [expr $x+$horz2] [expr $y+$vert2]
}

proc MoveObjImg {object x y} {
  .c coords $object $x $y
}
#------------------------------------------------------------------------
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

proc DrawObj {stim} {
	global o
	global im
	global ocolor
	global cscreen
	global cwidth
	global cheight
	global objSize
	global gridPad
	
	puts stdout "objSize: $objSize"
	if {[info exists o]} {.c delete $o}
	if {[info exists im]} {.c delete $im}
	puts stdout $stim
	
	switch $stim {
		circle {
			global horz2
			global vert2
			set horz $objSize
			set vert $objSize
			set horz2 [expr $horz/2]
			set vert2 [expr $vert/2]
			set x1 [expr $cwidth/2 - $horz2 + $gridPad]
			set y1 [expr $cheight/2 - $vert2 + $gridPad]
			set x2 [expr $cwidth/2 + $horz2 + $gridPad]
			set y2 [expr $cheight/2 + $vert2 + $gridPad]
			set o [.c create oval $x1 $y1 $x2 $y2 -fill $ocolor -width 0]
		}
		square {
			global horz2
			global vert2
			set horz $objSize
			set vert $objSize
			set horz2 [expr $horz/2]
			set vert2 [expr $vert/2]
			set x1 [expr $cwidth/2 - $horz2 + $gridPad]
			set y1 [expr $cheight/2 - $vert2 + $gridPad]
			set x2 [expr $cwidth/2 + $horz2 + $gridPad]
			set y2 [expr $cheight/2 + $vert2 + $gridPad]		
			set o [.c create rect $x1 $y1 $x2 $y2 -fill $ocolor -width 0]
		}
		horzLine {
			global horz2
			global vert2
			set horz $objSize
			set vert [expr $horz/5]
			set horz2 [expr $horz/2]
			set vert2 [expr $vert/2]
			set x1 [expr $cwidth/2 - $horz2 + $gridPad]
			set y1 [expr $cheight/2 - $vert2 + $gridPad]
			set x2 [expr $cwidth/2 + $horz2 + $gridPad]
			set y2 [expr $cheight/2 + $vert2 + $gridPad]		
			set o [.c create rect $x1 $y1 $x2 $y2 -fill $ocolor -width 0]

		}
		vertLine {
			global horz2
			global vert2
			set vert $objSize
			set horz [expr $vert/5]
			set horz2 [expr $horz/2]
			set vert2 [expr $vert/2]
			set x1 [expr $cwidth/2 - $horz2 + $gridPad]
			set y1 [expr $cheight/2 - $vert2 + $gridPad]
			set x2 [expr $cwidth/2 + $horz2 + $gridPad]
			set y2 [expr $cheight/2 + $vert2 + $gridPad]
			set o [.c create rect $x1 $y1 $x2 $y2 -fill $ocolor -width 0]
		}		
		default {
			global img
			set img [image create photo -file $stim]
			set w [image width $img]
			set h [image height $img]
			set centerw [expr $w / 2]
			set centerh [expr $h / 2]

			set im [$cscreen create image $centerw $centerh -image $img]
			.c coords $im 175 125
		}
	}


#-- leave @$ stuff in menu name for future use

	if {[info exists o]} {
		.c bind $o <B1-Motion>  {MoveObj $o %x %y}

		menu .menuObj@$o
		.menuObj@$o add command -label "Change color" -command "ChangeColor"		

		if {[tk windowingsystem]=="aqua"} {
			.c bind $o <2> "tk_popup .menuObj@$o %X %Y"
			.c bind $o <Control-1> "tk_popup .menuObj@$o %X %Y"
		} else {
			.c bind $o <3> "tk_popup .menuObj@$o %X %Y"
		}
	}
	if {[info exists im]} {
		.c bind $im <B1-Motion> {MoveObjImg $im %x %y}
		global img
		menu .menu@$im
		.menu@$im add comm -label "Zoom by 3" -command {scaleImage $img 3}		
		.menu@$im add comm -label "Zoom by 2" -command {scaleImage $img 2}
		.menu@$im add comm -label "Shrink by .5" -command {scaleImage $img 0.5}
		.menu@$im add comm -label "Shrink by .33" -command {scaleImage $img 0.33}
		.menu@$im add separator
		.menu@$im add comm -label "Flip LR" -command {scaleImage $img -1 1}
		.menu@$im add comm -label "Flip TB" -command {scaleImage $img 1 -1}
		.menu@$im add comm -label "Flip both" -command {scaleImage $img -1 -1}
		
		
		if {[tk windowingsystem]=="aqua"} {
			.c bind $im <2> "tk_popup .menu@$im %X %Y"
			.c bind $im <Control-1> "tk_popup .menu@$im %X %Y"
		} else {
			.c bind $im <3> "tk_popup .menu@$im %X %Y"
		}
	}
}


#------------------------------------------------------------------------

proc ChooseColor {changeWhat} {
	global ocolor
	global bgcolor
	switch $changeWhat {
		.b {
		    set ocolor \
        		[tk_chooseColor -initialcolor $ocolor -title "Choose a color" -parent .]
			.cbox configure -background $ocolor
		}
		.cbg {
		    set bgcolor \
        		[tk_chooseColor -initialcolor $bgcolor -title "Choose a color" -parent .]
			.c configure -background $bgcolor
			.cbg configure -background $bgcolor
		}
	}
}

proc ChangeColor {} {
	global o
    set ocolor \
        [tk_chooseColor -initialcolor $ocolor -title "Choose a different color" -parent .]
    .c itemconfigure $o -fill $ocolor
}

#------------------------------------------------------------------------
#========================================================================

set objSize 50
button .cbg -text "Background color" -command "ChooseColor .cbg"
button .b -text "Shape color" -command "ChooseColor .b"
button .cbox -background $ocolor -width 1 -state disabled
scale .slide -orient horizontal -length 142 -from 20 -to 110 \
	-variable objSize -tickinterval 30
button .bselect -text "Add custom image" -command "LoadFile"
label .lslide -text "Shape size:"
label .llist -text "Double-click to draw:"

button .q -text "Quit" -command "destroy ."




#========================================================================
grid .c -row 0 -column 0 -padx "$cpad 2" -pady "$cpad $cpad" -rowspan 10 

grid .cbg -row 0 -column 1 -padx {0 0} -pady {2 1} -columnspan 3
grid .b -row 1 -column 1 -padx {0 0} -pady {2 0}
grid .cbox -row 1 -column 2 -padx {0 4} -pady {2 0} -columnspan 2
grid .lslide -row 2 -column 1 -padx {2 2} -pady {0 0} -columnspan 3 -sticky ew
grid .slide -row 3 -column 1 -padx {2 2} -pady {0 2} -columnspan 3 -sticky ew

grid .llist -row 4 -column 1 -padx {2 2} -pady {2 0} -columnspan 3 -sticky ew
grid .stimlist -row 5 -column 1 -sticky news -padx {2 0} -pady {0 2} -columnspan 2
grid .sbar -row 5 -column 3 -sticky news -padx {0 4} -pady {0 2}

grid .bselect -row 6 -column 1 -padx {2 2} -pady {2 2} -columnspan 3

grid .q -row 9 -column 1 -padx {2 2} -pady {2 2} -columnspan 3
