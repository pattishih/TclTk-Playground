#!/bin/sh
# Run wish from the users PATH \
exec wish -f "$0" ${1+"$@"}

package require loaddata
package require graphing
package require dlsh

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
namespace eval ::wave:: {
	variable s [socket 100.0.0.5 5025]
}

#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
proc ::wave::talk {} {
	#--Open socket
	fconfigure $wave::s -buffering none;
	puts $wave::s "OUTP:SYNC OFF" 
		# "At lower ampl, you can reduce output distortions by disabling the sync signal.
		# The default is ON."
}

proc ::wave::bye {} {
	set outputStat [puts $wave::s OUTPUT?]
	puts $wave::s "*CLS";
	if {$outputStat == 1} {puts $wave::s "OUTPUT OFF"}
	close $wave::s;
}

proc ::wave::send {cmd} {
	set opc [puts $wave::s "*OPC?; $cmd; *OPC"]
#**Note what you get for $opc... Might need to rearrange above order or just use *WAI instead
	return $opc;
}

proc ::wave::setWave {} {
	puts $wave::s "FUNC USER"
# //~ replace with the total duration of the stim ($endt)
	set freqkHz [wave::T2f $endt]
	puts $wave::s "FREQ $freqInKHz; \
				   VOLT:HIGH $above; \
				   VOLT:LOW $below";

proc ::wave::T2f {period} {
# // get frequency
# // and return in kHz
	set kHz "E+3"
	set freq [eval "1/$period"]
	return $freq$kHz;
}

# //~ stim on for how long?
# // 
proc ::wave::setMode {ncyc} {
	# set function, freq, ampl, and offset of waveform first
	wave
	wave::send "BURST:MODE TRIG; \
				BURST:NCYC $ncyc; #burst count \
				TRIG:SOURCE BUS";
	wave::send "BURST:STAT ON";

	set outputStat [puts $wave::s OUTPUT?]
	if {$outputStat == 0} {puts $wave::s "OUTPUT ON"}
	return ;
}

proc ::wave::trigger {} {
	puts $wave::s "*TRG"
	puts $wave::s "SYST:BEEP";
	after 200;
	puts $wave::s "SYST:BEEP";
}
	
	
	

# Example of loading a user waveform - uses dlsh to create list of values (could be done with a for loop in tcl, though)
	
#proc  makeArb {} {
#	set data_points 16384
#	dl_local biphasic [dl_concat [dl_repeat -1.0 20] [dl_repeat 0.0 10] [dl_repeat 1.0 20] [dl_repeat 0.0 450]]
#	set template_length [dl_length $biphasic]	
#	set ratio [expr $data_points/$template_length]
#	dl_local biphasic [dl_concat [dl_repeat -1.0 [expr 20*$ratio]] [dl_repeat 0.0 [expr 10*$ratio]] \
#		  [dl_repeat 1.0 [expr 20*$ratio]] [dl_repeat 0.0 [expr 450*$ratio]]]	
#	set biphasic [join [dl_tcllist [dl_shift $biphasic 1]] , ]	
#	sendarb "FUNC USER"
#	after 2000	
#	sendarb "DATA VOLATILE, $biphasic"
#	after 5000
#	sendarb "DATA:COPY biphasic2 ,VOLATILE"
#}


	