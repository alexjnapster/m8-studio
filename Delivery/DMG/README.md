# Drag-to-Applications DMG

The image wraps a previously verified clean candidate. It does not rebuild or
re-sign the app, install anything, start capture, change display settings or
alter macOS security. The embedded app remains ad-hoc signed and unnotarized.

Create a temporary Python environment, install the pinned build-only packages
from `requirements.txt`, then run:

```sh
python Delivery/build-dmg.py --candidate /path/to/verified-candidate --output /path/to/new/M8-Studio-v5-preview-arm64.dmg
```

The candidate must contain its original manifest and matching app ZIP. Output
must not exist. macOS Command Line Tools and hdiutil are required. A generated
AppKit background and Finder metadata provide a Ukrainian/English drag-and-drop
window. The only shortcut points to `/Applications`; there is no installer script.

Checks cover input checksum/executable identity, the nested app signature before
and after imaging, image integrity, read-only mount, shortcut destination, and
signature/hash preservation after a disposable copy. Actual replacement and
permission continuity on an installed Mac remain separate acceptance gates.
The builder never launches the app or modifies the real Applications folder.

The build-only dependencies are the upstream MIT-licensed
[ds_store](https://github.com/dmgbuild/ds_store) and
[mac_alias](https://github.com/dmgbuild/mac_alias) packages. Their code is not
bundled into M8 Studio. Python writes the documented Finder metadata interface;
no AppleScript or GUI automation is used by the build recipe. File-format
availability does not establish rendering; inspect the mounted image in Finder.
