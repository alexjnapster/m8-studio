# Integrated Sound Studio and legacy companion

The current v5 workspace integrates the real EQ engine into M8 Studio's Sound
page and Controls / Sound / Scenes menu-bar panel. Both use one SoundModel and
session controller. The integrated app requires macOS 14.2+ for Core Audio taps.
Enable is explicit; launch does not start capture or change the sound output.
Ukrainian/English follows Studio's language. Four presets, eight editable bands,
headroom, peak protection and bypass are shared with the legacy companion.

On first integrated launch, only valid eight-band gains are imported from the
legacy companion if main-app gains are absent. Language and permissions are not
copied. Integrated Enable fails closed while the legacy companion is running;
quit that app explicitly before enabling the integrated engine. No app is
force-quit and no installed accepted binary is replaced during development.

`build-preview.sh` builds a distinct guarded main-app preview with synthetic
sessions, no audio observers/capture or auto-connect. It is not live audio proof.
The accepted standalone app remains available during controlled migration.


Real, local system-output EQ for Samsung stereo PCM audio on macOS 14.2+.
The companion has its own bundle identity so adding sound processing does not
replace M8 Studio's already-authorized media-key executable.

Build with `zsh build-sound.sh`, then put **M8 Studio Sound.app** in Applications.
Launch it, select Samsung as the macOS output, choose a preset and press Enable EQ.
macOS may request system-audio access. Audio is processed in memory; it is never
recorded or uploaded. The module makes no network connections.

Ukrainian is the default; the EN/УКР button switches languages. The menu-bar icon
provides presets, bypass and reopening the EQ window. Manual adjustments persist;
press Apply EQ to hear them. Applying restarts the tap briefly. Capture is always
off on a fresh launch. Bypass, output change, sleep and quitting stop the tap and
restore native playback. Re-enable deliberately after changing output or waking.

## Presets

Band gains in dB, with Q=1 peaking filters:

| Preset | 63 Hz | 125 Hz | 250 Hz | 500 Hz | 1 kHz | 2 kHz | 4 kHz | 8 kHz |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Warmth | 0 | +2.5 | +1 | 0 | 0 | −0.5 | −2 | −1.5 |
| Bass + | +1 | +4 | +1.5 | 0 | 0 | −1 | −2.5 | −1.5 |
| Clear voices | −2 | 0 | 0 | 0 | +1 | +1.5 | −1 | −1 |
| Flat EQ | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

All processed presets include a 50 Hz second-order high-pass, automatic preamp
attenuation from the peak frequency response plus 1.5 dB margin, and a linked
stereo peak limiter with 5 ms lookahead and 120 ms release. Output sample ceiling
is 0.98 (about −0.18 dBFS); this is not an oversampled true-peak limiter. Manual
bands are bounded to ±6 dB. No allocations, locks, disk I/O or logging occur in
the C DSP render loop. Atomic meter values are sampled twice per second only
while processing. Total latency also includes the Core Audio buffers.

Bass + provides upper-bass weight, not physical sub-bass extension. Headroom
reduces overall level; compare at matched perceived loudness using monitor volume.
Start with Standard sound and flat hardware EQ. Optional Adaptive Sound+,
Auto Volume and Atmos processing can alter the result and should be compared
separately. No Atmos renderer or codec is added.

## Evidence and limits

- 43 numerical checks: response at 32/44.1/48/96/192 kHz, silent input, overload
  and nonfinite values, stereo isolation, impulse decay, 5 ms delay, invalid
  configuration rejection and linked limiter image preservation.
- Live M80B 48 kHz stereo PCM tap/output startup succeeded; a generated quiet
  signal reached the processor and its meter.
- The user compared familiar music with Bass + and reported **fuller and less
  harsh** sound. This is listening acceptance on one setup, not an acoustic
  measurement or a universal professionally calibrated profile.
- Ukrainian/English native interface and preset/manual-band changes inspected.
- On a later check, native MacBook speakers were selected, processing was off,
  and Enable EQ was correctly disabled. No output was forced back to Samsung.
- Encoded/multichannel and unsupported non-Float32 processing formats are
  rejected; this module is not a passthrough processor. Protected playback may
  not be capturable. Do not enable EQ for an encoded Atmos playback test.
- Reboot, long sessions, every app's protected audio, other monitors, measured
  distortion/response and signed-update permission continuity remain unverified.

