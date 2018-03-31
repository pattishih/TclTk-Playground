#!/bin/sh
# Run wish from the users PATH \
exec wish -f "$0" ${1+"$@"}

package require agilentawg
package require dlsh

# revision 1.4.2

#:::::::::::::::::::::::::::::::::::::::::::::::::
namespace eval ::makeawg:: {
	variable wavePeriod 3.0
	variable startt 
	variable dur
	variable volt
	variable curr
	variable resis
	variable i 0
	variable pulseBoxSel
	variable pulseList Add_pulse
	variable vertices
	variable mu [format %c 181]
	variable om [format %c 937]
	variable hold
	variable neg
	variable waveParams 0
	variable arbdg
}

#--  This is kept here for easy access
namespace eval ::TempSpace:: {
	variable geom "319x528+550+280"
	variable canvasWidth 304
	variable canvasHeight 96
}
#:::::::::::::::::::::::::::::::::::::::::::::::::

#===================================================================================================

proc makeawg::updateFields {} {
#-- (Subtract 1, index starts at 0)
	set numPulses [llength [lrange $makeawg::pulseList  1 end]]
	
	if {$makeawg::pulseBoxSel == "Add_pulse" } {
		if {$numPulses == 0} {
			.arb.f.buttons.prevw(b) state !disabled
			.arb.f.buttons.del(b) state !disabled
			.arb.f.buttons.reset(b) state !disabled
			.arb.f.startt(ent) state !disabled
			.arb.f.dur(ent) state !disabled
			.arb.f.neg(chk) state !disabled

		#-- Set up the default parameters for the first pulse			
			set makeawg::startt 0;			# microseconds
            set makeawg::dur 100;			# microseconds
            set makeawg::volt 3.0; 			# Volts
            set makeawg::curr .06;			# Amps
            set makeawg::resis 50.0;		# Ohms
            set makeawg::neg 0;
            set makeawg::i 1;

        #-- Initialize makeawg::waveParams with the parameters of the first pulse
 	        set makeawg::waveParams \
		        [list [list $makeawg::wavePeriod] \
		            [list [list $makeawg::startt $makeawg::dur] [list $makeawg::volt $makeawg::neg]]]

        #-- Update textbox
             .arb.f.textbox replace 1.0 end "[list $makeawg::waveParams]"

        #----------------------------------------------------------------------
		} elseif {$numPulses > 0} {
		#-- Set up the parameters for a new pulse to be added into the combobox
			set makeawg::i [expr $numPulses + 1]
			set previ $numPulses
            set starttPrev [lindex $makeawg::waveParams $previ 0 0]
			set starttNew [expr "$starttPrev + $makeawg::dur + 1"]
            set durNew [lindex $makeawg::waveParams $previ 0 1]
			set makeawg::startt $starttNew
			set makeawg::dur $durNew

        #-- Append parameters of second pulse to makeawg::waveParam
		    lappend makeawg::waveParams [list [list $makeawg::startt $makeawg::dur] [list $makeawg::volt $makeawg::neg]]

        #-- Update textbox
		    .arb.f.textbox replace 1.0 end "[list $makeawg::waveParams]"
		}		
	#-- Add the new pulse to the combobox and make its index active
		lappend makeawg::pulseList $makeawg::startt
		.arb.f.select(dropdn) configure -values "$makeawg::pulseList"
		.arb.f.select(dropdn) set $makeawg::startt

    #-- Reenables the entry boxes for V=IR
#		makeawg::CheckIfTwo
        .arb.f.vir.volt(ent) state !disabled;  #comment out this line if you want to call 'makeawg::CheckIfTwo' above
                                               #currently, only changes to voltage is allowed
        
    #======================================================================
	} elseif {$makeawg::pulseBoxSel >= 0} {
    #-- Pull up parameters for the selected pulse     
        set i [lsearch -sorted -exact -dictionary $makeawg::pulseList $makeawg::pulseBoxSel]
 		set makeawg::i $i
        set makeawg::startt [lindex $makeawg::waveParams $i 0 0]
        set makeawg::dur [lindex $makeawg::waveParams $i 0 1]
        set makeawg::volt [lindex $makeawg::waveParams $i 1 0]
        set makeawg::neg [lindex $makeawg::waveParams $i 1 1]	

    #-- Update the textbox (just in case/just because)
		.arb.f.textbox replace 1.0 end "[list $makeawg::waveParams]"
	}
}

