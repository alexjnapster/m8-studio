# M8 Studio

Нативний застосунок у смузі меню macOS для керування екранами Samsung. Українська за замовчуванням; English доступна в налаштуваннях.

A native SwiftUI/AppKit menu-bar utility for Samsung displays. Built for Apple silicon and macOS 14.2 or later. The published beta is 2.1.0. Current working source targets the v5 roadmap and is a development build, signed locally without Developer ID notarization.

## Download the DMG

[Download M8 Studio v5 development preview for Apple silicon](https://github.com/alexjnapster/m8-studio/releases/tag/v5-development-2026-10-26).
Open the DMG, quit the old utilities, drag **M8 Studio.app** to **Applications**,
then open it from Applications. Ukrainian/English installation instructions and
an Applications shortcut are inside the image. macOS 14.2+ is required.

This is a development preview (internal bundle 3.0.0, build 5), not completed v5.
It is ad-hoc signed, not Apple-notarized; macOS may block first launch or require
renewed approval for media keys/system audio. Keep your previous app when updating.
No security settings are changed by the image. Check the release checksum.

## Latest development update — 2026-10-25

The `v5-development` branch now includes integrated Sound Studio and quick-menu
EQ, balance, mono, channel trims, linked night compression and per-output settings.
Native HiDPI modes are preferred; an opt-in M80B virtual SDR canvas adds finer
sizes with an independent timeout/recovery host. Favourite modes, explicit
reconnect recovery and estimated physical text-size matching are also available.
The navigation-only WidgetKit extension is packaged with the main app.

Connected-M8 tests verified 48 kHz PCM processing, shared quick-menu presets,
late-companion shutdown, native-first scaling, 2400 × 1350 virtual HiDPI,
timeout/Keep/Return and recovery after the isolated host was force-closed. The
user accepted the virtual picture/text check. The clean candidate passed 65 DSP,
63 sound-model, 21 lifecycle, 21 buffer, 25 display-assistance and 19 canvas-policy
checks, plus the existing keyboard/route/favourite checks and extracted signatures.

This is development source, not completed v5 or an automatic installed update.
Production widget-gallery acceptance, controlled installed permission migration,
longer dock/reboot/recovery, HDR/Atmos and instrument-measured calibration remain
open. See [audit](AUDIT-v5.md) and [roadmap](ROADMAP.md). Ad-hoc signing is not
Developer ID notarization. Keep the older Sound companion off while enabling the
integrated processor; reopening it stops integrated processing.

## Features

- Compact menu-bar controls and a full Studio window, Ukrainian and English interfaces, light/dark/system appearance.
- Per-display software dimming, linked screens, favorite scenes, scene import/export, undo, and quick reset.
- Display-reported scaling modes with a 15-second preview and an independent rollback helper.
- Mac volume/mute keys for Samsung audio when a local volume service has answered; permission-free global shortcuts as a fallback. Dedicated Apple brightness keys and F14/F15 are recognized. Ordinary F1/F2 remain standard function keys.
- Samsung Smart Monitor discovery, approved local WebSocket remote, certificate pinning, Keychain pairing tokens, UPnP volume/mute readback and wake-on-LAN.
- DDC backlight/contrast/volume controls appear only after successful reads. Software dimming remains separate from physical backlight control.
- The connected display's own ColorSync profile, ICC import, profile preview and undo. No generic profile is advertised as a measured calibration.
- Optional brightness following, evening schedule, and Option-scroll on the menu-bar icon.

## Compatibility and evidence

| Display or path | Status |
| --- | --- |
| Samsung M8 M80B, LS32BM801UIXUA | Previously exercised on an M2 MacBook Air: 4K/60 modes, ColorSync, software dimming, stereo 48 kHz output and local UPnP volume/mute. Standard monitor volume/mute keys and disconnected Mac-speaker fallback were physically accepted by the user. Final paired remote, reboot/dock and other hardware checks remain pending. |
| Smart Monitor M5/M7/M8/M9, M1 and smart Odyssey G6/G7 SKU families | Model recognition and service-gated controls implemented; representative SKU fixtures pass. Other physical monitors have not been tested. Firmware and connection determine which services answer. |
| Other external Samsung displays | macOS modes, software dimming and ColorSync are available; DDC controls require a successful probe. No Smart TV compatibility claim. |
| Intel Macs | Not supported by this build; the bundled DDC helper uses Apple silicon interfaces. |

USB-C HDR and Dolby Atmos are not unlocked by this utility. The original M80B USB-C path did not support external HDR and exposed stereo PCM audio. Capabilities of other models must be checked on their own connection. Measured color accuracy requires a panel-specific instrument calibration; acoustic quality requires listening or measurement. There are no fabricated perfect scores.

## Build and run

Install Xcode Command Line Tools, then:

```sh
zsh build.sh
open "M8 Studio.app"
```

The script builds an arm64 app and `../M8 Studio.zip`; it does not install the app or change security settings. Move the app into Applications. Locally signed rebuilds can require refreshing the app's Accessibility/Device Control permission and approving monitor pairing again. A stable Developer ID release is future work.

Enable Mac media keys in Studio Settings, then grant the requested macOS permission yourself. When F1–F12 are standard function keys, hold Fn/Globe for media functions. Other audio outputs retain normal Mac behavior. Media controls require the Samsung to be the active output and its network service to be reachable. Only the explicitly selected network monitor is controlled; simultaneous independent network monitors are not implemented.

Global shortcuts: Control–Option–Command with ↑/↓ for volume, M for mute, ←/→ for dimming, 0 for reset, Space for Studio. Registration status and last received command are visible in Settings. Registration success alone does not verify physical keyboard delivery.

## Tests

```sh
zsh Tests/test-keyboard.sh
zsh Tests/test-carbon.sh
```

The first suite checks media decoding, key ownership/release, mute repeat suppression, unrelated-key passthrough, Samsung identity fixtures and adaptive polling policy. The second checks all seven real Carbon callback dispatches internally; it does not synthesize physical key presses. On 2026-10-22, 75 policy checks and all seven internal command dispatches passed locally.

The app also contains opt-in integration harnesses (`--validate`, `--validate-scenes`, `--validate-quick`). They can temporarily change display modes, brightness, output routing or profiles and may request monitor pairing. Use these deliberately on a connected test setup; they are not run automatically in CI. Hardware-dependent evidence must be kept separate from fixture tests.

## Privacy

No analytics or cloud account is required. Local network traffic controls the selected monitor; UPnP volume uses HTTP on the trusted local network. Remote commands use a certificate-pinned local WebSocket. Pairing credentials are in Keychain, preferences stay on the Mac, and diagnostics/scenes export only at your request. Public source excludes personal ICC backups, local diagnostics, monitor addresses and credentials.

## Open-source foundations

The bundled [m1ddc](https://github.com/waydabber/m1ddc) helper is MIT-licensed; its license is included in ThirdParty. DDC reply validation has local changes. Media key event-format and dedicated brightness-key handling were studied from [MediaKeyTap](https://github.com/nhurden/MediaKeyTap), with MIT attribution in Resources/Licenses. [MonitorControl](https://github.com/MonitorControl/MonitorControl), [Lunar](https://github.com/alin23/Lunar), and [HotKey](https://github.com/soffes/HotKey) informed routing, recovery and shortcut research; their implementations are not bundled. Samsung model families were checked against [Samsung's Smart Monitor range](https://www.samsung.com/uk/monitors/smart-monitor/).

This is an independent project, not affiliated with Samsung or Apple. App code is MIT-licensed; third-party notices remain applicable.

## Current development increment

Desktop controls (menu → More actions → Desktop controls), a HiDPI scaling explorer with render-buffer dimensions and safe preview, panel-scoped imported ICC profiles, explicit Samsung audio routing and immersive-playback setup guidance are in development. See [driver findings](SAMSUNG-DRIVER-FINDINGS.md) and [v5 roadmap](ROADMAP.md) for evidence and remaining work. These additions do not claim measured calibration, automatic Atmos activation or native WidgetKit gallery registration.

## Sound presets and adjustable EQ

The integrated [Sound Studio](Sound/README.md) provides Warmth, Bass +,
Clear voices and eight editable EQ bands with automatic headroom, linked peak
protection and true bypass. The main Sound page, Setup and menu-bar Sound tab
share one engine and settings. No companion launch is needed in the current
workspace build. The previously accepted standalone companion remains installed
until controlled v5 migration; quit it before enabling integrated EQ. Processing
is stereo PCM and local, without recordings or uploads.
The M80B listening test was accepted as fuller and less harsh with Bass +; presets
are not instrument-measured speaker/room calibration. Run `python3 Tests/test-sound.py`
for the DSP numerical checks.

## Guided setup in development builds

Fresh launches open a five-step Setup journey; it can be reopened from the sidebar
or with `--setup`. Select the display, compare reported scaling modes, preserve the
panel's profile, choose audio, and optionally enable media keys. All stages can be
skipped. Finishing saves walkthrough completion without applying picture, profile
or sound settings. Existing preview recovery must be resolved first.

`--validate-setup <directory>` renders all five stages in both languages and
appearances and checks completion/recovery and hardware-state preservation. This
harness does not acquire media-key access or register shortcuts. It does not
replace a real first-run test on another Mac.
