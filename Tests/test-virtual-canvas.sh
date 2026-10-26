#!/bin/zsh
set -eu
cd "${0:A:h}/.."
CANVAS_ROOT=$(mktemp -d "${TMPDIR%/}/M8CanvasTest.XXXXXX")
trap 'rm -rf "$CANVAS_ROOT"' EXIT
xcrun swiftc Source/VirtualCanvasPlan.swift Tests/VirtualCanvas/main.swift -o "$CANVAS_ROOT/policy"
"$CANVAS_ROOT/policy"
xcrun clang -arch arm64 -mmacosx-version-min=14.2 -fobjc-arc -O2 Tools/VirtualCanvas/VirtualCanvas.m -o "$CANVAS_ROOT/host" -framework Foundation -framework CoreGraphics -framework ColorSync
"$CANVAS_ROOT/host" --self-test
# Argument rejections must finish before any virtual-display creation.
for CANVAS_BAD_WIDTH in 0 -16 1279 1921 3073; do
    if "$CANVAS_ROOT/host" 1 invalid-uuid "$CANVAS_BAD_WIDTH" 1; then
        print "FAIL invalid helper request accepted"; exit 1
    fi
done
print 'PASS malformed helper requests fail closed; no display created'

for CANVAS_BAD_WIDTH in 0 1921 3073; do
    if "$CANVAS_ROOT/host" --configure 1 invalid-uuid 9 "$CANVAS_BAD_WIDTH" 1 3840 2160 3840 2160 60000; then
        print 'FAIL invalid configurator request accepted'; exit 1
    fi
done
print 'PASS malformed configurator requests fail closed; no display changes'
