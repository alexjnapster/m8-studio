# M8 Studio v5 evidence audit

Updated 2026-10-22. **V5 is not complete and has not earned an objective 100/100 score.** The installed version is a 3.0.0 development increment. Automated checks establish specific behavior, not universal usability, acoustic quality or calibration accuracy.

| Category | Verified evidence | Remaining acceptance work |
| --- | --- | --- |
| Menu UX and layout | 12 native popover combinations pass: Ukrainian/English, light/dark, controls/empty/favorite scenes. Initial startup visibility race fixed. | Live long sessions, available-volume layouts, keyboard-only navigation and VoiceOver journey. |
| Desktop UX | Four native locale/theme layouts plus pin, desktop level, hide and reopen checks pass. Shares app model without extra polling. | Native WidgetKit gallery extension, multi-display relocation/position recovery in a real unplug/replug session. |
| UI and design | Native SwiftUI/AppKit controls, system appearance, accessible action labels, readable localized empty states. Inactive rendering/audio/profile badges made explicit. | Consistent focus treatment, reduced-motion journey and independent user feedback; no invented design score. |
| Initial setup | Detects displays/output routes; preserves existing profiles; model-aware modes and setup guidance. Volume-only connection no longer requires remote navigation pairing. | Fully guided new-Mac setup, explicit permission identity recovery, physical media-key confirmation. |
| Native keyboard behavior | 75 decoding, ownership, Samsung routing/identity and refresh-label checks; seven real Carbon callbacks dispatched internally. Other audio routes pass native media keys through. | macOS permission is currently inconsistent with its enabled UI toggle. Exact installed build has no active event tap yet. Standard physical volume/mute keys and unplug fallback must pass before certification. |
| Recovery and reliability | 23 connected-display scene checks pass, including wrong-display undo, route notifications, guarded mode preview and exact mode restoration. | Sleep/reboot/dock matrix and longer real-world operation. |
| Image and scaling | 4K60 actual M80B, HiDPI/render-buffer explorer, fractional refresh preservation, timed preview, legacy scenes checked. | Instrument calibration, additional cables/HDMI and other model generations. No app can create physical panel resolution or backlight capability. |
| Color | Three actual library/isolation checks prove wrong-panel imports are hidden/rejected without a profile mutation; current-panel imports are offered. Original profiles recoverable. | Measured white point/luminance/gamma/Delta E and panel-specific calibration provenance. Vendor/EDID profiles are descriptions, not measurements of this individual unit. |
| Sound | Selected Samsung stereo 48 kHz route read from Core Audio; real network volume readback available again after correcting a stale address. User confirms monitor Atmos menu exists. | Thin/harsh sound listening comparison, measured EQ, Atmos on/off state and command, actual encoded playback. No preset is labeled professionally calibrated. |
| Performance | Coalesced Core Audio changes, adaptive polling, shared desktop model. One current process sample was idle in the normal main run loop; physical footprint about 54 MB at that instant. | Repeatable energy, wakeup and long-session profiling; this sample is not a battery-life benchmark. |
| Privacy | Shareable diagnostics omit names, private addresses, tokens, persistent identities and profile paths. Private EDID/profile data stays local. | Continue checking every publication bundle. |
| Distribution | Public 2.1 beta source/build CI runs 2 and 3 succeeded; development app builds/signature verification pass locally and prior app archived. | Publish current development source atomically, clean public build verification, stable signing/notarization. Latest working source is ahead of public 2.1 beta. |

## Fixes from this audit

1. Separate verified volume-service setup from WebSocket remote-navigation pairing.
2. Connect the saved monitor volume service when the Samsung output becomes active, with debounce/cooldown and no capture on other outputs.
3. Preserve the requested connection mode across sleep/wake.
4. Explicitly show 1× rendering, other sound output and unavailable profile states.
5. Restore desktop-card placement and recover an off-screen saved position.
6. Give volume increase/decrease icons accurate accessibility labels.
7. Test actual media-key tap creation instead of treating AX client status as a sufficient proxy. macOS continues to enforce permission; no TCC database or system protection is changed.

## Next work order

1. Finish permission recovery and physical standard volume/mute/unplug tests on the exact installed build; avoid replacing it during approval.
2. Validate volume-only connection and queue behavior with readback while preserving volume/mute.
3. Add live EDID/audio-format inspection and exact-model offline firmware guidance using official packages.
4. Add reversible, clearly unmeasured sound comparison recipes for the user's thin/harsh/no-bass complaint; compare Standard, flat EQ and monitor Atmos processing at matched level.
5. Complete onboarding, desktop/gallery interaction, accessibility, clean public source/release verification and the remaining v5 roadmap gates.

An automatic four-hour follow-up was enabled at the user's request. It must report meaningful evidence and unfinished work, not promote passing fixtures into a perfect-product claim.
