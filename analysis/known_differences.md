# Known differences — not a completed exact reconstruction

Native editor, original bitmap catalog, keyframes, interpolated playback, document files and exports are implemented. Device builds and basic simulator UI flow pass.

Critical gaps: full vector/freehand/skeleton constructor; unit attachment/IK/constraint parity; animated image states and facial visemes; full ATS/ATI round-trip and embedded custom artwork; full original landing/onboarding and nested tools; keyframed camera/background; speed curves and complete effects; image/gallery background editing. Unknown artwork is visibly marked rather than treated as successfully rendered.

Current scene edits save as native JSON, not complete original ATS. XML loader rejects unsupported elements to prevent silent data loss. GIF export currently limited to1800 frames. MP4 exports at up to1920px width with an imported soundtrack; export output still needs runtime media validation.

No Android phone or emulator available. No pixel-level reference comparison, SSIM/MAE or measured Android animation parity exists. The screenshots show only the native app. This build must not be described as an exact or finished clone.
