# TileForge verification — 2026-11-23

These are historical source-project verification notes, not a fresh verification of this public export. Refer to the release-preparation SCRUB_REPORT.md for current checks. Referenced local logs, app bundles and disk images are not included in this source export.

## Delivered
- Native Apple Silicon app: `~/Applications/TileForge.app`
- Installer: `~/Desktop/TileForge.dmg` (160,647,901 bytes; updated with illustrated guide)
- SHA-256: `852b7820da1cc4f181b63d35aa8fc72ce6d3f6688ebfb234766f4870e24f3db2`
- Local ad-hoc signature, no Developer ID/notarization claim. macOS 14+.

## Evidence
- `swift test --disable-sandbox`: 13 tests, 0 failures (log: `tmp/final-tests.log`). Grid coverage, invalid bounds, exposure correction, missing tiles, alpha, shifted-feature alignment, PNG orientation, safe generated paths, argument boundaries, corrupt cache and actual subprocess failed-turn behavior.
- Real authenticated Codex built-in image generation: initial capability image plus 4 crop edits, without API keys. 2×2 composite: 1024×682, overlap diagnostic 0.00702189. Log: `tmp/integration.log`; generated crops and result: `tmp/integration/`.
- Visual inspection: source and composite opened at native resolution. No obvious join line on this simple sphere fixture. This is not broad image-quality certification.
- Native UI: launch, existing ChatGPT account detection, image import, grid preview, cached 4-tile job resume, result preview, and PNG export exercised through computer-use controls. Export: `tmp/qa-job/TileForge-1024x682.png` (1024×682). No additional generation was performed during the cached resume test.
- Final installed app launched successfully. UI shows the Google account switch entry and fit preview; account connected automatically via existing Codex ChatGPT session.
- Bundled runtime account-only check: concurrent account reads and close/reconnect passed (`tmp/account-check.log`).
- `codesign --verify --deep --strict ~/Applications/TileForge.app`: passed.
- `hdiutil verify`: installer CRC valid. Mounted read-only at `/Volumes/TileForge`; bundled runtime checked separately.
- Independent read-only reviewer found three P2 issues; fixed corrupt cache recovery, consistent instruction limit and account EOF handling. Reviewer follow-up: no remaining important regression in those changes.

## Google login boundary
No email/password fields exist in the app. The Google entry starts Codex-managed OAuth in the official OpenAI browser screen; users select Continue with Google there. The app does not pretend to be a Google OAuth client or modify OpenAI authorization URLs with undocumented provider parameters. A fresh Google login was not completed with a different account during QA; the existing ChatGPT account was used for production tests. OpenAI may request provider authentication if the browser has no Google session.

## Fixes established during verification
- Removed unintended raster Y flip (PNG round-trip test).
- Added `--` separator after variadic image arguments (CLI parsing test and real generation).
- Added bounded translation correction with an improvement gate (shifted fixture test).
- Atomic raster saves; decode caches before reusing them.
- Unique per-attempt reply filenames; require successful turn completion in JSONL.
- Scope account callbacks to connection identity, clear EOF handler and coalesce initialization.
- Build each app in a fresh directory. Overwriting signed running Mach-O inodes caused macOS to kill copied Codex; clean-inode packaging fixed it. Both DMG staging and app packaging now use unique staging directories.
- Separate final image dimensions from subsequent settings changes.

## Current limitations
- Identity, text, geometry and perfectly seamless output cannot be guaranteed by generative edits. The pipeline transfers high-frequency generated detail while retaining source low-frequency illumination; global translation correction cannot repair local warps.
- 8-bit sRGB; output cap 48 MP. Large jobs can consume several GB of RAM. No RAW/CMYK/vector workflow.
- Account image tool availability, connectivity and ChatGPT/Codex usage limits apply. Switching account affects the local Codex session. No paid API fallback.
- Fresh Google sign-in, public notarized distribution, Intel builds and a diverse photographic benchmark remain unverified.

## Research
- Built-in image tool and included Codex usage: https://learn.chatgpt.com/docs/image-generation
- Codex managed authentication: https://learn.chatgpt.com/docs/auth?surface=cli
- Google sign-in availability: https://help.openai.com/en/articles/7426629-why-cant-i-log-in-to-chatgpt
- Social sign-in method requirements: https://help.openai.com/en/articles/4936824-changing-your-account-sign-in-method
- General Sign in with ChatGPT route limitations are distinct from Codex built-in image generation: https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations

## Illustrated guide update
The nine-page English visual guide is generated as `output/pdf/TileForge_Visual_Guide.pdf`, with `TileForge_Visual_Guide.html` and nine images in `Guide_Pages/`. Packaging scripts include the English PDF and offline HTML. The guide was regenerated and visually reviewed locally; no new DMG was built or mounted for this update. See `docs/guide/VERIFICATION.md`.

## Interrupted-job fix
- A tile generation could fail when the image tool resolved the reference attachment relative to the tile work directory. The reference image is now staged inside every tile directory before Codex runs.
- Resume improvements: the latest interrupted job is restored on launch, the main action becomes "Resume where you left off", and decodable tile files are reused even if the saved completed list is stale. Nothing is retried automatically.
- Regression tests cover reference availability and resuming an interrupted job. Full `swift test --disable-sandbox`: 15 tests passed.
