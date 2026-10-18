#!/bin/bash
. $HOME/kdenlive-android/craftenv.sh
cd $HOME/kdenlive-android/CraftRoot
ST=$HOME/kdenlive-android/build/opencv.status
echo "START $(date +%T)" > $ST
for p in libs/opencv/opencv; do
  python3 craft-tmp/bin/craft.py --no-cache $p > $HOME/kdenlive-android/build/opencv_$(echo $p | tr / _).log 2>&1
  echo "END $p rc=$? $(date +%T)" >> $ST
done
echo "ALL DONE" >> $ST
