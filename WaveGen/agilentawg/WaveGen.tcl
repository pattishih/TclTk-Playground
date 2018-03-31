package provide agilentawg 1.2

# revision 1.2
#
# Example usage:
#	awg::talk
#	set seq {3.0 {{10 100} {3.0 1}} {{111 100} {3.0 0}}}
#	set arbdg [awg::expandSequence $seq]
#	awg::loadArb $arbdg; dg_delete $arbdg
#	awg::arm 3 gated 6
#	awg::unarm
#	awg::bye
#
# "Put"ting remote commands:
#   eg)  awg::pCmd "DISP:TEXT:CLEAR"
# "Get"ting info/status from wave generator:
#	eg)  awg::gCmd "OUTPUT?"
#
# {wavePeriod {{startTime0 duration0} {voltage0 negative?0}} ...}


package require dlsh

#::::::::::::::::::::::::::::::::::::::::::::::::::
namespace eval ::awg:: {
	variable s 
	namespace eval expandSequence:: {}
}
#::::::::::::::::::::::::::::::::::::::::::::::::::


#********************************************************************************
proc ::awg::pCmd {cmd} {
	puts $awg::s "$cmd";
	after 10;
}

proc ::awg::gCmd {cmd} {
	gets $awg::s "$cmd";
	after 20;	
}

proc ::awg::talk {} {
	#--Open socket
	if { [catch { socket 100.0.0.5 5024 } awg::s] } { return 0 }
	fconfigure $awg::s -buffering none;
	fconfigure stdout -buffering none;
	after 10;
	awg::pCmd {SYST:REM};
	awg::pCmd "[list DISP:TEXT 'Connected']";
	after 1800;
	awg::pCmd {DISP:TEXT:CLEar};
	return 1;
}

proc ::awg::bye {} {
	awg::pCmd [list DISP:TEXT 'Disconnecting'];
	after 1500;
	awg::pCmd {DISP:TEXT:CLEar};
	awg::pCmd {SYST:COMM:RLST LOC};
	close $awg::s;
}

#********************************************************************************
proc ::awg::trigger {} {
#-- Trigger per trial remotely
	#when remotely triggered, waveform generator will beep twice
	awg::pCmd {*TRG;SYST:BEEP;SYST:BEEP;*WAI}
}


proc ::awg::arm {wavePeriod stimDuration V { R 50 }} {
#-- Arm once at the beginning
#	* wavePeriod in milliseconds
#	* stimDuration can be time (in milliseconds) or 'gated'
#   * R is optional; defaults to 50 Ohms
#
# 	examples:
#		awg::arm 3 gated 6 50
#		awg::arm 3 2000 6 50

	awg::setWave $wavePeriod $V $R;
	awg::setMode $wavePeriod $stimDuration;
	awg::pCmd {OUTPut ON};

	#   "At lower amplitude, you can reduce output distortions by disabling 
	#    the sync signal. The default is ON."
	awg::pCmd {OUTP:SYNC OFF};

	#   "With the front-panel display disabled, there will be some improvement 
	#    in command execution speed from the remote interface."
	after 500
	awg::pCmd {DISP OFF};
	awg::pCmd [list DISP:TEXT 'Armed'];
}

proc ::awg::loadArb {arbdg} {
#	* arbDL is for future use and will allow users to specify which dl to use

	set arb [dg_tclListnames $arbdg]
	set arbWave [join [dl_tcllist $arbdg:$arb] ","]
	after 2000
	awg::pCmd "DATA VOLATILE, $arbWave";
	after 3000
	awg::pCmd {DATA:COPY STIM, VOLATILE};
}

proc ::awg::unarm {} {
	awg::pCmd {*RST};
	awg::pCmd {DISP ON};
    awg::pCmd {OUTPut OFF};
}


##################################################################################

proc ::awg::T2f {period} {
  # // get waveform period in microseconds
  # // convert to seconds --> Hz
  # // return in kHz
	set freq [expr "1/($period * .001)"];						#input in milliseconds
	return $freq;
}

