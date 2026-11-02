# Frame operations panel port

Source: original APK SHA256 03bad059f228e2d0796e44eb74e373a30b9539d8b7bc29efc5a51cabf5a352b4.

## Evidence

- decoded/resources/res/layout/frag_lay_frame_ops.xml: ordered vertical commands, hidden heading, 4dp left accent, 12sp text.
- analysis/android-reference/editor-panels/panel-frame.png and .xml: panel at x=80..166, buttons at x=84..166; first four rows 81 pixels high, scene row 95 pixels high. These are observed coordinates on the reference emulator, not universal density-independent measurements.
- analysis/evidence/FrameOpsFragment-onClick.json: add/delete/copy/paste handlers and saved-scene selection.
- analysis/evidence/FrameOpsFragment-updateUI.json: paste disabled at alpha 0.2 when no frames are available; deletion depends on canDeleteSelection.
- analysis/evidence/Scene-pasteFrames.json and Scene-pasteFramesAtIndex.json: paste before frame zero, after other current frames, generate fresh IDs.
- analysis/evidence/MainEditor-onFramesPasted.json: numerical current index retained.

## Native changes

App/FrameToolsPanel.swift uses original PNG assets, an 86pt context column with a 4pt accent, scrollable 81pt rows, and a 95pt scene row. This matches the observed reference geometry at scale 1; broader device scaling remains unverified. The scene is not dimmed. The main frame-tools button highlights while open. Tapping it again closes the panel. Commands leave the panel open, and enabled states refresh on document changes.

Sources/AnimationCore/FrameClipboard.swift supports copying frame snapshots into documents, including multiple frames for scene insertion. Current UI copy selects one frame; selected-range copy is not yet ported. New frame IDs preserve unit names and attachment references within each copied frame.

Scene insertion currently lists native saved JSON projects and inserts their frames rather than replacing the active document. Projects with a different embedded artwork directory are explicitly blocked; original saved-scene browser, imported ATS scene insertion, custom-resource merging, animations, speed points and tween reconciliation remain incomplete. The model still cannot represent all original frame-associated data. Clipboard persistence and original monetization/auto-tween restrictions are not established as equivalent.

Onion skin and redo remain available through the project menu after removing them from the frame context panel.

## Validation

Two additional core tests cover first-frame insertion, later bulk insertion, unique IDs, ordering, snapshot independence and no-op invalid inputs. The core check on commit 3ecb21f passed all 27 XCTest tests in Actions 41486074630.

The UI test covers empty clipboard, copy/paste, retained numerical selection, undo, last-frame delete guard and panel dismissal. Final commit 23288f6 passed 27 core tests in Actions 41486219699 and all 3 simulator UI tests in Actions 41486221286. Final screenshot downloaded to out/frame-panel-final and visually inspected. The final capture shows active toolbar highlighting, the original icon column, and disabled deletion for the last frame. The scene insertion picker/custom resources are not covered by this UI test.
