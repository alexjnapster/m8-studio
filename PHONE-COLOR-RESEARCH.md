# Phone-assisted display color balance — feasibility investigation

Investigated 2026-10-24 for the user's M80B and macOS v5 project.

## Primary evidence

- [Apple explains its Color Balance process](https://www.apple.com/newsroom/2021/04/apple-unveils-the-next-generation-of-apple-tv-4k/): the iPhone light sensor provides measurements and Apple TV adjusts its own video output, without changing the television's settings.
- [Apple's current calibration guide](https://support.apple.com/guide/tv/calibrate-video-and-audio-atvb228b7711/tvos) describes Color Balance using an iPhone with Face ID and iOS 14.5 or later. It documents the Apple TV workflow, not a general-purpose Mac calibration service or exportable ICC.
- [Samsung Smart Calibration guidance](https://www.samsung.com/in/support/tv-audio-video/how-to-use-smart-calibration-on-samsung-smart-tv/) lists Basic Mode for Smart Monitor M70B or higher and compatible iPhones. It describes Movie-mode adjustment, same-router connectivity and model-dependent availability. This family listing is not proof of availability/effect on the user's regional unit or PC input.
- [AVCameraCalibrationData](https://developer.apple.com/documentation/avfoundation/avcameracalibrationdata) describes camera geometry, intrinsics and lens distortion. Its name must not be mistaken for calibrated spectral/colorimetric response.

## Decision and implementation sequence

1. Check the user's iPhone model and whether SmartThings exposes Smart Calibration for this M8. The user confirms iPhone 17 Pro Max; do not ask the model again. SmartThings Smart Calibration menu availability remains unanswered. Face ID support alone does not establish Samsung compatibility.
2. If available, preserve current picture/input/profile settings, follow Samsung's supported workflow and identify exactly which picture mode/input was altered. Do not run it unattended or reset picture settings as a casual recovery action.
3. Re-check the actual Mac input. A successful monitor Movie-mode calibration does not prove PC-mode or HDR accuracy. Existing ICC characterization may no longer describe the new monitor settings; do not stack an unverified correction with another profile.
4. If Samsung's supported path is unavailable, research a separate opt-in iPhone companion: synchronized reference patches, explicit camera permission, locked camera conditions where supported, robust patch detection and rejection of clipping/unstable reads. Sensor calibration, spectral mismatch and tone mapping must be characterized before interpreting camera RGB as display XYZ.
5. Begin with repeatability and relative comparisons, not automatic system-wide color correction. Require independent colorimeter/spectroradiometer validation before calling a result measured calibration or advertising numerical color accuracy. Keep a reversible comparison and provenance per display, input and picture mode.

## What is not established

No public third-party API to invoke Apple's Apple TV Color Balance protocol was
found in the initial documentation search. This is a search result, not proof
that no private implementation exists. No Apple protocol or private sensor
calibration has been reverse engineered in this project. No iPhone measurements,
monitor correction, ICC generation or measured improvement has been performed.
No phone-based color-balance feature is currently implemented in Studio.

The most useful immediate candidate is supported Samsung calibration with
careful Mac-input verification. A home-built camera workflow can be researched,
but an attractive before/after or lower camera RGB error alone cannot establish
absolute display accuracy.

[Apple specifications](https://www.apple.com/ie/iphone-17-pro/specs/) confirm Face ID on iPhone 17 Pro Max. No specific Samsung confirmation for this phone model was found in this pass.
