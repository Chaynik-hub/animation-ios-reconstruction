# Progress — 2026-11-02 update

NOT COMPLETE. Do not distribute an intermediate IPA as an exact copy. Final packaging is gated by parity_requirements.json.

Original APK now runs in a hardware-accelerated Android 11 emulator in private Actions. Screenshots/XML cover onboarding, sword attachment, goal selector, subscription close, the hand-drag practice and landing/privacy screen. These are controlled CLI runtime observations; REA JSON is static evidence. The initially hidden editor controls are explicitly hidden by OBPracticeMove.InEditor.start, not missing normal app features.

Native additions: separate full-screen preview; rigid branch rotation and connected assembly movement; original FABRIK passes with angular limits, side-branch transforms and fixed/kinstop roots; attachment propagation; hold-Shift stretching and longitudinal bitmap stretch; frame interpolation with master-first attachment reconciliation, changed-link detachment and absent-assembly exclusion. Catalog expanded to 542 original definitions with scale/translation/state selection. XML writer and opaque-entry ATS preservation are implemented, and embedded custom ATI artwork loading is implemented; the original practice ATS import passed a simulator UI check. Full format compatibility remains unverified.

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

## Resumed verification
Commit 993da05: Actions 41481002665 passed 25 core XCTest tests; Actions 41481003330 passed both UI tests. Full-display screenshot inspected after download to out/resumed-window-validation: landscape window is 874 x 402 points, with canvas and both toolbars visible. Full visual parity remains unverified. See resumption-report-2026-11-02.md for the current report.

## Frame panel port (23288f6)
Original frame operations context column now uses original icons, observed row geometry, scroll, active toolbar highlight and no scene dimming. Clipboard insertion follows the original special case at frame zero and retains current numerical index. Native saved-scene insertion supports compatible artwork; different custom artwork packs, range selection and original timeline metadata remain incomplete. Core Actions 41486219699 passed 27 tests; simulator Actions 41486221286 passed 3 UI tests. Final entire-display screenshot inspected. See frame-panel-port.md.

## Reported phone bugs repaired (87b1aa2)
Replaced modal flat catalog with in-editor original pack covers and manifest folders, with back/close/toggle. Added explicit preview Back, frame number, finite playback and replay. Corrected UIImage alpha for onion skin and added skeleton edges. Connected-object duplicate/delete now preserve assembly structure; rendering respects arrange. Actions 41490559944 passed 30 core, 2 hosted rendering and 4 UI tests. Final catalog screenshot inspected. Preview IPA built in 41490599443 by explicit preview mode; full parity gate remains intact for final builds. See reported-bugs-fixed.md and current-repair-checkpoint.md. Original unit properties UI and the other recorded parity gaps remain unfinished.
