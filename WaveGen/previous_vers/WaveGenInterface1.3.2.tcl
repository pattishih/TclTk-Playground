#!/bin/sh
# Run wish from the users PATH \
exec wish -f "$0" ${1+"$@"}
#console show

# revision 1.3.2

#package require BWidget
package require dlsh


#source {C:\Users\lab\Dropbox\pshih\WaveGen\WaveGen.tcl}
#source {Z:\Dropbox\Science\[SheinbergLab]\pshih\WaveGen\WaveGen.tcl}
#source {L:\projects\analysis\pshih\WaveGen\WaveGen.tcl

#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
namespace eval ::waveGUI:: {
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
}

#--  This is kept here for easy access
namespace eval ::TempSpace:: {
	variable geom "319x544+550+300"
	variable canvasWidth 304
	variable canvasHeight 100
}
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


proc waveGUI::updateFields {} {
	#-- (Subtract 1, index starts at 0)
	set numInBox [expr [llength $waveGUI::pulseList] -1]
			
	if {$waveGUI::pulseBoxSel == "Add_pulse" } {
		if {$numInBox == 0} {
			.arb.f.buttons.prevw(b) state !disabled
			.arb.f.buttons.del(b) state !disabled
			.arb.f.buttons.reset(b) state !disabled
			.arb.f.startt(ent) state !disabled
			.arb.f.dur(ent) state !disabled
			.arb.f.neg(chk) state !disabled
			
		#-- Set up the default parameters for the first pulse			
			set waveGUI::startt(0) 0;			# microseconds
			set waveGUI::dur(0) 100;			# microseconds		
			set waveGUI::endt(0) 100;			# microseconds
			set waveGUI::volt(0) 30;			# millivolts
			set waveGUI::curr(0) 30;			# microAmperes
			set waveGUI::resis(0) 1;			# kOhms or E+3 microOhms
			set waveGUI::neg(0) 0;
		
		} elseif {$numInBox > 0} {
		#-- The following sets up the parameters for a new pulse to be added into the combobox
			set waveGUI::i $numInBox
			set previ [expr $numInBox - 1]

			set waveGUI::volt($waveGUI::i) $waveGUI::volt($previ)
			set waveGUI::curr($waveGUI::i) $waveGUI::curr($previ)
			set waveGUI::resis($waveGUI::i) $waveGUI::resis($previ)
			set waveGUI::dur($waveGUI::i) $waveGUI::dur($previ)
			set waveGUI::neg($waveGUI::i) 0
			set duration $waveGUI::dur($previ)
			set startPrev $waveGUI::startt($previ)
			set waveGUI::startt($waveGUI::i) [expr $startPrev + $duration + 1]
			set start $waveGUI::startt($waveGUI::i)
			set waveGUI::endt($waveGUI::i) [expr $start + $duration]
			echo "waveGUI::endt($waveGUI::i) $waveGUI::endt($waveGUI::i)"
		}

	#-- Add the new pulse to the combobox and select its index
		lappend waveGUI::pulseList [expr "$numInBox + 1"]
		.arb.f.select(dropdn) configure -values "$waveGUI::pulseList"
		.arb.f.select(dropdn) set [expr "$numInBox + 1"]
		
	#-- Update the entry widget with the values for the new pulse
		.arb.f.startt(ent) configure -textvariable waveGUI::startt($waveGUI::i)
		.arb.f.dur(ent) configure -textvariable waveGUI::dur($waveGUI::i)
		.arb.f.vir.volt(ent) configure -textvariable waveGUI::volt($waveGUI::i)
		.arb.f.vir.curr(ent) configure -textvariable waveGUI::curr($waveGUI::i)
		.arb.f.vir.resis(ent) configure -textvariable waveGUI::resis($waveGUI::i)
		.arb.f.neg(chk) configure -variable waveGUI::neg($waveGUI::i)

		::waveGUI::CheckIfTwo

	} elseif {$waveGUI::pulseBoxSel > 0} {	
		set waveGUI::i [expr $waveGUI::pulseBoxSel - 1]
		.arb.f.startt(ent) configure -textvariable waveGUI::startt($waveGUI::i)
		.arb.f.dur(ent) configure -textvariable waveGUI::dur($waveGUI::i)
		.arb.f.vir.volt(ent) configure -textvariable waveGUI::volt($waveGUI::i)
		.arb.f.vir.curr(ent) configure -textvariable waveGUI::curr($waveGUI::i)
		.arb.f.vir.resis(ent) configure -textvariable waveGUI::resis($waveGUI::i)
		.arb.f.neg(chk) configure -variable waveGUI::neg($waveGUI::i)	
	}
}

