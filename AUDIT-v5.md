# M8 Studio v5 evidence audit

Updated 2026-10-22. **V5 is not complete and has not earned an objective 100/100 score.** The installed version is a 3.0.0 development increment. Automated checks establish specific behavior, not universal usability, acoustic quality or calibration accuracy.

| Category | Verified evidence | Remaining acceptance work |
| --- | --- | --- |
| Menu UX and layout | 12 native popover combinations pass: Ukrainian/English, light/dark, controls/empty/favorite scenes. Initial startup visibility race fixed. | Live long sessions, available-volume layouts, keyboard-only navigation and VoiceOver journey. |
| Desktop UX | Four native locale/theme layouts plus pin, desktop level, hide and reopen checks pass. Shares app model without extra polling. | Native WidgetKit gallery extension, multi-display relocation/position recovery in a real unplug/replug session. |
| UI and design | Native SwiftUI/AppKit controls, system appearance, accessible action labels, readable localized empty states. Inactive rendering/audio/profile badges made explicit. | Consistent focus treatment, reduced-motion journey and independent user feedback; no invented design score. |
| Initial setup | Detects displays/output routes; preserves existing profiles; model-aware modes and setup guidance. Volume-only connection no longer requires remote navigation pairing. | Five-stage guided setup implemented and locally checked in UK/EN/light/dark. Actual isolated setup navigation, Return, language continuity and summary label/value pairs now verified; fresh-Mac permission/connection and update identity recovery remain. Physical media-key confirmation is complete. |
| Native keyboard behavior | 75 decoding, ownership, Samsung routing/identity and refresh-label checks; seven real Carbon callbacks dispatched internally. Other audio routes pass native media keys through. | Permission repair succeeded after the stale-entry removal authorization. macOS reports one enabled suppressing event tap owned by the installed app. User physically confirmed monitor Volume Down/Up, monitor mute/unmute and native Mac-speaker volume after disconnecting. Longer sessions, reboot/wake and future signed-update behavior remain to test. |
| Recovery and reliability | 23 connected-display scene checks pass, including wrong-display undo, route notifications, guarded mode preview and exact mode restoration. | Sleep/reboot/dock matrix and longer real-world operation. |
| Image and scaling | 4K60 actual M80B, HiDPI/render-buffer explorer, fractional refresh preservation, timed preview, legacy scenes checked. | Instrument calibration, additional cables/HDMI and other model generations. No app can create physical panel resolution or backlight capability. |
| Color | Three actual library/isolation checks prove wrong-panel imports are hidden/rejected without a profile mutation; current-panel imports are offered. Original profiles recoverable. | Measured white point/luminance/gamma/Delta E and panel-specific calibration provenance. Vendor/EDID profiles are descriptions, not measurements of this individual unit. |
| Sound | Selected Samsung stereo 48 kHz route read from Core Audio; real network volume readback available again after correcting a stale address. User confirms monitor Atmos menu exists. | Bass + listening comparison accepted by the user as fuller and less harsh; 43 DSP checks and live stereo PCM flow pass. Measured acoustic calibration, long-session recovery, Atmos state/command and encoded playback remain unverified. No preset is labeled professionally calibrated. |
| Performance | Coalesced Core Audio changes, adaptive polling, shared desktop model. One current process sample was idle in the normal main run loop; physical footprint about 54 MB at that instant. | Repeatable energy, wakeup and long-session profiling; this sample is not a battery-life benchmark. |
| Privacy | Shareable diagnostics omit names, private addresses, tokens, persistent identities and profile paths. Private EDID/profile data stays local. | Continue checking every publication bundle. |
| Distribution | Public v5 foundation CI passed; both current main and sound development bundles build locally and archives verify. Prior working builds are retained. | Sound-only beta published and public download verified; named push/PR CI runs passed. Onboarding and accessibility follow-up CI passed. Stable signing/notarization and a finished v5 release remain. Main app beta remains 2.1. |

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

## Guided setup development evidence

Five native stages provide explicit display, picture/color, sound, keyboard and
summary actions. The walkthrough never treats reading a status as proof of a
physical key test or measured calibration. It supports optional/skipped steps and
a language switch without resetting the selected stage. Finishing is blocked
while display-mode recovery is pending. The UI validation path skips keyboard
registration and tap creation, preserving the installed app's input ownership.

