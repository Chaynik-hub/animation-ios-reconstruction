# Reconstruction status

Evidence files in `evidence/` retain REA observations. App source is a new native implementation; a passing build does not establish original behavioral parity.

| Original subsystem | Evidence | Native implementation | Remaining differences |
|---|---|---|---|
| Scene coordinates and frame/unit/joint model | Frame, Unit, UPoint metadata; demo_engine.ats fixture | SceneDocument.swift | Unsupported XML elements explicitly rejected |
| Pose interpolation | InterpolatorFactory and NlerpInterpolator method bodies | PoseInterpolation.swift | Unit attachments, easing and effect reconciliation pending |
| Bitmap artwork | UnitAssets.makePngAsset; UnitDrawer.doDrawUnit | SceneCanvas.paint; 140 original definitions | Vector artwork, animated bitmap states, faces and stretch behavior incomplete |
| Frame insertion | Scene.addFrame | Workspace.addFrame | Camera tween reconciliation pending |
| Editor tool geometry | main.xml, controls_main.xml, dimens.xml | EditorController | Runtime Android reference unavailable; full parity unverified |
| Editing | Original joint and hierarchy metadata | Joint dragging, pan/zoom, flip, duplicate, delete | IK/constraints and constructor not fully ported |
| Local documents | Original ATS ZIP observation | JSON projects, basic ATS/XML read | Embedded ATI and complete ATS round-trip pending |
| Playback | SceneConfig FPS60 and interframes | CADisplayLink and pose interpolation | Variable speed, easing, speech/effects pending |
| Audio | MainEditor.addSound entry point | Local audio import and playback | Original audio timeline/editor not yet ported |
| Export | MainEditor.export entry point | PNG, GIF, H264 MP4 with soundtrack | Original export options and pixel parity unverified |
| Undo/redo | UndoRedoManager inventory | Bounded document history | Original transactional semantics unverified |

Unported: complete constructor/vector/freehand tools, scene/chunk operations, custom packs, facial animation, full project compatibility, detailed camera/background animation, effects and onboarding. Do not call this an exact reconstruction or a completed app.