#---------------------------------------------------------------------------------------------------

proc ::makeawg::recreateParams {{updateStatus ""}} {
#-- Remake the combobox in case anything was changed
	set replacedList [lreplace $makeawg::pulseList $makeawg::i $makeawg::i $makeawg::startt]
	set sortedList [lsort -integer [lrange $replacedList 1 end]]
	set makeawg::pulseList [list Add_pulse]
	eval lappend makeawg::pulseList $sortedList
    .arb.f.select(dropdn) configure -values "$makeawg::pulseList"

#-- Update the selection of the combobox if necessary
#-- Also adjust duration of pulse if necessary
    if {$updateStatus == "doUpdateSelection"} {
        .arb.f.select(dropdn) set $makeawg::startt
 	    set numPulses [llength [lrange $makeawg::pulseList 1 end]]
 	    set lastStartTime [lindex $makeawg::waveParams $numPulses 0 0]
	    set lastDurTime [lindex $makeawg::waveParams $numPulses 0 1]
	    set lastEndTime [expr "$lastStartTime + $lastDurTime"]

    #-- Adjust the duration, given the change in start time
        set oldstartTime [lindex $makeawg::waveParams $makeawg::i 0 0]
        set delta [expr "$oldstartTime - $makeawg::startt"]
        if {$delta <= [expr "$makeawg::dur * -1"]} {
            set makeawg::dur 100
        } else {
            set makeawg::dur [expr "$makeawg::dur + $delta"]
        }
    }

#-- Remake makeawg::waveParams in case anything was changed  
    set replacedParams [lreplace $makeawg::waveParams $makeawg::i $makeawg::i \
        [list [list $makeawg::startt $makeawg::dur] [list $makeawg::volt $makeawg::neg]]]
    echo $replacedParams
	set sortedParams [lsort -integer -index {0 0} [lrange $replacedParams 1 end]]
    set makeawg::waveParams [list $makeawg::wavePeriod]
	eval lappend makeawg::waveParams $sortedParams
	
#-- Update the "global" index (makeawg::i) with the index for the active Pulse ID
    set i [lsearch -sorted -exact -dictionary $makeawg::pulseList $makeawg::startt]
    set makeawg::i $i

#-- Update textbox
    .arb.f.textbox replace 1.0 end "[list $makeawg::waveParams]"
}

#---------------------------------------------------------------------------------------------------
#-- Grabs the parameters from the textbox
proc ::makeawg::grabSequence {waveParams} {
    if {[llength $waveParams] >= 2} {
        set makeawg::pulseList Add_pulse
        set makeawg::waveParams $waveParams
        set makeawg::wavePeriod [lindex $makeawg::waveParams 0];
        set numPulses [llength [lrange $makeawg::waveParams 1 end]];  #index_0 is the wave period
        set makeawg::resis 50.0;		# Ohms
        
        for {set pIndex 1} {$pIndex <= $numPulses} {incr pIndex} {
            set startTime [lindex $makeawg::waveParams $pIndex 0 0]
            lappend makeawg::pulseList $startTime
        }
        set makeawg::i $numPulses
        set makeawg::pulseBoxSel $startTime
        .arb.f.select(dropdn) set $startTime
        makeawg::updateFields
        .arb.f.buttons.del(b) state !disabled
        .arb.f.buttons.reset(b) state !disabled
        .arb.f.startt(ent) state !disabled
        .arb.f.dur(ent) state !disabled
        .arb.f.neg(chk) state !disabled
        .arb.f.vir.volt(ent) state !disabled
    }
}
    
