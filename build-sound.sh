#!/bin/zsh
set -eu
cd "${0:A:h}"
STAGING=$(mktemp -d "${TMPDIR%/}/M8Sound-build.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/M8 Studio Sound.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun clang -arch arm64 -mmacosx-version-min=14.2 -O2 -std=c11 -c Sound/DSP/M8DSP.c -o "$STAGING/dsp.o"
xcrun swiftc -target arm64-apple-macosx14.2 -swift-version 5 -O -parse-as-library -import-objc-header Sound/DSP/M8DSP.h Source/Capabilities.swift Sound/TapKit/*.swift Sound/SoundLifecycle.swift Sound/SoundPreferences.swift Sound/SoundCore.swift Sound/SoundApp.swift "$STAGING/dsp.o" -o "$APP/Contents/MacOS/M8StudioSound" -framework SwiftUI -framework AppKit -framework CoreAudio -framework AudioToolbox
cp Sound/Info.plist "$APP/Contents/Info.plist"
cp Sound/TapKit/LICENSE "$APP/Contents/Resources/CoreAudioTapKit-LICENSE"
cp Sound/TapKit/PROVENANCE.md "$APP/Contents/Resources/"
if [[ -e AppIcon.icns ]]; then cp AppIcon.icns "$APP/Contents/Resources/"; /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$APP/Contents/Info.plist"; fi
xattr -cr "$APP"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
ditto --noextattr --norsrc "$APP" "$PWD/M8 Studio Sound.app"
# Synced workspaces can attach Finder metadata again after this cleanup.
xattr -cr "$PWD/M8 Studio Sound.app"
if ! codesign --verify --deep --strict "$PWD/M8 Studio Sound.app"; then
    print -u2 'Workspace copy failed signature verification; use the verified distribution ZIP.'
fi
ditto -c -k --noextattr --norsrc --keepParent "$APP" "$PWD/../M8 Studio Sound.zip"
mkdir -p "$STAGING/archive-check"
ditto -x -k "$PWD/../M8 Studio Sound.zip" "$STAGING/archive-check"
codesign --verify --deep --strict "$STAGING/archive-check/M8 Studio Sound.app"
echo 'Built M8 Studio Sound (main app unchanged)'
