#!/bin/bash
. $HOME/kdenlive-android/craftenv.sh
cd $HOME/kdenlive-android/CraftRoot
R=$HOME/kdenlive-android/CraftRoot
B=$HOME/kdenlive-android/build/kio_file_build
python3 craft-tmp/bin/craft.py --run cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX=$B/install -DCMAKE_PREFIX_PATH=$R \
  -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_TESTING=OFF \
  -DCMAKE_TOOLCHAIN_FILE=$R/lib/cmake/Qt6/qt.toolchain.cmake \
  -DQT_CHAINLOAD_TOOLCHAIN_FILE=$R/share/ECM/toolchain/Android.cmake \
  -DECM_ADDITIONAL_FIND_ROOT_PATH=$R -DCMAKE_ANDROID_API=28 \
  -DQT_HOST_PATH=/usr -DQT_HOST_PATH_CMAKE_DIR=/usr/lib64/cmake \
  -DKF6_HOST_TOOLING=/usr/lib64/cmake \
  -B $B -S $HOME/kdenlive-android/build/kio_file_proj > $HOME/kdenlive-android/build/kio_file_cfg.log 2>&1 || { echo CFG FAILED; tail -15 $HOME/kdenlive-android/build/kio_file_cfg.log; exit 1; }
python3 craft-tmp/bin/craft.py --run ninja -C $B -j3 > $HOME/kdenlive-android/build/kio_file_build.log 2>&1 || { echo BUILD FAILED; grep -E "error|Error" $HOME/kdenlive-android/build/kio_file_build.log | head -15; exit 1; }
echo BUILD OK; find $B -name "*kio_file*.so" | head
