#!/bin/zsh
# Separate identity/preferences and synthetic sessions; never installs/captures.
set -eu
cd "${0:A:h}"
PREVIEW_ROOT=$(mktemp -d "${TMPDIR%/}/M8Sound-preview.XXXXXX")
PREVIEW_APP="$PREVIEW_ROOT/M8 Studio Sound Preview.app"
mkdir -p "$PREVIEW_APP/Contents/MacOS" "$PREVIEW_APP/Contents/Resources"
xcrun clang -arch arm64 -mmacosx-version-min=14.2 -O2 -std=c11 -c Sound/DSP/M8DSP.c -o "$PREVIEW_ROOT/dsp.o"
xcrun swiftc -D M8_SOUND_PREVIEW -target arm64-apple-macosx14.2 -swift-version 5 -O -parse-as-library -import-objc-header Sound/DSP/M8DSP.h Source/Capabilities.swift Sound/TapKit/*.swift Sound/SoundLifecycle.swift Sound/SoundPreferences.swift Sound/SoundCore.swift Sound/SoundApp.swift "$PREVIEW_ROOT/dsp.o" -o "$PREVIEW_APP/Contents/MacOS/M8StudioSound" -framework SwiftUI -framework AppKit -framework CoreAudio -framework AudioToolbox
cp Sound/Info.plist "$PREVIEW_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier local.M8Studio.Sound.Preview' "$PREVIEW_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName M8 Studio Sound Preview' "$PREVIEW_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName M8 Studio Sound Preview' "$PREVIEW_APP/Contents/Info.plist"
codesign --force --sign - "$PREVIEW_APP"
codesign --verify --deep --strict "$PREVIEW_APP"
print -r -- "$PREVIEW_APP"
