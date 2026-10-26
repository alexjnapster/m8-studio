#!/bin/zsh
set -eu
cd "${0:A:h}/.."
ASSIST_TEST=$(mktemp -t M8DisplayAssistance)
trap 'rm -f "$ASSIST_TEST"' EXIT
xcrun swiftc -swift-version 5 Source/ModeFavorites.swift Source/DisplayAssistance.swift Tests/DisplayAssistance/main.swift -o "$ASSIST_TEST" -framework CoreGraphics -framework Combine
"$ASSIST_TEST"
