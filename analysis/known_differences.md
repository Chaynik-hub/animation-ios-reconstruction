# Known differences — not a completed exact reconstruction

The native editor remains limited. New rigid/IK/stretch/attachment ports, 542 artwork definitions and separate preview are implemented. Core checks and basic simulator UI flow pass; complete original UI/gesture parity is not established.

Critical gaps: full vector/freehand/skeleton constructor; unit attachment/IK/constraint parity; animated image states and facial visemes; full ATS/ATI round-trip and embedded custom artwork; full original landing/onboarding and nested tools; keyframed camera/background; speed curves and complete effects; image/gallery background editing. Unknown artwork is visibly marked rather than treated as successfully rendered.

ATS saving now replaces model.xml while preserving opaque original entries, but embedded custom artwork loading, thumbnail regeneration and original audio archive format remain incomplete. Native JSON is not a portable media bundle. XML rejects unsupported elements. GIF export is limited to1800 frames. MP4 exports at up to1920px width; media output still needs runtime validation.

Original Android runs in a private KVM emulator. Onboarding/practice screenshots and UI XML exist; no physical phone is available. Complete per-screen pixel comparison and measured gesture/animation parity are still pending. This must not be described as an exact or finished copy. Final packaging is gated on verified parity coverage.
