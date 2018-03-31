#!/bin/sh
# Run wish from the users PATH \
exec wish -f "$0" ${1+"$@"}
#console show

# revision 1.3.3

#package require BWidget
package require dlsh


#source {C:\Users\lab\Dropbox\pshih\WaveGen\WaveGen.tcl}
#source {Z:\Dropbox\Science\[SheinbergLab]\pshih\WaveGen\WaveGen.tcl}
#source {L:\projects\analysis\pshih\WaveGen\WaveGen.tcl

#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
namespace eval ::makeAWG:: {
	variable startt 
	variable vertices
	variable period 1500
	variable volt
	variable curr
	variable resis
	variable dur
	variable endt
	variable i 0
	variable pulseBoxSel
	variable pulseList Add_pulse
	variable crudePlot
	variable mu [format %c 181]
	variable om [format %c 937]
	variable em [format %c 8212]
	variable hold
	variable neg
	variable maxAmpl
	variable waveParams
	variable ampType
	
	namespace eval expandSequence:: {}
}

#--  This is kept here for easy access
namespace eval ::TempSpace:: {
	variable geom "319x544+550+300"
	variable canvasWidth 304
	variable canvasHeight 100
}
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


proc makeAWG::updateFields {} {
	#-- (Subtract 1, index starts at 0)
	set numInBox [expr [llength $makeAWG::pulseList] -1]
			
	if {$makeAWG::pulseBoxSel == "Add_pulse" } {
		if {$numInBox == 0} {
			.arb.f.buttons.prevw(b) state !disabled
			.arb.f.buttons.del(b) state !disabled
			.arb.f.buttons.reset(b) state !disabled
			.arb.f.startt(ent) state !disabled
			.arb.f.dur(ent) state !disabled
			.arb.f.neg(chk) state !disabled
			
		#-- Set up the default parameters for the first pulse			
			set makeAWG::startt(0) 0;			# microseconds
			set makeAWG::dur(0) 100;			# microseconds		
			set makeAWG::endt(0) 100;			# microseconds
			set makeAWG::volt(0) 30;			# millivolts
			set makeAWG::curr(0) 30;			# microAmperes
			set makeAWG::resis(0) 1;			# kOhms or E+3 microOhms
			set makeAWG::neg(0) 0;
		
		} elseif {$numInBox > 0} {
		#-- The following sets up the parameters for a new pulse to be added into the combobox
			set makeAWG::i $numInBox
			set previ [expr $numInBox - 1]

			set makeAWG::volt($makeAWG::i) $makeAWG::volt($previ)
			set makeAWG::curr($makeAWG::i) $makeAWG::curr($previ)
			set makeAWG::resis($makeAWG::i) $makeAWG::resis($previ)
			set makeAWG::dur($makeAWG::i) $makeAWG::dur($previ)
			set makeAWG::neg($makeAWG::i) 0
			set duration $makeAWG::dur($previ)
			set startPrev $makeAWG::startt($previ)
			set makeAWG::startt($makeAWG::i) [expr $startPrev + $duration + 1]
			set start $makeAWG::startt($makeAWG::i)
			set makeAWG::endt($makeAWG::i) [expr $start + $duration]
			echo "makeAWG::endt($makeAWG::i) $makeAWG::endt($makeAWG::i)"
		}

	#-- Add the new pulse to the combobox and select its index
		lappend makeAWG::pulseList [expr "$numInBox + 1"]
		.arb.f.select(dropdn) configure -values "$makeAWG::pulseList"
		.arb.f.select(dropdn) set [expr "$numInBox + 1"]
		
	#-- Update the entry widget with the values for the new pulse
		.arb.f.startt(ent) configure -textvariable makeAWG::startt($makeAWG::i)
		.arb.f.dur(ent) configure -textvariable makeAWG::dur($makeAWG::i)
		.arb.f.vir.volt(ent) configure -textvariable makeAWG::volt($makeAWG::i)
		.arb.f.vir.curr(ent) configure -textvariable makeAWG::curr($makeAWG::i)
		.arb.f.vir.resis(ent) configure -textvariable makeAWG::resis($makeAWG::i)
		.arb.f.neg(chk) configure -variable makeAWG::neg($makeAWG::i)

		::makeAWG::CheckIfTwo

	} elseif {$makeAWG::pulseBoxSel > 0} {	
		set makeAWG::i [expr $makeAWG::pulseBoxSel - 1]
		.arb.f.startt(ent) configure -textvariable makeAWG::startt($makeAWG::i)
		.arb.f.dur(ent) configure -textvariable makeAWG::dur($makeAWG::i)
		.arb.f.vir.volt(ent) configure -textvariable makeAWG::volt($makeAWG::i)
		.arb.f.vir.curr(ent) configure -textvariable makeAWG::curr($makeAWG::i)
		.arb.f.vir.resis(ent) configure -textvariable makeAWG::resis($makeAWG::i)
		.arb.f.neg(chk) configure -variable makeAWG::neg($makeAWG::i)	
	}
}

