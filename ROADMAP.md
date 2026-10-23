# Goal: deliver M8 Studio v5 end to end

Updated 2026-10-22. User priority: **interface and menu-bar experience**. This roadmap is the active working goal; no perfection or physical compatibility claim is implied by a software release.

## Phase 1 — finish the v2 interface upgrade

- Deliver a polished compact menu with separate Controls and Scenes views, readable display summary, direct display/audio selection where available, selected brightness presets, useful empty states, keyboard setup access and clear mode recovery.
- Extend the native right-click menu with checked display and sound-output choices, preserving safe scene previews and reset.
- Keep Ukrainian complete and default, with equivalent English behavior, accessibility labels and light/dark appearance.
- Validate controls, empty scenes and populated scenes in both languages/themes; inspect native screenshots and actual menu interaction. Install the verified build while retaining the previous app.
- Publish reviewed source, verify the public macOS CI build, and provide a downloadable development release with checksums and accurate limitations.

## Phase 2 — deliver v3

- Improve hotkey troubleshooting so permission state, recognized media events, routing readiness and actual command delivery are distinguishable without recording typed text. Preserve normal Mac behavior for unrelated outputs.
- Make Samsung audio/display targeting explicit and durable. Recognize supported display audio routes carefully and avoid controlling the wrong monitor when several outputs exist.
- Improve connection lifecycle and idle behavior across screen sleep/wake, disconnect/reconnect and inactive output routes. Prefer notifications, coalescing and bounded retries to frequent polling.
- Make diagnostics safer to share by default; keep private addresses, MACs, display identities, pairing tokens and personal ICC data out of public reports and releases.
- Refine color/scaling/audio setup around actual device capabilities. Keep original ColorSync profiles recoverable. Do not advertise unsupported HDR, Dolby Atmos or unmeasured calibration quality.
- Audit interface, accessibility, keyboard, recovery, compatibility, performance, privacy and maintainability against concrete checks. Continue the substantive-improvement ledger with implementation/test evidence.
- Run appropriate policy, native UI and integration regressions, inspect the result, install v3 in Applications, preserve a recovery archive, publish sanitized source and a downloadable GitHub release, and verify release integrity.

## Completion gates

1. The implemented v2/v3 software scope builds from a clean public checkout and CI passes.
2. Policy and feasible native UI/integration checks pass; hardware-dependent tests are explicitly passed, failed or skipped with their reason.
3. Ukrainian and English controls render and behave correctly, including compact menu, scenes, recovery and settings.
4. Installed app and distributed archives are verified, source/release links resolve, and previous working builds are retained.
5. No unavailable capability, measured color/acoustic accuracy, battery improvement or perfect audit score is claimed without evidence.

## External verification still needed

The M80B is now connected again; the latest Core Audio check reports a selected Samsung DisplayPort route with two channels at 48 kHz and 3840 × 2160 at 60 Hz. Native media-key access is now verified by an enabled event tap, and the user physically confirmed standard monitor volume/mute keys plus native Mac-speaker fallback after disconnect. Final paired navigation, reboot/dock behavior, other Samsung hardware, HDMI HDR, instrument color calibration and acoustic measurements remain separate gates. Developer ID signing/notarization needs an available signing identity.

## Tracker limitation

The thread goal tracker retains an older unfinished usage-limited goal and rejects replacement objectives. That goal has not been falsely marked complete. This versioned roadmap records the user-authorized expanded scope while implementation continues.

## Image-quality expansion requested 2026-10-22

Research and implement the best supported scaling and image-quality setup for each connected Samsung M7/M8/M9 generation. Add meaningful HiDPI/render-size/refresh comparisons and safe previews, model-specific connection guidance (including PC input naming, USB-C bandwidth preference, HDMI Input Signal Plus and RGB/chroma checks), panel-scoped professional ICC imports and calibration provenance. Study shared community techniques against primary documentation. Keep experimental techniques opt-in and recoverable; separate unverified EDID/virtual-display/HDR experiments from working controls. Never substitute another panel's ICC or OLED settings for measured calibration of the actual display.

## v5 expansion — sound, desktop and portable Samsung features

User-requested target: v5. Earlier v2/v3 gates remain prerequisites, rather than being bypassed by a version-number change.

- Inspect official M9 monitor installer data and compare it with M8 capabilities. Publish reproducible findings; transfer only compatible behavior. Never flash M9 firmware or assign M9 OLED profiles to an M8.
- Add a native interactive desktop control card sharing the app’s live state, with brightness, capability-gated volume, scene preview and recovery. Preserve normal window use, provide hide/pin controls, avoid a second polling engine. Native WidgetKit gallery integration remains a separate milestone requiring extension packaging and actual registration testing.
- Build sound setup around verified output routing, channel checks, comfortable level, reversible listening comparisons and monitor-side settings. System-wide equalization needs an independently validated audio-processing path; do not expose decorative EQ sliders or promise Atmos from a stereo PCM route.
- Complete model-aware scaling/color guidance, safe mode previews, panel-scoped calibration imports, new-Mac setup and accessibility checks.
- Validate and install each stable increment; v5 is complete only when the declared scope, public build/release and feasible hardware checks meet the completion gates.

## Verified development increment, 2026-10-22

Implemented compact menu redesign, native desktop card, M80B HDMI identity fix, separate M9 identities, fractional-refresh scaling explorer, panel-scoped imports and sound/spatial setup guidance. Latest automated evidence: 75 policy checks; seven internally dispatched Carbon callbacks; 12 native menu layouts; eight desktop layout/lifecycle checks; 10 quality/profile/legacy scene checks; 23 connected-display scene/recovery checks. User confirms the M8 Atmos menu is present. Its enabled state, remotely writable command and actual Mac Atmos playback are unverified. The working build is 3.0.0 development; v5 has not been declared complete.

## Native key milestone verified

2026-10-22: standard volume up/down and mute work with the connected M8; after disconnect, native Mac-speaker volume keys work normally. User physically confirmed both tests. CGGetEventTapList independently confirmed an enabled tap owned by the unchanged installed build. Preserve that working build while continuing v5 in the workspace.

## Sound processing increment accepted, 2026-10-23

M8 Studio Sound 0.1.0 is installed separately in Applications. Four presets, eight
editable bands, a 50 Hz high-pass, automatic headroom, linked peak protection,
menu-bar actions, native bypass and route/sleep teardown are implemented. Numerical
DSP suite: 43 PASS. Live M80B 48 kHz stereo PCM processing was verified with a quiet
generated signal. The user reports Bass + sounds fuller and less harsh with
familiar music. Ukrainian and English interface, preset edits and persisted
manual values were inspected. This is subjective acceptance, not measured acoustic
calibration. The working main app and its native-key executable remain unchanged.
A subsequent native Mac-speaker route check showed EQ off and Enable disabled.

Next: publish the companion source/build evidence, test longer sessions and recovery
when the monitor is available, and complete onboarding/distribution/signing gates.
