#!/bin/zsh
# Build only; no installation, launch or PlugInKit registration.
set -eu
cd "${0:A:h}"
WIDGET_FLAGS=(-D M8_WIDGET_PREVIEW)
WIDGET_ID=local.M8Studio.Preview.Widget
WIDGET_NAME='M8 Studio Widget Preview'
if [[ "${1:-}" == --production ]]; then
    WIDGET_FLAGS=()
    WIDGET_ID=local.M8Studio.Widget
    WIDGET_NAME='M8 Studio Widget'
elif [[ -n "${1:-}" ]]; then
    print -u2 'Expected no argument or --production'; exit 2
fi
WIDGET_ROOT=$(mktemp -d "${TMPDIR%/}/M8Widget-build.XXXXXX")
WIDGET_APP="$WIDGET_ROOT/M8StudioWidget.appex"
mkdir -p "$WIDGET_APP/Contents/MacOS"
xcrun swiftc "${WIDGET_FLAGS[@]}" -application-extension -target arm64-apple-macosx14.2 -swift-version 5 -O -parse-as-library Source/StudioRoute.swift Widget/StudioWidget.swift -o "$WIDGET_APP/Contents/MacOS/M8StudioWidget" -framework SwiftUI -framework WidgetKit
cp Widget/Info.plist "$WIDGET_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $WIDGET_ID" "$WIDGET_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $WIDGET_NAME" "$WIDGET_APP/Contents/Info.plist"
# The extension follows its host's release version rather than a stale preview number.
for WIDGET_VERSION_KEY in CFBundleShortVersionString CFBundleVersion LSMinimumSystemVersion; do
    WIDGET_VERSION_VALUE=$(/usr/libexec/PlistBuddy -c "Print :$WIDGET_VERSION_KEY" Info.plist)
    /usr/libexec/PlistBuddy -c "Set :$WIDGET_VERSION_KEY $WIDGET_VERSION_VALUE" "$WIDGET_APP/Contents/Info.plist"
done
codesign --force --sign - --entitlements Widget/Entitlements.plist "$WIDGET_APP"
codesign --verify --deep --strict "$WIDGET_APP"
print -r -- "$WIDGET_APP"
