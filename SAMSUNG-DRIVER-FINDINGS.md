# Samsung M9 → M8 compatibility investigation

Inspected 2026-10-22. Static extraction only; no Windows installer, camera updater or monitor firmware was executed. This document contains no personal monitor identifiers or network addresses.

## Official packages inspected

- [Samsung M9 S32FM902SU support](https://www.samsung.com/uk/support/model/LS32FM902SUXEN/): Device(Install) S32FM90xS, version 1.0, `M90SF_S32FM90xS.exe`, published 2025-05-09. INF DriverVer 2025-03-10, 1.0.0.0.
- [Samsung M80B LS32BM801UIXUA support](https://www.samsung.com/ua/support/model/LS32BM801UIXUA/): Device(Install), version 1.0, `SxxBM80x.exe`, published 2022-02-09. INF DriverVer 2021-12-20, 1.0.0.0.

The ALZip self-extracting wrappers contain EGG archives. PE overlays were extracted using official 7-Zip 26.05; the EGG payloads were decoded with the separately downloaded MIT-licensed [unegg extractor](https://github.com/jinyeong-park/unegg-egg-file-extractor). These tools and Samsung binaries are research material, not bundled dependencies. The EGG file inventory and INF/profile fields were inspected directly. Extraction paths were checked before extraction.

## What the packages contain

| Item | M80B | M90SF | Consequence for Studio |
| --- | --- | --- | --- |
| Windows monitor INF | HDMI and USB-C variants | 15 DP, HDMI, USB-C, PBP, VRR and widescreen variants | Use exact identities for model policy; never force another model's timings. |
| RGB display profile | 536-byte matrix/TRC ICC | 536-byte matrix/TRC ICC | Profiles describe different primaries. Neither is an individual panel measurement. |
| Signature catalog | Present | Present | Windows package validation metadata, not a macOS control feature. |
| Windows setup executable | Present | Present | Not executed or ported. |
| Audio endpoint INF, audio .sys, EQ presets or Dolby codec payload | None in extracted inventory | None in extracted inventory | No sound-unlock payload was found in these monitor driver packages. This does not prove that monitor firmware lacks a sound effect. |

The M9 INF uses monitor-class installation sections and associates a profile with Windows display identities. It contains no EDID override block. Frequency ranges are declarations, not a list of safe macOS timings, and not evidence that an M80B can run at M9 refresh rates.

The packages' setup executables were not exhaustively decompiled; findings about absent payloads refer to the extracted inventory and INF, not every possible behavior of opaque executable code.

## Exact portable improvements implemented

- M80B USB-C `SAM7267` and HDMI `SAM7269` now both receive the correct M80B capability guidance. Previously Studio recognized only the USB-C identity.
- M90SF product variants are kept separate from M80B, including HDMI/DP/USB-C VRR variants. Classification requires Samsung's vendor identity; unrelated products are not matched by product number alone.
- Scaling choices come from macOS enumeration, with timed rollback. No M9 refresh rate, HDR or OLED capability is injected into the M8.
- Fractional refresh rates remain distinct in the mode list and newly saved scenes; older integer-rate scenes remain readable.
- Imported ICC files are associated with the selected display. A profile imported for another panel is not offered or applied silently. An already-active legacy import can be associated with its current display without changing the profile.

## Profile comparison

| Profile | rXYZ | gXYZ | bXYZ | Single-value RGB TRC gamma |
| --- | --- | --- | --- | --- |
| M80B | 0.486420, 0.266693, 0.004547 | 0.333374, 0.665710, 0.049255 | 0.143967, 0.067566, 0.767899 | 2.19921875 |
| M90SF | 0.590714, 0.263397, 0.009491 | 0.235016, 0.682907, 0.045258 | 0.138046, 0.053680, 0.766953 | 2.19921875 |

These are ICC tag values, not direct measurements of the user's panel and not an accuracy score. Equal gamma does not make the profiles interchangeable. No calibration lookup table was present in either 536-byte profile.

SHA-256 of the extracted profile files:

- M80B: `5a57dba1b57d881cd8390e3d753c87bc73c82fa4242cc08e7cd00933ee70e5ac`
- M90SF: `04f5778e5b92ca1475ae7fe08cb36b45b2432e4555d8c9299e3678007086b638`

## Sound and immersive playback

Samsung's shared M80B-era manual describes an optional Dolby Atmos virtual surround effect through embedded speakers, but explicitly makes availability model dependent. That passage alone does not establish that the exact connected monitor/input has the switch. The user subsequently confirmed seeing the Dolby Atmos option on their M8. Studio records that observation separately from its unknown enabled state and unknown Mac playback path. The confirmed RenderingControl service exposes volume and mute, not Atmos, EQ or Adaptive Sound state.

Apple documents [HDMI Passthrough](https://support.apple.com/guide/mac-help/mchle3a1461c/mac) for supported Dolby bitstreams in Music, QuickTime Player and TV on Apple silicon with a supported HDMI path and receiver. A two-channel PCM report neither proves nor disproves every receiver's encoded-bitstream capability. DisplayPort-over-USB-C must not be labeled HDMI passthrough.

[Apple Music playback settings](https://support.apple.com/guide/music/playback-settings-musdf855a1b/mac) and [Spatial Audio compatibility](https://support.apple.com/en-us/109354) govern playback. Studio provides live route information and setup links; it cannot globally enable Apple's renderer for other apps or honestly claim Atmos decoding from an unverified network command.

## Remaining verification

Hardware brightness via DDC, an Atmos toggle on the exact monitor/input, encoded HDMI playback, measured color accuracy, acoustic EQ and other M7/M8/M9 generations require their own verification. M9 firmware, profiles and camera firmware have not been applied to an M8. Native WidgetKit gallery packaging is a separate v5 milestone; the implemented desktop controls are an app-owned native panel.

## Actual connected M80B signal investigation

The connected Samsung EDID was read locally from `IOPortTransportStateDisplayPort` and duplicated registry copies were deduplicated conceptually; the raw EDID (which includes persistent identity material) is not published. Both 128-byte block checksums were valid. Its identity is the original M80B USB-C variant. The EDID identifies the monitor assembly as SAMSUNG; it does not disclose a verified internal LCD panel supplier/part number or speaker-DSP silicon part number.

It advertises 3840 × 2160 at 60 Hz and another detailed 2560 × 1440 timing at about 59.951 Hz. The declared display gamma is 2.2. These are declarations, not measurements of color accuracy.

CTA audio data advertises LPCM two-channel 32/44.1/48 kHz at 16/20/24 bits, AC-3 up to six channels, Enhanced AC-3 up to eight channels, and MAT/MLP up to eight channels. Speaker allocation advertises front left/right. The Enhanced AC-3 descriptor does not set the JOC flags; the MAT descriptor does not set the object-PCM capability bit. Consequently encoded Dolby-format declarations must not be labeled proof of Atmos metadata playback. Descriptor interpretation was checked against the [upstream edid-decode implementation](https://android.googlesource.com/platform/external/edid-decode/+/046bb92ce0ef1c797068d211dea38e1f92500068/parse-cta-block.cpp); no code from that implementation was copied into Studio.

Core Audio's available physical formats independently include LPCM two-channel 16/20/24-bit at 32/44.1/48 kHz and the encoded transport formats `cac3`, `cec3`, and `mtat`. Their carrier rates are not acoustic sample-rate improvements. Virtual formats include float PCM and the encoded transports. No format was forced or changed. The manufacturer's reported name is SAM. The queried plug-in bundle-ID property was not reported, so no exact audio driver/chip identity is claimed.

Current DDC reads for volume and luminance both failed. Network volume readback is available after resolving two responding endpoints to one monitor identity and saving a responding queried address. No device-reported address redirect was followed.

## Firmware and thin-sound investigation

The user reports installed firmware `1720` and a country-related online-update block. Samsung's exact Ukrainian model support page lists `T-PTMWWC.zip`, version **1720.7**, dated **2026-05-08**. The shortened on-screen number cannot establish that the installed version is older. The network identity service reports the firmware version as `Unknown`.

Samsung's official 2022 T-PTMWWC update guide documents a USB method using the extracted `T-PTMWWC` package at the USB root, attached to the monitor using the necessary USB-C hub/adapter. It notes that an update can begin automatically after insertion and may reset picture/audio settings. This is a possible alternative to online availability, not a verified region bypass, downgrade or proof that an update is needed. No firmware was flashed, modified or downloaded to a USB device.

No exact-M80B sound-fix changelog or validated community EQ correction was found in the reviewed sources. [Samsung's 2025 distortion advisory](https://www.samsung.com/us/support/troubleshoot/TSG10010544/) applies to M80F/M90SF and suggests disabling Adaptive Sound Pro for muffled/fading audio. It must not be relabeled an M80B thin-bass firmware fix. The user's described problem is thin/harsh sound with little bass, so a neutral baseline and cautious matched-level comparison are the first listening experiments.


## Expanded software/firmware investigation, 2026-10-24

See [static package research and transfer matrix](SAMSUNG-SOFTWARE-FIRMWARE-RESEARCH.md).
Current official Mac SDM and Easy Setting Box packages, an S8 firmware image and
bounded M80B update metadata were inspected without executing or flashing them.
A vendor DDC negotiation lead and more specific factory-type evidence are now
recorded; neither confirms a working M80B brightness unlock or an exact audio DSP.

## ViewFinity S9 audio transfer audit — 2026-10-24

The official [S90PC support listing](https://www.samsung.com/in/support/model/LS27C900PAWXXL/)
provides Device(Install) 1.0, `S27C90xP.exe`, dated 2023-07-07.
Downloaded package SHA256:
`4c67193a5e44dbb6c89a07773dd6d07d5b2d4d29fc0ec2c9221ae5c57badd431`.
Static PE-overlay/EGG extraction found seven entries: the Windows installer,
monitor INF/ICM/catalog and duplicate manual-install INF/ICM/catalog. The INF
is Monitor class, DriverVer 2023-03-23 1.0.0.0, DP SAM7394 and USB-C SAM7395.
It associates `S27C90xP.icm` and display declarations. No separate audio INF,
audio `.sys`, acoustic coefficient file or Dolby payload appears in that inventory.
The opaque installer was not executed or exhaustively decompiled. This is not
proof about all firmware contents. Vendor files stay outside the source repo.

Samsung lists [S9 Adaptive Sound+ and 2×5 W speakers](https://www.samsung.com/ca/monitors/high-resolution/viewfinity-s9-27-inch-ls27c900panxza/)
and [M9 Adaptive Sound Pro and 10 W output](https://www.samsung.com/ca/monitors/smart/smart-monitor-m9-32-inch-smart-tv-apps-4k-oled-ls32fm900snxza/).
The [M9 announcement](https://news.samsung.com/global/samsung-releases-smart-monitor-m9-with-ai-powered-qd-oled-display)
also names Active Voice Amplifier Pro. These are monitor features, not portable
Mac DSP modules. Equal power ratings do not establish matching speakers,
enclosures, amplifiers or safe transferable acoustic correction.

Reusable directions are explicit dialogue presets, matched-level comparison,
optional content dynamics, per-model capability discovery and per-output saved
EQ. Existing Clear voices and Bass+ are independently implemented starting
points. No extracted Samsung sound algorithm or coefficient is being bundled.
Room adaptation requires a measurement workflow and validation; source-content
analysis alone cannot measure speaker/room response. Dynamic bass should be
bounded by level/headroom and independently tested before it is offered.

Samsung's [2025 distortion advisory](https://www.samsung.com/us/support/troubleshoot/TSG10010544/)
specifically covers M80F and M90SF and suggests disabling Adaptive Sound Pro
for muffled/fading sound. It supports an optional troubleshooting guide for those
models, not enabling the feature everywhere or calling it an M80B firmware fix.
No automatic monitor DSP setting or firmware change was performed.

Implementation follow-up: S90PC DP/USB-C PnP identities now have their own family
classification. The S27C90xP Tizen model pattern is eligible for service discovery;
actual control still requires the same capability/readback gates. No sound DSP
coefficients or audio-format declarations are copied from the S9 display INF.
