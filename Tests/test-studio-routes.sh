#!/bin/zsh
set -eu
cd "${0:A:h}/.."
TEST_BINARY=$(mktemp -t M8StudioRoutes)
trap 'rm -f "$TEST_BINARY"' EXIT
for ROUTE_MODE in production preview; do
    ROUTE_FLAGS=()
    if [[ "$ROUTE_MODE" == preview ]]; then ROUTE_FLAGS=(-D M8_UI_PREVIEW); fi
    xcrun swiftc -swift-version 5 "${ROUTE_FLAGS[@]}" Source/StudioRoute.swift Tests/StudioRoutes/main.swift -o "$TEST_BINARY"
    "$TEST_BINARY"
done