proc ::makeAWG::prevwIt {} {
#///////////////////////////////////////////////////////////////////////////////////////////////////
#//  Put first vertex down at t = 0 @ ampl = 0;
#//  Get value of next pulse in $pulses -- subtract 1 to get its index in other variables;
#//  Start delay: If startt(pulse1) is not at time 0, then draw another vertex at startt(pulse1) @ ampl = 0;
#//  Turn pulse "on": Immediately put down another vertex @ ampl = user-set value;
#//  Draw pulse for dur(pulse1): Grab value of endt(pulse1) and put down vertex @ ampl = user-set value;
#//  Return to baseline 0: Immediately put down another vertex at next time point @ ampl = 0;
#//
#//  Get value of next pulse in $pulses...
#//  Start delay: Get startt(pulse2), if startt(pulse2) equals previous vertex, then don't draw; otherwise draw new vertex @ ampl = 0;
#//  Turn pulse "on": ...;
#//  ...
#//  Do this for each value in $pulses;
#//  End by drawing final vertex at the end of time series @ ampl = 0;
#///////////////////////////////////////////////////////////////////////////////////////////////////

	set time2pxlRatio [expr "(($TempSpace::canvasWidth - 4) / ($makeAWG::period*1.000))"];	#scale x-preview by the single-stimulation period
																						#subtract 4 for padding the waveform
	set pulses [lrange $makeAWG::pulseList 1 end]; 		#list of all available user added pulses
	set numPulses [llength $makeAWG::pulseList]; 		#total number of pulses to draw

	set reference [expr "ceil($TempSpace::canvasHeight/2)"]
	set theEnd [expr "int($makeAWG::period * $time2pxlRatio)"];
	set makeAWG::vertices [list [list 0 $reference]]
	
	set makeAWG::waveParams [list $makeAWG::period]
	set vcount 1;  																#includes vertex @ (0, 0)	
	foreach value $pulses {
		puts stdout $value
		set index [expr $value - 1]
		set makeAWG::maxAmpl [expr max([join [array get makeAWG::curr] ","])]
		set ampl2pxlRatio [expr "(($TempSpace::canvasHeight - 14) / ($makeAWG::maxAmpl*2.000))"]; #scale y-preview by the max amplitude
																						 #subtract 20 for padding the waveform
		if {$makeAWG::neg($index) == 1} {
			set amplcalc [expr -1 * $makeAWG::curr($index)]
		} elseif {$makeAWG::neg($index) == 0} {
			set amplcalc $makeAWG::curr($index)
		}
		
	#-- Update variable endt
		set makeAWG::endt($index) [expr $makeAWG::startt($index) + $makeAWG::dur($index)]
		
		set startOn [expr "int($makeAWG::startt($index) * $time2pxlRatio)"];			#shift plot to the right by 1 to account for border (?)
		set endOn [expr "int($makeAWG::endt($index) * $time2pxlRatio)"];
		set ampl [expr "int($reference - ($amplcalc * $ampl2pxlRatio))"];

		if {$makeAWG::startt($index) != 0} {
			lappend makeAWG::vertices [list $startOn $reference]
			incr vcount
		}
		if {[info exists prevIndex] && $makeAWG::endt($prevIndex) == $makeAWG::startt($index)} {
			puts stderr "Time point at $startOn was skipped"
		} else {
			lappend makeAWG::vertices [list $startOn $ampl]
			incr vcount
		}
		lappend makeAWG::vertices [list $endOn $ampl]
		incr vcount
		lappend makeAWG::vertices [list $endOn $reference]
		incr vcount

		lappend makeAWG::waveParams \
		    [list [list $index] \
                  [list $makeAWG::startt($index) $makeAWG::dur($index) $makeAWG::endt($index)] \
                  [list [list $makeAWG::volt($index) $makeAWG::curr($index) $makeAWG::resis($index)] \
                        [list $makeAWG::neg]]]
            
		set prevIndex $index
	}
	lappend makeAWG::waveParams [list $makeAWG::ampType]

	.arb.f.textbox replace 1.0 end "[list $makeAWG::waveParams]"
	
	lappend makeAWG::vertices [list $theEnd $reference]
	incr vcount
	unset prevIndex
#	puts stdout "$vcount $makeAWG::vertices"
	
#-- Delete plot and redraw (in next steps)
	.arb.f.plot delete waveform

#-- Draw the vertices on the canvas
	for {set j 1} {$j < $vcount} {incr j} {
		set prevj [expr $j - 1];
		set x0 [expr [lindex $makeAWG::vertices $prevj 0] + 3]
		set y0 [lindex $makeAWG::vertices $prevj 1]
		set x1 [expr [lindex $makeAWG::vertices $j 0] + 3]
		set y1 [lindex $makeAWG::vertices $j 1]
		
#		puts stdout "$x0 $y0 $x1 $y1"
		set c($j) [.arb.f.plot create line $x0 $y0 $x1 $y1 -fill "#ffffff" -width 1 -tags waveform]
	}
	
	.arb.f.buttons.export(b) state !disabled
}

