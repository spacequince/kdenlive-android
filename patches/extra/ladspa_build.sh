#!/bin/bash
# Cross-compile LADSPA plugin collections for Android arm64 as libladspa_<name>.so
R=$HOME/kdenlive-android
CC=$R/sdk/ndk/30.0.14904198/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android28-clang
OUT=$R/build/ladspa-libs
mkdir -p $OUT
CF="-O3 -fPIC -DPIC -ffast-math -fomit-frame-pointer -I$R/CraftRoot/include -Wno-everything"
LF="-shared -Wl,-Bsymbolic -lm"
ok=0; fail=0
# TAP plugins (one .c per plugin)
cd $R/src/ladspa-src/tap
for f in tap_*.c; do
  n=${f%.c}
  if $CC $CF -I. $f -o $OUT/libladspa_$n.so $LF 2> $OUT/$n.err; then ok=$((ok+1)); rm -f $OUT/$n.err; else fail=$((fail+1)); echo "FAIL tap $n: $(head -2 $OUT/$n.err)"; fi
done
echo "tap: ok=$ok fail=$fail"
ls $OUT | grep -c "\.so$"
