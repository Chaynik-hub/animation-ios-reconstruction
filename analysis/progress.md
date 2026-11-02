# Progress — 2026-11-02 update

NOT COMPLETE. Do not distribute an intermediate IPA as an exact copy. Final packaging is gated by parity_requirements.json.

Original APK now runs in a hardware-accelerated Android 11 emulator in private Actions. Screenshots/XML cover onboarding, sword attachment, goal selector, subscription close, the hand-drag practice and landing/privacy screen. These are controlled CLI runtime observations; REA JSON is static evidence. The initially hidden editor controls are explicitly hidden by OBPracticeMove.InEditor.start, not missing normal app features.

Native additions: separate full-screen preview; rigid branch rotation and connected assembly movement; original FABRIK passes with angular limits, side-branch transforms and fixed/kinstop roots; attachment propagation; hold-Shift stretching and longitudinal bitmap stretch; frame interpolation with master-first attachment reconciliation, changed-link detachment and absent-assembly exclusion. Catalog expanded to 542 original definitions with scale/translation/state selection. XML writer and opaque-entry ATS preservation are implemented, but embedded custom ATI artwork loading is still pending.

Validation: FABRIK core checks passed in Actions 41470683209; frame attachment interpolation checks passed in 41473288372; native build/UI test with separate preview passed in 41472070900. These passes cover specific scenarios, not complete original parity.

Still incomplete: full normal UI/panels, landing/onboarding, constructor/vector/freehand, custom packs and full ATS/ATI round trip, camera/background animation, effects/visemes/dialogues, variable speed, original audio/export settings, gestures and pixel comparisons. No new IPA delivered.

## Historical initial implementation (superseded)

REA6.8.0 connected. Original APK0.6.1(397) analyzed.1339 raw assets extracted; Android resources decoded. Focused editor/frame/unit/joint/interpolation/bitmap-drawing evidence saved.
Native core: XML geometry reader and unattached skeletal interpolation; four tests pass on macOS.
Native UIKit application: original140 bitmap objects, joint/descendant dragging, copy/delete/flip, frame insertion, undo/redo, onion skin,60Hz playback, JSON save/load, basic ATS/XML read, audio import/playback, PNG/GIF/MP4 export and soundtrack mix.
Device compilation succeeds. Simulator install and launch fixed by renaming reserved Resources directory to Content. Screenshot from Actions41455293825 downloaded and viewed. Native UI test in41455440874 passed character selection, second frame creation, play and stop. Final autosave/icon build41455852780 pending.
No physical phone verification or Android reference screenshots exist. User has no Android device.

NOT COMPLETE: landing/onboarding, full ATS/ATI compatibility, vector and freehand constructor, attachment/IK/constraint parity, custom packs, camera/background keyframes, effects, visemes, speed curves and full panel parity remain. No exact parity or finished status is claimed. See functionality_map.md.
Builds use private GitHub Actions macOS runner, final IPA must be signed through Sideloadly as previous apps.