#===================================================================================================
#-- This procedure is unused when only changes to the voltage parameter is allowed
#---- refer to the makeawg::updateFields for more information (around line 100)
proc ::makeawg::CheckIfTwo {} {
	set howMany [expr $makeawg::hold(0) + $makeawg::hold(1) + $makeawg::hold(2)]
	if { $howMany >= 2 } {
		if {$makeawg::hold(0)==0} {
			foreach i {chk ent} {
				.arb.f.vir.volt(${i}) state disabled
				foreach j {curr resis} {
					.arb.f.vir.${j}(${i}) state !disabled
		}}} elseif {$makeawg::hold(1)==0} {
			foreach i {chk ent} {
				.arb.f.vir.curr(${i}) state disabled
				foreach j {volt resis} {
					.arb.f.vir.${j}(${i}) state !disabled
		}}} elseif {$makeawg::hold(2)==0} {
			foreach i {chk ent} {
				.arb.f.vir.resis(${i}) state disabled
				foreach j {volt curr} {
					.arb.f.vir.${j}(${i}) state !disabled
	    }}}
	} else {
		foreach j {volt curr resis} {
			.arb.f.vir.${j}(chk) state !disabled
		}
		foreach j {volt curr resis} {
			.arb.f.vir.${j}(ent) state disabled
		}
	}
}

proc ::makeawg::VIR {changedVar value} {
	set makeawg::${changedVar} $value
	set howMany [expr $makeawg::hold(0) + $makeawg::hold(1) + $makeawg::hold(2)]
    if { $howMany == 2 } {
        if {$makeawg::hold(1)==1 && $makeawg::hold(2)==1 && $makeawg::hold(0)==0} {
            set makeawg::volt [expr $makeawg::resis * $makeawg::curr]
        } elseif {$makeawg::hold(0)==1 && $makeawg::hold(2)==1 && $makeawg::hold(1)==0} {
            set makeawg::curr [expr $makeawg::volt / $makeawg::resis]
        } elseif {$makeawg::hold(0)==1 && $makeawg::hold(1)==1 && $makeawg::hold(2)==0} {
            set makeawg::resis [expr $makeawg::volt / $makeawg::curr]
        }
    } else {
        tk_messageBox \
        -message "You must provide at least two of the stimulation parameters to compute the other."
    }

#-- Update list of parameters in case they have been modified
    makeawg::recreateParams
}

proc ::makeawg::negate {} {
    if {[info exists makeawg::neg]} {makeawg::recreateParams}
}
#===================================================================================================
proc ::makeawg::deleteIt {} {
    set makeawg::pulseList [.arb.f.select(dropdn) cget -values]
	set numPulsesNew [llength [lrange $makeawg::pulseList 1 end-1]];
#-- Get the index for the current selection
    set i [.arb.f.select(dropdn) current]
    set makeawg::waveParams [lreplace $makeawg::waveParams $i $i]
    set makeawg::pulseList [lreplace $makeawg::pulseList $i $i]
    set makeawg::i $numPulsesNew
    .arb.f.select(dropdn) configure -values $makeawg::pulseList
    .arb.f.select(dropdn) set ""
    previewIt
}

proc ::makeawg::resetPulseList {} {
	set makeawg::i 0;
	set makeawg::wavePeriod 3.0;
	set makeawg::startt "";
	set makeawg::dur "";
	set makeawg::volt "";
	set makeawg::curr "";
	set makeawg::resis "";
	set makeawg::neg "";
    set makeawg::waveParams "";
	
	set makeawg::pulseList Add_pulse;
	.arb.f.select(dropdn) configure -values "$makeawg::pulseList"
	.arb.f.select(dropdn) set ""
	.arb.f.plot delete waveform
	.arb.f.buttons.prevw(b) state disabled
	.arb.f.buttons.del(b) state disabled
	.arb.f.buttons.viewdg(b) state disabled	
    .arb.f.buttons.makedg(b) state disabled	
	.arb.f.buttons.reset(b) state disabled	
	.arb.f.startt(ent) state disabled
	.arb.f.dur(ent) state disabled
	.arb.f.neg(chk) state disabled
	.arb.f.vir.volt(chk) state disabled
	.arb.f.vir.curr(chk) state selected 
	.arb.f.vir.curr(chk) state disabled
	.arb.f.vir.resis(chk) state selected
	.arb.f.vir.resis(chk) state disabled
	.arb.f.vir.volt(ent) state disabled
	.arb.f.vir.curr(ent) state disabled
	.arb.f.vir.resis(ent) state disabled
}
#===================================================================================================

proc ::makeawg::getAmplitudes {numPulses} {
    for {set i 1} {$i <= $numPulses} {incr i} {
        lappend amplitudes [lindex $makeawg::waveParams $i 1 0]
    }
    return $amplitudes
}

