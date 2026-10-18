#!/bin/bash
# Dev helper: after a fresh launch, dismiss the autosave dialog, import the newest picker file and put it on V1
A=$HOME/kdenlive-android/sdk/platform-tools/adb
$A shell input tap 1119 452; sleep 6      # "Do not recover"
$A shell input tap 199 227; sleep 3        # Add Clip or Folder -> system picker
$A shell input tap 417 810; sleep 6        # first "Recent file" (kdenlive_test.mp4)
$A shell input draganddrop 336 219 440 860 1200; sleep 3   # bin -> timeline V1
