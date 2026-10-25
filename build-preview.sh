#!/bin/zsh
# Isolated native interaction harness. No Applications install or production prefs.
set -eu
cd "${0:A:h}"
PREVIEW_FLAGS=(-D M8_UI_PREVIEW)
PREVIEW_ID=local.M8Studio.Preview
PREVIEW_NAME='M8 Studio Preview'
if [[ "${1:-}" == --canvas-hardware || "${1:-}" == --hardware ]]; then
    PREVIEW_FLAGS+=(-D M8_CANVAS_HARDWARE_TEST)
    PREVIEW_ID=local.M8Studio.CanvasTest
    PREVIEW_NAME='M8 Canvas Test'
fi
if [[ "${1:-}" == --hardware ]]; then
    PREVIEW_FLAGS+=(-D M8_SOUND_HARDWARE_TEST)
    PREVIEW_ID=local.M8Studio.HardwareTest
    PREVIEW_NAME='M8 Hardware Test'
fi
if [[ "${1:-}" == --widget ]]; then
    # Launch Services doesn't resolve our URL handler from the temp location.
    PREVIEW_PARENT="$HOME/Library/Application Support/M8Studio/Development"
    mkdir -p "$PREVIEW_PARENT"
    PREVIEW_ROOT=$(mktemp -d "$PREVIEW_PARENT/WidgetPreview.XXXXXX")
else
    PREVIEW_ROOT=$(mktemp -d "${TMPDIR%/}/M8Studio-preview.XXXXXX")
fi
PREVIEW_APP="$PREVIEW_ROOT/$PREVIEW_NAME.app"
mkdir -p "$PREVIEW_APP/Contents/MacOS" "$PREVIEW_APP/Contents/Resources"
DSP_OBJECT=$(mktemp -t M8IntegratedDSP)
xcrun clang -arch arm64 -mmacosx-version-min=14.2 -O3 -c Sound/DSP/M8DSP.c -o "$DSP_OBJECT"
xcrun swiftc "${PREVIEW_FLAGS[@]}" -target arm64-apple-macosx14.2 -swift-version 5 -O -parse-as-library -D M8_INTEGRATED_SOUND Source/*.swift Sound/TapKit/*.swift Sound/SoundLifecycle.swift Sound/SoundPreferences.swift Sound/SoundCore.swift "$DSP_OBJECT" -import-objc-header Sound/DSP/M8DSP.h -o "$PREVIEW_APP/Contents/MacOS/M8Studio" -framework SwiftUI -framework AppKit -framework CoreAudio -framework AudioToolbox -framework AVFoundation -framework Security -framework CryptoKit -framework ServiceManagement -framework Carbon -framework ApplicationServices -framework ColorSync -framework LocalAuthentication
rm -f "$DSP_OBJECT"
cp Sound/TapKit/LICENSE "$PREVIEW_APP/Contents/Resources/CoreAudioTapKit-LICENSE"
cp Sound/TapKit/PROVENANCE.md "$PREVIEW_APP/Contents/Resources/CoreAudioTapKit-PROVENANCE.md"
cp Info.plist "$PREVIEW_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $PREVIEW_ID" "$PREVIEW_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $PREVIEW_NAME" "$PREVIEW_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $PREVIEW_NAME" "$PREVIEW_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 m8studio-preview' "$PREVIEW_APP/Contents/Info.plist"
if [[ "${1:-}" == --canvas-hardware || "${1:-}" == --hardware ]]; then
    xcrun swiftc -target arm64-apple-macosx14.2 -O Helpers/ModeGuard.swift -o "$PREVIEW_APP/Contents/Resources/ModeGuard" -framework CoreGraphics
    codesign --force --sign - "$PREVIEW_APP/Contents/Resources/ModeGuard"
    xcrun clang -arch arm64 -mmacosx-version-min=14.2 -fobjc-arc -D M8_CANVAS_DIAGNOSTICS -O2 Tools/VirtualCanvas/VirtualCanvas.m -o "$PREVIEW_APP/Contents/Resources/VirtualCanvas" -framework Foundation -framework CoreGraphics -framework ColorSync
    cp Tools/VirtualCanvas/LICENSE "$PREVIEW_APP/Contents/Resources/VirtualCanvas-LICENSE"
    cp Tools/VirtualCanvas/PROVENANCE.md "$PREVIEW_APP/Contents/Resources/VirtualCanvas-PROVENANCE.md"
    codesign --force --sign - "$PREVIEW_APP/Contents/Resources/VirtualCanvas"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 m8studio-canvas-test' "$PREVIEW_APP/Contents/Info.plist"
fi
for PREVIEW_LANGUAGE in uk en; do cp -R "Resources/$PREVIEW_LANGUAGE.lproj" "$PREVIEW_APP/Contents/Resources/"; done
if [[ "${1:-}" == --widget ]]; then
    PREVIEW_WIDGET=$(zsh build-widget-preview.sh)
    mkdir -p "$PREVIEW_APP/Contents/PlugIns"
    ditto --noextattr --norsrc "$PREVIEW_WIDGET" "$PREVIEW_APP/Contents/PlugIns/M8StudioWidget.appex"
fi
codesign --force --sign - "$PREVIEW_APP"
codesign --verify --deep --strict "$PREVIEW_APP"
print -r -- "$PREVIEW_APP"
