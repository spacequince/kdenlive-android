#!/bin/bash
# Everyday rebuild: regenerate staged assets/libs, configure, build the APK, sign and install on the connected phone.
# Usage: build/rebuild.sh [wait_seconds_after_launch]   (use --no-install to stop after the signed APK)
set -e
B=$HOME/kdenlive-android/build
$B/prep_assets.sh > $B/rebuild_assets.log 2>&1 || { echo "prep_assets failed, see $B/rebuild_assets.log"; exit 1; }
$B/prep_libs.sh   > $B/rebuild_libs.log   2>&1 || { echo "prep_libs failed, see $B/rebuild_libs.log"; exit 1; }
$B/kd_configure.sh > $B/rebuild_configure.log 2>&1 || { echo "configure failed, see $B/rebuild_configure.log"; exit 1; }
$B/kd_apk.sh
tail -1 $B/apk_build.log | grep -q "rc=0" || { echo "APK build failed, see $B/apk_build.log"; exit 1; }
if [ "$1" = "--no-install" ]; then echo "APK built (unsigned) in build/kdenlive-arm64/src/android-build/build/outputs/apk/release/"; exit 0; fi
$B/sign_install.sh "${1:-20}"
