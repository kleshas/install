#!/bin/bash
xsetwacom set 'Tablet Monitor stylus' MapToOutput HDMI-A-0
xsetwacom set 'Tablet Monitor Pad pad' MapToOutput HDMI-A-0
xsetwacom set 'Tablet Monitor Pad pad' button "1" key "+Control_L +z" #undo
xsetwacom set 'Tablet Monitor Pad pad' button "2" key "+Shift" #hold shift
xsetwacom set 'Tablet Monitor Pad pad' button "3" key "+Control_L" #hold control

xsetwacom set 'Tablet Monitor Pad pad' button "8" key "+" # zoom in
xsetwacom set 'Tablet Monitor Pad pad' button "9" key "-" # zoom out
#xsetwacom set 'Tablet Monitor Pad pad' button "4" key "+Control_L" #hold control
xsetwacom set 'Tablet Monitor Pad pad' button "10" key "4" # rotate left
xsetwacom set 'Tablet Monitor Pad pad' button "11" key "5" # centre
xsetwacom set 'Tablet Monitor Pad pad' button "12" key "6" # rotate right