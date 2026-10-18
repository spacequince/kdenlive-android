#!/bin/bash
# Exit 0 only if the system file picker has focus (waits up to ~8 s). Used before typing into the picker.
A=$HOME/kdenlive-android/sdk/platform-tools/adb
for i in 1 2 3 4 5 6 7 8; do
  $A shell dumpsys window | grep -m1 mCurrentFocus | grep -qE "documentsui|nbu.files" && exit 0
  sleep 1
done
echo "GUARD: file picker did not open; refusing to type" >&2
exit 1
