#!/bin/sh
# Run wish from the users PATH \
exec wish -f "$0" ${1+"$@"}

#source C:/usr/local/lib/dlsh/bin/dlshell.tcl
package require stimctrl
set rmt_source {L:\\projects\\analysis\\pshih\\Stim_MoveObjects.tcl}


option add *tearOff 0

#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
namespace eval ::ccanvas:: {
	# 5:4 aspect ratio
	variable cwidth 400
	variable cheight 320
	variable bgcolor {#888888}
	variable cpad 4
	variable cborder 3
	variable gridPad [expr $::ccanvas::cpad + $::ccanvas::cborder]
	variable cscreen [canvas .c \
				-width $::ccanvas::cwidth -height $::ccanvas::cheight \
				-background $::ccanvas::bgcolor \
				-borderwidth $::ccanvas::cborder -relief solid]
				
	if {![info exists ::ccanvas::ocolor]} {variable ocolor {#ffffff}}
}

namespace eval ::linkDisp:: {
	variable stimLink 0
	variable ocolorDec
	variable degHorz
	variable degVert
	variable pi [expr acos (-1)]
}

namespace eval ::stim:: {
	variable centerHorz
	variable centerVert
	variable moveVisAngle
	variable type
	variable typeDetail
	variable o
	variable img
	variable objSize
	namespace eval drawObj {}
}

namespace eval ::loadFile:: {
	variable type
	variable filetype
}

namespace eval ::scaleImage:: {}

global host
if {![info exists host]} {
	set host localhost
}
rmt_send $host "source $rmt_source"

#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

#------------------------------------------------------------------------
#proc ::linkDisp::deg2rad {degrees} {
#	variable pi
#	return [expr {($degrees / 180.0) * $::linkDisp::pi}]
#}

proc ::linkDisp::rad2deg {radians} {
	variable pi
	set degrees [expr {($radians / $::linkDisp::pi) * 180}]
	return $degrees
}

proc ::linkDisp::visAngle {x y} {
	# 2.54cm = 1 inch
	# Mac: 72dpi screen; Win: 96dpi screen
	set anglex [::linkDisp::rad2deg [expr 2*atan((($x*2.54/48)/2.000)/57.000)]]
	set angley [::linkDisp::rad2deg [expr 2*atan((($y*2.54/48)/2.000)/57.000)]]
	lappend returnAngles $anglex $angley
	return $returnAngles
}

#------------------------------------------------------------------------
proc ::stim::moveIt {object type x y} {
	global host
	
	if {$type == "shape"} {		
		.c coords $object \
			[expr $x-$::stim::centerHorz] [expr $y-$::stim::centerVert]\
			[expr $x+$::stim::centerHorz] [expr $y+$::stim::centerVert]
	} elseif {$type == "image"} {
		.c coords $object $x $y
	}
	
	
	set centx [expr $x - ($::ccanvas::cwidth/2) - 3]
	set centy [expr ($::ccanvas::cheight/2) + 5 - $y]
	set ::stim::moveVisAngle [::linkDisp::visAngle $centx $centy]
	
	if {$::linkDisp::stimLink == 1} {
		switch $::stim::typeDetail {
			circle {
				rmt_send $host "translateObj 0 $::stim::moveVisAngle; redraw"
			}
			square {
				rmt_send $host "translateObj 1 $::stim::moveVisAngle; redraw"
			}
			horzLine {
				rmt_send $host "translateObj 2 $::stim::moveVisAngle; redraw"
			}
			vertLine {		
				rmt_send $host "translateObj 3 $::stim::moveVisAngle; redraw"
			}
		}
	}
}

#------------------------------------------------------------------------

proc ::stim::drawObj::canvasCreate {shape horz vert} {
	variable ::linkDisp::degHorz
	variable ::linkDisp::degVert
	set ::stim::centerHorz [expr $horz/2]
	set ::stim::centerVert [expr $vert/2]
	set x1 [expr $::ccanvas::cwidth/2 - $::stim::centerHorz + $::ccanvas::gridPad]
	set y1 [expr $::ccanvas::cheight/2 - $::stim::centerVert + $::ccanvas::gridPad]
	set x2 [expr $::ccanvas::cwidth/2 + $::stim::centerHorz + $::ccanvas::gridPad]
	set y2 [expr $::ccanvas::cheight/2 + $::stim::centerVert + $::ccanvas::gridPad]
	set ::stim::o [.c create $shape $x1 $y1 $x2 $y2 -fill $::ccanvas::ocolor -width 0]
	
	set tempList  [::linkDisp::visAngle $::stim::centerHorz $::stim::centerVert]
	set ::linkDisp::degHorz [lindex $tempList 0]
	set ::linkDisp::degVert [lindex $tempList 1]
	
	if {$::linkDisp::stimLink == 1} {	
		::linkDisp::sendStim
	}
}

proc ::stim::drawObj {stim} {
	global im
	global w
	global h
	global host
	
	set ::stim::typeDetail $stim
	
	if {[info exists ::stim::o]} {.c delete $::stim::o}
	if {[info exists im]} {unset $im}
	puts stdout $stim
	
	switch $stim {
		circle {
			set w $::stim::objSize
			set h $::stim::objSize		
			set ::stim::type shape
			::stim::drawObj::canvasCreate oval $w $h
		}
		square {
			set w $::stim::objSize
			set h $::stim::objSize			
			set ::stim::type shape
			::stim::drawObj::canvasCreate rect $w $h
		}
		horzLine {
			set w $::stim::objSize
			set h [expr $w/5]			
			set ::stim::type shape
			::stim::drawObj::canvasCreate rect $w $h
		}
		vertLine {
			set h $::stim::objSize
			set w [expr $h/5]	
			set ::stim::type shape
			::stim::drawObj::canvasCreate rect $w $h
		}		
		default {
			set ::stim::img [image create photo -file $stim]
			set w [image width $::stim::img]
			set h [image height $::stim::img]
			set centerw [expr $w / 2]
			set centerh [expr $h / 2]			
			set ::stim::type image
			set ::stim::o [$::ccanvas::cscreen create image $centerw $centerh -image $::stim::img]
		# This is the centerish of the .c canvas
			.c coords $::stim::o 175 125
		}
	}


#-- leave @$ stuff in menu name for future use
	if {[info exists ::stim::type] && [info exists ::stim::o]} {

		.c bind $::stim::o <B1-Motion> {::stim::moveIt $::stim::o $::stim::type %x %y}

		menu .menu@$::stim::o
		.menu@$::stim::o add comm -label "Shape color" -command "::stim::changeColor"
		.menu@$::stim::o add separator
		.menu@$::stim::o add comm -label "Zoom 3x" -command {scaleImage $::stim::img 3}		
		.menu@$::stim::o add comm -label "Zoom 2x" -command {scaleImage $::stim::img 2}
		.menu@$::stim::o add comm -label "Shrink .5x" -command {scaleImage $::stim::img 0.5}
		.menu@$::stim::o add comm -label "Shrink .33x" -command {scaleImage $::stim::img 0.33}
		.menu@$::stim::o add separator
		.menu@$::stim::o add comm -label "Flip LR" -command {scaleImage $::stim::img -1 1}
		.menu@$::stim::o add comm -label "Flip TB" -command {scaleImage $::stim::img 1 -1}
		.menu@$::stim::o add comm -label "Flip both" -command {scaleImage $::stim::img -1 -1}	
		
		if {[tk windowingsystem]=="aqua"} {
			.c bind $::stim::o <2> "tk_popup .menu@$::stim::o %X %Y"
			.c bind $::stim::o <Control-1> "tk_popup .menu@$::stim::o %X %Y"
		} else {
			.c bind $::stim::o <3> "tk_popup .menu@$::stim::o %X %Y"
		}
	}	
}


#------------------------------------------------------------------------
proc ::stim::hex2dec {hex} {
	set r [scan [string range $hex 1 2] %x]
	set g [scan [string range $hex 3 4] %x]
	set b [scan [string range $hex 5 6] %x]
	return "$r $g $b"
}

#~~ This extra proc is probably superfluous... consider merging with chooseColor at a later time
proc ::stim::changeColor {chgWhat color} {	
	global host
	
	switch $chgWhat {
		.cobj {
			.cobjbox configure -background $color
			
			if {[info exists ::stim::o] && $::stim::type == "shape"} {
				.c itemconfigure $::stim::o -fill $color
				if {$::linkDisp::stimLink == 1} {
					set ::linkDisp::ocolorDec [::stim::hex2dec $::ccanvas::ocolor]
					set ::linkDisp::ocolorScaled [::linkDisp::scaleDecimals $::linkDisp::ocolorDec]		

					switch $::stim::typeDetail {
						circle {
							rmt_send $host "diskcolor \$::make_stims::oval $::linkDisp::ocolorScaled; \
							redraw"
						}
						square {
							rmt_send $host "polycolor 1 $::linkDisp::ocolorScaled; redraw"
						}
						horzLine {
							rmt_send $host "polycolor 2 $::linkDisp::ocolorScaled; redraw"
						}
						vertLine {		
							rmt_send $host "polycolor 3 $::linkDisp::ocolorScaled; redraw"
						}
					}
				}
			}
    	}
		.cbg {
			.c configure -background $color
			.cbgbox configure -background $color

			if {$::linkDisp::stimLink == 1} {
				set ::linkDisp::bgcolorDec [::stim::hex2dec $::ccanvas::bgcolor]
				rmt_send $host "setBackground $::linkDisp::bgcolorDec; redraw"
			}
		}			
    }
}

proc ::stim::chooseColor {chgWhat} {
	switch $chgWhat {
		.cobj {
		    set ::ccanvas::ocolor \
        		[tk_chooseColor -initialcolor $::ccanvas::ocolor -title "Choose a color" -parent .]
			puts stdout $::ccanvas::ocolor			
			::stim::changeColor $chgWhat $::ccanvas::ocolor
		}
		.cbg {
		    set ::ccanvas::bgcolor \
        		[tk_chooseColor -initialcolor $::ccanvas::bgcolor -title "Choose a color" -parent .]
			puts stdout $::ccanvas::bgcolor
			::stim::changeColor $chgWhat $::ccanvas::bgcolor
		}
	}
}



#------------------------------------------------------------------------
proc ::stim::dynamicSize {size} {
	global w
	global h

	if {[info exists ::stim::type] && [info exists ::stim::o]} {
		if {$::stim::type == "shape"} {
			set objCoords [.c bbox $::stim::o]
			puts stdout "objCoords: $objCoords"
			set x1 [lindex $objCoords 0]
			set y1 [lindex $objCoords 1]
			set x2 [lindex $objCoords 2]
			set y2 [lindex $objCoords 3]
			set changex [expr (abs($x1 - $x2) - $w)/2]
			set changey [expr (abs($y1 - $y2) - $h)/2]
			set ::stim::centerHorz [expr abs($changex)]
			set centerVert [expr abs($changey)]
	
			::stim::drawObj $::stim::typeDetail		
			.c coords $::stim::o \
				[expr $x1 + $changex] [expr $y1 + $changey] \
				[expr $x2 - $changex] [expr $y2 - $changey]
		}
	}
}	

#------------------------------------------------------------------------
proc ::loadFile {} {
	set ::loadFile::types {
			{"Image Files"	{.gif .ppm .pnm} }
			{"All files"	*}
	}
    set ::loadFile::file [tk_getOpenFile -filetypes $::loadFile::types -multiple 1 -parent .]
    foreach i $::loadFile::file {
    	.stimlist insert end $i
    	puts stdout $i
    }
}

#------------------------------------------------------------------------
proc ::scaleImage {im xfactor {yfactor 0}} {
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

proc ::linkDisp::scaleDecimals {rgb} {
	foreach i $rgb {
		lappend scaled [expr $i/255.0]
	}
	return $scaled
}

#########################################################################
proc ::linkDisp::sendStim {} {
	global host
	set ::linkDisp::ocolorDec [::stim::hex2dec $::ccanvas::ocolor]
	set ::linkDisp::ocolorScaled [::linkDisp::scaleDecimals $::linkDisp::ocolorDec]
	set ::linkDisp::bgcolorDec [::stim::hex2dec $::ccanvas::bgcolor]
	puts stdout $::linkDisp::ocolorScaled
	
	rmt_send $host "setBackground $::linkDisp::bgcolorDec"

	if {[info exists ::stim::typeDetail]} {
		switch $::stim::typeDetail {
			circle {
				puts stdout "Sent $::stim::typeDetail to Stim Display."
				rmt_send $host "scaleObj \$::make_stims::oval \
					$::linkDisp::degHorz $::linkDisp::degVert; \
					diskcolor \$::make_stims::oval $::linkDisp::ocolorScaled; \
					redraw; see 0"
				if {[info exists ::stim::moveVisAngle]} {
					puts stdout $::stim::moveVisAngle
					rmt_send $host "translateObj 0 $::stim::moveVisAngle; redraw"
			}
			square {
				rmt_send $host "scaleObj 1 \
					$::linkDisp::degHorz $::linkDisp::degVert; \
					polycolor 1 $::linkDisp::ocolorScaled; \
					redraw; see 1"
				if {[info exists ::stim::moveVisAngle]} {
					rmt_send $host "translateObj 1 $::stim::moveVisAngle; redraw"
			}				
			horzLine {
				rmt_send $host "scaleObj 2 \
					$::linkDisp::degHorz $::linkDisp::degVert; \
					polycolor 2 $::linkDisp::ocolorScaled; \
					redraw; see 2"
				if {[info exists ::stim::moveVisAngle]} {
					rmt_send $host "translateObj 2 $::stim::moveVisAngle; redraw"
			}
			vertLine {
				rmt_send $host "scaleObj 3 \
					$::linkDisp::degHorz $::linkDisp::degVert; \
					polycolor 3 $::linkDisp::ocolorScaled; \
					redraw; see 3"	
				if {[info exists ::stim::moveVisAngle]} {
					rmt_send $host "translateObj 3 $::stim::moveVisAngle; redraw"
			}
		}
	}
}


proc ::linkDisp::toggleLink {} {
	variable stimLink
	if {$::linkDisp::stimLink == 0} {
		set ::linkDisp::stimLink 1
		.link configure -text {:: Unlink with Stim Display ::}
		::linkDisp::sendStim
		
		#************************* 
		# // send current canvas objects and parameters to Stim Display
		# // using rmt_send via ::linkDisp::sendStim
		# //
		# // Afterwards, all changes to objects will also update Stim Display...
		# // This means that all procs that update the canvas will
		# // have to include an if statement that checks if stimLink == 1
		# // in which case, remote display should update automatically
		#
	} elseif {$::linkDisp::stimLink == 1} {
		set ::linkDisp::stimLink 0
		.link configure -text {:: Link with Stim Display ::}
	}
}

proc ::stim::doIt {activeSel} {
	if {[info exists ::stim::moveVisAngle]} {
		unset ::stim::moveVisAngle
	}
	::stim::drawObj $activeSel
}

#########################################################################
scrollbar .sbar -width 12 -command ".stimlist yview"

#
listbox .stimlist -height 4 -width 15 -yscroll ".sbar set"
	.stimlist insert 0 circle square horzLine vertLine

bind .stimlist <Double-B1-ButtonRelease> {::stim::doIt [.stimlist get active]}
bind . <Control-h> { console show }

#========================================================================

variable ::stim::objSize 50
ttk::label .cbg -text "Bg color:" 
button .cbgbox -background "#c0c0c0" -command "::stim::chooseColor .cbg" -width 3 -height 1
ttk::label .cobj -text "Shape color:" 
button .cobjbox -background "white" -command "::stim::chooseColor .cobj" -width 3 -height 1
ttk::separator .sep1 
scale .slide -orient horizontal  -from 20 -to 140 \
	-variable ::stim::objSize -tickinterval 40 -command "::stim::dynamicSize "
ttk::separator .sep2
ttk::button .bselect -text "Add custom image" -command "::loadFile"
ttk::label .lslide -text "Shape size:"
ttk::label .llist -text "Double-click to draw:"
ttk::separator .sep3 

#ttk::frame .bottomframe -borderwidth 0

set sendButton [ttk::button .send -text "Send Stim" \
	-command "::linkDisp::sendStim"]
set clearButton [ttk::button .clear -text "Clear Stim" \
	-command "rmt_send $host clearscreen"]
set linkButton [ttk::button .link -text ":: Link with Stim Display ::" -width 25 \
	-command "::linkDisp::toggleLink"]
set quitButton [ttk::button .q -text "Quit" -command "rmt_send $host {clearscreen}; destroy ."]

#========================================================================
grid .c -row 0 -column 0 -padx "$::ccanvas::cpad 2" -pady "$::ccanvas::cpad $::ccanvas::cpad" \
	-rowspan 9 -columnspan 4
grid .cbg -row 0 -column 4 -padx {2 1} -pady {1 0}  -sticky ew 
grid .cbgbox -row 0 -column 5 -padx {5 4} -pady {1 0}  -sticky e -columnspan 2
grid .cobj -row 1 -column 4 -padx {2 1} -pady {1 0}  -sticky ew 
grid .cobjbox -row 1 -column 5 -padx {5 4} -pady {1 0}  -sticky e -columnspan 2
grid .sep1 -row 2 -column 4  -padx {2 4} -pady {1 0} -columnspan 3 -sticky ew
grid .lslide -row 3 -column 4 -padx {2 4} -pady {0 0} -columnspan 3 -sticky ew
grid .slide -row 4 -column 4 -padx {2 4} -pady {0 2} -columnspan 3 -sticky ew
grid .sep2 -row 5 -column 4  -padx {2 4} -pady {0 0} -columnspan 3 -sticky ew
grid .llist -row 6 -column 4 -padx {2 4} -pady {2 0} -columnspan 3 -sticky ew
grid .stimlist -row 7 -column 4 -padx {2 0} -pady {0 2} -columnspan 2 -sticky news
grid .sbar -row 7 -column 6 -padx {0 4} -pady {0 2} -sticky nsew
grid .bselect -row 8 -column 4 -padx {2 4} -pady {2 2} -columnspan 3 -sticky ew
grid .sep3 -row 10 -column 0  -padx {4 4} -pady {0 2} -columnspan 7 -sticky ew
grid .q -row 11 -column 0 -padx {4 4} -pady {4 6} -sticky w
grid .link -row 11 -column 2 -padx {4 4} -pady {4 6} -sticky e
grid .clear -row 11 -column 3 -padx {4 4} -pady {4 6} -sticky we
grid .send -row 11 -column 4 -padx {2 4} -pady {4 6} -columnspan 3 -sticky ew




