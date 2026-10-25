#!/bin/zsh
set -eu
cd "${0:A:h}/.."
TEST_BINARY=$(mktemp -t M8SoundLifecycle)
trap 'rm -f "$TEST_BINARY"' EXIT
xcrun swiftc -swift-version 5 Sound/SoundLifecycle.swift Tests/SoundLifecycle/main.swift -o "$TEST_BINARY"
"$TEST_BINARY"
