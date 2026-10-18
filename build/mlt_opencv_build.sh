#!/bin/bash
. $HOME/kdenlive-android/craftenv.sh
cd $HOME/kdenlive-android/CraftRoot
B=$HOME/kdenlive-android/CraftRoot/build/libs/mlt/work/build
python3 craft-tmp/bin/craft.py --run cmake -DMOD_OPENCV=ON -DOpenCV_DIR=$HOME/kdenlive-android/CraftRoot/sdk/native/jni $B > $HOME/kdenlive-android/build/mlt_opencv_cfg.log 2>&1 || { echo CFG FAILED; grep -iE "error|not found" $HOME/kdenlive-android/build/mlt_opencv_cfg.log | head -8; exit 1; }
python3 craft-tmp/bin/craft.py --run ninja -C $B mltopencv > $HOME/kdenlive-android/build/mlt_opencv_build.log 2>&1
echo "build rc=$?"
grep -E "error:|FAILED" $HOME/kdenlive-android/build/mlt_opencv_build.log | head -8 | cut -c1-250
find $B -name "libmltopencv*" | head -2
