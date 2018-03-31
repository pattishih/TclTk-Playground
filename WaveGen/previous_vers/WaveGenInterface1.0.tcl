#!/bin/sh
# Run wish from the users PATH \
exec wish -f "$0" ${1+"$@"}
console show

#package require BWidget
#package require Tk
package require dlsh
#package require tkcon

source {C:\Users\lab\Dropbox\pshih\WaveGen\WaveGen.tcl}
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
namespace eval ::waveGUI:: {
	variable period 1
	namespace eval T2f {}
	variable ampl 50
	variable offset 50E+3

	
#--period hiLvl loLvl
#	variable sine
#--period hiLvl loLvl	cyc
#	variable square
#		variable cyc
#--period hiLvl loLvl symtry
#	variable ramp
#		variable symtry
#--period hiLvl loLvl width edge
#	variable pulse
#		variable width
#		variable edge
#--hiLvl loLvl
#	variable noise

#--period hiLvl loLvl select edit
	variable arb

	namespace eval configGUI {}
}
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
proc ::waveGUI::configGUI {} {
	ttk::label .waveform(l) -text "Select waveform:"
	ttk::combobox .waveform(dropdown) -textvariable waveform
	bind .waveform(dropdown) <<ComboboxSelected>> {[.waveform(dropdown) get]}
	ttk::label .period(l) -text "Period (ms):"
	ttk::entry .period(ent) -width 3 -textvariable ::waveGUI::period
	ttk::label .ampl(l) -text "High level (mV):"
	ttk::entry .ampl(ent) -width 3 -textvariable ::waveGUI::ampl
	ttk::label .offset(l) -text "Low level (mV):"
	ttk::entry .offset(ent) -width 3 -textvariable ::waveGUI::offset
	ttk::button .preview(b) -text "Preview" \
		-command "set ::waveGUI::period [.period(ent) get]; puts stdout $::waveGUI::period"

	grid .period(l) -row 0 -column 0
	grid .period(ent) -row 0 -column 1
	grid .ampl(l) -row 1 -column 0
	grid .ampl(ent) -row 1 -column 1
	grid .offset(l) -row 2 -column 0
	grid .offset(ent) -row 2 -column 1	
	grid .preview(b) -row 20 -column 0 -columnspan 2
}

bind . <Control-h> { console show }

# Examples of sending commands

#::wave::trigger
::waveGUI::configGUI
::wave::talk
puts stdout [::wave::sendarb "FUNC:SHAPE SIN"]
::wave::sendarb "FREQ 1.0E+3"
::wave::sendarb "VOLT 3.0"
#::wave::sendarb "OUTPUT ON"
::wave::bye


