export W=$HOME/kdenlive-android
export ANDROID_NDK_ROOT=$W/sdk/ndk/27.2.12479018
export JAVA_HOME=$W/jdk ANDROID_SDK_ROOT=$W/sdk ANDROID_HOME=$W/sdk ANDROID_NDK=$W/sdk/ndk/27.2.12479018
export PATH=$W/bin:$JAVA_HOME/bin:$PATH
craft() { python3 $W/CraftRoot/craft-tmp/bin/craft.py "$@"; }
