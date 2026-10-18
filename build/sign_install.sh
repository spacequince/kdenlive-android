#!/bin/bash
# repack unsigned APK with NDK30 libc++_shared, sign, install, launch, show errors
set -e
trap 'rm -rf $HOME/kdenlive-android/build/repack' EXIT
R=$HOME/kdenlive-android
W=$R/build/repack; rm -rf $W; mkdir -p $W
mkdir -p $W/lib/arm64-v8a
cp $R/sdk/ndk/30.0.14904198/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so $W/lib/arm64-v8a/
cp $R/build/kdenlive-arm64/src/android-build/build/outputs/apk/release/android-build-release-unsigned.apk $W/u.apk
cd $W; zip -q -d u.apk 'META-INF/*' || true
zip -q -0 u.apk lib/arm64-v8a/libc++_shared.so
BT=$R/sdk/build-tools/36.0.0
$BT/zipalign -f -p 4 u.apk a.apk
mkdir -p $R/out
$BT/apksigner sign --ks $R/keys/debug.keystore --ks-pass pass:android --key-pass pass:android --out $R/out/kdenlive-debug.apk a.apk
A=$R/sdk/platform-tools/adb
$A install -r $R/out/kdenlive-debug.apk | tail -1
$A logcat -c
$A shell am force-stop org.qtproject.example.kdenlive
$A shell am start -n org.qtproject.example.kdenlive/org.kdenlive.android.KdenliveActivity >/dev/null
sleep ${1:-12}
echo PID=$($A shell pidof org.qtproject.example.kdenlive || true)
