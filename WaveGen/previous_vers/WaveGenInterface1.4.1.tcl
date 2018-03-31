#!/bin/sh
# Run wish from the users PATH \
exec wish -f "$0" ${1+"$@"}

package require agilentawg
package require dlsh

# revision 1.3.4





#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
namespace eval ::makeawg:: {
	variable startt 
	variable vertices
	variable period 3
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
	variable waveParams 0
	variable ampType
}

#--  This is kept here for easy access
namespace eval ::TempSpace:: {
	variable geom "319x544+550+300"
	variable canvasWidth 304
	variable canvasHeight 100
}
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


proc makeawg::updateFields {} {
	#-- (Subtract 1, index starts at 0)
	set numInBox [expr [llength $makeawg::pulseList] -1]
			
	if {$makeawg::pulseBoxSel == "Add_pulse" } {
		if {$numInBox == 0} {
			.arb.f.buttons.prevw(b) state !disabled
			.arb.f.buttons.del(b) state !disabled
			.arb.f.buttons.reset(b) state !disabled
			.arb.f.startt(ent) state !disabled
			.arb.f.dur(ent) state !disabled
			.arb.f.neg(chk) state !disabled
			
		#-- Set up the default parameters for the first pulse			
			set makeawg::startt(0) 0;			# microseconds
			set makeawg::dur(0) 100;			# microseconds		
			set makeawg::endt(0) 100;			# microseconds
			set makeawg::volt(0) 3; 			# Volts
			set makeawg::curr(0) .06;			# Amps
			set makeawg::resis(0) 50;			# Ohms
			set makeawg::neg(0) 0;
		
		} elseif {$numInBox > 0} {
		#-- The following sets up the parameters for a new pulse to be added into the combobox
			set makeawg::i $numInBox
			set previ [expr $numInBox - 1]

			set makeawg::volt($makeawg::i) $makeawg::volt($previ)
			set makeawg::curr($makeawg::i) $makeawg::curr($previ)
			set makeawg::resis($makeawg::i) $makeawg::resis($previ)
			set makeawg::dur($makeawg::i) $makeawg::dur($previ)
			set makeawg::neg($makeawg::i) 0
			set duration $makeawg::dur($previ)
			set startPrev $makeawg::startt($previ)
			set makeawg::startt($makeawg::i) [expr $startPrev + $duration + 1]
			set start $makeawg::startt($makeawg::i)
			set makeawg::endt($makeawg::i) [expr $start + $duration]
			echo "makeawg::endt($makeawg::i) $makeawg::endt($makeawg::i)"
		}

	#-- Add the new pulse to the combobox and select its index
		lappend makeawg::pulseList [expr "$numInBox + 1"]
		.arb.f.select(dropdn) configure -values "$makeawg::pulseList"
		.arb.f.select(dropdn) set [expr "$numInBox + 1"]
		
	#-- Update the entry widget with the values for the new pulse
		.arb.f.startt(ent) configure -textvariable makeawg::startt($makeawg::i)
		.arb.f.dur(ent) configure -textvariable makeawg::dur($makeawg::i)
		.arb.f.vir.volt(ent) configure -textvariable makeawg::volt($makeawg::i)
		.arb.f.vir.curr(ent) configure -textvariable makeawg::curr($makeawg::i)
		.arb.f.vir.resis(ent) configure -textvariable makeawg::resis($makeawg::i)
		.arb.f.neg(chk) configure -variable makeawg::neg($makeawg::i)

		::makeawg::CheckIfTwo

	} elseif {$makeawg::pulseBoxSel > 0} {	
		set makeawg::i [expr $makeawg::pulseBoxSel - 1]
		.arb.f.startt(ent) configure -textvariable makeawg::startt($makeawg::i)
		.arb.f.dur(ent) configure -textvariable makeawg::dur($makeawg::i)
		.arb.f.vir.volt(ent) configure -textvariable makeawg::volt($makeawg::i)
		.arb.f.vir.curr(ent) configure -textvariable makeawg::curr($makeawg::i)
		.arb.f.vir.resis(ent) configure -textvariable makeawg::resis($makeawg::i)
		.arb.f.neg(chk) configure -variable makeawg::neg($makeawg::i)	
	}
}



