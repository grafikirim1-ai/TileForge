# Contributing to TileForge

Thanks for helping! TileForge is a small Swift package (`TileCore` library, `TileForge` app, `ForgeCheck` live check).

## Build and test
```sh
swift build
swift test
```
If SwiftPM manifest sandboxing is unavailable in your environment, add `--disable-sandbox` for a trusted checkout.

## Guidelines
- Keep changes focused and add or update a unit test when you touch `TileCore`.
- No telemetry, no token extraction, no private endpoints and no browser automation. Authentication stays with the official Codex CLI.
- Never commit personal images, job folders (`~/Library/Application Support/TileForge`), tokens or e-mail addresses.
- Example images you contribute must be yours to share (or openly licensed); say so in the pull request.
- UI strings are English; localization PRs are welcome.

## Reporting bugs
Open an issue with your macOS version, Mac model, TileForge version, grid and scale, and the job's `status` (not the images, unless you are happy to share them).
