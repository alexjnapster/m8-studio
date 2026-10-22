# 2.1.0 — 2026-10-22

- Recognize dedicated Apple brightness events and F14/F15, retain normal F1/F2 behavior, consume matching releases across output changes, and suppress repeated mute toggles.
- Show media access state and the last shortcut command in Ukrainian and English; prevent duplicate instances competing for shortcuts.
- Replace one-second idle polling with 30-second fallback checks, retaining one-second brightness follow and 15-second schedule checks. Observe Core Audio route/device changes with coalesced notifications. Back off remote volume polling when unused or unavailable.
- Recognize additional Samsung Smart Monitor SKU families, retaining capability readback gates. Stop following network-discovery identity responses to an alternate host.
- Preserve display-reported refresh-rate options on other monitors, remove M8-only naming/scaling copy, select a newly attached external display, and refresh profiles on automatic selection changes.
- Expose successfully probed DDC controls on other external monitors; validate readback and serialize writes for each control. Hide the known-unavailable DDC panel on the original M80B path.
- Remove an unavailable Samsung audio action when no Samsung output exists.
- Add portable policy fixtures and internal Carbon dispatch coverage. Prepare sanitized public source with third-party notices and compatibility limits.
