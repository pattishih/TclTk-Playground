#!/bin/sh
# Run wish from the users PATH \
exec wish -f "$0" ${1+"$@"}
#console show

# revision 1.3.1

#package require BWidget
package require dlsh
#package require tkcon

#source {C:\Users\lab\Dropbox\pshih\WaveGen\WaveGen.tcl}
source {Z:\Dropbox\Science\[SheinbergLab]\pshih\WaveGen\WaveGen.tcl}

#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
namespace eval ::waveGUI:: {
	variable startt
	variable vertices
	variable period
	variable volt
	variable dur
	variable endt
	variable i
	variable pulseBoxSel
	variable pulseList
	variable crudePlot
	variable mu [format %c 181]
	variable om [format %c 937]
	variable em [format %c 8212]
}
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
proc waveGUI::updateFields {} {
	#Variable pulseBoxSel updated immediately before this procedure call via bind event
	puts stdout $waveGUI::pulseBoxSel
	#Subtract 1 bc index starts at 0
	set pulseListTwo $waveGUI::pulseList
	set numInBox [expr [llength $waveGUI::pulseList] -1]
			
	if {$waveGUI::pulseBoxSel == "Add_stimulation" } {
		.arb.prevw(b) state !disabled 
		.arb.start(ent) state !disabled
		.arb.volt(ent) state !disabled
		.arb.dur(ent) state !disabled
		
		set waveGUI::i $numInBox
		set nexti [expr $numInBox + 1]
		set waveGUI::startt($nexti) [expr $waveGUI::endt($numInBox) +1]
		set waveGUI::volt($nexti) 25
		set waveGUI::dur($nexti) 1000
		lappend waveGUI::pulseList $nexti
		
		.arb.start(ent) configure -textvariable waveGUI::startt($nexti)
		.arb.select(dropdn) configure -values "$waveGUI::pulseList"
		.arb.select(dropdn) set $nexti
		set waveGUI::i $nexti
		
	} elseif {$waveGUI::pulseBoxSel > 0} {	
		.arb.prevw(b) state disabled
		set $waveGUI::i $waveGUI::pulseBoxSel
		if {![info exist waveGUI::startt($waveGUI::i)]} {
			set waveGUI::startt($waveGUI::i) [expr waveGUI::startt([expr $waveGUI::i -1])
		}
	}
}

proc ::waveGUI::prevwIt {} {
	set waveGUI::startt($waveGUI::i) [.arb.start(ent) get]
	set waveGUI::volt($waveGUI::i) [.arb.volt(ent) get]
	set waveGUI::dur($waveGUI::i) [.arb.dur(ent) get]

	if {$waveGUI::volt($waveGUI::i) == 0} {
		tk_messageBox -message "You must set the voltage to a value greater than or less than zero."
	} else {
		.arb.select(dropdn) set ""
		.arb.view(b) state !disabled
		set waveGUI::endt($waveGUI::i) [expr $waveGUI::endt([expr $waveGUI::i -1])+$waveGUI::dur($waveGUI::i)]

		puts stdout \
			[list $waveGUI::i $waveGUI::startt($waveGUI::i) $waveGUI::endt($waveGUI::i) $waveGUI::volt($waveGUI::i) $waveGUI::dur($waveGUI::i)]

	}
}

proc ::waveGUI::addPulse {} {
	set waveGUI::i 0
	set waveGUI::period 2000
	set waveGUI::startt(0) 0
	set waveGUI::volt(0) 25
	set waveGUI::dur(0) 1000
	set waveGUI::endt(0) -1
	set waveGUI::pulseList Add_stimulation

	font create HeaderFont -family Helvetica -size 11 -weight bold
	
	toplevel .arb
	wm title .arb "Arbitrary Waveform Creator"
	wm geometry .arb 320x375+540+330
	bind .arb <Control-h> {console show}	
#---------------------------------------------------------------------------------------------------

	ttk::label .arb.title(l) -text {The Makeshift Arbitrary Waveform Creator} -font HeaderFont
	ttk::separator .arb.sep1a; #---------------
	ttk::separator .arb.sep1b; #---------------
	ttk::label .arb.period(l) -text "Single stim period (${waveGUI::mu}s):"
	ttk::entry .arb.period(ent) -width 7 -textvariable waveGUI::period
		bind .arb.period(ent) <<KeyRelease>> { set $waveGUI::period %k }
	ttk::separator .arb.sep2a; #---------------
	ttk::separator .arb.sep2b; #---------------

	ttk::label .arb.select(l) -text "Pulse #:"
	ttk::combobox .arb.select(dropdn) -width 12 -textvariable waveGUI::pulseBoxSel
		.arb.select(dropdn) configure -values $waveGUI::pulseList
		
		bind .arb.select(dropdn) <<ComboboxSelected>> {\
			set waveGUI::pulseBoxSel [.arb.select(dropdn) get]; \
			waveGUI::updateFields}


	ttk::label .arb.start(l) -text "Next pulse start time (${waveGUI::mu}s):"
	ttk::entry .arb.start(ent) -width 7 -textvariable waveGUI::startt($waveGUI::i)
		.arb.start(ent) state disabled	
		bind .arb.start(ent) <<KeyRelease>> { set $waveGUI::startt($waveGUI::i) %k }	
	
	ttk::separator .arb.sep3; #---------------
	
	ttk::label .arb.volt(l) -text "V (${waveGUI::mu}V):"
	ttk::entry .arb.volt(ent) -width 5 -textvariable waveGUI::volt($waveGUI::i)
		.arb.volt(ent) state disabled
		bind .arb.volt(ent) <<KeyRelease>> { set $waveGUI::volt($waveGUI::i) %k }
	
#	ttk::separator .arb.sep3a -orient vertical
	
	ttk::label .arb.curr(l) -text "I (${waveGUI::mu}A):"
	ttk::entry .arb.curr(ent) -width 5 -textvariable waveGUI::curr($waveGUI::i)
		.arb.curr(ent) state disabled
		bind .arb.curr(ent) <<KeyRelease>> { set $waveGUI::curr($waveGUI::i) %k }

	#	ttk::separator .arb.sep3b -orient vertical

	ttk::label .arb.resis(l) -text "R (k$waveGUI::om):"
	ttk::entry .arb.resis(ent) -width 5 -textvariable waveGUI::resis($waveGUI::i)
		.arb.resis(ent) state disabled
		bind .arb.resis(ent) <<KeyRelease>> { set $waveGUI::resis($waveGUI::i) %k }
	
	ttk::separator .arb.sep4; #---------------
	
	ttk::label .arb.dur(l) -text "Duration of single pulse (${waveGUI::mu}s):"
	ttk::entry .arb.dur(ent) -width 7 -textvariable waveGUI::dur($waveGUI::i)
		.arb.dur(ent) state disabled
		bind .arb.dur(ent) <<KeyRelease>> { set $waveGUI::dur($waveGUI::i) %k }
#	ttk::label .arb.duru(l) -text ""
	
	ttk::button .arb.prevw(b) -text "Preview Pulse" \
		-command "waveGUI::prevwIt"
		.arb.prevw(b) state disabled

	ttk::button .arb.del(b) -text "Delete Pulse" \
		-command "waveGUI::deleteIt"
		.arb.del(b) state disabled
		
	ttk::button .arb.view(b) -text "View Waveform" \
		-command "waveGUI::plotIt"
		.arb.view(b) state disabled

	ttk::separator .arb.sep5; #---------------
	ttk::button .arb.quit(b) -text "Quit" -command "destroy ."
	
	canvas .arb.plot -width 304 -height 100 -background "#333333"

#---------------------------------------------------------------------------------------------------
	grid .arb.title(l) -row 0 -column 0 -columnspan 10 -padx {4 4} -pady {8 8} -sticky ew
	grid .arb.sep1a -row 1 -column 0 -columnspan 10 -padx {4 4} -pady {2 1} -sticky ew
	grid .arb.sep1b -row 2 -column 0 -columnspan 10 -padx {4 4} -pady {0 2} -sticky ew

	grid .arb.period(l) -row 3 -column 1 -columnspan 3 -padx {4 4} -pady {4 4} -sticky e
	grid .arb.period(ent) -row 3 -column 4 -columnspan 6 -padx {4 0} -pady {2 4} -sticky w

	grid .arb.sep2a -row 5 -column 0 -columnspan 10 -padx {4 4} -pady {2 1} -sticky ew
	grid .arb.sep2b -row 6 -column 0 -columnspan 10 -padx {4 4} -pady {0 4} -sticky ew
	
	grid .arb.select(l) -row 7 -column 1 -columnspan 3 -padx {4 4} -pady {2 4} -sticky e
	grid .arb.select(dropdn) -row 7 -column 4 -columnspan 6 -padx {4 4} -pady {2 4} -sticky w

	grid .arb.start(l) -row 8 -column 1 -columnspan 3 -padx {4 4} -pady {2 4} -sticky e
	grid .arb.start(ent) -row 8 -column 4 -columnspan 6 -padx {4 0} -pady {2 4} -sticky w

	grid .arb.sep3 -row 11 -column 0 -columnspan 10 -padx {4 4} -pady {2 1} -sticky ew
#---------------	
	grid .arb.volt(l) -row 12 -column 0 -padx {6 2} -pady {2 4} -sticky e
	grid .arb.volt(ent) -row 12 -column 1 -padx {2 4} -pady {2 4} -sticky w
	grid .arb.curr(l)	 -row 12 -column 2 -padx {6 2} -pady {2 4} -sticky e
	grid .arb.curr(ent) -row 12 -column 3 -padx {2 4} -pady {2 4} -sticky w
	grid .arb.resis(l)	 -row 12 -column 4 -padx {6 2} -pady {2 4} -sticky e
	grid .arb.resis(ent) -row 12 -column 5 -padx {2 4} -pady {2 4} -sticky w
#---------------
	grid .arb.sep4 -row 13 -column 0 -columnspan 10 -padx {4 4} -pady {1 2} -sticky ew
	grid .arb.dur(l) -row 20 -column 1 -columnspan 3 -padx {4 4} -pady {2 4} -sticky e
	grid .arb.dur(ent) -row 20 -column 4 -columnspan 6 -padx {4 0} -pady {2 4} -sticky w
	
	grid .arb.prevw(b) -row 25 -column 0 -columnspan 2 -padx {16 2} -pady {8 2} -sticky e
	grid .arb.del(b) -row 25 -column 2 -columnspan 2 -padx {2 2} -pady {8 2} -sticky w	
	grid .arb.view(b) -row 25 -column 4 -columnspan 6 -padx {2 2} -pady {8 2} -sticky w
	
	grid .arb.sep5 -row 27 -column 0 -columnspan 10 -padx {4 4} -pady {6 2} -sticky ew
	grid .arb.quit(b) -row 28 -column 0 -columnspan 10 -padx {4 4} -pady {4 4}
	grid .arb.plot -row 29 -column 0 -columnspan 10 -padx {5 5} -pady {5 5}
}
#---------------------------------------------------------------------------------------------------

proc ::waveGUI::plotIt {} {
	dlp_create waveform
	dl_local x [dl_series 1 $waveGUI::period]
	dlp_addXData waveform $x
	set timeseries [dl_repeat 0 $waveGUI::startt(0)]
	dlp_addYData waveform fdfda
	dlp_draw waveform lines 0
	dlp_plot waveform
}

#::wave::trigger
::waveGUI::addPulse

source C:/usr/local/lib/dlsh/bin/dlshell.tcl
raise .arb
wm state .console icon