proc ::waveGUI::prevwIt {} {
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

	set time2pxlRatio [expr "(($TempSpace::canvasWidth - 4) / ($waveGUI::period*1.000))"];	#scale x-preview by the single-stimulation period
																						#subtract 4 for padding the waveform
	set pulses [lrange $waveGUI::pulseList 1 end]; 		#list of all available user added pulses
	set numPulses [llength $waveGUI::pulseList]; 		#total number of pulses to draw

	set reference [expr "ceil($TempSpace::canvasHeight/2)"]
	set endend [expr "int($waveGUI::period * $time2pxlRatio)"];
	set waveGUI::vertices [list [list 0 $reference]]
	
	set waveGUI::waveParams [list $waveGUI::period]
	set vcount 1;  																#includes vertex @ (0, 0)	
	foreach value $pulses {
		puts stdout $value
		set index [expr $value - 1]


		set waveGUI::maxAmpl [expr max([join [array get waveGUI::curr] ","])]
		set ampl2pxlRatio [expr "(($TempSpace::canvasHeight - 14) / ($waveGUI::maxAmpl*2.000))"]; #scale y-preview by the max amplitude
																						 #subtract 20 for padding the waveform
		if {$waveGUI::neg($index) == 1} {
			set amplcalc [expr -1 * $waveGUI::curr($index)]
		} elseif {$waveGUI::neg($index) == 0} {
			set amplcalc $waveGUI::curr($index)
		}
		
	#-- Update variable endt
		set waveGUI::endt($index) [expr $waveGUI::startt($index) + $waveGUI::dur($index)]
		
		set startOn [expr "int($waveGUI::startt($index) * $time2pxlRatio)"];			#shift plot to the right by 1 to account for border (?)
		set endOn [expr "int($waveGUI::endt($index) * $time2pxlRatio)"];
		set ampl [expr "int($reference - ($amplcalc * $ampl2pxlRatio))"];

		if {$waveGUI::startt($index) != 0} {
			lappend waveGUI::vertices [list $startOn $reference]
			incr vcount
		}
		if {[info exists prevIndex] && $waveGUI::endt($prevIndex) == $waveGUI::startt($index)} {
			puts stderr "Time point at $startOn was skipped"
		} else {
			lappend waveGUI::vertices [list $startOn $ampl]
			incr vcount
		}
		lappend waveGUI::vertices [list $endOn $ampl]
		incr vcount
		lappend waveGUI::vertices [list $endOn $reference]
		incr vcount

		lappend waveGUI::waveParams [list [list $index] \
			[list $waveGUI::startt($index) $waveGUI::dur($index) $waveGUI::endt($index)] \
			[list $waveGUI::volt($index) $waveGUI::curr($index) $waveGUI::resis($index)]]
		
		set prevIndex $index
	}
	.arb.f.textbox replace 1.0 end "[list $waveGUI::waveParams]"
	
	lappend waveGUI::vertices [list $endend $reference]
	incr vcount
	unset prevIndex
#	puts stdout "$vcount $waveGUI::vertices"
	
#-- Delete plot and redraw (in next steps)
	.arb.f.plot delete waveform

#-- Draw the vertices on the canvas
	for {set j 1} {$j < $vcount} {incr j} {
		set prevj [expr $j - 1];
		set x0 [expr [lindex $waveGUI::vertices $prevj 0] + 3]
		set y0 [lindex $waveGUI::vertices $prevj 1]
		set x1 [expr [lindex $waveGUI::vertices $j 0] + 3]
		set y1 [lindex $waveGUI::vertices $j 1]
		
#		puts stdout "$x0 $y0 $x1 $y1"
		set c($j) [.arb.f.plot create line $x0 $y0 $x1 $y1 -fill "#ffffff" -width 1 -tags waveform]
	}
	
	.arb.f.buttons.export(b) state !disabled
}

