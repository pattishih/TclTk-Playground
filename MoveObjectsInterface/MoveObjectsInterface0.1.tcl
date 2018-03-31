#!/sw/bin/wish

#------------------------------------------------------------------------
proc ChooseColor {bWidget} {
    set currentColor \
        [tk_chooseColor -title "Choose a background color" -parent .]
    $bWidget configure -background $currentColor
}
#------------------------------------------------------------------------

label .l
        -command "ChooseColor .b"]



#------------------------------------------------------------------------
proc MoveObj {object x y} {
  .c coords $object [expr $x-25] [expr $y-25] [expr $x+25] [expr $y+25]
}
#------------------------------------------------------------------------

canvas .c -width 400 -height 300
set myoval [.c create oval 0 0 50 50 -fill orange]
#set myline [.c create line 50 50 100 100 -fill blue -width 4]

.c bind $myoval <B1-Motion>  {MoveObj $myoval %x %y}
.c bind $myline <B1-Motion>  {MoveObj $myline %x %y}


grid .c -row 0 -column 0
grid .b -row 1 -column 0 -pady {10 10}
