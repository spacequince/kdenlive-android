#!/bin/bash
. $HOME/kdenlive-android/craftenv.sh
cd $HOME/kdenlive-android/CraftRoot
R=$HOME/kdenlive-android/CraftRoot
python3 craft-tmp/bin/craft.py --run cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX=$R -DCMAKE_PREFIX_PATH=$R \
  -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_TESTING=OFF -DBUILD_SHARED_LIBS=ON \
  -DCMAKE_TOOLCHAIN_FILE=$R/lib/cmake/Qt6/qt.toolchain.cmake \
  -DQT_CHAINLOAD_TOOLCHAIN_FILE=$R/share/ECM/toolchain/Android.cmake \
  -DECM_ADDITIONAL_FIND_ROOT_PATH=$R -DCMAKE_ANDROID_API=28 \
  -DQT_HOST_PATH=/usr -DQT_HOST_PATH_CMAKE_DIR=/usr/lib64/cmake \
  -DKF6_HOST_TOOLING=/usr/lib64/cmake -DKDENLIVE_ANDROID_LIBS_DIR=$HOME/kdenlive-android/build/android-libs -DKDENLIVE_ANDROID_PKG_DIR=$HOME/kdenlive-android/build/android-pkg -DUSE_DBUS=OFF -DFETCH_OTIO=OFF -DRELEASE_BUILD=OFF \
  -B $HOME/kdenlive-android/build/kdenlive-arm64 -S $HOME/kdenlive-android/src/kdenlive
