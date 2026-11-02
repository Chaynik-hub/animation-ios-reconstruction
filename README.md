# Animation iOS reconstruction — incomplete

Native UIKit/Core Graphics/AVFoundation app reconstructed from an authorized Android APK using REA. This repository currently contains a working editor subset, not full functional or visual parity. See analysis/functionality_map.md.

## Build and installation

Run the **Build native iOS IPA** workflow in this private repository. It runs native core tests, generates the Xcode project via XcodeGen, compiles an unsigned device application on macOS, packages the IPA and attempts a simulator screenshot. No local Mac is needed.

Download **AnimationIOS-IPA** from the workflow artifacts. Open its IPA in Sideloadly on Windows, select the connected iPhone and sign with your own Apple account in Sideloadly. Do not share credentials in chat. The IPA is unsigned until this step.

Local macOS build, if ever needed: `brew install xcodegen`, `xcodegen generate`, then build scheme AnimationIOS. Native core checks: `swift test`.

Original fonts, artwork and icons are retained in App/Content. `original-assets/` and `decoded/` are local research inputs excluded from git; `analysis/evidence/` holds focused REA evidence.