The DSP is original project code based on the published
[W3C Audio EQ Cookbook](https://www.w3.org/TR/audio-eq-cookbook/) equations.
The capture layer is MIT CoreAudioTapKit; see TapKit/LICENSE and PROVENANCE.md
for the pinned upstream revision and local hardening changes.

## Unreleased route-policy hardening, 2026-10-24

Workspace source now shares the main app's Samsung display-transport policy.
The earlier sound beta used a Samsung name plus stereo-PCM check, which could
also admit a Samsung-branded Bluetooth or USB headset. EQ eligibility now requires
HDMI/DisplayPort transport, Samsung name/model/manufacturer metadata, a nonempty
endpoint UID, stereo PCM and a finite positive sample rate. Missing transport
information fails closed; manufacturer metadata can identify a display whose
name is generic. The same eligibility check runs before capture and during route
monitoring. No output is selected automatically.

Twelve added routing regressions pass (87 combined policy checks), and the sound
companion builds and verifies its signature. This is source/build verification,
not new physical headset or monitor acceptance. The accepted installed companion
and published sound beta are unchanged; this increment is not yet published.

## Render-buffer verification, 2026-10-24

`zsh Tests/test-audio-buffers.sh` exercises the actual vendored render-buffer
helpers using synthetic memory under Address Sanitizer. Twenty-one checks cover
interleaved/split stereo, mono duplication, leading hardware-input exclusion,
frame caps, unequal channel capacities, missing/nil/empty input/output, destination
stride, silence fill and guard samples around allocations. No HAL calls, capture,
permissions or physical audio devices are involved. This complements the 43 DSP
checks; it is not acoustic testing or long-session hardware recovery evidence.
The new workflow step is prepared locally; remote CI has not run it yet.

## Unreleased lifecycle recovery hardening, 2026-10-24

Blocking tap startup/teardown now runs through `SoundLifecycle`. Every new start,
bypass or shutdown supersedes older results, including callbacks already waiting
for the UI thread. A late success, error or meter reading cannot overwrite a
newer request. Eligibility, UID and sample rate are rechecked after startup;
partially failed or cancelled sessions are disposed. Output-change handling
invalidates the requested route immediately and never selects another output.

Bypass remains available while startup is pending, in the window and menu.
Stopping shows a switching state until teardown completes. Cancelling does not
interrupt an in-progress blocking macOS call or dismiss a system permission
dialog; the session is disposed when that call returns. Fresh launch remains off.

`zsh Tests/test-sound-lifecycle.sh` passes 21 checks against the actual controller
using synthetic sessions and deliberately delayed work/UI delivery. Coverage
includes output eligibility/UID/rate changes, partial startup failure and retry,
bypass during startup, stale success/failure/stop/meter events, shutdown and 100
successive reapplications with every session released exactly once. The same
checks pass locally under Thread Sanitizer without reported races. All 43 DSP
checks still pass, and the companion builds/signature verifies. This is not a
physical unplug/sleep/reboot or long-session certification.

`zsh build-sound-preview.sh` builds a separate `local.M8Studio.Sound.Preview`
identity/preferences domain, with synthetic eight-second starts, no hardware
listeners or HAL session creation. Native CUA verified startup, enabled Bypass
during startup, stopping state and completion to EQ off. UK/EN switching exposed
and fixed a stored-language status bug; both pending and completed recovery
messages now follow the current language. Screenshots were visually inspected.
This proves a synthetic window journey, not the sound menu journey or actual
audio capture. The preview was quit afterward. Installed accepted apps and the
public beta are unchanged; publication follows the v5 E2E gate.

An additional verification of the copied workspace app found inherited Finder
metadata could invalidate its signature even though the clean staging app was
valid. The synced filesystem can attach that metadata again after cleanup. The
build now checks the copied app (warning on filesystem metadata), then extracts
the distribution ZIP outside the synced folder and requires its signature to
verify. Use that verified ZIP for controlled installation; this does not alter
the accepted installed application or disable filesystem protections.

## Unreleased native menu and window refinements, 2026-10-24

The native Sound app menu now offers the same actions as the status menu, so
presets and bypass remain reachable while the utility is frontmost. Command-period
requests Bypass during startup or playback; it cannot enable EQ when off.
Show equalizer raises a single window instead of creating duplicate WindowGroup
instances. Saved-setting guidance uses the available Enable/Apply label and is
hidden during switching.

The synthetic preview verified native app-menu preset selection/start/bypass,
disabled controls while busy, UK/EN labels, the cancellation shortcut and its
off-state behavior. The corrected single-window ID and one-window native menu
were inspected after Show equalizer. Actual close/reopen and the MenuBarExtra
anchor remain unverified. No physical capture or hardware changes were performed;
the accepted installed companion is unchanged.

Integrated model regression harness: `zsh Tests/test-sound-model.sh`. It uses the
actual model/lifecycle with private temporary preferences and fake sessions/routes;
it never observes or starts a real audio device. `M8_MODEL_TSAN=1` runs it with
Thread Sanitizer. Saved preset names are reconciled with validated gains at load,
including after legacy migration; invalid or boolean EQ arrays are rejected.

## Advanced stereo and per-output settings — unreleased 2026-10-25

Optional controls now include balance, averaged mono, separate attenuation-only
channel trims (−12 to 0 dB), and linked night compression. Night mode uses a
3:1 ratio above −24 dBFS with 10 ms attack / 250 ms release and no automatic
makeup gain. It reduces loud peaks; it is not room adaptation or acoustic tuning.
The existing four presets and their neutral stereo behavior are preserved.

Each eligible endpoint remembers its own EQ/channel settings. Changing output
stops capture; returning only loads saved settings, never starts playback capture.
A new endpoint uses the startup EQ baseline and neutral stereo. Edits require
explicit Enable/Apply; Reset stereo preserves EQ bands. Encoded Atmos remains
unsupported by this PCM processor.

65 numerical DSP checks pass; 15 old/new neutral cases were bit-identical.
63 actual model checks, also under Thread Sanitizer, cover configuration payloads,
per-output separation and recovery. These are synthetic/numerical evidence.
Native UK/EN controls and accessible slider-save feedback passed. An isolated live
build processed the connected M80B's 48 kHz stereo PCM with nonzero flow, applied
night mode and shared quick-menu preset changes. Reopening the old companion
stopped the new session automatically; no output selection was performed. This is
routing/processing evidence, not instrument-measured acoustic calibration.
Controlled installed migration and longer physical recovery remain separate gates.
