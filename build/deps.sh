#!/bin/bash
. $HOME/kdenlive-android/craftenv.sh
cd $HOME/kdenlive-android/CraftRoot
PKGS="libs/qt/qtsvg libs/qt/qtdeclarative libs/qt/qtmultimedia libs/qt/qtspeech libs/qt/qtimageformats libs/qt/qtnetworkauth
kde/frameworks/extra-cmake-modules kde/frameworks/tier1/karchive kde/frameworks/tier1/kconfig kde/frameworks/tier1/kcoreaddons kde/frameworks/tier1/kguiaddons kde/frameworks/tier1/ki18n kde/frameworks/tier1/kitemviews kde/frameworks/tier1/kplotting kde/frameworks/tier1/kwidgetsaddons kde/frameworks/tier1/breeze-icons
kde/frameworks/tier2/kcompletion kde/frameworks/tier2/kcrash kde/frameworks/tier2/kjobwidgets kde/frameworks/tier2/kcolorscheme
kde/frameworks/tier3/kconfigwidgets kde/frameworks/tier3/kiconthemes kde/frameworks/tier3/kio kde/frameworks/tier3/knewstuff kde/frameworks/tier3/knotifications kde/frameworks/tier3/knotifyconfig kde/frameworks/tier3/kservice kde/frameworks/tier3/ktextwidgets kde/frameworks/tier3/kxmlgui kde/frameworks/tier3/kdeclarative kde/frameworks/tier3/kbookmarks kde/frameworks/tier3/purpose
qt-libs/kddockwidgets libs/ffmpeg libs/mlt"
for p in $PKGS; do
  n=$(echo $p | tr / _)
  echo "=== START $p $(date +%T)" >> $HOME/kdenlive-android/build/deps.status
  python3 craft-tmp/bin/craft.py --install-deps $p > $HOME/kdenlive-android/build/dep_$n.log 2>&1
  rc=$?
  echo "=== END $p rc=$rc $(date +%T)" >> $HOME/kdenlive-android/build/deps.status
done
echo "=== ALL DONE" >> $HOME/kdenlive-android/build/deps.status
