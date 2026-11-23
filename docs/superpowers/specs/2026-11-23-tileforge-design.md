# TileForge macOS
User-approved direction: native Mac app, GPT image production through Codex signed in with ChatGPT, no API key. Passwords are entered only in the official browser OAuth flow, never in this app.

SwiftUI desktop interface: account state/login, image import, row/column presets and custom grid, detail instruction, 2x/4x target, run/cancel, progress, before/after and export PNG/TIFF. Native app bundles the Codex executable so installation needs no terminal. Auth is delegated to Codex app-server account/login/start and account/read; use existing local ChatGPT session where available. GPT production uses built-in image_gen through Codex with sandboxed per-job working directories. No private HTTP endpoints or token extraction.

Image pipeline: oriented sRGB source; integer grid with 25% context margins; full-image reference plus tile supplied to each edit; normalize dimensions; align regenerated image to source where possible; retain source low-frequency illumination and generated detail; overlapping cosine weights; verify mismatch and expose a review-needed status. Generative output cannot guarantee invisible seams; no absolute promise. Source never overwritten. Jobs and partial results persist in Application Support, so canceled/failed jobs can resume. Bounded output pixels and memory estimates.

Alternatives considered: direct API (user rejected keys/cost setup), local diffusion (user chose GPT), Codex managed production (selected by user). Distribution limited to local ad-hoc signed build here; public notarization requires developer signing credentials.
