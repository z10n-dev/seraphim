#!/bin/bash

killall qs
hyprctl reload
sleep 1
qs -p ~/.config/testshell/03-example-bar.qml -d
qs -p ~/.config/testshell/03-example-bar-screen-2.qml -d
qs -p ~/.config/testshell/03-example-bar-screen-3.qml -d