proc ::makeAWG::resetPulseList {} {
	set makeAWG::i 0;
	set makeAWG::period 1500;		# microseconds
	array unset makeAWG::startt;
	array unset makeAWG::dur;
	array unset makeAWG::endt;
	array unset makeAWG::volt;
	array unset makeAWG::curr;
	array unset makeAWG::resis;
	array unset makeAWG::neg;
	array set makeAWG::startt;
	array set makeAWG::dur;
	array set makeAWG::endt;
	array set makeAWG::volt;
	array set makeAWG::curr;
	array set makeAWG::resis;
	array set makeAWG::neg;
	
	set makeAWG::pulseList Add_pulse;
	.arb.f.select(dropdn) configure -values "$makeAWG::pulseList"
	.arb.f.select(dropdn) set ""
	.arb.f.plot delete waveform
	.arb.f.buttons.prevw(b) state disabled
	.arb.f.buttons.del(b) state disabled
	.arb.f.buttons.viewdg(b) state disabled	
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

proc ::makeAWG::CheckIfTwo {} {
	set howMany [expr $makeAWG::hold(0) + $makeAWG::hold(1) + $makeAWG::hold(2)]
	if { $howMany >= 2 } {
		if {$makeAWG::hold(0)==0} {
			foreach i {chk ent} {
				.arb.f.vir.volt(${i}) state disabled
				set makeAWG::ampType "V"
				foreach j {curr resis} {
					.arb.f.vir.${j}(${i}) state !disabled
				}
			}
		} elseif {$makeAWG::hold(1)==0} {
			foreach i {chk ent} {
				.arb.f.vir.curr(${i}) state disabled
				set makeAWG::ampType "I"
				foreach j {volt resis} {
					.arb.f.vir.${j}(${i}) state !disabled
				}
			}		
		} elseif {$makeAWG::hold(2)==0} {
			foreach i {chk ent} {
				.arb.f.vir.resis(${i}) state disabled
				set makeAWG::ampType "R"
				foreach j {volt curr} {
					.arb.f.vir.${j}(${i}) state !disabled
				}
			}
		}
	} else {
		foreach j {volt curr resis} {
			.arb.f.vir.${j}(chk) state !disabled
		}
		foreach j {volt curr resis} {
			.arb.f.vir.${j}(ent) state disabled
		}
	}
}

proc ::makeAWG::VIR {changedVar value} {
	set makeAWG::${changedVar}($makeAWG::i) $value
	puts stdout "${changedVar} $value"

	set howMany [expr $makeAWG::hold(0) + $makeAWG::hold(1) + $makeAWG::hold(2)]
	if { $howMany == 2 } { 
		if {$makeAWG::hold(1)==1 && $makeAWG::hold(2)==1 && $makeAWG::hold(0)==0} {
			set makeAWG::volt($makeAWG::i) [expr $makeAWG::resis($makeAWG::i) * $makeAWG::curr($makeAWG::i)]
		} elseif {$makeAWG::hold(0)==1 && $makeAWG::hold(2)==1 && $makeAWG::hold(1)==0} {
			set makeAWG::curr($makeAWG::i) [expr $makeAWG::volt($makeAWG::i) / $makeAWG::resis($makeAWG::i)]
		} elseif {$makeAWG::hold(0)==1 && $makeAWG::hold(1)==1 && $makeAWG::hold(2)==0} {
			set makeAWG::resis($makeAWG::i) [expr $makeAWG::volt($makeAWG::i) / $makeAWG::curr($makeAWG::i)]
		}			
	} else { 
		tk_messageBox \
		-message "You must provide at least two of the stimulation parameters to compute the other."
	}
}

proc ::makeAWG::deleteIt {} {
    set makeAWG::pulseList [.arb.f.select(dropdn) cget -values]
	
    if {$makeAWG::pulseBoxSel in $makeAWG::pulseList} {
        set i [lsearch -exact $makeAWG::pulseList $makeAWG::pulseBoxSel]
        set makeAWG::pulseList [lreplace $makeAWG::pulseList $i $i]
        .arb.f.select(dropdn) configure -values $makeAWG::pulseList	
        .arb.f.select(dropdn) set ""
	}
}

proc ::makeAWG::addPulse {} {
	
	font create HeaderFont -family Helvetica -size 11 -weight bold
#	font create TitleFont -family Helvetica -size 9 -slant italic
	
	toplevel .arb
	wm title .arb "Arbitrary Waveform Maker"
	wm geometry .arb $TempSpace::geom
	
	bind .arb <Control-h> {console show}	
#---------------------------------------------------------------------------------------------------
	ttk::style theme use xpnative
	
	ttk::frame .arb.f
	ttk::labelframe .arb.f.vir  -borderwidth 1 -relief solid -padding "8 1" \
		-text "Select two:"
	ttk::frame .arb.f.buttons -padding "1 1"
	
	ttk::label .arb.f.title(l) -text {The Makeshift Arbitrary Waveform Maker} -font HeaderFont
	ttk::separator .arb.f.sep1a; #---------------
	ttk::separator .arb.f.sep1b; #---------------
	ttk::label .arb.f.period(l) -text "Single stim period (${makeAWG::mu}s):"
	ttk::entry .arb.f.period(ent) -width 7 -textvariable makeAWG::period
		bind .arb.f.period(ent) <KeyRelease> { .arb.f.period(ent) configure -textvariable makeAWG::period }
	ttk::separator .arb.f.sep2a; #---------------
	ttk::separator .arb.f.sep2b; #---------------

	ttk::label .arb.f.select(l) -text "Pulse #:"
	ttk::combobox .arb.f.select(dropdn) -width 10 -textvariable makeAWG::pulseBoxSel
		.arb.f.select(dropdn) configure -values $makeAWG::pulseList
		.arb.f.select(dropdn) state readonly
		bind .arb.f.select(dropdn) <<ComboboxSelected>> {\
			set makeAWG::pulseBoxSel [.arb.f.select(dropdn) get]; \
			makeAWG::updateFields}
			
	ttk::checkbutton .arb.f.neg(chk) -variable makeAWG::neg($makeAWG::i) -onvalue 1 -offvalue 0 -text "neg"\
		-command ""
		.arb.f.neg(chk) state disabled
	ttk::label .arb.f.neg(l) -text ""

	ttk::label .arb.f.startt(l) -text "Pulse start time (${makeAWG::mu}s):"
	ttk::entry .arb.f.startt(ent) -width 7 -textvariable makeAWG::startt($makeAWG::i)
		.arb.f.startt(ent) state disabled
		bind .arb.f.startt(ent) <KeyRelease> { .arb.f.startt(ent) configure -textvariable makeAWG::startt($makeAWG::i)}	
	
	ttk::label .arb.f.dur(l) -text "Duration of pulse (${makeAWG::mu}s):"
	ttk::entry .arb.f.dur(ent) -width 7 -textvariable makeAWG::dur($makeAWG::i)
		.arb.f.dur(ent) state disabled
		bind .arb.f.dur(ent) <KeyRelease> { .arb.f.dur(ent) configure -textvariable makeAWG::dur($makeAWG::i)}

	set makeAWG::hold(0) 0
	set makeAWG::hold(1) 1
	set makeAWG::hold(2) 1

	ttk::checkbutton .arb.f.vir.volt(chk) -variable makeAWG::hold(0) -onvalue 1 -offvalue 0 \
			-command {makeAWG::CheckIfTwo}
		.arb.f.vir.volt(chk) state disabled
	ttk::checkbutton .arb.f.vir.curr(chk) -variable makeAWG::hold(1) -onvalue 1 -offvalue 0 \
			-command {makeAWG::CheckIfTwo}
		.arb.f.vir.curr(chk) state selected 
		.arb.f.vir.curr(chk) state disabled
	ttk::checkbutton .arb.f.vir.resis(chk) -variable makeAWG::hold(2) -onvalue 1 -offvalue 0 \
			-command {makeAWG::CheckIfTwo}
		.arb.f.vir.resis(chk) state selected
		.arb.f.vir.resis(chk) state disabled

	ttk::label .arb.f.vir.volt(l) -text "V (mV):"
	ttk::entry .arb.f.vir.volt(ent) -width 5 -textvariable makeAWG::volt($makeAWG::i)
		.arb.f.vir.volt(ent) state disabled
		bind .arb.f.vir.volt(ent) <KeyRelease> { makeAWG::VIR volt $makeAWG::volt($makeAWG::i) }
		
	ttk::label .arb.f.vir.curr(l) -text "I (${makeAWG::mu}A):"
	ttk::entry .arb.f.vir.curr(ent) -width 5 -textvariable makeAWG::curr($makeAWG::i)
		.arb.f.vir.curr(ent) state disabled
		bind .arb.f.vir.curr(ent) <KeyRelease> { makeAWG::VIR curr $makeAWG::curr($makeAWG::i) }
		
	ttk::label .arb.f.vir.resis(l) -text "R (k$makeAWG::om):"
	ttk::entry .arb.f.vir.resis(ent) -width 5 -textvariable makeAWG::resis($makeAWG::i)
		.arb.f.vir.resis(ent) state disabled
		bind .arb.f.vir.resis(ent) <KeyRelease> { makeAWG::VIR resis $makeAWG::resis($makeAWG::i) }

	ttk::button .arb.f.buttons.prevw(b) -text "Preview" -width 9 \
		-command "makeAWG::prevwIt"
		.arb.f.buttons.prevw(b) state disabled

	ttk::button .arb.f.buttons.del(b) -text "Delete" -width 8 \
		-command "makeAWG::deleteIt"
		.arb.f.buttons.del(b) state disabled
		
	ttk::button .arb.f.buttons.export(b) -text "Export" -width 8 \
		-command "makeAWG::expandSequence"
		.arb.f.buttons.export(b) state disabled
	
	ttk::button .arb.f.buttons.viewdg(b) -text "View dg" -width 8 \
		-command "dg_view arb"
		.arb.f.buttons.viewdg(b) state disabled
		
	ttk::button .arb.f.buttons.reset(b) -text "Reset" -width 7 \
		-command "makeAWG::resetPulseList"
		.arb.f.buttons.reset(b) state disabled

	ttk::separator .arb.f.sep5; #---------------
	
	canvas .arb.f.plot -width $TempSpace::canvasWidth -height $TempSpace::canvasHeight \
		-background "#333333" -relief solid -border 1
		set x1 1
		set x2 [expr $TempSpace::canvasWidth + 2]
		set reference [expr round($TempSpace::canvasHeight/2)]
		.arb.f.plot create line $x1 $reference $x2 $reference -fill "#999999" -width 2 -tags xaxis
	
	tk::text .arb.f.textbox -width 38 -height 4
	ttk::separator .arb.f.sep6; #---------------
	
	ttk::button .arb.f.quit(b) -text "Quit" -command "destroy ."
#---------------------------------------------------------------------------------------------------

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
	grid .arb.f.neg(l) -row 7 -column 8 -padx {2 4} -pady {2 4} -sticky w
	
	grid .arb.f.startt(l) -row 8 -column 0 -columnspan 4 -padx {4 4} -pady {2 4} -sticky e
	grid .arb.f.startt(ent) -row 8 -column 4 -columnspan 6 -padx {4 0} -pady {2 4} -sticky w

	grid .arb.f.dur(l) -row 10 -column 0 -columnspan 4 -padx {4 4} -pady {2 4} -sticky e
	grid .arb.f.dur(ent) -row 10 -column 4 -columnspan 6 -padx {4 0} -pady {2 4} -sticky w

#	grid .arb.f.sep3 -row 11 -column 0 -columnspan 10 -padx {4 4} -pady {2 1} -sticky ew
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
#	grid .arb.f.sep4 -row 13 -column 0 -columnspan 10 -padx {4 4} -pady {1 2} -sticky ew

	grid .arb.f.buttons -row 25 -column 0 -columnspan 10 -padx {4 4} -pady {2 2} -sticky news	
	grid .arb.f.buttons.prevw(b) -row 0 -column 0 -columnspan 2 -padx {2 2} -pady {6 2} -sticky ew
	grid .arb.f.buttons.del(b) -row 0 -column 2 -columnspan 2 -padx {2 2} -pady {6 2} -sticky ew
	grid .arb.f.buttons.export(b) -row 0 -column 4 -padx {2 2} -pady {6 2} -sticky ew
	grid .arb.f.buttons.viewdg(b) -row 0 -column 5 -columnspan 2 -padx {2 2} -pady {6 2} -sticky ew	
	grid .arb.f.buttons.reset(b) -row 0 -column 7 -columnspan 3 -padx {2 2} -pady {6 2} -sticky ew

	grid .arb.f.sep5 -row 28 -column 0 -columnspan 10 -padx {4 4} -pady {6 2} -sticky ew		
	grid .arb.f.plot -row 29 -column 0 -columnspan 10 -padx {5 5} -pady {5 5}
	grid .arb.f.textbox -row 30 -column 0 -columnspan 10 -padx {5 5} -pady {5 5}	

	grid .arb.f.sep6 -row 32 -column 0 -columnspan 10 -padx {4 4} -pady {6 2} -sticky ew	
	grid .arb.f.quit(b) -row 33 -column 0 -columnspan 10 -padx {4 4} -pady {4 4}	
}
#---------------------------------------------------------------------------------------------------
proc ::makeAWG::exportIt {} {
	set arbdg [makeAWG::expandSequence $makeAWG::waveParams]
    .arb.f.buttons.viewdg(b) state !disabled
    makeAWG::plotdllist $arbdg:pulseSeries
}


proc ::makeAWG::expandSequence::getAmplitudes {numPulses ampIndex} {
    for {set i 1} {$i < $numPulses} {incr i} {
        lappend amplitudes [lindex $makeAWG::waveParams $i 2 0 $ampIndex]
    }
    return $amplitudes
}

proc ::makeAWG::expandSequence {waveParams} {
	    set wavePeriod [lindex $waveParams 0];
	set resolution [expr $wavePeriod * 2]; 							#This could be made to be user modifiable
	set upsample [expr "($resolution / ($wavePeriod*1.000))"]; 		# currently a superfluous step
	set theEnd [expr "int($wavePeriod * $upsample)"];
	set numPulses [expr "[llength [lindex $waveParams]] - 2"]; 		#account for 2 extra sublists (wavePeriod and ampType)
    set ampType [lindex $waveParams [expr $numPulses + 1]];
	switch -glob -- $ampType {
	    V {set ampIndex 0}
	    I {set ampIndex 1}
	    R {set ampIndex 2}
    }
    set amplitudes [makeAWG::expandSequence::getAmplitudes $numPulses $ampIndex]
    set maxAmplitude [expr max([join $amplitudes ","])]

	if {$makeAWG::startt(0) != 0} {
		set startAt [lindex $waveParams 1 1 0]
	} else { set startAt 0 }

	dg_create pulsesGroup
	dl_local first [dl_zeros [expr "int($startAt * $upsample) + 1"]]

	for {set i 1} {$i < $numPulses} {incr i} {
        set starttime [lindex $waveParams $i 1 0]
        set durtime [lindex $waveParams $i 1 1]
        set endtime [lindex $waveParams $i 1 2]
        set negPulse [lindex $waveParams $i 2 1]
        set currentAmp [lindex $waveParams $i 2 0 $ampIndex]
		set scaleAmp [expr "($currentAmp/$maxAmplitude) * 1.00"]  

	#~ starting at 0th timept currently adds 1 extra timept to the time series :(
        dl_local timeseries($i) \
			[dl_repeat 1 [expr "int($starttime * $upsample)"]]
			if {[info exists prevEndtime]} {
				dl_local timeseries($i) \
					[dl_concat timeseries($i) \
						[dl_zeros [expr "int($starttime - $prevEndtime) * $upsample)"]]]
			}
		if {$makeAWG::neg($i) == 0} {
			dl_set timeseries($i) [dl_mult timeseries($i) $scaleAmp]
		} elseif {$makeAWG::neg($i) == 1} {
			dl_set timeseries($i) [dl_mult timeseries($i) [expr $scaleAmp * -1]]
		}
		dg_addExistingList pulsesGroup timeseries($i) timeseries$i
        set prevEndtime $endtime
	}

	dl_local last [dl_zeros [expr "$theEnd - int($endtime * $upsample)"]]
	dg_addExistingList pulsesGroup $last last

	dl_local pulseSeries $first
	foreach tgroup [dl_tcllist [dg_listnames pulsesGroup]] {
		 dl_local pulseSeries [dl_concat pulseSeries pulsesGroup:$tgroup]
	}

	dg_delete pulsesGroup

#@-- To be expanded at a later date... (maybe)
    set arbdg [dg_create]
#    if {[dg_exists arb]} {dg_delete arb}
#	 dg_create arb
    dg_addExistingList $arbdg pulseSeries
#    dg_write arb arb.dg
	return $arbdg;
}

proc ::makeAWG::plotdllist {selection} {
	clearwin;
	dlp_create waveform
	dl_local x [dl_fromto 0 [dl_length arb::$selection]]
	dlp_addXData waveform $x
	dlp_addYData waveform $selection
	dlp_setxrange waveform 0 [dl_length $selection]
	dlp_setyrange waveform -1.5 1.5
	dlp_draw waveform lines 0
	dlp_plot waveform
}

::makeAWG::addPulse

source C:/usr/local/lib/dlsh/bin/dlshell.tcl
raise .arb
wm state .console icon


