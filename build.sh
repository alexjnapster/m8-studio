#!/bin/zsh
set -eu
export MACOSX_DEPLOYMENT_TARGET=14.0
cd "${0:A:h}"
STAGING=$(mktemp -d "${TMPDIR%/}/M8Studio-build.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/M8 Studio.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
make -C ThirdParty clean
make -C ThirdParty CC="clang -arch arm64"
cp ThirdParty/m1ddc "$APP/Contents/Resources/m1ddc"
xcrun swiftc -target arm64-apple-macosx14.0 -O Helpers/ModeGuard.swift -o "$APP/Contents/Resources/ModeGuard" -framework CoreGraphics
cp ThirdParty/m1ddc-LICENSE.txt "$APP/Contents/Resources/"
cp 'User Guide.html' "$APP/Contents/Resources/"
xcrun swiftc -target arm64-apple-macosx14.0 -swift-version 5 -O -parse-as-library Source/*.swift -o "$APP/Contents/MacOS/M8Studio" -framework SwiftUI -framework AppKit -framework CoreAudio -framework AVFoundation -framework Security -framework CryptoKit -framework ServiceManagement -framework Carbon -framework ApplicationServices -framework ColorSync -framework LocalAuthentication
cp -R Resources/. "$APP/Contents/Resources/"
cp Info.plist "$APP/Contents/Info.plist"
if [[ -e AppIcon.icns ]]; then cp AppIcon.icns "$APP/Contents/Resources/"; fi
xattr -cr "$APP"
codesign --force --sign - "$APP/Contents/Resources/m1ddc"
codesign --force --sign - "$APP/Contents/Resources/ModeGuard"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
ditto --noextattr --norsrc "$APP" "$PWD/M8 Studio.app"
ditto -c -k --noextattr --norsrc --keepParent "$APP" "$PWD/../M8 Studio.zip"
echo "Built $PWD/M8 Studio.app and ../M8 Studio.zip"
