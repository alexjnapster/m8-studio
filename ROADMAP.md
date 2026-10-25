# M8 Studio v5 — consolidated delivery goal

Updated 2026-10-25 after the user's advanced scaling/audio priority and connected M8 tests.

Publication order update: the user now explicitly requests updating GitHub with
this development source before full v5 completion. Publish the reviewed source,
keep the draft PR's acceptance status honest and verify remote CI. Stable v5
release and installed promotion still require their remaining gates.

BetterDisplay follow-up: static official v5.1.1 binary/metadata and MIT CLI study
recorded in BETTERDISPLAY-RESEARCH.md. Prioritize favourite scaling shortcuts,
clear provider status and opt-in recovery. Private-API scaling/HDR/virtual-screen
leads remain separate experiments, not verified M8 unlocks.

Current priority: finish advanced HiDPI scaling and richer audio end to end.
Studio and the menu now share one integrated EQ model. New source provides a
native-first fine-size picker, an explicit virtual HiDPI fallback, reconnect
review, control-provider status and physical text-size suggestions. The M80B
virtual path passed live 2560/2400-width tests, timed and explicit return, and
user picture acceptance. Native-first timeout, quick-menu Keep/Return and
forced-host-close restoration also passed. Live 48 kHz audio, applied night mode,
shared quick presets and late-companion shutdown passed in the isolated host.
Next: clean candidate verification and controlled delivery. New sound source adds per-output
EQ, balance, mono, channel trims and optional night compression; synthetic/DSP
checks do not replace a live capture journey. Preserve accepted installed apps
until controlled update. Full BetterDisplay feature parity, native model
editing, virtual HDR/streaming and measured calibration are not established.

Deliver and install an excellent native macOS monitor utility for the user's
Samsung M80B, with Ukrainian by default and equivalent English support. Finish
and test v5 end to end before updating the public GitHub source and release.
Preserve working native volume keys and accepted Bass + sound during development.
The version number is not a substitute for the completion gates below.

## Requirements and acceptance

| Workstream | Required result | Acceptance and remaining work |
| --- | --- | --- |
| Interface and menu | Beautiful, coherent native Studio, compact quick controls, clear feedback, useful empty states, accessible labels/focus, light/dark and reduced motion | Setup navigation and summary label/value pairs were verified through CUA in UK/EN. Complete actual menu/desktop keyboard and accessibility journeys; fix observed usability defects. Spoken VoiceOver remains unverified. |
| Setup and portability | Guided first launch, easy monitor connection, skippable optional permissions, remembered per-display preferences and recovery | Five stages implemented; 24 local layout/state checks passed. Real fresh-Mac permissions/connection still needs acceptance. Never change mode/profile/output just by finishing Setup. |
| Native keys | Standard Mac volume/mute controls the selected Samsung speakers; normal Mac-speaker behavior after disconnect. Improve brightness keys and usable fallback shortcuts | User physically accepted volume/mute and disconnected fallback. Preserve that evidence; no repetition absent a new failure. Reboot/dock/update continuity remain. |
| Brightness | Smooth fine/coarse software dimming, quick presets/reset, optional linked screens; real backlight control only where verified | Existing dimming and capability-gated hardware controls remain. Resolve Samsung's vendor DDC discovery lead with bounded read-only investigation before any opt-in write experiment. Do not equate dimming with backlight power reduction. |
| Picture and scaling | Best supported text clarity, HiDPI/render-size/refresh choices, model/cable guidance, HDR only on a verified compatible path | Report actual macOS modes, preserve fractional refresh, timed independent rollback and per-monitor selection. Verify connected-M8 restoration and relevant HDMI/USB-C paths; do not invent physical refresh/HDR capabilities. |
| Color | Preserve original profile; built-in useful reference descriptions, panel-scoped ICC import/selection/undo and calibration provenance | Wrong-panel imports are rejected. Professionally measured accuracy requires this unit's instrument measurements; generic/vendor/M9 profiles must not be labeled calibrated. A correct profile also depends on picture mode/white balance/luminance conditions. |
| Sound | Real useful presets including bass enhancement, editable EQ, headroom/protection, bypass, route safety, native key control and honest format information | Accepted separate companion has four presets/eight bands, 43 DSP checks and live M80B PCM evidence. User accepted Bass +. Source now has 87 route/policy checks and 21 Address Sanitizer buffer checks. Complete start/stop/apply/output/sleep/long-session recovery coverage. No invented codec or physical bass extension. |
| Atmos and immersive sound | Investigate monitor Atmos effect, state/control and a compatible encoded playback path; Apple spatial sound only where actually supported | User confirms Atmos menu exists. Enabled state, remote command and encoded Mac playback remain unknown. Stereo EQ is not an Atmos decoder. Hide unavailable controls. |
| Desktop and widgets | Useful interactive desktop card plus the requested native WidgetKit integration where implementable | App-owned card exists; it is not WidgetKit. Native card show/pin/hide/reopen/focus and the user-reported medium preview widget/Sound link passed. Production navigation-widget packaging is implemented; production registration/gallery acceptance remains. Do not silently count the card as completion of the gallery request. |
| Samsung compatibility and research | Capability-driven M7/M8/M9 and useful S-series support; learn from official software, drivers, firmware and licensed open repos | Maintain version/hash/source/compatibility/experiment matrix. Inspect actual interfaces, not branding assumptions. No opaque installers/firmware execution, cross-model flashing or calibration transfer. Other models need their own hardware evidence. |
| Hardware identity and experiments | Identify exact panel/main-board/audio components where evidence permits, then test genuinely supported features | User label: S32BM801UI / LS32BM801UIXUA / Type S32BM801U / CA01. Factory configuration 32S6AUNEB is a distinct field. Exact fitted LCD/audio-chip mapping remains unknown. No speculative decoding or service-menu changes. |
| Reliability and consumption | Bounded reconnection, low idle work, coalesced events, safe sleep/wake/unplug/replug, failure recovery and stable preferences | Existing adaptive polling and route teardown verified in specific checks. Complete adverse-state matrix, longer runs and repeatable CPU/memory/wakeup observations; no unsupported battery claims. |
| Audit and 100 improvements | Maintain a substantive change ledger and audit UX, design, accessibility, features, reliability, performance, privacy, image, sound and distribution | Existing 100-entry ledger is an inventory, not proof of 100 successful live tests. Reconcile it with code and evidence. Record pass/fail/not-tested per criterion; do not invent perfect scores. |
| Local install and public delivery | Usable saved app in Applications, rollback/recovery, source/build reproducibility, verified ZIP/checksum/signature, GitHub updated after E2E | User has no Developer ID membership. Prepare honest ad-hoc local delivery and permission recovery; no paid account requirement for local use. Notarization is unavailable. Preserve accepted apps until controlled update/rollback is concrete. |

