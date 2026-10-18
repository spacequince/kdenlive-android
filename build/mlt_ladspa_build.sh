#!/bin/bash
. $HOME/kdenlive-android/craftenv.sh
cd $HOME/kdenlive-android/CraftRoot
B=$HOME/kdenlive-android/CraftRoot/build/libs/mlt/work/build
export PKG_CONFIG_PATH=$HOME/kdenlive-android/CraftRoot/lib/pkgconfig:$PKG_CONFIG_PATH
python3 craft-tmp/bin/craft.py --run cmake -DUSE_LADSPA=ON -DMOD_JACKRACK=ON -DUSE_LV2=OFF -DUSE_VST2=OFF $B > $HOME/kdenlive-android/build/mlt_ladspa_cfg.log 2>&1 || { echo CFG FAILED; grep -iE "error|not found" $HOME/kdenlive-android/build/mlt_ladspa_cfg.log | head -8; exit 1; }
python3 craft-tmp/bin/craft.py --run ninja -C $B mltladspa > $HOME/kdenlive-android/build/mlt_ladspa_build.log 2>&1
echo "build rc=$?"
grep -E "error:|FAILED" $HOME/kdenlive-android/build/mlt_ladspa_build.log | head -8 | cut -c1-240
find $B -name "libmltladspa*" | head
