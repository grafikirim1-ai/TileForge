from pathlib import Path
import subprocess
root=Path(__file__).resolve().parent.parent
view=(root/'Sources/TileForge/TileForgeApp.swift').read_text()
view='import SwiftUI\nimport AppKit\nimport TileCore\n'+view[view.index('private let accent='):]
view+='\n'+(root/'scripts/render-guide.swift').read_text()
render=root/'tmp/guide/GuideRenderer.swift';render.parent.mkdir(parents=True,exist_ok=True);render.write_text(view)
model=root/'tmp/guide/JobModel.swift';model.write_text((root/'Sources/TileForge/JobModel.swift').read_text().replace('Task { await refreshAccount() }',''))
objects=list((root/'.build/arm64-apple-macosx/debug/TileCore.build').glob('*.swift.o'))
subprocess.run(['swiftc','-parse-as-library','-swift-version','5','-target','arm64-apple-macosx14.0','-I',str(root/'.build/arm64-apple-macosx/debug/Modules'),str(model),str(render),*[str(p) for p in objects],'-o',str(root/'tmp/guide/render-guide')],check=True)
subprocess.run([str(root/'tmp/guide/render-guide'),str(root)],check=True)
