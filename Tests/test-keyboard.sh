#!/bin/zsh
set -eu
cd "${0:A:h}/.."
TEST_BINARY=$(mktemp -t M8StudioKeyboard)
trap 'rm -f "$TEST_BINARY"' EXIT
xcrun swiftc -swift-version 5 Source/Keyboard.swift Source/Capabilities.swift Tests/Keyboard/main.swift -o "$TEST_BINARY" -framework Carbon -framework AppKit -framework ApplicationServices
"$TEST_BINARY"
