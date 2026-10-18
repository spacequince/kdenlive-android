#!/bin/bash
. $HOME/kdenlive-android/craftenv.sh
cd $HOME/kdenlive-android/CraftRoot
ST=$HOME/kdenlive-android/build/ffmpeg.status
echo "START x264 $(date +%T)" > $ST
sed -i 's/^Jobs = 3/Jobs = 1/' etc/CraftSettings.ini
python3 craft-tmp/bin/craft.py --no-cache libs/x264 > $HOME/kdenlive-android/build/x264.log 2>&1
echo "END x264 rc=$? $(date +%T)" >> $ST
sed -i 's/^Jobs = 1/Jobs = 3/' etc/CraftSettings.ini
python3 craft-tmp/bin/craft.py --no-cache libs/ffmpeg > $HOME/kdenlive-android/build/ffmpeg_build.log 2>&1
echo "END ffmpeg rc=$? $(date +%T)" >> $ST
echo "ALL DONE" >> $ST
