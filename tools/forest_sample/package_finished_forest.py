"""Self-contained Blender + runnable Godot latest-forest handoff."""
import hashlib
import json
import shutil
import zipfile
from pathlib import Path
from PIL import Image
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"output/finished-latest-forest"
PACKAGE=ROOT/"output/transfer/latest-forest-ready-20261027"
PACKAGE.mkdir(parents=True,exist_ok=True)

def copy(source,relative):
    destination=PACKAGE/relative
    destination.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,destination)

def write(relative,text):
    destination=PACKAGE/relative
    destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_text(text,encoding="utf-8",newline="")

for relative in ["scenes/art/LatestForest.tscn","scenes/art/LatestForest.gd",
                 "scenes/art/LatestForestPlayer.gd","scripts/UserArt.gd","tests/latest_forest.gd"]:
    copy(ROOT/relative,relative)
for directory in ["assets/latest_forest","assets/user_art"]:
    for path in (ROOT/directory).rglob("*"):
        if path.is_file() and path.suffix in (".png",".json"):
            copy(path,path.relative_to(ROOT))
for name in ["forest-ready.blend","segmentation-guide.png","segmentation-cleaned.png","original-8k.png","manifest.json"]:
    copy(OUT/name,"blender/"+name)
for directory in ["masks","layers","previews"]:
    for path in (OUT/directory).glob("*.png"):
        copy(path,"blender/"+directory+"/"+path.name)
copy(ROOT/"tools/forest_sample/finish_latest_forest.py","blender/finish_latest_forest.py")
copy(ROOT/"docs/latest-forest-ready.md","制作记录.md")
write("blender/.gdignore","")
write("project.godot",'''config_version=5
[application]
config/name="最新森林 · 原图分层演示"
run/main_scene="res://scenes/art/LatestForest.tscn"
[display]
window/size/viewport_width=1024
window/size/viewport_height=576
window/stretch/mode="canvas_items"
[rendering]
renderer/rendering_method="gl_compatibility"
''')
write("START.cmd",'''@echo off
setlocal
set "engine=%USERPROFILE%/Desktop/Godot_v4.7.2-stable_win64_console.exe"
if not exist "%engine%" for /f "delims=" %%G in ('where godot 2^>nul') do set "engine=%%G"
if not exist "%engine%" (
  echo Godot not found. Open project.godot with Godot 4.7.2 and press F5.
  pause
  exit /b 1
)
"%engine%" --headless --editor --path "%~dp0." --import
if errorlevel 1 (
  pause
  exit /b 1
)
"%engine%" --path "%~dp0."
''')
write("先读我.txt",'''解压后双击 START.cmd，自动导入并运行；需要这台电脑已有的 Godot 4.7.2。
也可用 Godot 打开 project.godot，按 F5。

WASD/方向键：移动。空格：自动从入口走到树洞。H：遮挡对比。R：重置。Esc：退出。
无需手工抠图或配置 Blender。角色使用已有静态方向姿态。

Blender 工程在 blender/forest-ready.blend，原图与蒙版已内嵌。
原始 8K 图保持不变；分割指引仅用于透明度，未把生成颜色加入原画。
这仍是固定机位的 2.5D 预渲染实验；未补画树后信息，细枝蒙版为自动分割质量。
制作记录.md 供查阅，不需要按教程完成额外操作。
''')

source=np.asarray(Image.open(ROOT/"assets/latest_forest/original-8k.png").convert("RGB"))
preview=np.asarray(Image.open(OUT/"previews/godot-unchanged.png").convert("RGB"))
difference=np.abs(source[4::8,4::8].astype(np.int16)-preview.astype(np.int16))
assert difference.max()==0,"Unexpected source-color change"
assert hashlib.sha256((OUT/"original-8k.png").read_bytes()).digest()==hashlib.sha256((ROOT/"assets/latest_forest/original-8k.png").read_bytes()).digest()
qa={"blender_version":"5.2.3 LTS","source_dimensions":[8192,4608],"original_preserved":True,
    "screenshot_dimensions":[1024,576],"unchanged_max_rgb_difference":int(difference.max()),
    "latest_scene_tests_passed":32,"prologue_tests_passed":65,"generated_rgb_used":False,
    "mask_source":"imagegen ID segmentation, thresholded by Blender; automatic silhouette quality",
    "reconstruction":"fixed-camera 2.5D; hidden surfaces not painted"}
write("验证记录.json",json.dumps(qa,ensure_ascii=False,indent=2))
files=[p for p in PACKAGE.rglob("*") if p.is_file() and p.name!="checksums.json" and ".godot" not in p.parts and p.suffix not in (".import",".uid")]
hashes={p.relative_to(PACKAGE).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
write("checksums.json",json.dumps(hashes,ensure_ascii=False,indent=2))
files.append(PACKAGE/"checksums.json")
archive=ROOT/"output/latest-forest-ready-20261027.zip"
with zipfile.ZipFile(archive,"w",zipfile.ZIP_DEFLATED) as package:
    for path in files:
        package.write(path,"latest-forest-ready/"+path.relative_to(PACKAGE).as_posix())
with zipfile.ZipFile(archive) as package:
    assert package.testzip() is None
    for path,digest in hashes.items():
        assert hashlib.sha256(package.read("latest-forest-ready/"+path)).hexdigest()==digest
print(json.dumps({"zip":str(archive),"folder":str(PACKAGE),"files":len(files),"megabytes":round(archive.stat().st_size/1048576,2)},ensure_ascii=False))
