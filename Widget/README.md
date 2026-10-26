# Native WidgetKit development prototype

This is a real sandboxed macOS WidgetKit extension, separate from the app-owned
desktop card. It currently implements **navigation widgets**, not live monitor
readings or inline hardware changes. It is included in new production candidate builds, with identity
`local.M8Studio.Widget` and production `m8studio` navigation links. The accepted
installed app is unchanged. Live state and production-gallery acceptance remain
open; preview gallery acceptance does not certify the production host.

`zsh build-preview.sh --widget` embeds the extension in the isolated
`local.M8Studio.Preview` host. `zsh build-widget-preview.sh` builds just the appex.
Both use ad-hoc signing without changing the accepted Applications apps. Launch
the isolated host through native UI before checking WidgetKit discovery.

The bundle contains Ukrainian and English variants, each with small and medium
families. Ukrainian is listed first; choosing the English variant is explicit.
Small opens quick controls; medium has Controls, Display, Sound and Scenes links.
The design provides light/dark colors. The user accepted the medium preview
widget rendering and its Sound link; other sizes/locales remain unverified. No made-up brightness, volume or connection values appear.
The navigation timeline uses `.never`: no repeating polling or hardware access.

The only entitlement is App Sandbox. There is no microphone/audio/display access,
network client entitlement, shared credential container or copied personal ICC.
Shared live state and inline controls need a separately designed and verified
communication/signing path; this prototype must not be presented as that result.

## Navigation boundary

The production host declares `m8studio://open/<destination>`. Preview host and
widget use `m8studio-preview` instead. `StudioRoute` accepts only seven fixed
navigation destinations. It rejects query strings, fragments, credentials, ports,
foreign schemes and paths/commands outside that list. Links do not apply settings,
choose outputs, change a mode, read a file or supply a monitor address.

Cold-launch quick navigation waits at most one second for the status item, then
falls back to Studio. New requests cancel older pending navigation. This path
builds. Warm Safari-to-host Color/quick routing passed from a dedicated non-temp
AppSupport development location. Cold startup and widget click-through remain open.

## Evidence, 2026-10-24

- Extension and embedded isolated host compile, sign and verify with the installed
  Command Line Tools. Full Xcode and app-intent metadata tools are not installed.
- After native isolated-host launch, read-only PlugInKit reports one registered
  `local.M8Studio.Preview.Widget` at the embedded appex path. Registration is not
  proof of gallery rendering or successful timeline execution.
- Route parser boundary tests run in production and preview configurations.
- Safari rejected the preview custom URL. Read-only Launch Services showed the
  scheme claimed by the temp-directory host but no default handler. Explicit
  registration did not resolve the temp host. Staging the isolated preview under
  Application Support resolved handler lookup and warm native URL navigation.
  No security setting or trusted installed identity was changed.
- CUA could inspect Finder's Desktop but could not act on its desktop container
  or empty-background coordinates. Notification Center inspection timed out.
  Automation did not verify gallery interaction. The user subsequently confirmed
  that M8 Studio appears, the medium preview renders, and Sound opens Sound Studio.
- Production app builds with the new navigation handler. Accepted installed
  apps remain unchanged; no interim GitHub publication is authorized.

Production packaging now checks the nested signature, host/extension version,
exact extension file inventory and sandbox-only entitlement. The extension has no
App Group, audio capture, network or monitor control entitlement. Building does
not register or launch it. Native production gallery/click-through after controlled
installation, other families/locales and any future live data/controls remain gates.
