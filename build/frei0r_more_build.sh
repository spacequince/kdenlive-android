#!/bin/bash
. $HOME/kdenlive-android/craftenv.sh
cd $HOME/kdenlive-android/CraftRoot
ST=$HOME/kdenlive-android/build/frei0r_more.status
echo "START $(date +%T)" > $ST
sed -i 's/^Jobs = 3/Jobs = 1/' etc/CraftSettings.ini
for p in libs/gavl libs/frei0r-bigsh0t libs/frei0r-plugins; do
  python3 craft-tmp/bin/craft.py --no-cache $p > $HOME/kdenlive-android/build/frei0r_more_$(echo $p | tr / _).log 2>&1
  echo "END $p rc=$? $(date +%T)" >> $ST
done
sed -i 's/^Jobs = 1/Jobs = 3/' etc/CraftSettings.ini
echo "ALL DONE" >> $ST
