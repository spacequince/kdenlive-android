#!/bin/bash
. $HOME/kdenlive-android/craftenv.sh
cd $HOME/kdenlive-android/CraftRoot
sed -i 's/^Jobs = 3/Jobs = 1/' etc/CraftSettings.ini
python3 craft-tmp/bin/craft.py --install-deps libs/mlt > $HOME/kdenlive-android/build/dep_libs_mlt.log 2>&1
rc=$?
sed -i 's/^Jobs = 1/Jobs = 3/' etc/CraftSettings.ini
echo "=== MLT END rc=$rc $(date +%T)" >> $HOME/kdenlive-android/build/deps.status