proc ::makeawg::resetPulseList {} {
	set makeawg::i 0;
	set makeawg::period 3;				# milliseconds
	array unset makeawg::startt;
	array unset makeawg::dur;
	array unset makeawg::endt;
	array unset makeawg::volt;
	array unset makeawg::curr;
	array unset makeawg::resis;
	array unset makeawg::neg;
	array set makeawg::startt;
	array set makeawg::dur;
	array set makeawg::endt;
	array set makeawg::volt;
	array set makeawg::curr;
	array set makeawg::resis;
	array set makeawg::neg;
	
	set makeawg::pulseList Add_pulse;
	.arb.f.select(dropdn) configure -values "$makeawg::pulseList"
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

proc ::makeawg::CheckIfTwo {} {
	set howMany [expr $makeawg::hold(0) + $makeawg::hold(1) + $makeawg::hold(2)]
	if { $howMany >= 2 } {
		if {$makeawg::hold(0)==0} {
			foreach i {chk ent} {
				.arb.f.vir.volt(${i}) state disabled
				set makeawg::ampType "V"
				foreach j {curr resis} {
					.arb.f.vir.${j}(${i}) state !disabled
				}
			}
		} elseif {$makeawg::hold(1)==0} {
			foreach i {chk ent} {
				.arb.f.vir.curr(${i}) state disabled
				set makeawg::ampType "I"
				foreach j {volt resis} {
					.arb.f.vir.${j}(${i}) state !disabled
				}
			}		
		} elseif {$makeawg::hold(2)==0} {
			foreach i {chk ent} {
				.arb.f.vir.resis(${i}) state disabled
				set makeawg::ampType "R"
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

proc ::makeawg::VIR {changedVar value} {
	set makeawg::${changedVar}($makeawg::i) $value
	puts stdout "${changedVar} $value"

	set howMany [expr $makeawg::hold(0) + $makeawg::hold(1) + $makeawg::hold(2)]
	if { $howMany == 2 } {
		if {$makeawg::hold(1)==1 && $makeawg::hold(2)==1 && $makeawg::hold(0)==0} {
			set makeawg::volt($makeawg::i) [expr $makeawg::resis($makeawg::i) * $makeawg::curr($makeawg::i)]
		} elseif {$makeawg::hold(0)==1 && $makeawg::hold(2)==1 && $makeawg::hold(1)==0} {
			set makeawg::curr($makeawg::i) [expr $makeawg::volt($makeawg::i) / $makeawg::resis($makeawg::i)]
		} elseif {$makeawg::hold(0)==1 && $makeawg::hold(1)==1 && $makeawg::hold(2)==0} {
			set makeawg::resis($makeawg::i) [expr $makeawg::volt($makeawg::i) / $makeawg::curr($makeawg::i)]
		}
	} else {
		tk_messageBox \
		-message "You must provide at least two of the stimulation parameters to compute the other."
	}
}

proc ::makeawg::deleteIt {} {
    set makeawg::pulseList [.arb.f.select(dropdn) cget -values]
	
    if {$makeawg::pulseBoxSel in $makeawg::pulseList} {
        set i [lsearch -exact $makeawg::pulseList $makeawg::pulseBoxSel]
        set makeawg::pulseList [lreplace $makeawg::pulseList $i $i]
        .arb.f.select(dropdn) configure -values $makeawg::pulseList	
        .arb.f.select(dropdn) set ""
	}
}

proc ::makeawg::addPulse {} {
	font create TopTitleFont -family Helvetica -size 11 -weight bold
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
	
	ttk::label .arb.f.title(l) -text {The Makeshift Arbitrary Waveform Maker} -font TopHeaderFont
	ttk::separator .arb.f.sep1a; #---------------
	ttk::separator .arb.f.sep1b; #---------------
	ttk::label .arb.f.period(l) -text "Single stim period (ms):"
	ttk::entry .arb.f.period(ent) -width 7 -textvariable makeawg::period
		bind .arb.f.period(ent) <KeyRelease> { .arb.f.period(ent) configure -textvariable makeawg::period }
	ttk::separator .arb.f.sep2a; #---------------
	ttk::separator .arb.f.sep2b; #---------------

	ttk::label .arb.f.select(l) -text "Pulse #:"
	ttk::combobox .arb.f.select(dropdn) -width 10 -textvariable makeawg::pulseBoxSel
		.arb.f.select(dropdn) configure -values $makeawg::pulseList
		.arb.f.select(dropdn) state readonly
		bind .arb.f.select(dropdn) <<ComboboxSelected>> {\
			set makeawg::pulseBoxSel [.arb.f.select(dropdn) get]; \
			makeawg::updateFields}
			
	ttk::checkbutton .arb.f.neg(chk) -variable makeawg::neg($makeawg::i) -onvalue 1 -offvalue 0 -text "neg"
		.arb.f.neg(chk) state disabled

	ttk::label .arb.f.startt(l) -text "Pulse start time (${makeawg::mu}s):"
	ttk::entry .arb.f.startt(ent) -width 7 -textvariable makeawg::startt($makeawg::i)
		.arb.f.startt(ent) state disabled
		bind .arb.f.startt(ent) <KeyRelease> { .arb.f.startt(ent) configure -textvariable makeawg::startt($makeawg::i)}	
	
	ttk::label .arb.f.dur(l) -text "Duration of pulse (${makeawg::mu}s):"
	ttk::entry .arb.f.dur(ent) -width 7 -textvariable makeawg::dur($makeawg::i)
		.arb.f.dur(ent) state disabled
		bind .arb.f.dur(ent) <KeyRelease> { .arb.f.dur(ent) configure -textvariable makeawg::dur($makeawg::i)}

	set makeawg::hold(0) 0
	set makeawg::hold(1) 1
	set makeawg::hold(2) 1
	ttk::checkbutton .arb.f.vir.volt(chk) -variable makeawg::hold(0) -onvalue 1 -offvalue 0 \
			-command {makeawg::CheckIfTwo}
		.arb.f.vir.volt(chk) state disabled
	ttk::checkbutton .arb.f.vir.curr(chk) -variable makeawg::hold(1) -onvalue 1 -offvalue 0 \
			-command {makeawg::CheckIfTwo}
		.arb.f.vir.curr(chk) state selected 
		.arb.f.vir.curr(chk) state disabled
	ttk::checkbutton .arb.f.vir.resis(chk) -variable makeawg::hold(2) -onvalue 1 -offvalue 0 \
			-command {makeawg::CheckIfTwo}
		.arb.f.vir.resis(chk) state selected
		.arb.f.vir.resis(chk) state disabled

	ttk::label .arb.f.vir.volt(l) -text "V (mV):"
	ttk::entry .arb.f.vir.volt(ent) -width 5 -textvariable makeawg::volt($makeawg::i)
		.arb.f.vir.volt(ent) state disabled
		bind .arb.f.vir.volt(ent) <KeyRelease> { makeawg::VIR volt $makeawg::volt($makeawg::i) }
	ttk::label .arb.f.vir.curr(l) -text "I (${makeawg::mu}A):"
	ttk::entry .arb.f.vir.curr(ent) -width 5 -textvariable makeawg::curr($makeawg::i)
		.arb.f.vir.curr(ent) state disabled
		bind .arb.f.vir.curr(ent) <KeyRelease> { makeawg::VIR curr $makeawg::curr($makeawg::i) }
	ttk::label .arb.f.vir.resis(l) -text "R (k$makeawg::om):"
	ttk::entry .arb.f.vir.resis(ent) -width 5 -textvariable makeawg::resis($makeawg::i)
		.arb.f.vir.resis(ent) state disabled
		bind .arb.f.vir.resis(ent) <KeyRelease> { makeawg::VIR resis $makeawg::resis($makeawg::i) }

	ttk::button .arb.f.buttons.prevw(b) -text "Preview" -width 9 \
		-command "makeawg::prevwIt"
		.arb.f.buttons.prevw(b) state disabled
	ttk::button .arb.f.buttons.del(b) -text "Delete" -width 8 \
		-command "makeawg::deleteIt"
		.arb.f.buttons.del(b) state disabled
	ttk::button .arb.f.buttons.export(b) -text "Make dg" -width 8 \
		-command "makeawg::exportIt"
		.arb.f.buttons.export(b) state disabled
	ttk::button .arb.f.buttons.viewdg(b) -text "View dg" -width 8 \
		-command "dg_view arb"
		.arb.f.buttons.viewdg(b) state disabled
	ttk::button .arb.f.buttons.reset(b) -text "Reset" -width 7 \
		-command "makeawg::resetPulseList"
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
	grid .arb.f.buttons.export(b) -row 0 -column 4 -padx {2 2} -pady {6 2} -sticky ew
	grid .arb.f.buttons.viewdg(b) -row 0 -column 5 -columnspan 2 -padx {2 2} -pady {6 2} -sticky ew	
	grid .arb.f.buttons.reset(b) -row 0 -column 7 -columnspan 3 -padx {2 2} -pady {6 2} -sticky ew

	grid .arb.f.sep5 -row 28 -column 0 -columnspan 10 -padx {4 4} -pady {6 2} -sticky ew		
	grid .arb.f.plot -row 29 -column 0 -columnspan 10 -padx {5 5} -pady {5 5}
	grid .arb.f.textbox -row 30 -column 0 -columnspan 10 -padx {5 5} -pady {5 5}	

	grid .arb.f.sep6 -row 32 -column 0 -columnspan 10 -padx {4 4} -pady {6 2} -sticky ew	
	grid .arb.f.quit(b) -row 33 -column 0 -columnspan 10 -padx {4 4} -pady {4 4}	
}
####################################################################################################
proc ::makeawg::prevwIt {} {
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

	set time2pxlRatio [expr "(($TempSpace::canvasWidth - 4) / ($makeawg::period*1000*1.000))"];	#scale x-preview by the single-stimulation period
																				    			#subtract 4 for padding the waveform
	set pulseNames [lrange $makeawg::pulseList 1 end]; 						#list of all available user added pulses
	set numPulses [llength $pulseNames]; 		        					#total number of pulses to draw
    
	set reference [expr "ceil($TempSpace::canvasHeight/2)"]
	set theEnd [expr "int($makeawg::period*1000 * $time2pxlRatio)"];
	set makeawg::vertices [list [list 0 $reference]]
	set makeawg::waveParams [list $makeawg::period]
    set makeawg::makeawg::waveParamsExtras [list $numPulses]
    
	set vcount 1;  															#includes vertex @ (0, 0)	
	foreach value $pulseNames {
		set index [expr $value - 1]
		set maxAmplitude [expr max([join [array get makeawg::volt] ","])]
		set amp2pxlRatio [expr "(($TempSpace::canvasHeight - 14) / ($maxAmplitude*2.000))"]; 	#scale y-preview by the max amplitude
																						 		#subtract 20 for padding the waveform
		if {$makeawg::neg($index) == 1} {
			set amplcalc [expr (-1 * $makeawg::volt($index))]
		} elseif {$makeawg::neg($index) == 0} {
			set amplcalc $makeawg::volt($index)
		}
		
	#-- Update variable endt
		set makeawg::endt($index) [expr $makeawg::startt($index) + $makeawg::dur($index)]
		
		set startOn [expr "int($makeawg::startt($index) * $time2pxlRatio)"];	#shift plot to the right by 1 to account for border (?)
		set endOn [expr "int($makeawg::endt($index) * $time2pxlRatio)"];
		set amplitude [expr "int($reference - ($amplcalc * $amp2pxlRatio))"];

        if {$makeawg::startt($index) != 0} {
            lappend makeawg::vertices [list $startOn $reference]
            incr vcount
        }
		if {[info exists prevIndex] && $makeawg::endt($prevIndex) == $makeawg::startt($index)} {
			puts stderr "Time point at $startOn was skipped"
		} else {
			lappend makeawg::vertices [list $startOn $amplitude]
			incr vcount
            lappend makeawg::vertices [list $endOn $amplitude]
            incr vcount
            lappend makeawg::vertices [list $endOn $reference]
            incr vcount
		}
#     {{wavePeriod} {{starttime_0 duration_0} {voltage_0 negative?_0}} {...}}
		lappend makeawg::waveParams \
		    [list [list $makeawg::startt($index) $makeawg::dur($index)] \
                  [list $makeawg::volt($index) $makeawg::neg($index)]]
#     {{numPulses} {{index_0 endtime_0} {current_0 resistance_0}} {...} {ampType}}
		lappend makeawg::waveParamsExtras \
		    [list [list $index $makeawg::endt($index)] \
                  [list $makeawg::curr($index) $makeawg::resis($index)]]

		set prevIndex $index
	}
    .arb.f.textbox replace 1.0 end "[list $makeawg::waveParams]"
	lappend makeawg::waveParamsExtras [list $makeawg::ampType]
	lappend makeawg::vertices [list $theEnd $reference]
	incr vcount
	unset prevIndex
#	puts stdout "$vcount $makeawg::vertices"
	
#-- Delete plot and redraw (in next steps)
	.arb.f.plot delete waveform
#-- Draw the vertices on the canvas
	for {set j 1} {$j < $vcount} {incr j} {
		set prevj [expr $j - 1];
		set x0 [expr [lindex $makeawg::vertices $prevj 0] + 3]      # +3 to add extra space on left
		set y0 [lindex $makeawg::vertices $prevj 1]
		set x1 [expr [lindex $makeawg::vertices $j 0] + 3]
		set y1 [lindex $makeawg::vertices $j 1]
		
#		puts stdout "$x0 $y0 $x1 $y1"
		set c($j) [.arb.f.plot create line $x0 $y0 $x1 $y1 -fill "#ffffff" -width 1 -tags waveform]
	}
	.arb.f.buttons.export(b) state !disabled
}

proc ::makeawg::exportIt {waveParams} {
	set arb [awg::expandSequence $waveParams]
    .arb.f.buttons.viewdg(b) state !disabled
    set verifydl [lindex [dg_tclListnames $arb] 0]
    makeawg::plotdllist $arb:$verifydl
}

proc ::makeawg::plotdllist {verifydl} {
	clearwin;
	dlp_create waveform
	dl_local x [dl_fromto 0 [dl_length $verifydl]]
	dlp_addXData waveform $x
	dlp_addYData waveform $verifydl
	dlp_setxrange waveform 0 [dl_length $verifydl]
	dlp_setyrange waveform -1.5 1.5
	dlp_draw waveform lines 0
	dlp_plot waveform
}

::makeawg::addPulse

source C:/usr/local/lib/dlsh/bin/dlshell.tcl
raise .arb
wm state .console icon


