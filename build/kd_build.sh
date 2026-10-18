#!/bin/bash
. $HOME/kdenlive-android/craftenv.sh
cd $HOME/kdenlive-android/CraftRoot
python3 craft-tmp/bin/craft.py --run ninja -C $HOME/kdenlive-android/build/kdenlive-arm64 -j3 -k 20 > $HOME/kdenlive-android/build/kd_build.log 2>&1
echo "=== KDBUILD END rc=$? $(date +%T)" >> $HOME/kdenlive-android/build/deps.status
