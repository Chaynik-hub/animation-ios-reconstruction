# Current repair checkpoint

User priority: fix reported unusable catalog/preview, opaque onion skin and missing skeleton connections, then continue full Android parity. User has authorized ongoing work; do not ask for permission again. Do not describe the app as complete.

## Implemented and verified on 87b1aa2

- Original pack metadata/covers and manifest folder hierarchy retained in packs.json/catalog.json. 18 bundled packs; 187 catalog definitions assigned to folders.
- Catalog is an in-editor column with pack covers, folders, back navigation, explicit close, and toggle using the Insert button. Selecting an item leaves the chooser usable for more insertions.
- Previous-frame opacity now multiplies individual bitmap alpha rather than being overwritten.
- Selected skeleton paints orange connecting lines as well as joints; preview/export omit editing handles.
- Preview has an explicit Back button on iOS, frame counter, finite playback and replay. Android's hardware Back has no directly visible iPhone equivalent; visible close is intentional platform adaptation, not pixel equality.
- Connected-object copy/delete primitives and tests added; the existing duplicate/delete actions now use them. Rendering respects arrange order.

## Validation

Core Actions 41489438821: success, 30 tests. Simulator Actions 41489910665 passed both hosted render tests and all four UI tests. Final commit 87b1aa2 passed all 30 core tests, 2 render tests and 4 UI tests in Actions 41490559944 (core check also performed by the validation workflow). Entire-display catalog screenshot inspected after download to out/reported-bugs-final. Device IPA build 41490599443 compiled and produced its IPA. Two additional hosted UIKit render tests inspect pixels for ghost alpha and skeleton/export separation; four UI scenarios cover frame tools, catalog folders/close, insertion/preview close, and original ATS import.

## Remaining original parity

The current unit properties menu still needs replacement with the original list/properties context panels. Original properties screenshot/XML captured in out/original-unit-properties from Actions 41487928650; evidence JSON for visibility rules and actions saved under analysis/evidence. Constructors/freehand/vector, full item asset coverage, masks/faces/visemes, speed/camera/background/effects, full ATS/ATI/ATP round trip, original export/audio UI, landing/settings/onboarding and network-dependent features remain incomplete. Range selection and original timeline metadata are not yet fully represented.

Do not treat the bug repair set or passing smoke tests as full app equivalence.
