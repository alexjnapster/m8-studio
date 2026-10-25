# Controlled local v5 update and rollback

This is the local delivery procedure for the user's accepted ad-hoc builds.
It does not install an update, reset permissions or imply that v5 is complete.
The public GitHub update follows the local v5 E2E gate.

## Baseline evidence collected 2026-10-24

Both accepted Applications bundles were signature-verified and privately archived
with `ditto`. Each archive was extracted outside the synced workspace; its code
signature, executable SHA256 and designated requirement matched the installed
original. The installed executables were checked again after archiving.

The private snapshot is under `~/Library/Application Support/M8Studio/Backups/`.
Its `manifest.json` records the archive hashes, executable hashes, versions,
bundle identifiers and signing requirements. The exact local path is recorded
in the gitignored `Tests/v5-accepted-rollback-path.txt`. It may contain private
installed resources and must never be published.

The accepted apps' designated requirements bind their current code hashes.
Rebuilt ad-hoc apps therefore must not be assumed to retain macOS permission.
The verified archives preserve the old binary identities; actual permission
behavior after an update or rollback still needs a controlled native check.
No TCC, Keychain, pairing credentials or preferences were changed or backed up
by this binary snapshot. It is not a complete system-state backup.

## Promotion gate

1. Complete the required software and local v5 E2E checks in ROADMAP.md. Reconcile
   open items explicitly; fixture/layout passes cannot replace native acceptance.
2. Build a clean candidate from a recorded source commit, excluding personal ICC,
   raw diagnostics and credentials. Verify its version, intended bundle identity,
   archive checksum and extracted signature outside the synced folder.
3. Recheck the installed baseline against the snapshot manifest. If it changed,
   stop and inspect the change; never overwrite a different build by assumption.
4. Review preference compatibility. If a candidate migrates settings, privately
   export the app-owned preferences immediately before promotion. Do not export
   Keychain credentials or publish preferences. Avoid restoring stale settings
   over subsequent user changes.
5. Quit both utilities normally before replacement, ensuring EQ has restored
   native playback and no old media-key process remains. Do not force the user's
   output to Samsung or kill an active audio process to make a test pass.
6. Stage the verified candidate outside the synced workspace, then perform the
   controlled Applications replacement. Do not re-sign the archived baseline.
   Any required macOS authentication or permission approval is performed directly
   by the user; no database edits or security-setting bypasses.
7. Verify the installed executable hash and signature, then perform native launch,
   permission/keyboard ownership, monitor audio and disconnected fallback checks
   appropriate to the new identity. Previous accepted tests remain evidence for
   the old build, not automatic acceptance of the new one.

## Recovery gate

If the installed candidate fails, quit it normally. Verify the selected rollback
archive against its manifest, extract into a separate non-synced staging folder,
and verify the restored bundle's signature, executable hash and requirement
before returning it to the exact Applications path. Launch that restored copy
and check the observed failure has cleared. Do not keep running mixed copies.

Archive/extraction identity checks passed for both baseline bundles. Actual
Applications replacement, rollback launch and TCC continuity have **not** been
performed. This procedure is reviewable preparation, not a completed update.
The user has no Developer ID membership; notarization is unavailable for this
local delivery and no membership request is pending.

## Clean candidate packaging

After committing reviewed changes, run `python3 Delivery/build-candidate.py`.
It refuses a dirty checkout and existing output directories, exports exactly the
committed file inventory, and builds in a temporary non-synced directory. It runs
policy, Carbon, DSP, buffer, lifecycle, integrated-model and route checks plus
widget compilation. The unified candidate packages the main app with its
navigation-only widget extension. Nested identity, version, file inventory,
sandbox-only entitlement and signature are checked; production gallery acceptance
is still required after controlled installation.

The source ZIP rejects private research/diagnostic directories, environment files
and EDID/ICC/ICM/HEIC resources. The app's Resources tree must exactly match
committed public resources and explicit build products; the extracted app's
signature verifies outside sync. The output includes source/app ZIPs, checks,
SHA256SUMS and a manifest tied to the commit. Byte-identical repeated binaries
are not established. Never substitute this packaging result for native E2E.

The script never launches, installs or publishes anything. Its manifest explicitly
marks a development candidate, with no installed, production widget-gallery, real capture,
permission, acoustic/color calibration or completed-v5 acceptance. Public GitHub
publication still follows the full local gate.
