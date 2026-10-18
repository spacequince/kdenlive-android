#!/bin/bash
# usage: fresh.sh <clip-name-without-.mp4> ...   New project (1080p30), import the named clips by touch, drag them to V1 in order
A=$HOME/kdenlive-android/sdk/platform-tools/adb
G=$HOME/kdenlive-android/build/mouse/guard.sh
M="timeout 60 python3 $HOME/kdenlive-android/build/mouse/session.py"
cd $HOME/kdenlive-android/build/mouse
# first New answers any 'save changes?' prompt, second New starts from an unmodified project (the import is flaky straight after the prompt)
$M 'click 182 73' 'wait 2' 'click 1348 806' 'wait 2' 'click 1308 456' 'wait 4' >/dev/null 2>&1
$M 'click 182 73' 'wait 2.5' 'click 1348 806' 'wait 3' 'click 156 567' 'wait 1' >/dev/null 2>&1
for c in "$@"; do
  $M 'dclick 400 400' 'wait 4' >/dev/null 2>&1
  $HOME/kdenlive-android/build/mouse/guard_picker.sh || exit 3; $A shell input tap 400 125; sleep 1; $A shell input text "$c"; $A shell input keyevent 66; sleep 4; $A shell input tap 500 250; sleep 4
  $M 'click 1135 469' 'wait 1.5' >/dev/null 2>&1
done
# bin is sorted by name; drag each in sorted-row order is up to the caller, so only the first row is dragged here
[ -n "$NODRAG" ] || $M 'drag 285 198 345 840' 'wait 1' 'click 400 840' 'wait 1' >/dev/null 2>&1
