load polygon
load disk

namespace eval ::make_stims:: {
	variable rect
	variable oval
}

proc ::make_stims {} {
    resetObjList		 ;# unload existing objects
    glistInit 4			 ;# initialize stimuli

	set ::make_stims::oval [disk]
	glistAddObject $::make_stims::oval 0
	

    for { set i 1 } { $i < 4 } { incr i } { 
		set ::make_stims::rect($i) [make_rect]
		glistAddObject $::make_stims::rect($i) $i
	}	

#    polycolor $p 1. 0 0 .6
#    polyfill $p 1
#    scaleObj $p 5 5
#    glistAddObject $poly(0) $i
#    glistAddObject $p $i
}

# This just creates a simple square, which can be scaled to create rects
proc make_rect {} {
    set s [polygon]
    polyverts $s "-.5 -.5 .5 .5" "-.5 .5 .5 -.5"
    return $s
}


::make_stims
setBackground 128 128 128	;# make background gray

proc clearscreen { } { glistSetVisible 0; redraw }
proc see { stim } {  glistSetVisible 1; glistSetCurGroup $stim; redraw }
proc setstim { stim } { set $stim }
