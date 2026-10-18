#!/bin/bash
. $HOME/kdenlive-android/craftenv.sh
cd $HOME/kdenlive-android/CraftRoot
ST=$HOME/kdenlive-android/build/fftwf.status
echo "START $(date +%T)" > $ST
sed -i 's/^Jobs = 3/Jobs = 1/' etc/CraftSettings.ini
python3 craft-tmp/bin/craft.py --no-cache libs/libfftwf > $HOME/kdenlive-android/build/fftwf_build.log 2>&1
echo "END rc=$? $(date +%T)" >> $ST
sed -i 's/^Jobs = 1/Jobs = 3/' etc/CraftSettings.ini
