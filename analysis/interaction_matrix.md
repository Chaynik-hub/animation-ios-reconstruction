# Interactions

| Action | Native behavior | Original parity |
|---|---|---|
| Add at end | Copy pose, new frame ID | Core rule confirmed by Scene.addFrame |
| Add between two frames | Interpolate matching objects at0.5 | Camera/tween side effects incomplete |
| Drag joint | Move joint and descendants | Original IK/constraints not fully matched |
| Pinch/pan | Adjust viewport | Runtime comparison unavailable |
| Play |60Hz media-time based rendering | Partial: variable speeds/easing absent |
| Import | Read JSON or supported ATS/XML | Partial: unsupported markup rejected |
| Save | Atomic JSON write | Native format, not complete ATS round trip |
| Export | PNG/GIF/MP4 and share sheet | Needs runtime/export validation |