`--validate-setup <directory>` passed 20 native layouts and four workflow/state
checks (24 PASS). Policy regression passed 75 checks and all seven internal Carbon
callbacks passed. Native screenshots were inspected in both languages and themes. These checks do not certify first-run permissions on a different Mac,
monitor-side menu interaction or disconnected hardware. Installed executables
are preserved; the new UI is a workspace/source increment.

## Accessibility follow-up, 2026-10-24

The previously queued onboarding CI runs 39978634938 and 39978629517 both
completed successfully on public commit 7e0d0de. These are build/policy/DSP checks;
the 24 native setup layout/workflow checks were performed locally.

A subsequent workspace change marks card/stage titles as accessibility headings,
combines summary labels with their values, gives stage/actions stable identifiers,
and configures native Return default actions for Continue and Finish. Actual
VoiceOver announcements, focus order and physical keyboard navigation still need
an interactive journey; metadata and compilation do not establish that result.
Accepted installed apps are preserved.

## Isolated interaction preview, 2026-10-24

`build-preview.sh` builds a separate `local.M8Studio.Preview` bundle in temporary
storage with its own preferences. Compile-time guards suppress global shortcut
registration, media-key permission/tap access, automatic polling and Samsung
connection attempts. It opens Setup directly without a status item or desktop
card. It contains public localizations, not personal ICC resources. It is a
navigation harness, not a replacement for the installed app; do not use its
hardware-setting actions for unattended tests.

The preview build/signature verification and normal production build passed;
policy regression passed 75 checks and all seven internal Carbon callbacks
passed. The attempted CUA launch was blocked because macOS was locked. No actual
Continue/Back/Return/language or accessibility interaction was performed, so this
journey remains pending for an unlocked session. No global VoiceOver setting or
permission was changed. Both accepted installed executable hashes are unchanged.
The public accessibility source's CI runs 40032006623 and 40032000821 both passed.
These results do not certify spoken VoiceOver or fresh-Mac setup.

## Sound route audit, 2026-10-24 — unreleased

While native setup interaction remained blocked by the locked Mac, source review
found a real mismatch: the sound companion's name-only Samsung check could admit
stereo Bluetooth/USB headsets, despite its stated display-only policy. The main
app already filtered by display transport. The companion now shares that policy
and additionally requires a valid stereo PCM endpoint/rate. Twelve new fixtures
cover valid display identities and headset/wireless/unknown/encoded/multichannel
and invalid-rate rejection. Combined policy: 87 PASS; sound build and signature
verification: PASS. No installed app or audio output was changed, and no new live
hardware acceptance is claimed. Publication is pending the unlocked-session work.

## Render-buffer coverage, 2026-10-24 — local evidence

The Mac remained locked at the next native-interaction attempt. Independent
verification added 21 synthetic-memory checks of the actual audio buffer helpers
under Address Sanitizer, with no audio-device access. They pass for stereo
layouts, channel stride, frame limits, unequal buffer lengths, nil/empty cases,
silence and exclusion of leading hardware inputs. No production buffer-code
change was needed. A new CI step is staged locally, not yet remotely verified.
This does not close native setup, spoken VoiceOver or long-session recovery gates.
Both accepted installed hashes remain unchanged.

## Native setup interaction and observed accessibility fix, 2026-10-24

In the isolated preview, CUA verified Return from display to picture, Back to
start, Continue by click, English switching retaining the picture stage, Return
through sound/keys/summary and Finish to overview. Actual AX inspection found
summary values absent despite visible text. Replacing implicit child combining
with explicit labels and values fixed all six summary pairs in Ukrainian and
English, verified in the rebuilt native preview. English-to-Ukrainian retained
the summary stage; Finish in Ukrainian and reopening Setup also worked.

This used the built-in screen/native speakers, without changing output, mode,
ICC or permissions; it is not a connected-M8 fresh-Mac journey or spoken VoiceOver
acceptance. The preview now exposes a separately labeled M8P status item and an
explicit desktop-card action for further interaction checks, with the existing
input/network/polling guards. The desktop action created a panel, but the native
inspection hit a menu-state timeout; pin/hide/menu navigation remain unverified.
The isolated preview was quit afterward. Accepted installed binaries remain
unchanged. The user has no Developer ID membership/certificate; local ad-hoc
release/rollback is the intended route, with notarization explicitly unavailable.

