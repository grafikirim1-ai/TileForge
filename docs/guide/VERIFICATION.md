# Visual user guide verification — 2026-11-23

- Nine English steps: installation, Google/OpenAI sign-in, import, grid, scale/detail, generation, comparison, export and resume.
- Native example UI comes from ForgeView and ForgeModel fixtures. The sample email remains `example@example.com`; no personal identity was added.
- Browser and save dialog flows are labeled diagrams. UI instructions match the English labels in `Sources/TileForge/TileForgeApp.swift`.
- A4 landscape, cream background and embedded Arial fonts. Layout decision: `grid_decision.json`.
- Regenerated `output/pdf/TileForge_Visual_Guide.pdf`, `TileForge_Visual_Guide.html` and all nine `Guide_Pages/` images. Removed the previous guide outputs.
- Reviewed all nine rendered pages in a contact sheet and inspected sign-in, settings, processing and comparison at full size. Corrected the Before/After highlights to frame the two segments rather than the adjacent zoom controls; other highlights still frame the intended controls.
- Programmatic checks passed: nine pages, nine bookmarks, English PDF metadata and extracted text, no replacement characters, all text blocks within page bounds, English HTML language/title/alt text and nine existing relative image references.
- Python syntax checks and `git diff --check` passed. `swift build --disable-sandbox` passed; only sandbox-related user-cache warnings appeared.
- Default `python3` could not import ReportLab. Generation succeeded with the existing local ReportLab and PyMuPDF cache directories on `PYTHONPATH`; Pillow was already available. No dependencies were downloaded.
- Packaging scripts now copy `USER GUIDE.pdf`, `USER GUIDE.html` and `Guide_Pages/` into the app resources and DMG root. A new app package/DMG was not built or mounted in this update; previous installer hashes do not certify these new assets.

## Repository language audit

Scanned all files, including hidden and ignored files, excluding `.build/` and `.git/`. No remaining text-file hits for the requested language patterns or previous guide names. The layout-decision JSON filename was also translated.

Raw byte matching also reports the following binary files. Compressed image/PDF bytes can match character patterns accidentally; these hits are not evidence of readable non-English text. The English screenshots and regenerated guide pages were visually reviewed. Existing image assets and the untracked walkthrough GIF were left unchanged.

- `docs/guide/examples/reference.png`
- `docs/guide/examples/result.png`
- `docs/guide/examples/tile-preview.png`
- `docs/guide/screens/01-login.png`
- `docs/guide/screens/02-empty.png`
- `docs/guide/screens/03-source.png`
- `docs/guide/screens/04-grid.png`
- `docs/guide/screens/05-progress.png`
- `docs/guide/screens/06-result.png`
- `docs/social-preview.png`
- `docs/tileforge-walkthrough.gif`
- `output/pdf/Guide_Pages/01.png`
- `output/pdf/Guide_Pages/02.png`
- `output/pdf/Guide_Pages/03.png`
- `output/pdf/Guide_Pages/04.png`
- `output/pdf/Guide_Pages/05.png`
- `output/pdf/Guide_Pages/06.png`
- `output/pdf/Guide_Pages/07.png`
- `output/pdf/Guide_Pages/08.png`
- `output/pdf/Guide_Pages/09.png`
- `output/pdf/TileForge_Visual_Guide.pdf`
- `tmp/guide/render-guide`
