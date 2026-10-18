#!/bin/bash
. $HOME/kdenlive-android/craftenv.sh
cd $HOME/kdenlive-android/CraftRoot
python3 craft-tmp/bin/craft.py libs/mlt > $HOME/kdenlive-android/build/mlt_full.log 2>&1
echo "=== MLTFULL END rc=$? $(date +%T)" >> $HOME/kdenlive-android/build/deps.status
