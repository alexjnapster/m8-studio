#!/bin/zsh
set -eu
cd "${0:A:h}/.."
TEST_BINARY=$(mktemp -t M8AudioBuffers)
trap 'rm -f "$TEST_BINARY"' EXIT
# Exercise the actual render-path helpers under Address Sanitizer, without HAL.
xcrun swiftc -swift-version 5 -sanitize=address Sound/TapKit/AudioBufferListUtilities.swift Tests/AudioBuffers/main.swift -o "$TEST_BINARY" -framework AudioToolbox
"$TEST_BINARY"