proc ::awg::setWave {wavePeriod V { R 50 }} {
	set freqInHz [awg::T2f $wavePeriod]
	awg::pCmd {FUNC:USER STIM};
	awg::pCmd {FUNC USER};
	awg::pCmd "OUTPut:LOAD $R";									#default: 50 Ohms (in Ohms)
	awg::pCmd "FREQ $freqInHz";									#default: 1 kHz (1E+3 Hz)
	awg::pCmd "VOLT $V Vpp";
	awg::pCmd {VOLT:OFFSet 0};
}

proc ::awg::stimdur2cyc {wavePeriod stimDuration} {
	set cycles [expr int(floor($stimDuration / $wavePeriod))];	#compute # of duty cycles
	return $cycles;
}


proc ::awg::setMode {wavePeriod stimDuration} {
#-- default is currently BURSt mode
  # // Parameters for waveform should be set first
	switch -glob -- $stimDuration {
		"gated" {
			awg::pCmd {BURSt:MODE GATed};
			awg::pCmd {TRIG:SOURce EXT}; 						#external via Trig In
		} default { 
		#-- burst duty cycle, given the duration of the trial/stimulation time:
			set ncyc [awg::stimdur2cyc $wavePeriod $stimDuration]
			awg::pCmd {BURSt:MODE TRIG};
			awg::pCmd "BURSt:NCYC $ncyc";
			awg::pCmd {TRIG:SOURce BUS};
			puts stdout "Duty cycle: $ncyc"
		}
	}	
	awg::pCmd {BURSt:STAT ON};
}

##################################################################################
proc ::awg::expandSequence::getAmplitudes {numPulses waveParams} {
    for {set pIndex 1} {$pIndex <= $numPulses} {incr pIndex} {
        lappend amplitudes [lindex $waveParams $pIndex 1 0]
    }
    return $amplitudes
}

proc ::awg::expandSequence {waveParams} {
	set wavePeriod [expr "[lindex $waveParams 0] * 1000"];  #ms --> microseconds
	set numPulses [llength [lrange $makeawg::waveParams 1 end]];  #index_0 is the wave period
	set resolution [expr 16384];  #16,384 is the minimum temporal resolution. This could be made to be user modifiable
	set upsample [expr "($resolution / ($wavePeriod*1.000))"];  #If not sufficiently sampled, the waveform generator will automatically upsample your waveform upon loading. 
	set wavePeriodScaled [expr "int($wavePeriod * $upsample)"];
    
    set amplitudes [awg::expandSequence::getAmplitudes $numPulses $waveParams]
    set maxAmplitude [expr max([join $amplitudes ","])]

    set dlpulseList "";
	for {set pIndex 1} {$pIndex <= $numPulses} {incr pIndex} {
        set startTime [expr "int([lindex $waveParams $pIndex 0 0] * $upsample)"]
        set durTime [expr "int([lindex $waveParams $pIndex 0 1] * $upsample)"]
        set endTime [expr "$startTime + $durTime"]
        set remainingTime [expr "$wavePeriodScaled - $endTime"]
        set posneg [expr "([lindex $waveParams $pIndex 1 1] * -2) + 1"];  #shift values such that pos = 1 (orig: 0) and neg = -1 (orig: 1)
        set pulseAmp [expr "[lindex $waveParams $pIndex 1 0] * $posneg"]
        set pAmpScaled [expr "($pulseAmp * 1.000) / $maxAmplitude"]

        dl_local pulse$pIndex [dl_mult [dl_repeat "0 1 0" "$startTime $durTime $remainingTime"] $pAmpScaled]
        lappend dlpulseList $[list pulse$pIndex]
        echo $dlpulseList
    }
    dl_local pulseSeries 0.0;  #extra 0 for the beginning of the time series
    if {[llength $dlpulseList] == 1} { 
        set dlpulses $pulse1
    } else {
        set dlpulses [eval eval dl_add $dlpulseList]
    }
    dl_concat $pulseSeries $dlpulses

# @-- To be expanded at a later date... (maybe)
    set arbdg [dg_create]
    dg_addExistingList $arbdg $pulseSeries

	return $arbdg;
}

