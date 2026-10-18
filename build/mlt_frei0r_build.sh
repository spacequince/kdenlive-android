#!/bin/bash
. $HOME/kdenlive-android/craftenv.sh
cd $HOME/kdenlive-android/CraftRoot
python3 craft-tmp/bin/craft.py --run ninja -C $HOME/kdenlive-android/CraftRoot/build/libs/mlt/work/build mltfrei0r > $HOME/kdenlive-android/build/mlt_frei0r_build.log 2>&1
echo "rc=$?"
tail -3 $HOME/kdenlive-android/build/mlt_frei0r_build.log | tr '\r' '\n' | tail -2
ls -la $HOME/kdenlive-android/CraftRoot/build/libs/mlt/work/build/out/lib/mlt/libmltfrei0r.so