proc ::waveGUI::resetPulseList {} {
	set waveGUI::i 0;
	set waveGUI::period 1500;		# microseconds
	array unset waveGUI::startt;
	array unset waveGUI::dur;
	array unset waveGUI::endt;
	array unset waveGUI::volt;
	array unset waveGUI::curr;
	array unset waveGUI::resis;
	array unset waveGUI::neg;
	array set waveGUI::startt;
	array set waveGUI::dur;
	array set waveGUI::endt;
	array set waveGUI::volt;
	array set waveGUI::curr;
	array set waveGUI::resis;
	array set waveGUI::neg;
	
	set waveGUI::pulseList Add_pulse;
	.arb.f.select(dropdn) configure -values "$waveGUI::pulseList"
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

proc ::waveGUI::CheckIfTwo {} {
	set howMany [expr $waveGUI::hold(0) + $waveGUI::hold(1) + $waveGUI::hold(2)]
	if { $howMany >= 2 } {
		if {$waveGUI::hold(0)==0} {
			foreach i {chk ent} {
				.arb.f.vir.volt(${i}) state disabled
				foreach j {curr resis} {
					.arb.f.vir.${j}(${i}) state !disabled
				}
			}
		} elseif {$waveGUI::hold(1)==0} {
			foreach i {chk ent} {
				.arb.f.vir.curr(${i}) state disabled
				foreach j {volt resis} {
					.arb.f.vir.${j}(${i}) state !disabled
				}
			}		
		} elseif {$waveGUI::hold(2)==0} {
			foreach i {chk ent} {
				.arb.f.vir.resis(${i}) state disabled
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

proc ::waveGUI::VIR {changedVar value} {
	set waveGUI::${changedVar}($waveGUI::i) $value
	puts stdout "${changedVar} $value"

	set howMany [expr $waveGUI::hold(0) + $waveGUI::hold(1) + $waveGUI::hold(2)]
	if { $howMany == 2 } { 
		if {$waveGUI::hold(1)==1 && $waveGUI::hold(2)==1 && $waveGUI::hold(0)==0} {
			set waveGUI::volt($waveGUI::i) [expr $waveGUI::resis($waveGUI::i) * $waveGUI::curr($waveGUI::i)]
		} elseif {$waveGUI::hold(0)==1 && $waveGUI::hold(2)==1 && $waveGUI::hold(1)==0} {
			set waveGUI::curr($waveGUI::i) [expr $waveGUI::volt($waveGUI::i) / $waveGUI::resis($waveGUI::i)]
		} elseif {$waveGUI::hold(0)==1 && $waveGUI::hold(1)==1 && $waveGUI::hold(2)==0} {
			set waveGUI::resis($waveGUI::i) [expr $waveGUI::volt($waveGUI::i) / $waveGUI::curr($waveGUI::i)]
		}			
	} else { 
		tk_messageBox \
		-message "You must provide at least two of the stimulation parameters to compute the other."
	}
}

proc ::waveGUI::deleteIt {} {
    set waveGUI::pulseList [.arb.f.select(dropdn) cget -values]
	
    if {$waveGUI::pulseBoxSel in $waveGUI::pulseList} {
        set i [lsearch -exact $waveGUI::pulseList $waveGUI::pulseBoxSel]
        set waveGUI::pulseList [lreplace $waveGUI::pulseList $i $i]
        .arb.f.select(dropdn) configure -values $waveGUI::pulseList	
        .arb.f.select(dropdn) set ""
	}
}

proc ::waveGUI::addPulse {} {
	
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
	ttk::label .arb.f.period(l) -text "Single stim period (${waveGUI::mu}s):"
	ttk::entry .arb.f.period(ent) -width 7 -textvariable waveGUI::period
		bind .arb.f.period(ent) <KeyRelease> { .arb.f.period(ent) configure -textvariable waveGUI::period }
	ttk::separator .arb.f.sep2a; #---------------
	ttk::separator .arb.f.sep2b; #---------------

	ttk::label .arb.f.select(l) -text "Pulse #:"
	ttk::combobox .arb.f.select(dropdn) -width 10 -textvariable waveGUI::pulseBoxSel
		.arb.f.select(dropdn) configure -values $waveGUI::pulseList
		.arb.f.select(dropdn) state readonly
		bind .arb.f.select(dropdn) <<ComboboxSelected>> {\
			set waveGUI::pulseBoxSel [.arb.f.select(dropdn) get]; \
			waveGUI::updateFields}
			
	ttk::checkbutton .arb.f.neg(chk) -variable waveGUI::neg($waveGUI::i) -onvalue 1 -offvalue 0 -text "neg"\
		-command ""
		.arb.f.neg(chk) state disabled
	ttk::label .arb.f.neg(l) -text ""

	ttk::label .arb.f.startt(l) -text "Pulse start time (${waveGUI::mu}s):"
	ttk::entry .arb.f.startt(ent) -width 7 -textvariable waveGUI::startt($waveGUI::i)
		.arb.f.startt(ent) state disabled
		bind .arb.f.startt(ent) <KeyRelease> { .arb.f.startt(ent) configure -textvariable waveGUI::startt($waveGUI::i)}	
	
	ttk::label .arb.f.dur(l) -text "Duration of pulse (${waveGUI::mu}s):"
	ttk::entry .arb.f.dur(ent) -width 7 -textvariable waveGUI::dur($waveGUI::i)
		.arb.f.dur(ent) state disabled
		bind .arb.f.dur(ent) <KeyRelease> { .arb.f.dur(ent) configure -textvariable waveGUI::dur($waveGUI::i)}

	set waveGUI::hold(0) 0
	set waveGUI::hold(1) 1
	set waveGUI::hold(2) 1

	ttk::checkbutton .arb.f.vir.volt(chk) -variable waveGUI::hold(0) -onvalue 1 -offvalue 0 \
			-command {waveGUI::CheckIfTwo}
		.arb.f.vir.volt(chk) state disabled
	ttk::checkbutton .arb.f.vir.curr(chk) -variable waveGUI::hold(1) -onvalue 1 -offvalue 0 \
			-command {waveGUI::CheckIfTwo}
		.arb.f.vir.curr(chk) state selected 
		.arb.f.vir.curr(chk) state disabled
	ttk::checkbutton .arb.f.vir.resis(chk) -variable waveGUI::hold(2) -onvalue 1 -offvalue 0 \
			-command {waveGUI::CheckIfTwo}
		.arb.f.vir.resis(chk) state selected
		.arb.f.vir.resis(chk) state disabled

	ttk::label .arb.f.vir.volt(l) -text "V (mV):"
	ttk::entry .arb.f.vir.volt(ent) -width 5 -textvariable waveGUI::volt($waveGUI::i)
		.arb.f.vir.volt(ent) state disabled
		bind .arb.f.vir.volt(ent) <KeyRelease> { waveGUI::VIR volt $waveGUI::volt($waveGUI::i) }
		
	ttk::label .arb.f.vir.curr(l) -text "I (${waveGUI::mu}A):"
	ttk::entry .arb.f.vir.curr(ent) -width 5 -textvariable waveGUI::curr($waveGUI::i)
		.arb.f.vir.curr(ent) state disabled
		bind .arb.f.vir.curr(ent) <KeyRelease> { waveGUI::VIR curr $waveGUI::curr($waveGUI::i) }
		
	ttk::label .arb.f.vir.resis(l) -text "R (k$waveGUI::om):"
	ttk::entry .arb.f.vir.resis(ent) -width 5 -textvariable waveGUI::resis($waveGUI::i)
		.arb.f.vir.resis(ent) state disabled
		bind .arb.f.vir.resis(ent) <KeyRelease> { waveGUI::VIR resis $waveGUI::resis($waveGUI::i) }

	ttk::button .arb.f.buttons.prevw(b) -text "Preview" -width 9 \
		-command "waveGUI::prevwIt"
		.arb.f.buttons.prevw(b) state disabled

	ttk::button .arb.f.buttons.del(b) -text "Delete" -width 8 \
		-command "waveGUI::deleteIt"
		.arb.f.buttons.del(b) state disabled
		
	ttk::button .arb.f.buttons.export(b) -text "Export" -width 8 \
		-command "waveGUI::exportIt"
		.arb.f.buttons.export(b) state disabled
	
	ttk::button .arb.f.buttons.viewdg(b) -text "View dg" -width 8 \
		-command "dg_view arb"
		.arb.f.buttons.viewdg(b) state disabled
		
	ttk::button .arb.f.buttons.reset(b) -text "Reset" -width 7 \
		-command "waveGUI::resetPulseList"
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

#set waveGUI::vertices [list {0 50} {0 5} {20 5} {20 50} {20 50} {20 94} {40 94} {40 50} {40 50} {40 5} {60 5} {60 50}]
#set waveGUI::startt {0 0 1 101 2 202}
#set waveGUI::endt {0 100 1 201 2 302}

proc ::waveGUI::exportIt {} {
	clearwin;
	
	set resolution [expr $waveGUI::period * 2]; 	#This could be made to be user modifiable
	set upsample [expr "($resolution / ($waveGUI::period*1.000))"]; # currently a superfluous step
	set endend [expr "int($waveGUI::period * $upsample)"];
	
	set maxAmp2 [expr max([join [array get waveGUI::curr] ","])]

	foreach {index val} [array get waveGUI::startt] {lappend starttimes $val}
	foreach {index val} [array get waveGUI::endt] {lappend endtimes $val}
	foreach {index val} [array get waveGUI::dur] {lappend durtimes $val}

    dl_set starttimes $starttimes
    dl_set endtimes $endtimes
    dl_set durtimes $durtimes
    set lstarttimes [dl_length starttimes]
    set lendtimes [dl_length endtimes]
    set ldurtimes [dl_length durtimes]

	if {$waveGUI::startt(0) != 0} {
		set startAt "[expr [lindex [dl_tcllist starttimes] 1] - 1]"
	} else { set startAt 0 }

	dg_create pulses
	dl_local first [dl_zeros [expr "int($startAt * $upsample) + 1"]]

	for {set i 0} {$i < [dl_length durtimes]} {incr i} {
		#~ currently, starting at the 0th time point adds one extra time point to the time series :(	
		dl_set timeseries($i) \
			[dl_repeat 1 [expr "int([lindex [dl_tcllist durtimes] $i] * $upsample)"]]
			if {[expr $i + 1] < [dl_length starttimes]} {
				dl_set timeseries($i) \
					[dl_concat timeseries($i) \
						[dl_zeros [expr "int(([lindex [dl_tcllist starttimes] [expr $i + 1]] - [lindex [dl_tcllist endtimes] $i] - 1) * $upsample)"]]]
			}
		if {$waveGUI::neg($i) == 0} {
			dl_set timeseries($i) [dl_mult timeseries($i) $waveGUI::curr($i)]
		} elseif {$waveGUI::neg($i) == 1} {
			dl_set timeseries($i) [dl_mult timeseries($i) [expr $waveGUI::curr($i) * -1]]
		}
		
		dg_addExistingList pulses timeseries($i) timeseries$i
#		dl_delete $timeseries($i)
	}

	dl_local last \
		[dl_zeros [expr "$endend - int(([lindex [dl_tcllist endtimes] [expr ([dl_length endtimes] - 1)]]) * $upsample)"]]
	dg_addExistingList pulses $last last
	dl_set pulseSeries $first

	foreach tgroup [dl_tcllist [dg_listnames pulses]] {
		 dl_set pulseSeries [dl_concat pulseSeries [dl_div pulses:$tgroup $maxAmp2]]
	}

	dg_delete pulses
#@-- Possibly to be expanded at a later date...	 ---
    if {[dg_exists arb]} {dg_delete arb}
    
    dg_create arb
    dg_addExistingList arb pulseSeries
    dg_write arb arb.dg
    .arb.f.buttons.viewdg(b) state !disabled

    waveGUI::plotdllist
#@---------------------------------------------------
}


proc ::waveGUI::plotdllist {} {
	dlp_create waveform
	dl_local x [dl_fromto 0 [dl_length pulseSeries]]
	dlp_addXData waveform $x
	dlp_addYData waveform pulseSeries
	dlp_setxrange waveform 0 [dl_length pulseSeries]
	dlp_setyrange waveform -1.5 1.5
	dlp_draw waveform lines 0
	dlp_plot waveform
	dl
}




::waveGUI::addPulse

source C:/usr/local/lib/dlsh/bin/dlshell.tcl
raise .arb
wm state .console icon


