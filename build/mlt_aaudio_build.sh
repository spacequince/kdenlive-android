#!/bin/bash
. $HOME/kdenlive-android/craftenv.sh
cd $HOME/kdenlive-android/CraftRoot
R=$HOME/kdenlive-android/CraftRoot
B=$HOME/kdenlive-android/build/mlt_aaudio_out
python3 craft-tmp/bin/craft.py --run cmake -G Ninja \
  -DCMAKE_BUILD_TYPE=MinSizeRel \
  -DCMAKE_TOOLCHAIN_FILE=$R/lib/cmake/Qt6/qt.toolchain.cmake \
  -DQT_CHAINLOAD_TOOLCHAIN_FILE=$R/share/ECM/toolchain/Android.cmake \
  -DCMAKE_ANDROID_API=28 -DQT_HOST_PATH=/usr -DQT_HOST_PATH_CMAKE_DIR=/usr/lib64/cmake \
  -B $B -S $HOME/kdenlive-android/build/mlt_aaudio > $HOME/kdenlive-android/build/mlt_aaudio_cfg.log 2>&1 || { echo CFG FAILED; tail -15 $HOME/kdenlive-android/build/mlt_aaudio_cfg.log; exit 1; }
python3 craft-tmp/bin/craft.py --run ninja -C $B > $HOME/kdenlive-android/build/mlt_aaudio_build.log 2>&1 || { echo BUILD FAILED; grep -E "error|warning: incompatible" $HOME/kdenlive-android/build/mlt_aaudio_build.log | head -15; exit 1; }
echo BUILD OK; ls -la $B/libmltaaudio.so