## Consolidated goal and desktop presentation fix, 2026-10-24

ROADMAP.md consolidates all requests into workstreams and release gates. Local
v5 E2E and controlled installation precede public GitHub delivery.

Explicitly opening an unpinned desktop card previously placed it below Studio.
It now temporarily presents above normal windows without changing the pin
preference; leaving focus restores desktop level. Startup restoration preserves
its desktop behavior. Native CUA verified open, pin, hide, reopening with pin
retained, unpin and return to Studio. UK/EN controls and refreshed window titles
were checked. A missing Ukrainian Disabled value was fixed and read back natively.
Isolated desktop harness: 10 PASS (four layouts, pin/desktop levels, foreground
presentation/focus restoration, hide/reopen). Production and preview builds pass.

Actual UK/EN quick popovers opened through an isolated native launch item;
Controls/Scenes switching and return to Studio worked without applying scenes or
changing brightness/audio. One Tab press did not establish control focus; full
keyboard-only and spoken VoiceOver remain gates. An initial CUA timeout was
followed by a normal main-run-loop process sample and a successful reconnect to
the visible card; no app hang is claimed. Accepted installed apps remain unchanged.
Phone color research is documented separately; no calibration was performed.

## Audio cancellation and stale-result recovery, 2026-10-24

The sound lifecycle now rejects superseded startup/error/meter/stop callbacks,
including UI deliveries delayed until after bypass or shutdown. Startup validates
the supported route both before and after the blocking tap call. Failed and
cancelled candidates are torn down. Bypass is available during startup, with a
switching status until teardown completes. No output-selection operation was added.

Actual controller tests with synthetic sessions: 21 PASS, also 21 PASS under
Thread Sanitizer with no reported races; 100 synthetic reapplications each start
and stop exactly once. DSP regression: 43 PASS. Companion build and signature
verification pass. These tests do not capture audio, change hardware or certify
real unplug/sleep/reboot recovery. A distinct synthetic sound preview subsequently
verified the native window startup/bypass/stopping/off journey and UK/EN status
changes. It exposed a retained-language message bug, now fixed by storing semantic
notice state and localizing at render time. Screenshots inspected; preview quit.
The sound menu journey remains unverified. A copied-workspace signature check also
found Finder metadata reattached by the synced filesystem after cleanup; the
build warns if that workspace copy fails, and requires the distribution ZIP's
signature to verify after extraction outside the synced folder. The trusted installed
main and sound executable hashes were rechecked unchanged. Source and the new CI
step remain local until the user-requested full v5 E2E publication gate is met.

## Compact-menu keyboard interaction, 2026-10-24

The popover now activates consistently on left-click, establishes its hosting
responder and gives the page selector explicit editing focus. Left/Right selects
Controls/Scenes, Command-Return opens Studio, and Escape dismisses the popover.
The shortcut appears in Open Studio's help text. Opening no longer performs two
hardware/permission refreshes; right-click retains its own single refresh.

