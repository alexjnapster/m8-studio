# Virtual canvas host

Original process lifecycle, input policy, mirror setup and restoration code.
The private CoreGraphics Objective-C interface declarations were cross-checked
against Chromium's BSD-licensed `ui/display/mac/test/virtual_display_util_mac.mm`:
https://chromium.googlesource.com/chromium/src/+/HEAD/ui/display/mac/test/virtual_display_util_mac.mm

No BetterDisplay implementation is included. Private interfaces can change across
macOS versions. The host is an explicitly started M80B experiment, not a native
model override or an advertised stable display driver. Runtime class availability
and compilation are not proof that a physical mirror or recovery works.
