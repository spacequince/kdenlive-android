#!/bin/bash
. $HOME/kdenlive-android/craftenv.sh
cd $HOME/kdenlive-android/CraftRoot
S=$HOME/kdenlive-android/build/kf.status; : > $S
for p in kde/frameworks/tier1/kplotting kde/frameworks/tier1/kimageformats kde/frameworks/tier1/kitemviews kde/frameworks/tier2/kcrash kde/frameworks/tier2/kfilemetadata kde/frameworks/tier3/kdeclarative kde/frameworks/tier3/ktextwidgets kde/frameworks/tier3/kio kde/frameworks/tier3/knotifyconfig kde/frameworks/tier3/knewstuff kde/frameworks/tier3/purpose kde/frameworks/tier4/frameworkintegration; do
  n=$(echo $p | tr / _)
  python3 craft-tmp/bin/craft.py $p > $HOME/kdenlive-android/build/kf_$n.log 2>&1
  echo "END $p rc=$? $(date +%T)" >> $S
done
echo "KF ALL DONE" >> $S
