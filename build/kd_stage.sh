#!/bin/bash
. $HOME/kdenlive-android/craftenv.sh
rm -rf $HOME/kdenlive-android/build/stage
cd $HOME/kdenlive-android/CraftRoot
DESTDIR=$HOME/kdenlive-android/build/stage python3 craft-tmp/bin/craft.py --run ninja -C $HOME/kdenlive-android/build/kdenlive-arm64 install > $HOME/kdenlive-android/build/stage_install.log 2>&1
echo "STAGE rc=$?"
