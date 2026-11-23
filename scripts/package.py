#!/usr/bin/env python3
"""Build a self-contained Apple Silicon macOS app with the installed Codex runtime."""
from pathlib import Path
import os, plistlib, shutil, subprocess, uuid
ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)
subprocess.run(['swift','build','--disable-sandbox','-c','release','--product','TileForge'],check=True)
build_id=uuid.uuid4().hex
app=ROOT/'tmp'/('package-'+build_id)/'TileForge.app'
mac=app/'Contents'/'MacOS'; res=app/'Contents'/'Resources'
mac.mkdir(parents=True,exist_ok=True);res.mkdir(parents=True,exist_ok=True)
shutil.copy2(ROOT/'.build/release/TileForge',mac/'TileForge')
runtime=os.environ.get('TILEFORGE_CODEX_VENDOR')
if not runtime:
    node_codex=Path(shutil.which('codex')).resolve()
    package=node_codex.parent.parent
    arch='arm64' if os.uname().machine=='arm64' else 'x64'
    triple='aarch64-apple-darwin' if arch=='arm64' else 'x86_64-apple-darwin'
    runtime=package/'node_modules'/'@openai'/f'codex-darwin-{arch}'/'vendor'/triple
runtime=Path(runtime)
for name in ['bin','codex-path']:
    shutil.copytree(runtime/name,res/'codex-runtime'/name,dirs_exist_ok=True)
shutil.copy2(runtime/'codex-package.json',res/'codex-runtime'/'codex-package.json')
plist={'CFBundleExecutable':'TileForge','CFBundleIdentifier':'studio.prosigma.TileForge','CFBundleName':'TileForge','CFBundleDisplayName':'TileForge','CFBundleShortVersionString':'1.0.0','CFBundleVersion':'1','CFBundlePackageType':'APPL','LSMinimumSystemVersion':'14.0','NSHighResolutionCapable':True,'NSPrincipalClass':'NSApplication','CFBundleIconFile':'AppIcon','NSHumanReadableCopyright':'TileForge · 2026. Codex runtime © OpenAI; Apache-2.0.'}
with (app/'Contents'/'Info.plist').open('wb') as f:plistlib.dump(plist,f)
shutil.copy2(ROOT/'README.md',res/'README.txt')
shutil.copy2(ROOT/'LICENSE',res/'LICENSE.txt')
guide=ROOT/'output/pdf'
shutil.copy2(guide/'TileForge_Visual_Guide.pdf',res/'USER GUIDE.pdf')
shutil.copy2(guide/'TileForge_Visual_Guide.html',res/'USER GUIDE.html')
shutil.copytree(guide/'Guide_Pages',res/'Guide_Pages',dirs_exist_ok=True)
shutil.copytree(ROOT/'licenses',res/'licenses',dirs_exist_ok=True)
if (ROOT/'tmp/AppIcon.icns').exists():shutil.copy2(ROOT/'tmp/AppIcon.icns',res/'AppIcon.icns')
subprocess.run(['codesign','--force','--sign','-',str(app)],check=True)
subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
destination=ROOT/'dist/TileForge.app'
destination.parent.mkdir(exist_ok=True)
if destination.exists():destination.rename(ROOT/'tmp'/('previous-'+build_id+'.app'))
app.rename(destination)
print(destination)
