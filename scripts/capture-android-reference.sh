#!/usr/bin/env bash
set -euo pipefail
mkdir -p reference-output
adb shell getprop > reference-output/device-properties.txt
adb shell wm size 960x540
adb shell wm density 160
adb install input/*.apk
adb logcat -c
adb shell am start -n com.zalivka.animation2/ru.jecklandin.stickman.features.landing.LandingActivity
sleep 20
adb exec-out screencap -p > reference-output/launch.png
adb shell uiautomator dump /sdcard/ui.xml
adb pull /sdcard/ui.xml reference-output/launch.xml
adb logcat -d > reference-output/launch.log
adb shell dumpsys activity activities > reference-output/activities.txt

python3 scripts/walk-android-reference.py
