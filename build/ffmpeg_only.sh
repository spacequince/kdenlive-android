#!/bin/bash
. $HOME/kdenlive-android/craftenv.sh
cd $HOME/kdenlive-android/CraftRoot
ST=$HOME/kdenlive-android/build/ffmpeg2.status
echo "START ffmpeg $(date +%T)" > $ST
python3 craft-tmp/bin/craft.py --no-cache --fetch --unpack --compile --install --qmerge libs/ffmpeg > $HOME/kdenlive-android/build/ffmpeg_build2.log 2>&1
echo "END ffmpeg rc=$? $(date +%T)" >> $ST