proc ::makeawg::previewIt {} {
#-- Update list of parameters in case they have been modified
    makeawg::recreateParams

	set numPulses [llength [lrange $makeawg::waveParams 1 end]];  #index_0 is the wave period -- skip
	set wavePeriod [expr "1000 * [lindex $makeawg::waveParams 0]"];  #multiply by 1000 to convert ms to microseconds
	set scaleTime2Pxl [expr "$TempSpace::canvasWidth / ($wavePeriod * 1.000)"];  #scale x-axis by the wave period
	set wavePeriodScaled [expr "int($wavePeriod * $scaleTime2Pxl)"];

    set amplitudes [makeawg::getAmplitudes $numPulses];
    set maxAmplitude [expr max([join $amplitudes ","])];
    set scaleAmp2Pxl [expr "($TempSpace::canvasHeight - 10) / ($maxAmplitude * 2.000)"];  #scale y-axis by the max amplitude; -10 for extra padding
	set horzReference [expr "ceil($TempSpace::canvasHeight/2) + 2"];  #+2 to better center the horiz. ref at vertical midpt

#-- Vertices that will be used for drawing the pulse on the canvas widget
	set makeawg::vertices [list [list 0 $horzReference]];
	
#-- The number of vertices (vcount 1 is vertex at (0, 0))
	set vcount 1
	for {set pIndex 1} {$pIndex <= $numPulses} {incr pIndex} {      
        set posneg [expr "([lindex $makeawg::waveParams $pIndex 1 1] * -2) + 1"];  #shift values such that pos = 1 (orig: 0) and neg = -1 (orig: 1)
        set pulseAmp [expr "[lindex $makeawg::waveParams $pIndex 1 0] * $posneg"]
        set pAmpScaled [expr "int($horzReference - ($pulseAmp * $scaleAmp2Pxl))"];

        set startTime [lindex $makeawg::waveParams $pIndex 0 0]
        set durTime [lindex $makeawg::waveParams $pIndex 0 1]
        set endTime [expr "$startTime + $durTime"]        
		set startOn [expr "int($startTime * $scaleTime2Pxl)"];
		set endOn [expr "int($endTime * $scaleTime2Pxl)"];

        if {![info exists endtPrev] && $startTime != 0} {
            lappend makeawg::vertices [list $startOn $horzReference]; incr vcount
            lappend makeawg::vertices [list $startOn $pAmpScaled]; incr vcount
            lappend makeawg::vertices [list $endOn $pAmpScaled]; incr vcount
        } elseif {[info exists endtPrev]} {
            if {$startTime <= [expr "$endtPrev + 1"]} {
               echo "skip"
            lappend makeawg::vertices [list $startOn $pAmpScaled]; incr vcount
            lappend makeawg::vertices [list $endOn $pAmpScaled]; incr vcount
            } else {
                set endOnPrev [expr "int($endtPrev * $scaleTime2Pxl)"];
                lappend makeawg::vertices [list $endOnPrev $horzReference]; incr vcount
                lappend makeawg::vertices [list $startOn $horzReference]; incr vcount
                lappend makeawg::vertices [list $startOn $pAmpScaled]; incr vcount
                lappend makeawg::vertices [list $endOn $pAmpScaled]; incr vcount
            }
        } else {
            lappend makeawg::vertices [list $startOn $pAmpScaled]; incr vcount
            lappend makeawg::vertices [list $endOn $pAmpScaled]; incr vcount
        }
        set endtPrev $endTime
    }
	unset endtPrev

    lappend makeawg::vertices [list $endOn $horzReference]; incr vcount
	lappend makeawg::vertices [list $wavePeriodScaled $horzReference]; incr vcount
#	echo "$vcount $makeawg::vertices"

#-- Delete plot and redraw (in next steps)
	.arb.f.plot delete waveform
	
#-- Draw the vertices on the canvas in sequential order
	for {set j 1} {$j < $vcount} {incr j} {
		set prevj [expr $j - 1];
		set x0 [expr [lindex $makeawg::vertices $prevj 0] + 3];      # +3 to add extra space on left
		set y0 [lindex $makeawg::vertices $prevj 1]
		set x1 [expr [lindex $makeawg::vertices $j 0] + 3]
		set y1 [lindex $makeawg::vertices $j 1]	
#		echo "$x0 $y0 $x1 $y1"
		set c($j) [.arb.f.plot create line $x0 $y0 $x1 $y1 -fill "#ffffff" -width 1 -tags waveform]
	}
	.arb.f.buttons.makedg(b) state !disabled
}

