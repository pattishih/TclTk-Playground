#!/bin/sh
# Run wish from the users PATH \
exec wish -f "$0" ${1+"$@"}
#console show

# revision 1.1

#package require BWidget
#package require Tk
package require dlsh
#package require tkcon

#source {C:\Users\lab\Dropbox\pshih\WaveGen\WaveGen.tcl}
source {Z:\Dropbox\Science\[SheinbergLab]\pshih\WaveGen\WaveGen.tcl}

#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
namespace eval ::waveGUI:: {
	variable startt
	variable vertices
	variable volt
	variable dur
	variable endt
	variable i
}
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
proc waveGUI::updateWidgets {selection} {
	switch $selection {
		"Off Period" {
			set waveGUI::volt($waveGUI::i) 0
			.start(ent) state !disabled
			.dur(ent) state !disabled
			.add(b) state !disabled
		}
		"On Period" {
			.start(ent) state !disabled
			.volt(ent) state !disabled
			.dur(ent) state !disabled
			.add(b) state !disabled
		}
	}
}

proc ::waveGUI::addIt {} {
	incr $waveGUI::i
	puts stdout [list $waveGUI::startt($waveGUI::i) $waveGUI::volt($waveGUI::i) $waveGUI::dur($waveGUI::i)]
	.start(ent) state disabled
	.volt(ent) state disabled
	.dur(ent) state disabled
	.add(b) state disabled
}

proc ::waveGUI::addPulse {} {
	set waveGUI::i 0
	set waveGUI::startt($waveGUI::i) 0
	set waveGUI::volt($waveGUI::i) 0
	set waveGUI::dur($waveGUI::i) 1000
	set addWhat {}
	font create HeaderFont -family Helvetica -size 10 -weight bold
	
	ttk::label .title(l) -text {[The Makeshift Arbitrary Waveform Creator]} -font HeaderFont
	ttk::separator .sep1
	ttk::label .addPulse(l) -text "Add Single Pulse"
	
	ttk::label .select(l) -text "Select What to Add:"
	ttk::combobox .add(dropdown) -textvariable addWhat -width 10
		.add(dropdown) configure -values [list "Off Period" "On Period"]
		bind .add(dropdown) <<ComboboxSelected>> {set $addWhat [.add(dropdown) get]; waveGUI::updateWidgets $addWhat}
	

	ttk::label .start(l) -text "Start Time (microsec):"
	ttk::entry .start(ent) -width 8 -textvariable waveGUI::startt($waveGUI::i)
		.start(ent) state disabled
	ttk::label .volt(l) -text "Voltage (mV):"
	ttk::entry .volt(ent) -width 8 -textvariable waveGUI::volt($waveGUI::i)
		.volt(ent) state disabled
	ttk::label .dur(l) -text "Duration (microsec):"
	ttk::entry .dur(ent) -width 8 -textvariable waveGUI::dur($waveGUI::i)
		.dur(ent) state disabled

	ttk::button .add(b) -text "Add to Waveform" \
		-command "waveGUI::addIt; set $addWhat {}"
		.add(b) state disabled
	
	grid .title(l) -row 0 -column 0 -columnspan 10 -padx {4 4} -pady {4 2} -sticky w
	grid .sep1 -row 1 -column 0 -columnspan 10 -padx {4 4} -pady {2 2} -sticky ew
	grid .addPulse(l) -row 2 -column 0 -columnspan 10 -padx {4 4} -pady {2 4} -sticky w
	
	grid .select(l) -row 3 -column 1 -padx {4 4} -pady {2 4} -sticky e
	grid .add(dropdown) -row 3 -column 2 -columnspan 9 -padx {4 4} -pady {2 4} -sticky w

	grid .start(l) -row 4 -column 1 -padx {4 4} -pady {2 4} -sticky e
	grid .start(ent) -row 4 -column 2 -columnspan 9 -padx {4 4} -pady {2 4} -sticky w
	
	grid .volt(l) -row 5 -column 1 -padx {4 4} -pady {2 4} -sticky e
	grid .volt(ent) -row 5 -column 2 -columnspan 9 -padx {4 4} -pady {2 4} -sticky w

	grid .dur(l) -row 6 -column 1 -padx {4 4} -pady {2 4} -sticky e
	grid .dur(ent) -row 6 -column 2 -columnspan 9 -padx {4 4} -pady {2 4} -sticky w
	
	grid .add(b) -row 20 -column 0 -columnspan 10 -padx {4 4} -pady {2 2}
}

bind . <Control-h> { console show }

#::wave::trigger
::waveGUI::addPulse

source C:/usr/local/lib/dlsh/bin/dlshell.tcl


