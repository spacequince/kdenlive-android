# Building Kdenlive for Android (arm64) — everything in this directory

Target: Pixel-class phones (Android 9+, tested on Pixel 9 Pro / Android 17), landscape, mouse + keyboard first.
Result: `out/kdenlive-debug.apk` (about 80 MB, arm64-v8a only, debug-signed).

## 0. What is where

| Path | Content |
|---|---|
| `src/kdenlive` | Kdenlive checkout (commit `d10b2cc`) — apply `patches/0001-*.patch` (24 files; adds `src/android/*`) |
| `src/kio` | KIO checkout at tag `v6.31.0` (only used to build the `kio_file` plugin) |
| `src/ladspa-src/{swh,tap}` | LADSPA plugin sources (github swh/ladspa, LMMS/tap-plugins) |
| `CraftRoot` | Craft prefix (Qt 6.11.2, KF6 6.31.0, FFmpeg 8.1.1 + x264 + MediaCodec, MLT 7.x, ...) |
| `sdk`, `jdk` | Android SDK (platforms 35 + 36, build-tools 35/36), NDK 27.2 (build) + NDK 30 (libc++_shared), Temurin JDK 17 |
| `patches/` | all source changes, see below |
| `build/` | scripts and logs (`*.sh`, `*.py`), staging dirs (`android-pkg`, `android-libs`, `ladspa-libs`) |
| `docs/` | this file |

Always run Craft/ninja through the bash scripts (they `source craftenv.sh`); in zsh the NDK variables get lost.