#---------------------------------------------------------------------------------------------------

proc ::makeawg::makeDg {} {
	set makeawg::arbdg [awg::expandSequence $makeawg::waveParams]
    .arb.f.buttons.viewdg(b) state !disabled
    set verifydl [lindex [dg_tclListnames $makeawg::arbdg] 0]
    makeawg::plotdllist $makeawg::arbdg:$verifydl
}

proc ::makeawg::plotdllist {verifydl} {
	clearwin;
	dlp_create waveform
	dl_local x [dl_fromto 0 [dl_length $verifydl]]
	dlp_addXData waveform $x
	dlp_addYData waveform $verifydl
	dlp_setxrange waveform 0 [dl_length $verifydl]
	dlp_setyrange waveform -1.5 1.5
	dlp_draw waveform lines 0 -lwidth 200
	dlp_plot waveform
}

####################################################################################################

proc ::makeawg::addPulse {} {
	toplevel .arb
	wm title .arb "Arbitrary Waveform Maker"
	wm geometry .arb $TempSpace::geom
	bind .arb <Control-h> {console show}
	ttk::style theme use xpnative
	font create TopTitleFont -family Helvetica -size 11 -weight bold
#---------------------------------------------------------------------------------------------------
	ttk::frame .arb.f
	ttk::labelframe .arb.f.vir  -borderwidth 1 -relief solid -padding "8 1" -text "Select two:"
	ttk::frame .arb.f.buttons -padding "1 1"
	ttk::label .arb.f.title(l) -text {The Makeshift Arbitrary Waveform Maker} -font TopHeaderFont
	ttk::separator .arb.f.sep1a; ttk::separator .arb.f.sep1b
	ttk::label .arb.f.period(l) -text "Single stim period (ms):"
	ttk::entry .arb.f.period(ent) -width 6 -textvariable makeawg::wavePeriod
		bind .arb.f.period(ent) <FocusOut> { makeawg::recreateParams }		
	ttk::separator .arb.f.sep2a; ttk::separator .arb.f.sep2b
	ttk::label .arb.f.select(l) -text "Pulse ID:"
	ttk::combobox .arb.f.select(dropdn) -width 10 -textvariable makeawg::pulseBoxSel
		.arb.f.select(dropdn) configure -values $makeawg::pulseList
		.arb.f.select(dropdn) state readonly
		bind .arb.f.select(dropdn) <<ComboboxSelected>> {\
			set makeawg::pulseBoxSel [.arb.f.select(dropdn) get]; \
			makeawg::updateFields}
	ttk::checkbutton .arb.f.neg(chk) -variable makeawg::neg -onvalue 1 -offvalue 0 -text "neg" \
	    -command "makeawg::negate"
		.arb.f.neg(chk) state disabled
	ttk::label .arb.f.startt(l) -text "Pulse start time (${makeawg::mu}s):"
	ttk::entry .arb.f.startt(ent) -width 6 -textvariable makeawg::startt
		.arb.f.startt(ent) state disabled
		bind .arb.f.startt(ent) <FocusOut> { makeawg::recreateParams doUpdateSelection }	
	ttk::label .arb.f.dur(l) -text "Duration of pulse (${makeawg::mu}s):"
	ttk::entry .arb.f.dur(ent) -width 6 -textvariable makeawg::dur
		.arb.f.dur(ent) state disabled
		bind .arb.f.dur(ent) <FocusOut> { makeawg::recreateParams }
#-- makeawg::hold is associated with the procedure 'makeawg::CheckIfTwo'
#---- It's for ensuring that 2 of the 3 variables (in V=IR) are selected for its calculation
	set makeawg::hold(0) 1
	set makeawg::hold(1) 0
	set makeawg::hold(2) 1
	ttk::checkbutton .arb.f.vir.volt(chk) -variable makeawg::hold(0) -onvalue 1 -offvalue 0 \
			-command {makeawg::CheckIfTwo}
		.arb.f.vir.volt(chk) state selected 
		.arb.f.vir.volt(chk) state disabled
	ttk::checkbutton .arb.f.vir.curr(chk) -variable makeawg::hold(1) -onvalue 1 -offvalue 0 \
			-command {makeawg::CheckIfTwo}
		.arb.f.vir.curr(chk) state disabled
	ttk::checkbutton .arb.f.vir.resis(chk) -variable makeawg::hold(2) -onvalue 1 -offvalue 0 \
			-command {makeawg::CheckIfTwo}
		.arb.f.vir.resis(chk) state selected
		.arb.f.vir.resis(chk) state disabled
	ttk::label .arb.f.vir.volt(l) -text "V (V):"
	ttk::entry .arb.f.vir.volt(ent) -width 5 -textvariable makeawg::volt
		.arb.f.vir.volt(ent) state disabled
		bind .arb.f.vir.volt(ent) <FocusOut> { makeawg::VIR volt $makeawg::volt }
	ttk::label .arb.f.vir.curr(l) -text "I (A):"
	ttk::entry .arb.f.vir.curr(ent) -width 5 -textvariable makeawg::curr
		.arb.f.vir.curr(ent) state disabled
		bind .arb.f.vir.curr(ent) <FocusOut> { makeawg::VIR curr $makeawg::curr }
	ttk::label .arb.f.vir.resis(l) -text "R ($makeawg::om):"
	ttk::entry .arb.f.vir.resis(ent) -width 5 -textvariable makeawg::resis
		.arb.f.vir.resis(ent) state disabled
		bind .arb.f.vir.resis(ent) <FocusOut> { makeawg::VIR resis $makeawg::resis }
#---------------
	ttk::button .arb.f.buttons.prevw(b) -text "Preview" -width 9 \
		-command "makeawg::previewIt"
		.arb.f.buttons.prevw(b) state disabled
	ttk::button .arb.f.buttons.del(b) -text "Delete" -width 8 \
		-command "makeawg::deleteIt"
		.arb.f.buttons.del(b) state disabled
	ttk::button .arb.f.buttons.makedg(b) -text "Make dg" -width 8 \
		-command "makeawg::makeDg"
		.arb.f.buttons.makedg(b) state disabled
	ttk::button .arb.f.buttons.viewdg(b) -text "View dg" -width 8 \
		-command {dg_view $makeawg::arbdg}
		.arb.f.buttons.viewdg(b) state disabled
	ttk::button .arb.f.buttons.reset(b) -text "Reset" -width 7 \
		-command "makeawg::resetPulseList"
		.arb.f.buttons.reset(b) state disabled
	ttk::separator .arb.f.sep5
	canvas .arb.f.plot -width $TempSpace::canvasWidth -height $TempSpace::canvasHeight \
		-background "#333333" -relief solid -border 1
		set x1 1
		set x2 [expr $TempSpace::canvasWidth + 2]
		set horzReference [expr round($TempSpace::canvasHeight/2) + 2];   #+2 to better center the horiz. ref at vertical midpt
		.arb.f.plot create line $x1 $horzReference $x2 $horzReference -fill "#999999" -width 2 -tags xaxis
	tk::text .arb.f.textbox -width 38 -height 3
        bind .arb.f.textbox <KeyRelease> { .arb.f.buttons.prevw(b) state !disabled }
	    bind .arb.f.textbox <FocusOut> { eval makeawg::grabSequence [.arb.f.textbox get 1.0 end] }
	    bind .arb.f.textbox <Key-Tab> { eval makeawg::grabSequence [.arb.f.textbox get 1.0 end] }
	ttk::separator .arb.f.sep6; #---------------
	ttk::button .arb.f.quit(b) -text "Quit" -command "destroy ."
#===================================================================================================
	grid .arb.f -row 0 -column 0 -sticky news
	grid .arb.f.title(l) -row 0 -column 0 -columnspan 10 -padx {4 4} -pady {8 8} -sticky ew
	grid .arb.f.sep1a -row 1 -column 0 -columnspan 10 -padx {4 4} -pady {2 1} -sticky ew
	grid .arb.f.sep1b -row 2 -column 0 -columnspan 10 -padx {4 4} -pady {0 2} -sticky ew
	grid .arb.f.period(l) -row 3 -column 0 -columnspan 4 -padx {4 4} -pady {4 4} -sticky e
	grid .arb.f.period(ent) -row 3 -column 4 -columnspan 6 -padx {4 0} -pady {2 4} -sticky w
	grid .arb.f.sep2a -row 5 -column 0 -columnspan 10 -padx {4 4} -pady {2 1} -sticky ew
	grid .arb.f.sep2b -row 6 -column 0 -columnspan 10 -padx {4 4} -pady {0 4} -sticky ew
	grid .arb.f.select(l) -row 7 -column 1 -columnspan 3 -padx {4 4} -pady {2 4} -sticky e
	grid .arb.f.select(dropdn) -row 7 -column 4 -columnspan 2 -padx {4 4} -pady {2 4} -sticky w
	grid .arb.f.neg(chk) -row 7 -column 6 -columnspan 2 -padx {4 2} -pady {2 4} -sticky e
	grid .arb.f.startt(l) -row 8 -column 0 -columnspan 4 -padx {4 4} -pady {2 4} -sticky e
	grid .arb.f.startt(ent) -row 8 -column 4 -columnspan 6 -padx {4 0} -pady {2 4} -sticky w
	grid .arb.f.dur(l) -row 10 -column 0 -columnspan 4 -padx {4 4} -pady {2 4} -sticky e
	grid .arb.f.dur(ent) -row 10 -column 4 -columnspan 6 -padx {4 0} -pady {2 4} -sticky w
#---------------
	grid .arb.f.vir -row 12 -column 0 -columnspan 10 -padx {4 4} -pady {6 6} -sticky ewns
	grid .arb.f.vir.volt(chk) -row 0 -column 2 -columnspan 1 -padx {6 2} -pady {2 1} -sticky ew
	grid .arb.f.vir.curr(chk) -row 0 -column 4 -columnspan 1 -padx {6 2} -pady {2 1} -sticky ew
	grid .arb.f.vir.resis(chk) -row 0 -column 6 -columnspan 1 -padx {6 2} -pady {2 1} -sticky ew
	grid .arb.f.vir.volt(l) -row 1 -column 1 -padx {6 2} -pady {2 4} -sticky e
	grid .arb.f.vir.volt(ent) -row 1 -column 2 -padx {2 6} -pady {2 4} -sticky w
	grid .arb.f.vir.curr(l)	 -row 1 -column 3 -padx {6 2} -pady {2 4} -sticky e
	grid .arb.f.vir.curr(ent) -row 1 -column 4 -padx {2 6} -pady {2 4} -sticky w
	grid .arb.f.vir.resis(l) -row 1 -column 5 -padx {6 2} -pady {2 4} -sticky e
	grid .arb.f.vir.resis(ent) -row 1 -column 6 -padx {2 6} -pady {2 4} -sticky w
#---------------
	grid .arb.f.buttons -row 25 -column 0 -columnspan 10 -padx {4 4} -pady {2 2} -sticky news	
	grid .arb.f.buttons.prevw(b) -row 0 -column 0 -columnspan 2 -padx {2 2} -pady {6 2} -sticky ew
	grid .arb.f.buttons.del(b) -row 0 -column 2 -columnspan 2 -padx {2 2} -pady {6 2} -sticky ew
	grid .arb.f.buttons.makedg(b) -row 0 -column 4 -padx {2 2} -pady {6 2} -sticky ew
	grid .arb.f.buttons.viewdg(b) -row 0 -column 5 -columnspan 2 -padx {2 2} -pady {6 2} -sticky ew	
	grid .arb.f.buttons.reset(b) -row 0 -column 7 -columnspan 3 -padx {2 2} -pady {6 2} -sticky ew
	grid .arb.f.sep5 -row 28 -column 0 -columnspan 10 -padx {4 4} -pady {6 2} -sticky ew		
	grid .arb.f.plot -row 29 -column 0 -columnspan 10 -padx {5 5} -pady {5 5}
	grid .arb.f.textbox -row 30 -column 0 -columnspan 10 -padx {5 5} -pady {5 5}	
	grid .arb.f.sep6 -row 32 -column 0 -columnspan 10 -padx {4 4} -pady {6 2} -sticky ew	
	grid .arb.f.quit(b) -row 33 -column 0 -columnspan 10 -padx {4 4} -pady {4 4}	
}
####################################################################################################

::makeawg::addPulse

source C:/usr/local/lib/dlsh/bin/dlshell.tcl
raise .arb
wm state .console icon


