# M8 Studio Sound — development sound module

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