## 1. Host prerequisites (Fedora 44; installed with sudo once)
- `qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtshadertools-devel qt6-qtsvg-devel qt6-qttools-devel` **6.11.2** (exactly Craft's Qt version: host tools for the cross build)
- `kf6-kconfig-devel kf6-kcoreaddons-devel kf6-ki18n-devel` **6.31.0**
- `perl-XML-Parser` (generates the swh LADSPA plugin sources), `p7zip` (Craft needs a `7za`: symlinked in `bin/`)
- Not needed on the host but used: `ffmpeg` (test footage, icon scaling), `python3`, `zip`.
- Patchelf comes from a venv: `python3 -m venv build/venv && build/venv/bin/pip install patchelf`.

## 2. One-time toolchain / dependency stages (hours; results are cached in `CraftRoot`)
1. SDK/NDK/JDK: cmdline-tools, `platforms;android-35`, `platforms;android-36`, `build-tools;35.0.0`, `build-tools;36.0.0`, `ndk;27.2.12479018`, `ndk;30.0.14904198`. JDK 17 (system Java 25 is too new).
2. Craft: `craft --add-blueprint-repository`, copy `patches/craft/{BlueprintSettings,CraftSettings}.ini` to `CraftRoot/etc/`, apply `patches/craft/blueprints.diff` to `CraftRoot/etc/blueprints/locations/craft-blueprints-kde` (MLT modules off, kddockwidgets X11 fix, FFmpeg with x264/JNI/MediaCodec and a working pkg-config).
   `Jobs = 3` (autotools packages need `Jobs = 1`: `build/ffmpeg_x264.sh` and friends toggle it).
3. `build/deps.sh` (Qt modules, KF6, kddockwidgets, FFmpeg, MLT; several packages come from Craft's binary cache). Then:
   - `build/ffmpeg_x264.sh`, `build/ffmpeg_only.sh` — FFmpeg with libx264 + `--enable-jni --enable-mediacodec` (the cache build has neither)
   - `build/fftwf_build.sh` — single-precision FFTW (swh LADSPA pitch/EQ plugins)
   - `build/frei0r_more_build.sh` — bigsh0t (360 degree effects); gavl is skipped on purpose
   - `build/opencv_build.sh` — OpenCV 4.12 + contrib (for the MLT motion tracker), optional. OpenCV's `dnn` module runs `protoc` while building, and the Android-built one cannot run on the PC: first build a host `protoc` of the same version (`cmake -S CraftRoot/build/libs/protobuf/work/protobuf-33.0 -B build/protoc_host -G Ninja -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_ABSL_PROVIDER=package && ninja -C build/protoc_host protoc`); `BlueprintSettings.ini` passes it as `Protobuf_PROTOC_EXECUTABLE` and disables the Android sample/Java targets.
   - `build/mlt_opencv_build.sh` — MLT `mltopencv` module (`MOD_OPENCV=ON`, `OpenCV_DIR=CraftRoot/sdk/native/jni`)
4. `build/kio_file_build.sh` — the KIO `file` worker (upstream KIO has no workers on Android).
5. MLT extras (all patch the Craft MLT source in `CraftRoot/download/git/libs/mlt`: `git apply patches/extra/mlt-android-all.patch`):
   - `build/mlt_frei0r_build.sh` — frei0r module with `libfrei0r_<name>.so` naming and `FREI0R_PATH`
   - `build/mlt_ladspa_build.sh` — LADSPA host (uses the glib shim in `build/glibshim`, see `patches/extra/glib.h`)
   - `build/mlt_aaudio_build.sh` — own AAudio consumer (`patches/extra/consumer_aaudio.c`, also registered as `sdl2_audio`)
6. LADSPA plugins: `build/ladspa_build.sh` (TAP) and `build/ladspa_swh_build.py` (swh: run `perl makestub.pl X.xml > gen/X.c` for every `*.xml` in `src/ladspa-src/swh` first, create `config.h`, see the script header).

## 3. Everyday build (minutes) — `build/rebuild.sh`
```
build/prep_assets.sh      # MLT data, Kdenlive data, icons (breeze-dark .rcc), manifest, Java service, frei0r + LADSPA plugins as JNI libs
build/prep_libs.sh        # extra native libs + dependency closure, soname fixes (patchelf)
build/kd_configure.sh     # cmake (only needed after CMake changes or new libs)
build/kd_apk.sh           # ninja apk (Gradle)
build/sign_install.sh     # swap in NDK30 libc++_shared, zipalign, sign with keys/debug.keystore, adb install, launch
```
`build/kd_stage.sh` (an install to a staging dir) must have been run once so `prep_assets.sh` finds Kdenlive's data files.

## 4. Why things are the way they are (non-obvious)
- **libc++:** Craft's cached KDE/Qt libs were built with clang 22 (NDK 30) and need `std::__ndk1::__hash_memory`; NDK 27/29's `libc++_shared.so` lack it. `sign_install.sh` replaces it with NDK 30's.
- **Android only loads `lib*.so`:** hence the `libfrei0r_*`, `libladspa_*`, `libmlt*` names, unversioned `libx264.so`, `libcairo.so`... (`prep_libs.sh` renames and `patchelf --replace-needed`).
- **Plugins are plain JNI libs** (`android-pkg/libs/arm64-v8a`), not Qt "bundled libs" (those are all dlopen'ed at start).
- **MLT is RELOCATABLE** and ignores `MLT_REPOSITORY`/`FREI0R_PATH`/`LADSPA_PATH` unless patched; the app passes the native lib dir explicitly (`androidPrepareData`, `mltconnection.cpp`).
- **Helper programs (`melt`, `ffmpeg`, `ffprobe`)** are shipped as executables named `libmelt.so`, `libffmpeg.so`, `libffprobe.so` in the native library directory (the only place Android lets an app execute files from) and Kdenlive's settings (`meltpath`, `ffmpegpath`, `ffprobepath`) point at them (`main.cpp`). This makes every job that spawns them work (transcode verified; proxy, stabilize, speed change, scene split, tracker use `melt`). Needed to make that work:
  - `RUNPATH=$ORIGIN` on every shipped library (the linker does not search the app's lib dir for processes the app starts),
  - libraries whose soname equals a system library's are renamed `lib<n>_kd.so` (`liblzma`, `libcrypto`, `libssl`; otherwise the system's `libunwindstack`/our `libavformat` pick the wrong copy),
  - MLT's repository scan is patched to only try `libmlt*.so` (the lib dir also holds Qt, FFmpeg...), `MLT_REPOSITORY` is honoured by `mlt_factory_init` on Android,
  - FFmpeg is built with `--enable-ffmpeg --enable-ffprobe`.
  Final rendering still runs in-process (`android/androidrender.cpp`) because it needs Android services (MediaStore publishing, foreground service).
- **Android makes every top-level window full screen** (splash centring is done inside the window).
- **Qt for Android drops mouse buttons for dialog windows:** `KdenliveActivity.java` turns mouse into touch while a `QDialog` is visible.
- `/tmp` is a small tmpfs: all scratch files go under `build/`.

## 5. Testing helpers
- `build/mouse/vmouse.py`, `session.py` — drive a real virtual mouse on the phone (adb `uinput`), see the header of `vmouse.py`.
- `selftest.txt` / `mouselog.txt` marker files in `/sdcard/Android/data/org.qtproject.example.kdenlive/files/` enable developer self tests and mouse logging (delete them afterwards).
- Test footage: `/sdcard/Movies/KdTest/` (generated with ffmpeg, see `docs/test-footage.md`).

## 6. Known gaps
See `src/kdenlive/ANDROID-TODO.md` (touch, portrait) and `docs/UPSTREAMING.md`.
