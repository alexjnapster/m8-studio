## Sound companion development, 2026-10-23

- Add local stereo PCM processing with Warmth, Bass +, Clear voices and Flat EQ.
- Add eight editable bands, automatic preamp headroom, sub-bass protection, linked
  peak limiting and native bypass; stop processing on route change, sleep or quit.
- Add Ukrainian/English sound UI and menu-bar actions; preserve main media-key build.
- Verify 43 DSP checks and live M80B audio flow. User accepts Bass + as fuller and
  less harsh. No measured acoustic calibration or Atmos rendering is claimed.

# 3.0.0 development — foundation for the v5 goal, 2026-10-22

- Redesign the menu with Controls/Scenes pages, direct output/display choices, readable empty states and native right-click actions.
- Add a live desktop control card with hide/reopen, saved placement, desktop/floating levels, brightness, gated volume and mode recovery. This is an app-owned panel; native WidgetKit gallery support remains planned.
- Inspect official M9/M80B driver payloads. Recognize both original M80B HDMI and USB-C identities and keep M9 variants separate.
- Add a HiDPI scaling explorer showing logical/render dimensions. Preserve fractional refresh rates and legacy scene compatibility.
- Bind imported ICC profiles to their selected panel and reject cross-panel application without mutating ColorSync.
- Add sound-comparison guidance and an immersive-playback assistant. Record user-confirmed availability of a monitor Atmos menu separately from its unknown enabled state and Mac playback path.
- Improve monitor-audio binding, media-key diagnostics, event-tap recovery, sleep/wake cancellation and shareable diagnostic privacy.
- Validate 75 portable policies, native Carbon dispatch, 12 quick-menu layouts, 8 desktop layout/lifecycle checks, 10 quality/profile/scene-format checks and 23 connected-display scene/recovery checks. Physical media-key delivery and Atmos playback remain separate verification gates.

# 2.1.0 — 2026-10-22

- Recognize dedicated Apple brightness events and F14/F15, retain normal F1/F2 behavior, consume matching releases across output changes, and suppress repeated mute toggles.
- Show media access state and the last shortcut command in Ukrainian and English; prevent duplicate instances competing for shortcuts.
- Replace one-second idle polling with 30-second fallback checks, retaining one-second brightness follow and 15-second schedule checks. Observe Core Audio route/device changes with coalesced notifications. Back off remote volume polling when unused or unavailable.
- Recognize additional Samsung Smart Monitor SKU families, retaining capability readback gates. Stop following network-discovery identity responses to an alternate host.
- Preserve display-reported refresh-rate options on other monitors, remove M8-only naming/scaling copy, select a newly attached external display, and refresh profiles on automatic selection changes.
- Expose successfully probed DDC controls on other external monitors; validate readback and serialize writes for each control. Hide the known-unavailable DDC panel on the original M80B path.
- Remove an unavailable Samsung audio action when no Samsung output exists.
- Add portable policy fixtures and internal Carbon dispatch coverage. Prepare sanitized public source with third-party notices and compatibility limits.
