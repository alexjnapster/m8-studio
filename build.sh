#!/bin/zsh
set -eu
export MACOSX_DEPLOYMENT_TARGET=14.2
cd "${0:A:h}"
STAGING=$(mktemp -d "${TMPDIR%/}/M8Studio-build.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/M8 Studio.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
make -C ThirdParty clean
make -C ThirdParty CC="clang -arch arm64"
cp ThirdParty/m1ddc "$APP/Contents/Resources/m1ddc"
xcrun swiftc -target arm64-apple-macosx14.2 -O Helpers/ModeGuard.swift -o "$APP/Contents/Resources/ModeGuard" -framework CoreGraphics
xcrun clang -arch arm64 -mmacosx-version-min=14.2 -fobjc-arc -O2 Tools/VirtualCanvas/VirtualCanvas.m -o "$APP/Contents/Resources/VirtualCanvas" -framework Foundation -framework CoreGraphics -framework ColorSync
cp Tools/VirtualCanvas/LICENSE "$APP/Contents/Resources/VirtualCanvas-LICENSE"
cp Tools/VirtualCanvas/PROVENANCE.md "$APP/Contents/Resources/VirtualCanvas-PROVENANCE.md"
cp ThirdParty/m1ddc-LICENSE.txt "$APP/Contents/Resources/"
cp 'User Guide.html' "$APP/Contents/Resources/"
DSP_OBJECT=$(mktemp -t M8IntegratedDSP)
xcrun clang -arch arm64 -mmacosx-version-min=14.2 -O3 -c Sound/DSP/M8DSP.c -o "$DSP_OBJECT"
xcrun swiftc -target arm64-apple-macosx14.2 -swift-version 5 -O -parse-as-library -D M8_INTEGRATED_SOUND Source/*.swift Sound/TapKit/*.swift Sound/SoundLifecycle.swift Sound/SoundPreferences.swift Sound/SoundCore.swift "$DSP_OBJECT" -import-objc-header Sound/DSP/M8DSP.h -o "$APP/Contents/MacOS/M8Studio" -framework SwiftUI -framework AppKit -framework CoreAudio -framework AudioToolbox -framework AVFoundation -framework Security -framework CryptoKit -framework ServiceManagement -framework Carbon -framework ApplicationServices -framework ColorSync -framework LocalAuthentication
rm -f "$DSP_OBJECT"
cp Sound/TapKit/LICENSE "$APP/Contents/Resources/CoreAudioTapKit-LICENSE"
cp Sound/TapKit/PROVENANCE.md "$APP/Contents/Resources/CoreAudioTapKit-PROVENANCE.md"
cp -R Resources/. "$APP/Contents/Resources/"
cp Info.plist "$APP/Contents/Info.plist"
if [[ -e AppIcon.icns ]]; then cp AppIcon.icns "$APP/Contents/Resources/"; fi
WIDGET_SOURCE=$(zsh build-widget-preview.sh --production)
mkdir -p "$APP/Contents/PlugIns"
ditto --noextattr --norsrc "$WIDGET_SOURCE" "$APP/Contents/PlugIns/M8StudioWidget.appex"
xattr -cr "$APP"
codesign --force --sign - "$APP/Contents/Resources/m1ddc"
codesign --force --sign - "$APP/Contents/Resources/ModeGuard"
codesign --force --sign - "$APP/Contents/Resources/VirtualCanvas"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
ditto --noextattr --norsrc "$APP" "$PWD/M8 Studio.app"
ditto -c -k --noextattr --norsrc --keepParent "$APP" "$PWD/../M8 Studio.zip"
echo "Built $PWD/M8 Studio.app and ../M8 Studio.zip"
