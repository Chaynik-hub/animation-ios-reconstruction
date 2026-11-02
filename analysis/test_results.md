# Checks

Four Swift core tests passed on macOS: original480x640 scene fixture/interframes4 and point coordinates; invalid coordinates; preserved100-unit bone length during rotation; incompatible topology rejection.
Full device target built successfully in Actions41453679053,41453924195 and41454270754. Those workflows failed at simulator install, not compilation.
Simulator install error: IXErrorDomain13, Missing bundle ID. Explicit complete Info.plist and version set. Additional signing/absolute path/retained bundle diagnostics in Actions41454765719 pending.
No visual equivalence metrics and no successful simulator screenshot yet. Audio/video exports compiled but runtime results remain unverified.

Simulator launch and screenshot succeeded in41455293825 after renaming root Resources to Content (reserved bundle structure). Screenshot inspected at out/working-simulator/out/editor.png. UI test succeeded in41455440874: open object catalog, choose original character, create frame2, start/stop playback. No Android visual parity measurements or physical iPhone validation.
