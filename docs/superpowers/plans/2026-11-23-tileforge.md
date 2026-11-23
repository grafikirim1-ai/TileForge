# TileForge Implementation Plan

> **For agentic workers:** Execute inline using executing-plans.

**Goal:** Usable native macOS image tiling/detail/reassembly application using a ChatGPT-authenticated Codex runtime.
**Architecture:** SwiftUI app, tested Swift image core, managed Codex subprocess. Bundle runtime; OAuth managed by app-server. Per-job immutable input and persistent tiles.
**Tech Stack:** Swift 6 / SwiftUI / AppKit / Accelerate / ImageIO / Codex CLI.
**Spec:** docs/superpowers/specs/2026-11-23-tileforge-design.md

## Global Constraints
- No API key or password collection. No private backend calls.
- macOS 14+, ARM64 runtime in this build.
- Source image unchanged. Output capped at 48 million pixels.

## Review Focus
- Odd image sizes: exact grid coverage.
- Alpha/EXIF: oriented import and premultiplied channels.
- Failed generation: preserve job; no success on missing image.
- Sign-in canceled/disconnected: visible actionable error and no leaked tokens.
- Cancel: stop child and do not export partial composite as final.

### Task 1: Core
- [x] Write coverage, bounds, constant reconstruction, exposure mismatch and alpha tests; observe failure.
- [x] Implement GridPlan, Raster, tile preparation, low-frequency color stabilization, weighted blend and seam report; run suite.
### Task 2: Codex bridge
- [x] Test event parsing and failed/missing output handling; observe failure.
- [x] Implement runtime detection, account RPC, browser login, per-tile Codex execution, cancellation and timeouts.
- [x] Verify actual image generation using signed-in account.
### Task 3: Desktop app
- [x] Implement account/import/settings/progress/preview/export and job resume.
- [x] Build .app with bundled Codex; ad-hoc sign and verify launch.
### Task 4: Verification
- [x] Run full suite, real 2x2 production, inspect output, UI screenshot, document limits and package.
