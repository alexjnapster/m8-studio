#!/bin/zsh
set -eu
cd "${0:A:h}/.."
FAVORITES_TEST=$(mktemp -t M8ModeFavorites)
trap 'rm -f "$FAVORITES_TEST"' EXIT
xcrun swiftc Source/ModeFavorites.swift Tests/ModeFavorites/main.swift -o "$FAVORITES_TEST" -framework CoreGraphics
"$FAVORITES_TEST"
