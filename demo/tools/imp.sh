#!/bin/bash
# usage: imp.sh <clip>...   import clips into the open project (Project Bin tab must be showing)
A=$HOME/kdenlive-android/sdk/platform-tools/adb
G=$HOME/kdenlive-android/build/mouse/guard.sh
M="timeout 60 python3 $HOME/kdenlive-android/build/mouse/session.py"
cd $HOME/kdenlive-android/build/mouse
for c in "$@"; do
  $M 'click 156 570' 'wait 1' 'dclick 400 480' 'wait 4' >/dev/null 2>&1
  $HOME/kdenlive-android/build/mouse/guard_picker.sh || exit 3; $A shell input tap 400 125; sleep 1; $A shell input text "$c"; $A shell input keyevent 66; sleep 4; $A shell input tap 500 250; sleep 4
  $M 'click 1135 469' 'wait 1.5' >/dev/null 2>&1
done