## Phone-assisted color research — added 2026-10-24

Investigate the user's Apple TV/iPhone Color Balance idea. Prioritize Samsung's
supported Smart Calibration path: official Samsung guidance lists Basic Mode for
Smart Monitor M70B and higher with compatible iPhones, but availability on this
regional M80B, picture mode and Mac input still needs direct confirmation.
Apple's feature corrects Apple TV output; do not claim it supplies a Mac ICC or
changes every source. No documented public third-party entry point was found in
the initial Apple documentation search. A custom phone-assisted workflow remains
an experiment until repeatability and independent instrument comparison establish
accuracy. Geometric camera calibration data is not a display colorimeter profile.
Keep exposure/processing, panel spectral response, viewing angle, ambient light,
picture mode and per-input applicability in the validation plan. No automatic
ICC/gamma/white-balance application from unvalidated phone readings.

## Execution order

1. Close observed native interaction defects: foreground desktop presentation,
   pin/hide/reopen, menu Controls/Scenes and keyboard focus, UK/EN equivalence.
2. Finish sound lifecycle and connected-monitor picture/profile/reconnection
   acceptance, using safe tests that restore state. Continue useful offline work
   when hardware or an unlocked UI session is unavailable.
3. Implement compatible high-value research findings and WidgetKit integration;
   retain a separate experimental boundary and recovery path for unverified work.
4. Reconcile the feature/audit/improvement ledger against actual source and test
   evidence. Fix release-blocking defects before adding lower-priority scope.

5. Build a clean sanitized v5 candidate; complete local end-to-end tests and
   controlled Applications update with verified rollback/permission recovery.
6. Only after that E2E gate, update GitHub source and release, verify remote CI,
   tree parity, public download checksum and extracted signature, and record the
   delivered version. Do not publish interim increments; user explicitly set this
   order on 2026-10-24.

