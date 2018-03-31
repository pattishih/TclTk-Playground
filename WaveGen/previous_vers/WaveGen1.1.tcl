#!/bin/sh
# Run wish from the users PATH \
exec wish -f "$0" ${1+"$@"}

# revision 1.1

#package require loaddata
#package require graphing
#package require dlsh

#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
namespace eval ::wave:: {
	variable s
}

#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
proc ::wave::pCmd {cmd} {
	puts $wave::s "$cmd";
	after 10;
}

proc ::wave::gCmd {cmd} {
	gets $wave::s {$cmd};
}

proc ::wave::talk {} {
	#--Open socket
	set wave::s [socket 100.0.0.5 5024]
	fconfigure $wave::s -buffering none;
	fconfigure stdout -buffering none;
	after 10;
	wave::pCmd {SYST:REM};
	wave::pCmd "[list DISP:TEXT 'Connected!']";
	after 1500;
	wave::pCmd {DISP:TEXT:CLEar};

	#   "At lower amplitude, you can reduce output distortions by disabling 
	#    the sync signal. The default is ON."
	wave::pCmd {OUTP:SYNC OFF};
}



proc ::wave::bye {} {
	wave::pCmd [list DISP:TEXT 'Disconnecting...'];
	after 1500;
	wave::pCmd {DISP:TEXT:CLEar};
	wave::pCmd {SYST:COMM:RLST LOC};
	close $wave::s;
}

#--------------------------------------------------------------------------------
proc ::wave::loadArb {arb} {
	wave::pCmd {DATA VOLATILE, $arb};
	wave::gCmd {*OPC?}; #waits until OPC bit returns 1
	wave::pCmd {DATA:COPY STIM, VOLATILE};
}

proc ::wave::T2f {period} {
  # // get frequency
  # // and return in kHz
	set kHz "E+3"
	set freq [expr "1.00/$period"]
	return $freq$kHz;
}

proc ::wave::stimdur2cyc {t totalTime} {
	set cycles [expr floor($totalTime / $t)]
	return $cycles;
}

proc ::wave::setMode {endt stimDuration} {
  # // set function, freq, ampl, and offset of waveform first
	set ncyc [wave::stimdur2cyc $endt $stimDuration]
	wave::pCmd {BURSt:MODE TRIG};
	wave::pCmd {BURSt:NCYC $ncyc};
	wave::pCmd {TRIG:SOURce BUS};
	wave::pCmd {BURSt:STAT ON};
}

#********************************************************************************
proc ::wave::setWave {endt} {# NEED $max; $min variables here!!
	set freqInKHz [wave::T2f $endt]
	
	wave::pCmd {FUNC:USER STIM};
	wave::pCmd {FUNC USER};
	wave::pCmd {OUTPut:LOAD 50};				#50 Ohms
	wave::pCmd {FREQ $freqInKHz};			#Frequency in kHz
	wave::pCmd {VOLT:HIGH $max};
	wave::pCmd {VOLT:LOW $min};
	
	
}
#********************************************************************************
proc ::wave::trigger {} {
	wave::pCmd {*TRG;SYST:BEEP;*WAI}
}

proc ::wave::arm {endt stimDuration arb} {
	wave::loadArb $arb;
	wave::setWave $endt;
	wave::setMode $endt $stimDuration;

	set outputStatus [wave::gCmd {OUTPut?}]
	if {$outputStatus == 0} {wave::pCmd {OUTPut ON}};

	set dispStatus [wave::gCmd {DISP?}]

	#   "With the front-panel display disabled, there will be some improvement 
	#    in command execution speed from the remote interface."
	if {$dispStatus == 1} {wave::pCmd {DISP OFF}};

	wave::pCmd [list DISP:TEXT 'Ready'];
}

proc ::wave::unarm {} {
	wave::pCmd {*RST};
	wave::pCmd {DISP ON};
	set outputStatus [wave::gCmd OUTPut?]
	if {$outputStatus == 1} {wave::pCmd {OUTPut OFF}};
}

