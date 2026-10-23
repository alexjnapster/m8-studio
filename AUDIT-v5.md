# M8 Studio v5 evidence audit

Updated 2026-10-22. **V5 is not complete and has not earned an objective 100/100 score.** The installed version is a 3.0.0 development increment. Automated checks establish specific behavior, not universal usability, acoustic quality or calibration accuracy.

| Category | Verified evidence | Remaining acceptance work |
| --- | --- | --- |
| Menu UX and layout | 12 native popover combinations pass: Ukrainian/English, light/dark, controls/empty/favorite scenes. Initial startup visibility race fixed. | Live long sessions, available-volume layouts, keyboard-only navigation and VoiceOver journey. |
| Desktop UX | Four native locale/theme layouts plus pin, desktop level, hide and reopen checks pass. Shares app model without extra polling. | Native WidgetKit gallery extension, multi-display relocation/position recovery in a real unplug/replug session. |
| UI and design | Native SwiftUI/AppKit controls, system appearance, accessible action labels, readable localized empty states. Inactive rendering/audio/profile badges made explicit. | Consistent focus treatment, reduced-motion journey and independent user feedback; no invented design score. |
| Initial setup | Detects displays/output routes; preserves existing profiles; model-aware modes and setup guidance. Volume-only connection no longer requires remote navigation pairing. | Fully guided new-Mac setup and signed-update permission identity recovery. Physical media-key confirmation is complete. |
| Native keyboard behavior | 75 decoding, ownership, Samsung routing/identity and refresh-label checks; seven real Carbon callbacks dispatched internally. Other audio routes pass native media keys through. | Permission repair succeeded after the stale-entry removal authorization. macOS reports one enabled suppressing event tap owned by the installed app. User physically confirmed monitor Volume Down/Up, monitor mute/unmute and native Mac-speaker volume after disconnecting. Longer sessions, reboot/wake and future signed-update behavior remain to test. |
| Recovery and reliability | 23 connected-display scene checks pass, including wrong-display undo, route notifications, guarded mode preview and exact mode restoration. | Sleep/reboot/dock matrix and longer real-world operation. |
| Image and scaling | 4K60 actual M80B, HiDPI/render-buffer explorer, fractional refresh preservation, timed preview, legacy scenes checked. | Instrument calibration, additional cables/HDMI and other model generations. No app can create physical panel resolution or backlight capability. |
| Color | Three actual library/isolation checks prove wrong-panel imports are hidden/rejected without a profile mutation; current-panel imports are offered. Original profiles recoverable. | Measured white point/luminance/gamma/Delta E and panel-specific calibration provenance. Vendor/EDID profiles are descriptions, not measurements of this individual unit. |
| Sound | Selected Samsung stereo 48 kHz route read from Core Audio; real network volume readback available again after correcting a stale address. User confirms monitor Atmos menu exists. | Bass + listening comparison accepted by the user as fuller and less harsh; 43 DSP checks and live stereo PCM flow pass. Measured acoustic calibration, long-session recovery, Atmos state/command and encoded playback remain unverified. No preset is labeled professionally calibrated. |
| Performance | Coalesced Core Audio changes, adaptive polling, shared desktop model. One current process sample was idle in the normal main run loop; physical footprint about 54 MB at that instant. | Repeatable energy, wakeup and long-session profiling; this sample is not a battery-life benchmark. |
| Privacy | Shareable diagnostics omit names, private addresses, tokens, persistent identities and profile paths. Private EDID/profile data stays local. | Continue checking every publication bundle. |
| Distribution | Public v5 foundation CI passed; both current main and sound development bundles build locally and archives verify. Prior working builds are retained. | Publish and verify the sound increment and its clean CI build, stable signing/notarization, and a finished v5 release. Published stable/beta release remains 2.1. |

## Fixes from this audit

1. Separate verified volume-service setup from WebSocket remote-navigation pairing.
2. Connect the saved monitor volume service when the Samsung output becomes active, with debounce/cooldown and no capture on other outputs.
3. Preserve the requested connection mode across sleep/wake.
4. Explicitly show 1× rendering, other sound output and unavailable profile states.
5. Restore desktop-card placement and recover an off-screen saved position.
6. Give volume increase/decrease icons accurate accessibility labels.
7. Test actual media-key tap creation instead of treating AX client status as a sufficient proxy. macOS continues to enforce permission; no TCC database or system protection is changed.

## Next work order

1. Preserve the now-working installed build. Physical standard monitor volume/mute keys and unplug fallback are user-confirmed PASS. Develop future changes in workspace; avoid replacing the trusted keyboard build until update identity/permission behavior is accounted for.
2. Validate volume-only connection and queue behavior with readback while preserving volume/mute.
3. Add live EDID/audio-format inspection and exact-model offline firmware guidance using official packages.
4. Add reversible, clearly unmeasured sound comparison recipes for the user's thin/harsh/no-bass complaint; compare Standard, flat EQ and monitor Atmos processing at matched level.
5. Complete onboarding, desktop/gallery interaction, accessibility, clean public source/release verification and the remaining v5 roadmap gates.

An automatic four-hour follow-up was enabled at the user's request. It must report meaningful evidence and unfinished work, not promote passing fixtures into a perfect-product claim.

## Native media-key acceptance completed

2026-10-22: after user approved the stale permission-entry removal, the existing installed M8 Studio process acquired one enabled CGEvent tap (options 0, mask 19456). Studio displayed “Media keys are active.” No additional re-add action was necessary after that approval. The user confirmed: (1) physical standard Volume Down followed by Volume Up decreased monitor volume and returned it, (2) physical mute toggled the monitor and restored it, and (3) after monitor disconnection, standard volume keys worked normally with native Mac speakers. Physical outcomes are user-observed; event-tap presence was independently read using CGGetEventTapList. The app has not been rebuilt or replaced after this acceptance.

This resolves the immediate native volume-key requirement on this setup. It is not proof of every keyboard, reboot/dock configuration or future ad-hoc update. Keep the working installed build intact while continuing v5 development.

## Sound module acceptance, 2026-10-23

See [Sound module evidence](Sound/README.md). Installed companion 0.1.0 executable
SHA256: `efad6a81af68febc3bc82d30dc6a178b7e73cfcdd44d15fe146d7a61a12a0d71`.
The user accepted Bass + as fuller and less harsh. Actual generated PCM reached
the 48 kHz M80B processing path; 43 numerical checks passed. Native UK/EN layouts,
preset updates and manual-band editing were inspected. A later check showed native
MacBook speakers selected, EQ off and Enable EQ disabled. Main app executable
remains `d5df99c03f8b267cd9ecff90dfe3eab8af6ae90a0a9459cc56f44d6422e87710`.

The companion is a development component, not a finished v5 release. It has no
measured speaker/room correction, encoded Atmos processing, oversampled true-peak
limiting or signed-update identity guarantee. Future main-app builds include an
entry point to the separately installed sound module; the trusted main app has
not been overwritten for that UI change.