Audio lifecycle checkpoint (2026-10-24): stale-result cancellation and startup
route revalidation are implemented; 21 synthetic controller checks also pass
under Thread Sanitizer, alongside 43 DSP checks and a verified companion build.
A separate synthetic preview verified native window startup cancellation and
UK/EN recovery messages; the sound menu and real hardware recovery matrix remain
open. This does not close the long-session gate.

Menu checkpoint (2026-10-24): explicit page focus, UK/EN arrow switching,
Command-Return to Studio, Escape and reopening focus passed native isolated checks.
Full button traversal with macOS Keyboard Navigation and spoken VoiceOver remain
open. Sound's shared native app menu passed synthetic preset/start/bypass and
Command-period checks; one-window reuse and corrected UK/EN guidance were observed.
The MenuBarExtra anchor and a real close/reopen cycle still need verification.

Widget checkpoint (2026-10-24): a sandboxed WidgetKit navigation prototype now
builds and embeds in the isolated preview; PlugInKit registration was observed.
Small/medium UK/EN variants use allowlisted navigation links, not live readings
or inline hardware controls. The host's URL parser is tested in both identities.
The user confirms native gallery discovery, correct medium preview rendering and Sound-link navigation; other sizes/locales and production embedding remain unverified. The temp host claimed the scheme
but had no Launch Services handler; a dedicated non-temp AppSupport preview
location resolved handler lookup and warm Safari Color/quick navigation passed.
This is host URL evidence, not native widget click-through. See Widget/README.md. Keep production embedding, live widget
state/controls and native acceptance open; the desktop card is still separate.

## Release completion gates

- Required software work above is implemented and usable; missing requested work
  is explicitly unresolved, not silently removed or called complete.
- UK/EN native interactions and meaningful regression/integration tests pass;
  release-blocking failures are fixed and adverse-state results are recorded.
- The installed update, rollback copy, native keys and sound route behavior are
  verified. A source build or isolated preview alone is not installed acceptance.
- Public source/release matches the tested implementation, CI passes and the
  downloadable artifact verifies. No private diagnostics, EDID/serials, pairing
  credentials, personal ICC files or proprietary vendor assets are published.
- Hardware/instrument-dependent results are clearly scoped: untested other-model
  hardware, acoustic/color measurements and encoded Atmos cannot receive assumed
  passes. A complete local software release must not claim those unknowns solved.

## Accepted baseline to preserve

- Installed M8 Studio: 3.0.0 development, native monitor volume/mute and unplugged
  Mac-speaker fallback physically accepted by the user. Executable SHA256:
  `d5df99c03f8b267cd9ecff90dfe3eab8af6ae90a0a9459cc56f44d6422e87710`.
- Installed Sound companion: 0.1.0, Bass + listening accepted as fuller/less harsh,
  live M80B 48 kHz stereo PCM verified. Executable SHA256:
  `efad6a81af68febc3bc82d30dc6a178b7e73cfcdd44d15fe146d7a61a12a0d71`.
- Working installed apps are frozen during independent development. Future ad-hoc
  builds may require macOS permission repair; do not weaken TCC/SIP or pretend
  ad-hoc updates guarantee permission continuity.
- Existing public sound beta and draft PR remain historical development outputs;
  full v5 is not released. Latest local-only work has not been published.

## Evidence and continuation

Use AUDIT-v5.md, Sound/README.md, SAMSUNG-DRIVER-FINDINGS.md and
SAMSUNG-SOFTWARE-FIRMWARE-RESEARCH.md for public-safe evidence. Private checkpoints,
exact device data and the 100-refinement inventory remain under Research/.
The previous four-hour automation is absent (the app rejected an update because
it no longer exists). Do not claim scheduled continuation or silently recreate
a possibly user-deleted automation. The thread goal API retains an older
unfinished objective and cannot replace its text; this versioned roadmap is the
consolidated current scope. Never falsely complete the old goal to rename it.


Advanced implementation checkpoint (2026-10-25): actual M80B virtual mirror
2560×1440/5120×2880 and 2400×1350/4800×2700 at 60 Hz verified. User accepts
picture/text without flicker. Timed return and Keep/Return restore exact physical
mode, origins, mirrors, profiles and audio snapshot. A fresh configurator process
fixes creator-process CoreGraphics mode-cache failure. Native model overrides
are not implemented by this fallback. New controls have 65 DSP, 52 actual-model
(TSan also passed), 25 display-assistance and 19 virtual-policy checks. See
AUDIT-v5.md for limits and remaining live/new-build acceptance. No interim GitHub
publication or accepted Applications replacement has occurred.
