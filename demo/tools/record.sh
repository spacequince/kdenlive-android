#!/bin/bash
# Record the phone screen and convert it for a GitHub README.
# usage: record.sh <name> <seconds>      (run your demo actions while it records, e.g. from another terminal)
# output: demo-out/<name>.mp4 (cropped to the app, h264) and demo-out/<name>.gif (README-friendly, <= 8 MB target)
set -e
A=$HOME/kdenlive-android/sdk/platform-tools/adb
OUT=$HOME/kdenlive-android/demo-src/demo-out; mkdir -p $OUT
N=${1:?name}; T=${2:-8}
REMOTE=/sdcard/Movies/kdemo_$N.mp4
# screenrecord has a 180 s limit; size matches the landscape screen
$A shell screenrecord --time-limit $T --bit-rate 12000000 $REMOTE
$A pull $REMOTE $OUT/raw_$N.mp4 >/dev/null; $A shell rm -f $REMOTE
# crop away the Android status bar (top 30 px) and the black side bars; app area measured on the Pixel 9 Pro: app area x=108..1988, y=58..958 (below the status bar)
ffmpeg -loglevel error -y -i $OUT/raw_$N.mp4 -vf "crop=1880:900:108:58,fps=30" -c:v libopenh264 -b:v 6M -pix_fmt yuv420p -an $OUT/$N.mp4
# two-pass palette GIF: 960 px wide, 15 fps
ffmpeg -loglevel error -y -i $OUT/$N.mp4 -vf "fps=15,scale=960:-1:flags=lanczos,palettegen=max_colors=128:stats_mode=diff" $OUT/pal_$N.png
ffmpeg -loglevel error -y -i $OUT/$N.mp4 -i $OUT/pal_$N.png -lavfi "fps=15,scale=960:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=4" $OUT/$N.gif
rm -f $OUT/pal_$N.png
ls -la $OUT/$N.mp4 $OUT/$N.gif | awk '{print $5, $9}'
