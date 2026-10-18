#!/bin/bash
# Build a trimmed Breeze icon theme (sizes 16/22/24/32) as a Qt resource file for the Android assets
R=$HOME/kdenlive-android
SRC=/usr/share/icons/breeze-dark
ST=$R/build/icons_stage
OUT=$R/build/android-pkg/assets/icons
rm -rf $ST; mkdir -p $ST/breeze-dark $OUT
cp -L $SRC/index.theme $ST/breeze-dark/
python3 - <<'PY'
import os, re, shutil
src='/usr/share/icons/breeze-dark'; dst=os.path.expanduser('~/kdenlive-android/build/icons_stage/breeze-dark')
sizes={'16','22'}
n=0
for cat in sorted(os.listdir(src)):
    cp=os.path.join(src,cat)
    if not os.path.isdir(cp): continue
    for sz in os.listdir(cp):
        sp=os.path.join(cp,sz)
        if sz in sizes and os.path.isdir(sp):
            for root,dirs,files in os.walk(sp, followlinks=True):
                for f in files:
                    s=os.path.join(root,f)
                    if not os.path.exists(s): continue   # dangling symlink
                    rel=os.path.relpath(s, src)
                    d=os.path.join(dst, rel)
                    os.makedirs(os.path.dirname(d), exist_ok=True)
                    shutil.copy(os.path.realpath(s), d); n+=1
print('copied', n, 'icons')
# qrc
lines=['<RCC><qresource prefix="/icons">']
for root,dirs,files in os.walk(os.path.expanduser('~/kdenlive-android/build/icons_stage')):
    for f in files:
        p=os.path.join(root,f); rel=os.path.relpath(p, os.path.expanduser('~/kdenlive-android/build/icons_stage'))
        lines.append(f'<file alias="{rel}">{p}</file>')
lines.append('</qresource></RCC>')
open(os.path.expanduser('~/kdenlive-android/build/icons_stage/icons.qrc'),'w').write('\n'.join(lines))
PY
du -sh $ST
/usr/lib64/qt6/libexec/rcc --binary -o $OUT/breeze-icons.rcc $ST/icons.qrc && ls -la $OUT/breeze-icons.rcc
