#!/bin/bash
# Exit 0 only if Kdenlive (or the system file picker it opened) has focus. Used before any scripted phone input.
A=$HOME/kdenlive-android/sdk/platform-tools/adb
F=$($A shell dumpsys window | grep -m1 mCurrentFocus)
case "$F" in
  *org.qtproject.example.kdenlive*|*documentsui*|*nbu.files*|*com.android.intentresolver*) exit 0;;
esac
echo "GUARD: Kdenlive is not in front ($F); refusing to send input" >&2
exit 1
