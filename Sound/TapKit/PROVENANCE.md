CoreAudioTapKit, MIT, copyright Cole Stanfield (2026).
Upstream: https://github.com/CJStanfield/CoreAudioTapKit
Pinned commit: aab395f1e8e5dd1bd369c3bbfcf5c6bdca85e099
See LICENSE for the complete license.

M8 Studio modifications: app-specific identity; mutedWhenTapped for native playback
when the IOProc is stopped; reject unsupported tap/output formats and missing tap
streams; atomic render gate; fail aggregate-alive timeout; hide device UIDs in logs. No upstream demo
assets or dependencies included.

The M8 DSP is original code using the published RBJ coefficient equations:
https://www.w3.org/TR/audio-eq-cookbook/
