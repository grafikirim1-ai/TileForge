#!/usr/bin/env python3
from pathlib import Path
import os,shutil,subprocess,sys,uuid
root=Path(__file__).resolve().parent.parent
output=Path(sys.argv[1]) if len(sys.argv)>1 else root/'dist/TileForge.dmg'
backup=None
if output.exists():
    if '--replace' not in sys.argv:raise SystemExit(f'Will not overwrite existing disk image: {output}')
    backup=root/'tmp'/('dmg-before-guide-'+uuid.uuid4().hex+'.dmg')
    output.rename(backup)
stage=root/'tmp'/('dmg-stage-'+uuid.uuid4().hex)
stage.mkdir(parents=True,exist_ok=True)
shutil.copytree(root/'dist/TileForge.app',stage/'TileForge.app',dirs_exist_ok=True)
link=stage/'Applications'
if not link.exists() and not link.is_symlink():link.symlink_to('/Applications')
guide=root/'output/pdf'
shutil.copy2(guide/'TileForge_Visual_Guide.pdf',stage/'USER GUIDE.pdf')
shutil.copy2(guide/'TileForge_Visual_Guide.html',stage/'USER GUIDE.html')
shutil.copytree(guide/'Guide_Pages',stage/'Guide_Pages')
(stage/'READ ME FIRST.txt').write_text("""TileForge — GPT Detail Studio for macOS

INSTALLATION
Drag TileForge to Applications and open it. Requires Apple Silicon and macOS 14+.
This app is ad-hoc signed and is not Apple-notarized. Gatekeeper may block it.

SIGN IN
Click Sign in with Google, then Continue with Google on the official OpenAI page.
Use the account linked to your ChatGPT plan. The app never asks for your password.
An existing local Codex ChatGPT session may connect automatically.

USAGE
Choose image > choose grid and scale > Enhance and compose > Export.
Images and tiles are sent to OpenAI. Internet and an eligible account are required.
Each tile consumes ChatGPT/Codex usage; no API key is required.
Use Resume saved job… and select job.json to continue interrupted work.
Generation can change details and cannot guarantee seamless joins. Review at 100%.
The source file is preserved. See the bundled README for limits and notices.

ILLUSTRATED GUIDE
Open USER GUIDE.pdf or USER GUIDE.html for nine illustrated steps.
Keep the Guide_Pages folder beside the HTML file for offline viewing.
""",encoding='utf-8')
subprocess.run(['hdiutil','create','-volname','TileForge','-srcfolder',str(stage),'-format','UDZO','-fs','HFS+',str(output)],check=True)
subprocess.run(['hdiutil','verify',str(output)],check=True)
print(output)
