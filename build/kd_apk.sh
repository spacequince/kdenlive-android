#!/bin/bash
. $HOME/kdenlive-android/craftenv.sh
cd $HOME/kdenlive-android/CraftRoot
python3 craft-tmp/bin/craft.py --run ninja -C $HOME/kdenlive-android/build/kdenlive-arm64 -j3 apk > $HOME/kdenlive-android/build/apk_build.log 2>&1
echo "APK END rc=$?" >> $HOME/kdenlive-android/build/apk_build.log
