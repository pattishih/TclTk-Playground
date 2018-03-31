#!/bin/sh
# Run wish from the users PATH \
exec wish -f "$0" ${1+"$@"}
#console show

# revision 1.2

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
	variable pulseBox
	variable pulseList
	variable crudePlot
}
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
proc waveGUI::updateWidgets {} {
	#Variable pulseBox updated immediately before this procedure call via bind event
	puts stdout $waveGUI::pulseBox
	#Subtract 1 bc index starts at 0
	set pulseListTwo $waveGUI::pulseList
	set numInBox [expr [llength $waveGUI::pulseList] -1]
			
	if {$waveGUI::pulseBox == "Add stimulation" } {
		.arb.add(b) state !disabled 
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
		.arb.add(dropdown) configure -values "$waveGUI::pulseList"
		.arb.add(dropdown) set $nexti
		set waveGUI::i $nexti
		
	} elseif {$waveGUI::pulseBox > 0} {	
		.arb.add(b) state disabled
		set $waveGUI::i $waveGUI::pulseBox
		if {![info exist waveGUI::startt($waveGUI::i)]} {
			set waveGUI::startt($waveGUI::i) [expr waveGUI::startt([expr $waveGUI::i -1])
		}
	}
}

proc ::waveGUI::addIt {} {
	set waveGUI::startt($waveGUI::i) [.arb.start(ent) get]
	set waveGUI::volt($waveGUI::i) [.arb.volt(ent) get]
	set waveGUI::dur($waveGUI::i) [.arb.dur(ent) get]

	if {$waveGUI::volt($waveGUI::i) == 0} {
		tk_messageBox -message "You must set the voltage to a value greater than or less than zero."
	} else {
		.arb.add(dropdown) set ""
		.arb.view(b) state !disabled
		set waveGUI::endt($waveGUI::i) [expr $waveGUI::endt([expr $waveGUI::i -1])+$waveGUI::dur($waveGUI::i)]

		puts stdout \
			[list $waveGUI::i $waveGUI::startt($waveGUI::i) $waveGUI::endt($waveGUI::i) $waveGUI::volt($waveGUI::i) $waveGUI::dur($waveGUI::i)]

	}
}

proc ::waveGUI::addPulse {} {
	set waveGUI::i 0
	set waveGUI::period 3000
	set waveGUI::startt(0) 0
	set waveGUI::volt(0) 25
	set waveGUI::dur(0) 1000
	set waveGUI::endt(0) -1
	set waveGUI::pulseList 0
	
	font create HeaderFont -family Helvetica -size 11 -weight bold
	bind . <Control-h> {[wm state .console normal]}
	toplevel .arb
	wm title .arb "Arbitrary Waveform Creator"	
	wm geometry .arb 320x370+540+330

	ttk::label .arb.title(l) -text {The Makeshift Arbitrary Waveform Creator} -font HeaderFont
	ttk::separator .arb.sep1
	ttk::label .arb.period(l) -text "Period (microsec):"
	ttk::entry .arb.period(ent) -width 8 -textvariable waveGUI::period
	ttk::separator .arb.sep2
	
	ttk::label .arb.select(l) -text "Pulse #:"
	ttk::combobox .arb.add(dropdown) -textvariable waveGUI::pulseBox -width 15
		set waveGUI::pulseList [list "Add stimulation"]
		.arb.add(dropdown) configure -values $waveGUI::pulseList
		bind .arb.add(dropdown) <<ComboboxSelected>> \
			{set $waveGUI::pulseBox [.arb.add(dropdown) current]; \
			waveGUI::updateWidgets}

	ttk::label .arb.start(l) -text "Start time (microsec):"
	ttk::entry .arb.start(ent) -width 8 -textvariable waveGUI::startt($waveGUI::i)
		.arb.start(ent) state disabled
	ttk::label .arb.volt(l) -text "Voltage (mV):"
	ttk::entry .arb.volt(ent) -width 8 -textvariable waveGUI::volt($waveGUI::i)
		.arb.volt(ent) state disabled
	ttk::label .arb.dur(l) -text "Duration of stim (microsec):"
	ttk::entry .arb.dur(ent) -width 8 -textvariable waveGUI::dur($waveGUI::i)
		.arb.dur(ent) state disabled

	ttk::button .arb.add(b) -text "Add Pulse to Waveform" \
		-command "waveGUI::addIt"
		.arb.add(b) state disabled
		
	ttk::button .arb.view(b) -text "View Waveform" \
		-command "waveGUI::plotIt"
		.arb.view(b) state disabled

	ttk::separator .arb.sep3		
	ttk::button .arb.quit(b) -text "Quit" -command "destroy ."
	
	canvas .arb.plot -width 304 -height 100 -background "#333333"
	
	grid .arb.title(l) -row 0 -column 0 -columnspan 10 -padx {8 8} -pady {4 4} -sticky w
	grid .arb.sep1 -row 1 -column 0 -columnspan 10 -padx {4 4} -pady {2 2} -sticky ew


	grid .arb.period(l) -row 2 -column 1 -padx {4 4} -pady {4 4} -sticky e
	grid .arb.period(ent) -row 2 -column 2 -columnspan 8 -padx {4 4} -pady {2 4} -sticky w
	
	grid .arb.sep2 -row 3 -column 0 -columnspan 10 -padx {4 4} -pady {4 4} -sticky ew
	
	grid .arb.select(l) -row 4 -column 1 -padx {4 4} -pady {2 4} -sticky e
	grid .arb.add(dropdown) -row 4 -column 2 -columnspan 8 -padx {4 4} -pady {2 4} -sticky w

	grid .arb.start(l) -row 5 -column 1 -padx {4 4} -pady {2 4} -sticky e
	grid .arb.start(ent) -row 5 -column 2 -columnspan 8 -padx {4 4} -pady {2 4} -sticky w
	
	grid .arb.volt(l) -row 6 -column 1 -padx {4 4} -pady {2 4} -sticky e
	grid .arb.volt(ent) -row 6 -column 2 -columnspan 8 -padx {4 4} -pady {2 4} -sticky w

	grid .arb.dur(l) -row 7 -column 1 -padx {4 4} -pady {2 4} -sticky e
	grid .arb.dur(ent) -row 7 -column 2 -columnspan 8 -padx {4 4} -pady {2 4} -sticky w
	
	grid .arb.add(b) -row 19 -column 1 -padx {4 4} -pady {4 2} -sticky e
	grid .arb.view(b) -row 19 -column 2 -columnspan 8 -padx {4 4} -pady {4 2} -sticky w
	
	grid .arb.sep3 -row 20 -column 0 -columnspan 10 -padx {4 4} -pady {6 2} -sticky ew
	grid .arb.quit(b) -row 21 -column 0 -columnspan 10 -padx {4 4} -pady {4 4}
	grid .arb.plot -row 22 -column 0 -columnspan 10 -padx {5 5} -pady {5 5}
}

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


