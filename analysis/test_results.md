# Checks

Four Swift core tests passed on macOS: original480x640 scene fixture/interframes4 and point coordinates; invalid coordinates; preserved100-unit bone length during rotation; incompatible topology rejection.
Full device target built successfully in Actions41453679053,41453924195 and41454270754. Those workflows failed at simulator install, not compilation.
Simulator install error: IXErrorDomain13, Missing bundle ID. Explicit complete Info.plist and version set. Additional signing/absolute path/retained bundle diagnostics in Actions41454765719 pending.
No visual equivalence metrics and no successful simulator screenshot yet. Audio/video exports compiled but runtime results remain unverified.

Simulator launch and screenshot succeeded in41455293825 after renaming root Resources to Content (reserved bundle structure). Screenshot inspected at out/working-simulator/out/editor.png. UI test succeeded in41455440874: open object catalog, choose original character, create frame2, start/stop playback. No Android visual parity measurements or physical iPhone validation.

Latest resumed check (993da05): core Actions 41481002665 passed 25 XCTest tests; simulator Actions 41481003330 passed 2 UI tests. Entire-display screenshot and accessibility geometry inspected locally; window is 874 x 402 points. Earlier pending/no-screenshot statements above are historical. No full pixel parity or physical iPhone validation is established.

Frame panel final check (23288f6): 27 core XCTest tests passed in 41486219699, 3 simulator UI tests passed in 41486221286. Added tests cover clipboard insertion ordering/identity, copy/paste/undo, empty clipboard, last-frame guard and panel dismissal. Final panel screenshot downloaded to out/frame-panel-final and visually inspected. This does not establish complete original panel parity.
