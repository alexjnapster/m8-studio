#!/bin/zsh
set -eu
cd "${0:A:h}/.."
MODEL_TEST_ROOT=$(mktemp -d "${TMPDIR%/}/M8SoundModelTest.XXXXXX")
trap 'rm -rf "$MODEL_TEST_ROOT"' EXIT
xcrun clang -arch arm64 -mmacosx-version-min=14.2 -O2 -c Sound/DSP/M8DSP.c -o "$MODEL_TEST_ROOT/dsp.o"
MODEL_SANITIZER_FLAGS=()
if [[ "${M8_MODEL_TSAN:-0}" == 1 ]]; then MODEL_SANITIZER_FLAGS=(-sanitize=thread); fi
xcrun swiftc "${MODEL_SANITIZER_FLAGS[@]}" -D M8_INTEGRATED_SOUND -target arm64-apple-macosx14.2 -swift-version 5 -import-objc-header Sound/DSP/M8DSP.h Source/Capabilities.swift Sound/TapKit/*.swift Sound/SoundPreferences.swift Sound/SoundLifecycle.swift Sound/SoundCore.swift Tests/SoundModel/main.swift "$MODEL_TEST_ROOT/dsp.o" -o "$MODEL_TEST_ROOT/check" -framework SwiftUI -framework AppKit -framework CoreAudio -framework AudioToolbox
"$MODEL_TEST_ROOT/check"
