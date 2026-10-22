# Working goals and acceptance gates

Updated 2026-10-22. This is an ongoing project, not a certificate of completion or a claim of perfect hardware quality.

1. Verify physical media-key and global-shortcut delivery after the user grants macOS permission. Verify real Samsung volume/mute while connected. Keep ordinary Mac output behavior intact.
2. Reduce idle work without losing timely audio-route or display changes. Prefer notifications, coalesce bursts, allow timer tolerance, and measure CPU/memory before and after. Keep battery-life claims separate from short CPU samples.
3. Expand Samsung compatibility by actual services, not a model-name promise. Collect opt-in hardware evidence for M5/M7/newer M8/M9 and smart Odyssey models. Expose only confirmed controls.
4. Keep Ukrainian complete and default, with equivalent English functionality. Audit menu, window, keyboard, VoiceOver, light/dark and reduced-motion behavior.
5. Preserve safe mode preview/recovery, correct scene targeting, profile undo and no invisible dimming. Improve integration coverage across disconnect/reconnect and sleep/wake.
6. Keep color/HDR/audio advice specific to the actual model, cable and Mac. Measured calibration, HDMI HDR and acoustic testing remain external measurement/hardware dependencies.
7. Maintain public source and reproducible builds, respect upstream licenses, and never publish device addresses, private profiles or credentials. Add stable Developer ID signing/notarization when a signing identity is available.
8. Continue the existing substantive-improvement ledger and evidence-based audits. No self-awarded perfect category scores where evidence is missing.

Current pending work: physical hotkeys and final paired remote approval; other Samsung hardware tests; longer energy measurements; HDMI HDR verification; measured panel/acoustic calibration; stable signing. Public CI is intended for build/policy checks and cannot certify physical monitor compatibility.
