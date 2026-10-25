# Samsung software and firmware research — 2026-10-24

Static investigation for the v5 goal. No downloaded installer, app, helper,
script or firmware was executed or installed. No firmware was flashed. Original
packages and extracted copyrighted resources remain private research material,
outside the public-source tree. Findings do not establish a hardware unlock.

## Packages and provenance

| Package | Official source | SHA256 | Inspection |
| --- | --- | --- | --- |
| Samsung Display Manager macOS 1.0.0, 79,099,296 bytes | [S80UD support](https://www.samsung.com/nz/support/model.LS32D804UAEXXY/), SW/202605/20260511134834918 | `3310f019e723240523f686910b5a8e824b15730d65db5686c8090dad04ba2bde` | pkgutil static expansion, signature metadata, plist, resources, strings |
| Display Manager manuals archive, 4,468,581 bytes | Same support page, SW/202509/20250929153505772 | `d8bf6334ffa7cf918bc8f5e75e3fc89851214a5a3fd298ceb68128392c4ec8e8` | English/UK PDFs and newer English manual inside Mac package |
| Easy Setting Box macOS 3.1.6, 53,797,590 bytes | [Exact M80B support](https://www.samsung.com/ua/support/model/LS32BM801UIXUA/), SW/202501/20250120110820849 | `c46ef526eb70892b8cc937410346ebed288c1c81c5e96584851a759028c2e14f` | pkgutil static expansion and Mac manual |
| Easy Setting Box Mac manual, 4,781,551 bytes | Same M80B download entry | `21e95723b4d07fb31a4db27b937d1b702bb1b78e67298bce8228adb28bf007de` | Text inspection; window-layout and mouse-travel workflows |
| S80UD M-D8000SGZZ-1005.0[03D1].zip, 943,240 bytes | S80UD support, FM/202509/20250912110919956 | `69b4b2430fdb7c6ea5566093279102df4dc2f77507d9a20b891807e49a63973d` | Archive contains one 3,499,968-byte IMG; header and readable strings only |
| M80B T-PTMWWC 1720.7 | Exact M80B support, FM/202605/20260508160345100 | Full archive **not downloaded or hashed** | Bounded HTTP ranges: ZIP directory and two small entries; decompressed entry lengths/CRCs checked |

## What the current Mac package establishes

Its main executable is universal arm64/x86_64; Info.plist reports version 1.0.0,
identifier com.samsung.Samsung-Display-Manager and minimum macOS 14.0. This is
stronger package-specific evidence than older support articles that simultaneously
mention macOS 12 and future Mac support. It does not prove runtime compatibility
on every listed OS/monitor. pkgutil reports trusted notarization and a Developer
ID Installer signature; the observed certificate subject is Tran Luu, not an
inference of Samsung authorship from a certificate name. Official download-host
provenance is recorded separately.

The included 63-page English manual's page 19 was rendered and inspected. It
separates Smart Monitors (floating menu/split screen) from regular Samsung
monitors (additional picture/game/KVM/PIP-PBP/general controls). Those regular
monitor functions must not be assumed writable on M80B. A bundled SQLite schema
separates monitor types, per-monitor presets, application overrides, input
favorites, split layouts and KVM records. It is a design reference, not a database
of hardware capabilities or calibration.

## Implementation candidates and transfer gates

| Candidate | Evidence | M80B relevance and implementation gate |
| --- | --- | --- |
| Better DDC discovery | Binary strings describe an EasyBox GET/SET EB negotiation around capability reads, plus legacy fallback; Rust ddc_macos ARM/Intel paths are present | A genuine research lead, **not a verified unlock**. Determine protocol semantics and supported models first; start with bounded read-only queries on the selected display. Do not send guessed vendor writes. |
| Capability-driven hardware controls | SDM distinguishes regular/Smart monitors and verified capabilities | Strengthen current readback gating. Offer a control only after its actual service/range is established; never enable S-series controls just because an M8 uses Samsung branding. |
| Workspace grids and reusable layouts | Easy Setting Box Mac manual describes adjustable window zones | Potentially useful on M8 without panel firmware changes. Independently implement native window behavior, review AX permission scope, exclusions, multi-display placement and undo. Do not copy UI assets. |
| App-specific display scenes | SDM database describes per-app picture overrides | Use opt-in reversible scenes with precedence/manual pause; no arbitrary ICC swapping or automatic destructive input switch. Verify focus-change and crash recovery. |
| Input favorites / PIP-PBP / KVM | SDM regular-monitor manual and schema | S-series candidates only where hardware/API readback confirms support. M80B remote input selection is distinct from inventing physical KVM or PBP. |
| Smart monitor pointer travel | Official manuals describe same-network/USB prerequisites and optional model support | Investigate separately; no hidden keyboard capture or opaque vendor service installation. Existing paired remote does not establish this protocol. |
| Hardware passport | Driver identities, EDID, actual Core Audio formats, factory-type evidence | Separate reported signal, manufacturer claims, observed configuration and exact part IDs; avoid serials in public diagnostics. Unknown part IDs stay unknown. |
| Firmware guidance and recovery | Exact package directory, metadata and official USB instructions | Validate model/platform/version, retain settings, warn about automatic USB update; no cross-model flashing, downgrade or region-reset feature. |
| Screen Color Match / calibration | SDM documentation describes hardware/model/Galaxy dependencies | No basis to import another panel's calibration or label a phone/reference profile instrument-accurate on this M8. |
| OLED-specific taskbar protection | SDM docs/resources | Not applicable to the M80B VA panel; keep it out of this monitor's normal controls. |

## Firmware findings and boundaries

The M80B ZIP is 1,671,303,637 bytes. Its five directory entries include
T-PTMWWC/image/info.txt, upgrade.msd and SWU_AUTO_FLAG. The small metadata entry
confirms major 1720, minor 7 and build date 2026-02-24; the auto flag contains 1.
The platform/key-type labels mention PontusM and AES-256-CBC/SHA512. These are
labels, **not recovered cryptographic keys, a chip ID or a decrypted payload**.
The 1.67 GB upgrade.msd payload was not fetched/decrypted/disassembled. No audio
fix or hidden capability is established by its metadata. The user's shortened
1720 display still does not prove an older version than 1720.7.

The S8 image starts with NVTSC_IMG and includes readable DDC event, T-CON,
calibration and USB-C controller update diagnostics. These show firmware has
model-specific display/controller paths; they do not identify the M80B hardware
or provide a portable Mac audio/display driver. No calibration blob or firmware
code was transferred into Studio.

## Internal component identification

The user's existing photo provides a factory panel-type configuration, retained
in private checkpoints. It is more specific than EDID's monitor assembly name,
but no authoritative mapping to an exact fitted LCD or audio DSP was found.
Do not decode supplier letters speculatively or alter the factory Type setting.

[Samsung Parts lists BN95-08496A as LCD-CSOT](https://samsungparts.com/fr/products/bn95-08496a)
and [BN94-17471A as a main PCB assembly](https://samsungparts.com/fr/products/bn94-17471a).
These are catalog leads, not confirmation that those exact revisions are fitted
to LS32BM801UIXUA. Regional/model revision matching and actual chip markings/BOM
remain unresolved. No codec/amplifier silicon part number is confirmed. Preserve
that distinction in future UI and experiments.

## Next verification

Resolve the vendor DDC negotiation semantics, exact unit's panel-type mapping and
audio/main-board BOM before exposing an experiment. Finish native menu/desktop
interactions and recovery independently of that research. Keep licensing and
capability evidence with every implemented candidate. Public GitHub publication
remains deferred until the user's v5 end-to-end delivery gate is satisfied.
