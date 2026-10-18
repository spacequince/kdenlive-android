# What could go upstream, and what is a hack

## Kdenlive (`patches/0001-*.patch`, 24 files)
Reasonable to propose after cleanup:
- CMake: make KF6 NewStuff / Notifications-config / KFileMetaData / Purpose optional (`KDENLIVE_NO_*`); `Q_OS_ANDROID` guards.
- `MediaBrowser`/`ClipCreationDialog`/frame export without `KIOFileWidgets` (not available on Android).
- Splash screens: centre the card inside the window.
Android-specific files (`src/android/*`): `androidsetup` (assets -> files dir, MLT env, permissions, MediaStore publishing, lifecycle save), `androidrender` (in-process render, replaces `melt`/`kdenlive_render`), `androidui` (dialog borders, long press = right click, mouse logging).
Hacks that need a proper design first: default scale factor 0.5, forcing `openlastproject`, skipping the setup wizard, dummy `meltpath`, the autosave filter regex, `QT_QML_IMPORT_PATH` for KF6 QML, JNI Java classes outside Qt's packaging.

## MLT (`patches/extra/mlt-android-all.patch`, `consumer_aaudio.c`)
- frei0r: `libfrei0r_<name>.so` file naming and `FREI0R_PATH` on RELOCATABLE builds. Small, upstreamable.
- LADSPA host: `LADSPA_PATH` on RELOCATABLE builds + `libladspa_*` filter on Android. Small, upstreamable.
- `consumer_aaudio.c`: a new Android audio consumer (derived from `consumer_sdl2_audio.c`, LGPL). Upstreamable as a module, needs cleanup (device selection, latency, error handling, tests).
- glib shim: only to avoid building glib; MLT could drop its glib dependency in the LADSPA host instead.

## Craft blueprints (`patches/craft/blueprints.diff`, `*.ini`)
- FFmpeg: `--enable-libx264`, `--enable-jni --enable-mediacodec`, working `pkg-config` for cross builds.
- MLT: disable DeckLink/JACK/OpenFX on Android; kddockwidgets: do not include X11 headers on Android.
- Binary-cache libraries are built with NDK 30 (clang 22): the Android recipe set should pin the same NDK for the runtime `libc++_shared.so`.

## Not done / known problems
Helper-program jobs (transcode verified on the phone; proxies, stabilize, speed change, scene split and the OpenCV tracker run through the shipped `libmelt.so`/`libffmpeg.so` but were not exercised from the UI yet).
Touch and portrait (`ANDROID-TODO.md`), release signing + application id, Movit (needs desktop OpenGL), unregistered frei0r plugins `delay0r`/`delaygrab`/`bgsubtract0r`, gavl scopes, license review of bundled plugins (swh/TAP are GPL, MLT `plusgpl` and x264 are GPL: the APK as a whole is GPL).
