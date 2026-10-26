# BetterDisplay interoperability and feature study

Investigated 2026-10-24. Static analysis and primary documentation, not execution
or modification of BetterDisplay. The application was not installed or launched.
Vendor binaries and strings remain outside this source repository. No proprietary
code, assets or licensing components are bundled into M8 Studio.

## Evidence inspected

The official GitHub release API lists v5.1.1, published 2026-10-06. The downloaded
[official DMG](https://github.com/waydabber/BetterDisplay/releases/tag/v5.1.1)
SHA256 is `533ce08c91a02e0fdca2bc0e461404968ab18d32bbd9fd3314218e1a8d51c1de`.
A bounded 7-Zip extraction read the app/helper executables and Info.plist only.
Metadata identifies `pro.betterdisplay.BetterDisplay`, version 5.1.1, minimum
macOS 26.3, with Intel and ARM executable slices. `codesign -d` reports a
Developer ID signature and hardened runtime. This is signature metadata on an
extracted executable, not full-resource verification or a notarization assessment.

Static imports include CoreDisplay, private DisplayServices, ScreenCaptureKit
and Metal. Undefined symbols include CoreDisplay display-info queries,
DisplayServices brightness functions and CGVirtualDisplay classes. These are
architecture leads, not recovered implementations or proof they work on an M80B.
The examined landing repository contains documentation rather than app source.

The separate [betterdisplaycli source](https://github.com/waydabber/betterdisplaycli)
is MIT-licensed. Its code serializes commands/parameters, correlates UUID replies
and exchanges distributed notifications with the running app. It is a client,
not a display driver or standalone implementation of flexible scaling. It was
read, not executed or bundled. M8 Studio's existing MIT m1ddc dependency is also
by this developer; it remains the separately attributed hardware-control path.

## Priorities for M8 Studio

These are our implementation judgments, not claims of BetterDisplay parity.

| Feature | Current evidence and proposed work |
| --- | --- |
| Favourite modes and quick scaling | High value now. Add per-display stable favourites and a menu-bar size picker, using enumerated macOS modes and existing timed recovery. New independent implementation; no vendor code. |
| Finer native HiDPI range | Investigate separately. BetterDisplay's [current scaling tutorial](https://betterdisplay.pro/guide/tutorials/fully-scalable-hidpi-desktop/) describes model overrides with activation/authorization and a virtual-screen alternative. Our favourite picker does not generate extra modes or reproduce that engine. |
| Resolution clarity | Show logical size, render buffer and actual output separately. The tutorial explains that extra rendering detail does not increase panel pixel count. Retain M80B-specific 4K/60 Hz guidance. |
| Reconnect protection | Add explicit per-display opt-in recovery for a saved mode/profile/layout only when still available. BetterDisplay's [configuration protection](https://betterdisplay.pro/guide/interface-reference/app-menu/device-menu/configuration-protection/) also distinguishes unavailable settings. Avoid fighting deliberate user changes or repeatedly reinitializing a display. |
| Controller explanation | Make selected volume/brightness provider and missing capabilities visible. The [Samsung controller](https://betterdisplay.pro/guide/interface-reference/settings/displays/display/device-control/network-controllers/samsung/) sends relative keys; pairing does not supply every capability. Retain M8 Studio's physically accepted absolute-volume/readback path. |
| Audio device association | Preserve exact output matching and stop on output change. The [audio configuration guide](https://betterdisplay.pro/guide/interface-reference/settings/displays/display/device-control/volume-control/) separates software/native/hardware volume and mute. Do not replace our strict matching with broad name guesses. |
| Audio enhancements | Independently consider balance, mono, channel trims, optional dynamics and per-output presets. BetterDisplay's [software-audio guide](https://betterdisplay.pro/guide/interface-reference/settings/displays/display/device-control/software-audio/) exposes these with explicit access and format requirements. Its loudness control is not acoustic calibration. Keep accepted Bass+ unchanged until each new DSP path has numerical/recovery/listening checks. |
| UI-size matching | Use reported physical dimensions cautiously to suggest, then preview, a similar UI size across displays. [UI Scale Matching](https://betterdisplay.pro/guide/interface-reference/settings/groups/group/ui-scale-matching/) is a useful product reference; EDID dimensions and each display's available modes need verification. |
| HDR/color/3D LUT | Separate image effects from calibration. Extra brightness is hardware/path dependent. A LUT requires known input/output conditions and validation; M9 OLED correction must not be applied to M8. Do not infer a working HDR or RGB-range override from imported symbols. |
| PIP and virtual displays | Useful experimental branch for missing scaling or teleprompter workflows. ScreenCaptureKit capture requires explicit access; CGVirtualDisplay/private interface stability needs OS-specific validation. Not part of the new favourite-mode feature. |
| Diagnostics and automation | Add useful read-only connection/provider reports and tightly scoped automation. The MIT CLI demonstrates IPC plumbing, not authority to expose unrestricted display commands through URLs or HTTP. Existing navigation-only links stay allowlisted. |

## First implementation and limits

Source/ModeFavorites.swift stores up to eight validated favourites per display,
using logical/render dimensions and fractional refresh rather than transient
mode IDs. Scaling Explorer stars manage them. Quick Controls offers Desktop size,
favourites first and common reported sizes. Unavailable saved modes are omitted
without deletion so they can return with the matching connection. Choosing a mode
uses the existing independent rollback helper; adding/removing a star changes only
app preferences. No model override, custom timing, firmware or display disconnect
is performed by this work. Test/build/native evidence belongs in AUDIT-v5.md.


## Implemented follow-up — 2026-10-25

Independent code now provides per-display reconnect review for saved size/profile,
visible brightness/volume/EQ control paths and advisory physical text-size
matching. Apple's [screen-size API](https://developer.apple.com/documentation/coregraphics/cgdisplayscreensize(_:))
may estimate dimensions when EDID is unavailable; the UI labels the result an
estimate and requires a preview.

Advanced scaling uses an exact reported 2× mode first, otherwise an opt-in M80B
virtual canvas with 16-pixel width steps. This is the virtual presentation path,
not a native model override or full BetterDisplay parity. Chromium's BSD display
utility documents the private ABI; original lifecycle/mirror/recovery code is
in Tools/VirtualCanvas. A fresh configurator process addresses creator-side mode
visibility, consistent with [this implementation's documented investigation](https://github.com/go-macos/virtualdisplay).
Connected M80B 2560 and 2400 logical-width tests, intended mirror direction,
automatic return and Keep/Return passed; the user accepts correct text/picture.
Exact pre/post configuration snapshots match. HDR, colorimetric accuracy,
latency, reboot/dock behavior and all generated sizes remain unmeasured/untested.

Optional stereo balance, averaged mono, attenuation trims, linked night compression
and per-output saved sound settings are independently implemented. The accepted
EQ defaults are retained. Numerical/model/native preview evidence is recorded in
AUDIT-v5.md. Connected-M8 48 kHz PCM processing and late-companion shutdown
passed in the isolated test host. Controlled installation and longer physical
recovery remain separate gates. Native-first selection, quick-menu return and
forced-host-close restoration also passed on this M8; none establish HDR,
colorimetric or latency parity.
