#!/bin/bash
# Stage extra native libs (MLT modules + their deps) with Android-friendly sonames
R=$HOME/kdenlive-android
L=$R/build/android-libs
PE=$R/build/venv/bin/patchelf
rm -rf $L; mkdir -p $L
# x264: Android only packages unversioned lib*.so -> make the installed lib unversioned and patch ffmpeg's dependency on it
if [ -L $R/CraftRoot/lib/libx264.so ]; then
  real=$(readlink -f $R/CraftRoot/lib/libx264.so); rm $R/CraftRoot/lib/libx264.so; cp $real $R/CraftRoot/lib/libx264.so
  $PE --set-soname libx264.so $R/CraftRoot/lib/libx264.so
fi
$PE --replace-needed libx264.so.165 libx264.so $R/CraftRoot/lib/libavcodec.so 2>/dev/null || true
cp $R/CraftRoot/lib/mlt-7/libmlt*.so $L/
cp $R/CraftRoot/build/libs/mlt/work/build/out/lib/mlt/libmltfrei0r.so $L/libmltfrei0r.so  # patched: libfrei0r_<name>.so plugins (patches/extra/mlt-frei0r-android.patch)
cp $R/CraftRoot/build/libs/mlt/work/build/out/lib/mlt/libmltladspa.so $L/libmltladspa.so  # LADSPA host (patches/extra/mlt-ladspa-android.patch + build/glibshim)
cp -L $R/CraftRoot/lib/libfftw3f_arm64-v8a.so $L/  # for the FFT-based swh LADSPA plugins
# cairo (for the cairo-based frei0r plugins): unversioned name, deps (pixman...) pulled in by the closure below
cp -L $R/CraftRoot/lib/libcairo.so.2 $L/libcairo.so; $PE --set-soname libcairo.so $L/libcairo.so
cp $R/CraftRoot/build/libs/mlt/work/build/out/lib/mlt/libmltopencv.so $L/libmltopencv.so  # motion tracker (MOD_OPENCV=ON, build/mlt_opencv_build.sh)
rm -f $L/libmltsdl2.so  # SDL2 needs a Java SDLActivity; not usable on Android
for n in avdevice avfilter swscale; do cp -L $R/CraftRoot/lib/lib$n.so $L/; done
cp -L $R/CraftRoot/lib/librubberband.so $L/librubberband.so
cp -L $R/CraftRoot/lib/libspatialaudio.so $L/libspatialaudio.so
cp $R/sdk/ndk/30.0.14904198/toolchains/llvm/prebuilt/linux-x86_64/lib/clang/21/lib/linux/aarch64/libomp.so $L/
cp $R/build/kio_file_build/lib/kf6/kio/libplugins_kf6_kio_kio_file.so $L/  # KIO file worker (built by build/kio_file_build.sh)
cp $R/build/mlt_aaudio_out/libmltaaudio.so $L/  # Android AAudio consumer (build/mlt_aaudio_build.sh)
$PE --set-soname librubberband.so $L/librubberband.so
$PE --set-soname libspatialaudio.so $L/libspatialaudio.so
$PE --replace-needed librubberband.so.3 librubberband.so $L/libmltrubberband.so
$PE --replace-needed libspatialaudio.so.2 libspatialaudio.so $L/libmltspatialaudio.so
ls $L | wc -l

# dependency closure: add any NEEDED lib that exists in CraftRoot/lib but is not in the APK/staged yet
python3 - <<'PY'
import os, re, subprocess, zipfile, shutil, glob
R=os.path.expanduser('~/kdenlive-android')
L=R+'/build/android-libs'
RN=R+'/sdk/ndk/30.0.14904198/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-readelf'
apk=R+'/build/kdenlive-arm64/src/android-build/build/outputs/apk/release/android-build-release-unsigned.apk'
have=set()  # deliberately independent of any previous APK; Qt6/KF6 libs are deployed by androiddeployqt itself
system={'libc.so','libm.so','libdl.so','liblog.so','libz.so','libandroid.so','libEGL.so','libGLESv2.so','libGLESv3.so','libGLESv1_CM.so','libvulkan.so','libOpenSLES.so','libjnigraphics.so','libmediandk.so','libcamera2ndk.so','libnativewindow.so','libaaudio.so','libbinder_ndk.so','libstdc++.so','libamidi.so','libnativehelper.so','libsync.so','libc++_shared.so'}
added=[]
renames={}
while True:
    need=set()
    for f in glob.glob(L+'/*.so'):
        out=subprocess.run([RN,'-d',f],capture_output=True,text=True).stdout
        for line in out.splitlines():
            if 'NEEDED' in line: need.add(line.split('[')[1].rstrip(']'))
    have|={os.path.basename(f) for f in glob.glob(L+'/*.so')}
    new=[n for n in need if n not in have and n not in system and not n.startswith(('libQt6','libKF6','libmlt-7','libmlt++','libkdenlive'))]
    if not new: break
    for n in new:
        src=R+'/CraftRoot/lib/'+n
        if os.path.exists(src):
            m=re.match(r'^(lib.+\.so)\.[0-9.]+$', n)
            if m:
                # Android packages only lib*.so: ship it unversioned and patch every user of the old name
                renames[n]=m.group(1)
                shutil.copy(os.path.realpath(src), L+'/'+m.group(1)); added.append(n+'->'+m.group(1))
                have.add(n)
            else:
                shutil.copy(os.path.realpath(src), L+'/'+n); added.append(n)
        else:
            print('UNRESOLVED', n); have.add(n)
PE=R+'/build/venv/bin/patchelf'
for old,new in renames.items():
    subprocess.run([PE,'--set-soname',new,L+'/'+new],check=True)
    for f in glob.glob(L+'/*.so'):
        subprocess.run([PE,'--replace-needed',old,new,f],check=True)
print('closure added:', sorted(added))
PY

# Libraries whose soname equals a system library's (checked against /system, /apex, /vendor of the phone: liblzma, libcrypto, libssl)
# must be renamed: once ours is loaded in a helper process the linker reuses it for the system consumers (libunwindstack needs the
# system liblzma: "cannot locate symbol Xzs_Construct") and, the other way round, our consumers get the system BoringSSL ("BIO_read_ex").
for n in lzma crypto ssl; do
  if [ -f $L/lib$n.so ]; then
    mv $L/lib$n.so $L/lib${n}_kd.so; $PE --set-soname lib${n}_kd.so $L/lib${n}_kd.so
    for f in $L/*.so; do $PE --replace-needed lib$n.so lib${n}_kd.so "$f" 2>/dev/null || true; done
  fi
done
# RUNPATH=$ORIGIN on every library that helper executables (libmelt.so, libffmpeg.so, ...) may load: Android's linker does not search the
# app's native library directory for processes started by the app (LD_LIBRARY_PATH would shadow system libs such as liblzma)
for f in $L/*.so; do $PE --set-rpath '$ORIGIN' "$f" 2>/dev/null || true; done
for f in $R/CraftRoot/lib/libmlt-7_arm64-v8a.so $R/CraftRoot/lib/libmlt++-7_arm64-v8a.so; do $PE --set-rpath '$ORIGIN' "$f"; done
