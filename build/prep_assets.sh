#!/bin/bash
R=$HOME/kdenlive-android
P=$R/build/android-pkg/assets
rm -rf $R/build/android-pkg; mkdir -p $P/mlt $P/kdenlive
cp -r $R/CraftRoot/share/mlt-7/. $P/mlt/
cp -r $R/build/stage$R/CraftRoot/share/kdenlive/. $P/kdenlive/
du -sh $P/*

# manifest (landscape lock) and launcher icon
cp $R/CraftRoot/src/android/templates/AndroidManifest.xml $R/build/android-pkg/AndroidManifest.xml
sed -i 's|android:screenOrientation="unspecified"|android:screenOrientation="sensorLandscape"|' $R/build/android-pkg/AndroidManifest.xml
ICON=$R/src/kdenlive/data/icons/1024-apps-kdenlive.png
for d in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  n=${d%%:*}; s=${d##*:}
  mkdir -p $R/build/android-pkg/res/mipmap-$n
  ffmpeg -loglevel error -y -i $ICON -vf scale=$s:$s $R/build/android-pkg/res/mipmap-$n/ic_launcher.png
done
grep -c sensorLandscape $R/build/android-pkg/AndroidManifest.xml

# Android hardware H.264 render preset (libx264 is not part of the Android FFmpeg build)
python3 - <<'PY'
import os
f=os.path.expanduser('~/kdenlive-android/build/android-pkg/assets/kdenlive/export/profiles.xml')
t=open(f).read()
preset='''  <profile name="MP4-H264 (Android hardware)" extension="mp4"
   bitrates="30000,1000" defaultbitrate="8000"
   audiobitrates="64,128,160,256,384" defaultaudiobitrate="160"
   args="f=mp4 movflags=+faststart vcodec=h264_mediacodec pix_fmt=nv12 vb=%bitrate+'k' acodec=aac ab=%audiobitrate+'k'"/>
'''
if 'Android hardware' not in t:
    i=t.index('<profile ')
    t=t[:i]+preset.lstrip()+'  '+t[i:]
    open(f,'w').write(t)
print('preset added')
PY

# full-screen theme without the action bar (the title bar wastes 100px of a 960px-tall screen)
mkdir -p $R/build/android-pkg/res/values
cat > $R/build/android-pkg/res/values/themes.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="KdenliveTheme" parent="android:Theme.DeviceDefault.NoActionBar">
        <item name="android:windowFullscreen">true</item>
        <item name="android:windowLayoutInDisplayCutoutMode">shortEdges</item>
    </style>
</resources>
XML
sed -i 's|android:hardwareAccelerated="true"|android:hardwareAccelerated="true"\n        android:theme="@style/KdenliveTheme"|' $R/build/android-pkg/AndroidManifest.xml
grep -c KdenliveTheme $R/build/android-pkg/AndroidManifest.xml

# read access to shared photos/videos/audio so picked files can be used in place (no copy)
sed -i 's|<!-- %%INSERT_PERMISSIONS -->|<!-- %%INSERT_PERMISSIONS -->\n    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />\n    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />\n    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />|' $R/build/android-pkg/AndroidManifest.xml
grep -c READ_MEDIA $R/build/android-pkg/AndroidManifest.xml
# let adb/scrcpy capture the app's playback audio for demo videos (apps targeting API 28 are opted out by default)
sed -i 's|android:allowBackup="true"|android:allowBackup="true"\n        android:allowAudioPlaybackCapture="true"|' $R/build/android-pkg/AndroidManifest.xml
grep -c allowAudioPlaybackCapture $R/build/android-pkg/AndroidManifest.xml

bash $R/build/prep_icons.sh | tail -2

# frei0r effect plugins as plain JNI libs (not Qt "bundled libs": those are all dlopen'ed at startup)
python3 - <<'PY'
import os, glob, shutil, subprocess
R=os.path.expanduser('~/kdenlive-android')
RN=R+'/sdk/ndk/30.0.14904198/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-readelf'
dst=R+'/build/android-pkg/libs/arm64-v8a'; os.makedirs(dst, exist_ok=True)
ok=0; skipped=[]
for f in sorted(glob.glob(R+'/CraftRoot/lib/frei0r-1/*.so')):
    needed=subprocess.run([RN,'-d',f],capture_output=True,text=True).stdout
    out=dst+'/libfrei0r_'+os.path.basename(f)[:-3]+'.so'
    shutil.copy(f, out); ok+=1
    if 'libcairo.so.2' in needed:   # shipped as libcairo.so (Android only packages unversioned lib*.so)
        subprocess.run([R+'/build/venv/bin/patchelf','--replace-needed','libcairo.so.2','libcairo.so',out],check=True)
print('frei0r plugins:', ok, 'skipped (cairo):', skipped)
nl=0
for f in sorted(glob.glob(R+'/build/ladspa-libs/libladspa_*.so')):
    shutil.copy(f, dst+'/'+os.path.basename(f)); nl+=1
print('ladspa plugins:', nl)
PY

# data files of the LADSPA host module (normally installed by `ninja install`)
mkdir -p $R/build/android-pkg/assets/mlt/jackrack
J=$R/CraftRoot/download/git/libs/mlt/src/modules/jackrack
cp $J/filter_ladspa.yml $J/producer_ladspa.yml $J/blacklist.txt $R/build/android-pkg/assets/mlt/jackrack/
ls $R/build/android-pkg/assets/mlt/jackrack

# render foreground service (Java) + permissions + service entry
mkdir -p $R/build/android-pkg/src
cp -r $R/build/android-pkg-src/src/. $R/build/android-pkg/src/
M=$R/build/android-pkg/AndroidManifest.xml
sed -i 's|<!-- %%INSERT_PERMISSIONS -->|<!-- %%INSERT_PERMISSIONS -->\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROCESSING" />\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n    <uses-permission android:name="android.permission.WAKE_LOCK" />|' $M
sed -i 's|</application>|    <service android:name="org.kdenlive.android.RenderService" android:exported="false" android:foregroundServiceType="mediaProcessing" />\n    </application>|' $M
grep -c "RenderService\|FOREGROUND_SERVICE" $M

# custom activity (mouse events -> touch while a dialog is open)
sed -i 's|android:name="org.qtproject.qt.android.bindings.QtActivity"|android:name="org.kdenlive.android.KdenliveActivity"|' $R/build/android-pkg/AndroidManifest.xml
grep -c KdenliveActivity $R/build/android-pkg/AndroidManifest.xml

# OpenCV motion tracker metadata
mkdir -p $R/build/android-pkg/assets/mlt/opencv
cp $R/CraftRoot/download/git/libs/mlt/src/modules/opencv/filter_opencv_tracker.yml $R/build/android-pkg/assets/mlt/opencv/

# melt as an executable named like a library (Android only allows executing files from the native library dir)
cp $R/CraftRoot/build/libs/mlt/work/build/out/bin/melt $R/build/android-pkg/libs/arm64-v8a/libmelt.so
$R/build/venv/bin/patchelf --set-rpath '$ORIGIN' $R/build/android-pkg/libs/arm64-v8a/libmelt.so
ls -la $R/build/android-pkg/libs/arm64-v8a/libmelt.so

# ffmpeg / ffprobe command line tools (same trick)
for t in ffmpeg ffprobe; do
  if [ -f $R/CraftRoot/bin/$t ]; then
    cp $R/CraftRoot/bin/$t $R/build/android-pkg/libs/arm64-v8a/lib$t.so
    $R/build/venv/bin/patchelf --set-rpath '$ORIGIN' $R/build/android-pkg/libs/arm64-v8a/lib$t.so
    echo "staged lib$t.so"
  fi
done

# plugins loaded by helper executables need to find libc++_shared.so / libcairo.so too
for f in $R/build/android-pkg/libs/arm64-v8a/*.so; do $R/build/venv/bin/patchelf --set-rpath '$ORIGIN' "$f" 2>/dev/null || true; done
