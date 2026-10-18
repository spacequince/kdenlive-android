#!/bin/bash
# Binary-patch Qt 6.11.2's Android platform plugin so a failed AndroidDeadlockProtector in
# QAndroidPlatformOpenGLWindow::eglSurface() skips the frame (returns EGL_NO_SURFACE, retried on the
# next flush) instead of qFatal()ing. Re-run after any Craft reinstall of qtbase, then build/rebuild.sh.
# Offsets are for the 6.11.2 arm64 build (verified: tbz at 0xa1318 -> fatal branch 0xa1408).
python3 -I - <<'P'
import struct
import os
p=os.path.expanduser("~/kdenlive-android/CraftRoot/plugins/platforms/libplugins_platforms_qtforandroid_arm64-v8a.so")
d=bytearray(open(p,'rb').read()); a=0xa1318
w=struct.unpack_from('<I',d,a)[0]
if a+((w>>5)&0x3fff)*4==0xdeadbeef: pass
if (w&0x7e00001f)!=0x36000000: raise SystemExit('already patched or different build')
assert a+((w>>5)&0x3fff)*4==0xa1408
struct.pack_into('<I',d,a,(w&~(0x3fff<<5))|(((0xa1368-a)//4)<<5)); open(p,'wb').write(d); print('patched')
P