Native isolated CUA verified UK/EN arrow selection, a visible focus ring,
Command-Return opening Studio, Escape dismissal and arrow selection after reopening.
No brightness, scene, output or permission changes were made. The first attempt
using only default focus/responder setup failed; adding explicit editable focus
and an appearance focus request resolved the observed arrow-key failure.
Tab did not advance to ordinary buttons on this session. macOS button tabbing
depends on system Keyboard Navigation; this app does not change that global
setting. Full button traversal with that setting enabled and spoken VoiceOver
remain unverified. See [Apple's focus guidance](https://developer.apple.com/documentation/swiftui/view/focusable(_:interactions:)).

## Sound command menu and one-window behavior, 2026-10-24

The sound companion exposes its shared preset/enable/bypass actions in a native
Sound app menu as well as MenuBarExtra. Command-period requests Bypass only when
there is an active or starting session; it does not enable EQ when off. A semantic
single Window scene replaces WindowGroup so Show equalizer reuses its window.
Saved-preset guidance names Enable EQ while off, Apply EQ while running, and stays
out of the way during switching.

Synthetic CUA verified menu Bass + selection, menu startup, disabled presets with
enabled Bypass during startup, menu cancellation, UK/EN menu labels, Command-period
cancellation and no startup from that shortcut when off. The previous WindowGroup
produced a second window; the fixed scene retained ID sound and the native Window
menu showed one EQ window after Show equalizer. UK/EN saved-setting hints and
pending-start hint suppression were read back; screenshots inspected. A close
command did not prove a close/reopen cycle, so that journey remains open. The
MenuBarExtra anchor itself was not exercised; sharing actions is not proof of
that presentation. Synthetic preview was quit. No HAL sessions or installed app
updates were involved. Both production builds pass; archive verification is
recorded separately from synced workspace-copy metadata.

## WidgetKit prototype and navigation boundary, 2026-10-24

Implemented a real sandboxed extension with UK/EN small/medium navigation widgets,
an isolated preview embedding option and allowlisted app navigation URLs. It has
no shared live readings, credentials, network/audio access or hardware actions.
Cold-launch quick handling has a bounded wait/fallback; newer navigation cancels
older pending work. The production app builds with the handler, but production
widget embedding is deliberately still open pending native evidence.

The appex and embedded preview signature verify, and PlugInKit reports the embedded
widget after native launch. Parser checks exercise both schemes, including cross-
identity rejection. This does not certify gallery rendering or click-through.
Safari initially rejected the temp host's URL; Launch Services reported a
claimed scheme but no handler. Follow-up: staging the isolated preview in a
dedicated non-temp Application Support folder resolved handler lookup; warm
Safari-to-host Color and quick navigation passed. This is not a widget click
or cold-start acceptance. No security setting or accepted app identity changed.
CUA could read Finder Desktop but its context-menu actions failed; Notification
Center inspection timed out. No widget was added. Native visual layout, URL
delivery, gallery/add/remove, live controls/data and production delivery remain
unverified. See Widget/README.md for build instructions and the next investigation.


## Integrated sound redesign — local development, 2026-10-24

Sound presets and editable EQ now render inside the main Sound page. A third
quick-panel Sound tab shares the same model, gains, lifecycle and bypass state;
right-click menu includes preset and enable/bypass actions. No launcher is
required. The original DSP coefficients and serial session teardown are retained.
Main audio usage descriptions are localized, dependency license/provenance is
packaged, and the integrated deployment minimum is macOS 14.2.

Native isolated preview: English light and Ukrainian dark Sound pages inspected;
quick-panel Bass+ appeared as the same gains in Studio; main-window synthetic
startup and Cmd-period bypass propagated back to quick Sound. These are synthetic
interaction checks, not live HAL capture or updated keyboard permission proof.
The accepted installed apps remain unchanged. Legacy companion conflict refusal,
one-time preference import and actual integrated audio permission/capture still
need controlled runtime coverage. No interim publication is authorized.

Native sizing follow-up: `NSHostingController.sizingOptions` now tracks preferred
content size. The final Ukrainian/dark quick Sound screenshot shows complete
header, right edge, presets and footer. Quick Enable/Bypass -> main EQ stopping
and then off were read back, and a native slider change marked Custom. Setup's
sound button and completion summary now refer to integrated Sound Studio.
These changes still need controlled installed real-capture/update acceptance.


## Integrated sound safety and S9 recognition — 2026-10-24

The production SoundModel now accepts private preference stores and fake session/
route providers for tests. Its default initializer still selects the real local
route, native observers and capture engine; the UI has no test-mode control. The
model harness explicitly disables observers and injects synthetic sessions, so
no audio device, output selection, TCC access or installed preference is touched.

33 actual-model checks passed, including one-time validated legacy import, main
preference precedence, no language/credential import, malformed/nonfinite/boolean
gain rejection, consistent preset labels, live UK/EN legacy-conflict notices,
refusal before engine construction, reapply teardown, output-change stop, no
auto-start after reconnect, pending-start bypass and shutdown rejection. The
same checks passed under Thread Sanitizer without reported races. This covers
model/controller behavior with injected sessions, not real HAL or OS permissions.

Preset labels are derived from gains on load, preventing an old/corrupt preset
name from claiming Bass+ while different coefficients are selected. Sound DSP
coefficients and real-time processing have not changed.

S90PC DP SAM7394 and USB-C SAM7395 from the inspected official INF are recognized
as S90PC only with Samsung's vendor identity. Exact S27C90xP Tizen model patterns
are eligible for ViewFinity S9 service discovery. Six added positive/negative
regressions bring keyboard/capability policy checks to 93. This does not establish
S9 hardware readback, transfer M8 tuning, enable an unsupported control or prove
measured acoustic correction.


## Failure/retry and delivery preparation — 2026-10-24

Extended actual-model checks cover failed session startup, partial-session
teardown, live UK/EN failure messages, explicit retry, shutdown during an active
session and repeated shutdown. The first run reproduced a failure: capture
teardown completed but `running` remained true. Shutdown now clears running/busy
and bypass state and is idempotent. All 41 integrated-model checks pass after
the fix; fake sessions and private test preferences only. Redundant initial
route refreshes were also removed, without changing observer behavior.

Native widget exploration confirmed desktop widgets enabled in System Settings
and read the configured Show Desktop F11 shortcut. Finder can expose Desktop
pixels/AX but its empty-background click still returns noWindowsAvailable;
Control Center inspection timed out. No gallery or widget was added, no settings
were changed, Show Desktop was reversed and General was restored. Do not count
this as native widget acceptance or repeatedly retry the same blocked surface.

A committed-source candidate builder now prepares source/app archives and a
manifest without private local resources, installation or publication. Execution
evidence is recorded separately; code presence alone is not package acceptance.

## BetterDisplay study and quick scaling — 2026-10-24

Inspected the official BetterDisplay 5.1.1 DMG statically, plus its current public
manual and MIT CLI source. It was not installed or run. Imported private display
interfaces are investigation leads, not recovered algorithms or proven M8
capabilities. BETTERDISPLAY-RESEARCH.md records the artifact hash, evidence limits
and feature priorities. Vendor files remain outside the repository.

The independent favourite-mode store passed 19 checks covering persistence,
per-display separation, logical/render dimensions, fractional refresh, removal,
eight-entry capacity and corrupt preferences. Production and isolated preview
builds passed. CI and clean-candidate recipes now include the new check; these
changes have not run remotely or been published.

Actual guarded-preview interactions verified Ukrainian/English favourite stars,
persistence across preview restart, current-mode labels and Desktop size menu
entries, plus All modes & favorites navigation back to Display. A first native
check found that stars for reported modes with a different aspect ratio did
nothing: selection eligibility incorrectly used the aspect-filtered shortcut
list. The fix validates against all reported eligible modes; the 1920 × 1200
favourite then appeared in the quick menu alongside the current 1710 × 1107 mode.
Test favourites were removed, preview language restored to Ukrainian and the
preview quit through its native app menu. Only isolated preview preferences were
changed. No mode, audio output, ICC, permission or installed app was changed.

This was built-in Retina display coverage while the M8 was disconnected. Timed
mode application and connected-M8 favourite/reconnect behavior were not exercised
by this journey. The picker generates no new modes, HDR output or calibration.

Widget acceptance update: the user reports that M8 Studio appears in the native
gallery, the medium preview widget renders correctly, and its Sound link opens
Sound Studio. Automation could not independently inspect the gallery or establish
click causality. This accepts that user-reported preview journey, not production
embedding, other sizes/locales or live widget controls. The preview registration
remains available because the user may have added that widget.

## Advanced scaling and audio implementation — 2026-10-25

Display assistance adds explicit saved mode/profile recovery after a real absent
then present transition, a physical-size-based text-size suggestion and visible
brightness/volume/EQ providers. No restoration runs automatically on startup or
refresh. Twenty-five isolated checks cover matching, invalid dimensions, missing
modes, persistence, corruption, separate displays, reconnect/dismiss/forget and
repeated events. Native guarded UK/EN save/forget and provider/empty-state views
were inspected; no actual profile application or layout restoration was tested.

The independent virtual HiDPI host offers 1280–3072 logical pixels in 16-pixel
steps at 16:9, with a 2× render buffer. It is an explicitly started M80B landscape
experiment near 60 Hz, using session mirroring rather than an EDID/model override.
An independent process owns the virtual source, an initial deadline, parent and
connection monitoring and restoration of the original physical mode/origin.
Input validation and private-API availability do not imply physical acceptance.
Nineteen policy checks and helper argument/self checks pass without display writes.
The ABI declarations were checked against Chromium's BSD display-test utility;
its license/provenance are included. No BetterDisplay code is bundled.

The first connected test failed before mirroring: CoreGraphics returned no modes
for the newly created display in its creator process. Failed attempts removed the
source, and baseline snapshots matched. A fresh configurator process resolves the
mode-cache problem. Actual M80B checks then verified:

- 2560 × 1440 logical, 5120 × 2880 render, 60 Hz and the intended mirror direction.
- Unconfirmed preview timed out and the entire before/after snapshot matched.
- 2400 × 1350 logical, 4800 × 2700 render and 60 Hz; native Keep acknowledged.
- User reports correct picture/readable text with no flicker or blank screen.
- Explicit Return restored the exact snapshot: physical/built-in modes, render
  sizes, refresh, origins, mirrors, ICC paths and selected audio device.

This is live evidence on one M80B/Mac path, not measured color, physical output
link timing, latency, HDR parity, all generated sizes, reboot or dock coverage.
Native reported HiDPI should be preferred where available. Final UI now chooses
an exact reported 2× mode first; a missing size uses the virtual fallback. This
selection follow-up passed on the connected M8: 2560 × 1440 used a reported
2× mode with only the two physical displays present, and its timeout restored the
exact baseline. The 2400-width fallback also passed Keep and Return through the
actual quick menu. Force-closing only the isolated test host removed its virtual
source and restored that baseline; recovery was observed within 0.451 seconds in
this one experiment, not a latency guarantee. No system overrides,
firmware, admin helper, Screen Recording grant or permanent arrangement was used.

Stereo processing adds optional balance, averaged mono, attenuation-only channel
trims and stereo-linked night compression (3:1 above −24 dBFS, 10 ms attack,
250 ms release, no makeup gain). Neutral defaults retain the accepted EQ presets.
Sixty-five DSP checks pass, including the earlier forty-three checks. A separate
old/new numerical comparison found bit-identical neutral output in fifteen cases.
Sixty-three actual-model checks pass, also under Thread Sanitizer with no reported
races, including per-output memory, independent channels/settings, no auto-enable
and immutable processing options. The twenty-one lifecycle checks still pass.

Actual guarded UK/EN views verified balance, mono/night toggles, trim values,
Reset stereo and pending/saved guidance. Accessibility slider edits now save and
mark pending through their binding setter, including without a mouse-release
callback. Temporary preview stereo changes were reset and language restored UK.
Actual manual processing through the connected M80B passed at 48 kHz stereo PCM:
nonzero audio flow, Bass +, applied night compression and a Warm preset selected
through the shared quick menu. This verifies processing/routing, not measured
acoustic improvement from the new controls. The earlier Bass + listening
acceptance remains valid and was not repeated.

A real late-companion launch exposed continued integrated capture despite an
Apply refusal. The fix observes companion launch and stops pending/active capture;
63 model checks include late-start and pending-start cancellation, also under
Thread Sanitizer with no reported races. A fresh isolated live build then stopped
EQ automatically when the accepted companion reopened. Neither app selected an
audio output, and full display/profile/audio-route snapshots remained identical.
The accepted companion was left open with EQ off and its existing Bass + settings.
Both accepted installed executable hashes remain unchanged. Controlled installed
migration, fresh-Mac capture permissions and longer recovery remain gates.


## Production widget packaging — 2026-10-25

Production builds now embed the navigation-only WidgetKit extension with
local.M8Studio.Widget identity, production navigation scheme and matching host
version/minimum OS. Preview builds retain separate identity/scheme. The clean
candidate audit checks exact nested file inventory, extension point, versions,
sandbox-only entitlement and signature. No shared state, credentials, audio or
network access is added. The user's medium preview rendering/Sound-link
acceptance remains preview evidence; this packaging work does not establish
production registration, gallery rendering, other families or live controls.
