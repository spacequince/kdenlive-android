#!/bin/bash
. $HOME/kdenlive-android/craftenv.sh
cd $HOME/kdenlive-android/CraftRoot
B=$HOME/kdenlive-android/CraftRoot/build/libs/mlt/work/build
python3 craft-tmp/bin/craft.py --run ninja -C $B mlt melt > $HOME/kdenlive-android/build/mlt_core_build.log 2>&1
echo "build rc=$?"; grep -E "error:|FAILED" $HOME/kdenlive-android/build/mlt_core_build.log | head -5 | cut -c1-200
ls -la $B/out/lib/libmlt-7* $B/out/bin/melt 2>/dev/null
