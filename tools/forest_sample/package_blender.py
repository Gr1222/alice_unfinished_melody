"""Create a self-contained, checksummed Blender handoff ZIP. Standard library only."""
import ast
import hashlib
import json
import shutil
import zipfile
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
destination = ROOT / "output" / "transfer"
destination.mkdir(parents=True, exist_ok=True)
(destination / ".gdignore").write_text("", encoding="utf-8")
name = "alice-forest-blender-" + stamp
bundle = destination / name
bundle.mkdir(exist_ok=False)


def write(relative, content, bom=False):
    target = bundle / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8-sig" if bom else "utf-8", newline="")


def copy(source, relative):
    target = bundle / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


for relative in ["tools/forest_sample/build_blender.py", "tools/forest_sample/build_layout.py",
                 "data/art/forest_study.json", "docs/forest-study.md", "docs/forest-skills.lock.json",
                 "scenes/art/ForestStudy.gd", "scenes/art/ForestStudy.tscn",
                 "scenes/art/ForestPrerender2D.gd", "scenes/art/ForestPrerender2D.tscn",
                 "scenes/art/ForestStudyPlayer.gd", "tests/forest_prerender.gd"]:
    copy(ROOT / relative, relative)
for path in (ROOT / "assets/forest_prerender").iterdir():
    if path.suffix in (".png", ".json"):
        copy(path, "assets/forest_prerender/" + path.name)
for path in (ROOT / "output/forest-study").iterdir():
    if path.is_file() and path.suffix == ".png":
        copy(path, "previews/" + path.name)

references = {
    "forest-map-original.png": Path("C:/Users/sophi/AppData/Local/Temp/codex-clipboard-4645557c-5b43-4d3c-bbf1-6ba12709ff06.png"),
    "workflow-red-circle.jpg": Path("C:/Users/sophi/AppData/Local/Temp/codex-clipboard-61a73c42-0308-4e7f-9863-4f1c7ecc231d.jpg"),
}
for file, source in references.items():
    if not source.is_file():
        raise FileNotFoundError(f"Required user reference image missing: {source}")
    copy(source, "references/" + file)
for skill in ("blender-modeler", "environment-artist", "hand-painted-style"):
    source = Path("C:/Users/sophi/.codex/skills") / skill
    for path in source.rglob("*"):
        if path.is_file():
            copy(path, "skills/" + skill + "/" + path.relative_to(source).as_posix())

write("project.godot", '''config_version=5
[application]
config/name="Forest prerender transfer experiment"
run/main_scene="res://scenes/art/ForestPrerender2D.tscn"
[display]
window/size/viewport_width=480
window/size/viewport_height=270
window/size/window_width_override=960
window/size/window_height_override=540
window/stretch/mode="canvas_items"
[rendering]
renderer/rendering_method="gl_compatibility"
textures/default_filters/use_nearest_mipmap_filter=false
''')
write("RUN_BLENDER.cmd", '@echo off\r\npowershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RUN_BLENDER.ps1" %*\r\npause\r\n')
write("RUN_BLENDER.ps1", '''param([string]$BlenderPath = '', [switch]$BuildOnly)
$ErrorActionPreference = 'Stop'
$bundleRoot = $PSScriptRoot
if (-not $BlenderPath) {
    $found = Get-Command blender -ErrorAction SilentlyContinue
    if ($found) { $BlenderPath = $found.Source }
}
if (-not $BlenderPath) {
    $installRoot = Join-Path $env:ProgramFiles 'Blender Foundation'
    if (Test-Path -LiteralPath $installRoot) {
        $found = Get-ChildItem -LiteralPath $installRoot -Filter blender.exe -Recurse -File |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($found) { $BlenderPath = $found.FullName }
    }
}
if (-not $BlenderPath) { $BlenderPath = (Read-Host 'Enter full path to blender.exe').Trim('"') }
if (-not (Test-Path -LiteralPath $BlenderPath -PathType Leaf)) { throw 'blender.exe not found' }
$scriptFile = Join-Path $bundleRoot 'tools/forest_sample/build_blender.py'
$logRoot = Join-Path $bundleRoot 'logs'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$logPath = Join-Path $logRoot ('blender-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.txt')
$blenderArgs = @('--background', '--python-exit-code', '1', '--python', $scriptFile)
if (-not $BuildOnly) { $blenderArgs += @('--', '--render') }
Write-Output ('Blender: ' + $BlenderPath)
Write-Output ('Log: ' + $logPath)
$ErrorActionPreference = 'Continue'
& $BlenderPath @blenderArgs 2>&1 | Tee-Object -FilePath $logPath
$resultCode = $LASTEXITCODE
if ($resultCode -ne 0) {
    Write-Output 'Blender failed. Keep the logs folder for diagnosis.'
    exit $resultCode
}
Write-Output 'Done. Open the latest folder under output/forest-study/.'
''', bom=True)
write("VERIFY_PACKAGE.ps1", '''$ErrorActionPreference = 'Stop'
$bundleRoot = $PSScriptRoot
$manifest = Get-Content -LiteralPath (Join-Path $bundleRoot 'checksums.json') -Raw | ConvertFrom-Json
$failed = 0
foreach ($item in $manifest.files) {
    $path = Join-Path $bundleRoot $item.path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Write-Output ('MISSING: ' + $item.path)
        $failed++
    } elseif ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.sha256) {
        Write-Output ('CHANGED: ' + $item.path)
        $failed++
    }
}
Write-Output ('Checked ' + $manifest.files.Count + ' files; failures: ' + $failed)
if ($failed -gt 0) { exit 1 }
''', bom=True)
write("README_先读我.md", '''# 森林三渲二实验 · Blender 迁移包

制作方向：**预渲染场景＋2D 像素角色**。使用现有低模小样验证制作流程；当前不是原始地图的拆图或完整风格还原。

## 在有 Blender 的 Windows 电脑上使用

1. 将 ZIP **全部解压**到可写文件夹，例如 `D:/AliceForest/`。不要在压缩包预览窗口中直接启动。
2. 双击 `RUN_BLENDER.cmd`。启动器会搜索 PATH 和 Program Files 下的 Blender；找不到时提示输入 `blender.exe` 的完整路径。
3. 等待运行结束，在 `output/forest-study/<时间戳>/` 打开 `forest-bridge.blend` 和 `blender-preview.png`。
4. 失败时保留 `logs/` 中的日志，交给另一台电脑上的 Codex 排查。

Blender 4.2+ 是脚本适配目标，推荐先尝试 Blender 4.5 LTS。包不含 Blender 安装程序，不需要网络、额外 Python、pip 或插件。**本包尚未在 Blender 内实际执行**；现有预览均由 Godot 渲染，不能据此认定 Blender 输出已经通过验证。成功启动后请先检查树木、相机、地面朝向和三档明暗。

启动器以命令行运行 Blender，不会自动弹出编辑器；生成文件后双击 `.blend` 打开。每次生成使用新时间戳目录。

## 手动运行

在解压目录打开 PowerShell，替换实际安装路径：

```powershell
& 'C:/Program Files/Blender Foundation/Blender 4.5/blender.exe' --background --python-exit-code 1 --python './tools/forest_sample/build_blender.py' -- --render
```

只生成工程、不渲染：

```powershell
& 'C:/Program Files/Blender Foundation/Blender 4.5/blender.exe' --background --python-exit-code 1 --python './tools/forest_sample/build_blender.py'
```

macOS/Linux 也可用相应 Blender 可执行文件运行同一组参数；Windows 启动器仅供 Windows。也可在 Blender 的 Scripting 界面打开 `build_blender.py` 后 Run Script。请保留本包目录结构，因为脚本按自身位置查找布局文件。

## 文件说明

| 路径 | 内容 |
| --- | --- |
| tools/forest_sample/build_blender.py | 创建新场景、模型、集合、材质、相机，保存 .blend 并可选渲染 |
| tools/forest_sample/build_layout.py | 可重复生成布局数据，使用普通 Python 或 Blender 自带 Python |
| data/art/forest_study.json | 已生成的 543 个物体及配色、机位，首次运行不需重新生成 |
| references/forest-map-original.png | 用户提供的森林原图，用于美术参考 |
| references/workflow-red-circle.jpg | 用户圈定的技术方向参考 |
| previews/ | Godot 已验证的三维、像素缩小及二维前后遮挡截图 |
| assets/forest_prerender/ | Godot 离线生成的地面与 15 张透明图层及锚点清单 |
| IMAGE_INSTRUCTIONS.md | 图像、机位、分层与出图要求 |
| HANDOFF_PROMPT.md | 给另一台电脑上的 Codex 的完整接手指令 |
| docs/ | 原有实验说明及技能来源记录；其中原电脑绝对路径仅供历史参考 |
| skills/ | 三项已安装的 Blender 技能副本及上游 MIT LICENSE，供代理按需读取 |
| project.godot、scenes/art/、tests/forest_prerender.gd | 可选的独立 Godot 对照实验，不是完整游戏项目 |

本包目前不含已生成的 `.blend`，脚本运行后才会创建。脚本当前自动输出合成图，**Blender 自动导出透明分层尚未实现**；接手指令中列出了后续任务，不能把 Godot 的透明层冒充 Blender 成果。Blender 三档明暗依赖 Eevee，不能直接改成 Cycles。

## 验证包是否完整

解压后运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./VERIFY_PACKAGE.ps1
```

`checksums.json` 记录所有载荷文件的 SHA-256（不包含它自身）。修改脚本或数据后校验报 CHANGED 属于预期。

## 可选：运行已有二维对照

使用 Godot 4.7.2 打开本包的 `project.godot`，导入完成后 F5。WASD/方向键移动，R 复位，Esc 退出。它使用已经打包的 PNG，不需要 Blender。

本包不含序章剧情、音乐资源和游戏 Autoload。`docs/forest-study.md` 中的序章回归命令只适用于原完整项目。本包可运行的测试是 `tests/forest_prerender.gd`。
''')
write("IMAGE_INSTRUCTIONS.md", '''# 图片与出图指令

## 方向与参考优先级

用户选择“预渲染场景＋2D 像素角色”。本次先沿用现有低模小样完成三渲二实验。`references/workflow-red-circle.jpg` 只说明技术路线，原图中的其他文字不应当作新需求。

`references/forest-map-original.png` 是最初美术参考。它的暗蓝绿环境、紫色枯树、青蓝及暖黄色蘑菇是后续风格目标；当前模型形状和细节与之差距较大。不要把本阶段误解为重新还原整张原图，也不要未经用户要求生成新地图替代现有布局。

## 当前脚本出图

- 渲染器：Eevee；正交相机；960×540 PNG；Standard 色彩变换；三档明暗，无写实反射。
- 逻辑输出：模型和贴图用于离线渲染；运行时使用二维图片。
- 照明和材质不要直接与 Godot 色值作像素级比较，两种渲染器需要人工校准。
- 地形统一坐标：布局为 Godot Y-up；Blender 转换为 `(x, -z, y)`。禁止只转换位置、不转换相机与朝向。
- 画面应完整显示树冠，桥必须连接两岸，木桥、树桩顶面和树干正面应具有一致透视。
- 当前角色模型仅用于尺度对照，正式背景与透明层中应隐藏 `COL_ScaleReference`。

## 后续透明图层交付目标（待在 Blender 实现）

1. 同一相机、同一分辨率、同一色彩管理分别输出地面、树木和树桩。
2. 地面包含烘焙阴影；树木/树桩单独输出真实 RGBA 透明图，不使用棋盘格假透明。
3. 建议原生画布先统一为 480×270，与现有二维实验匹配；放大检查使用最近邻，不能靠低分辨率自动代替像素修绘。
4. 每棵树以树根接地处为排序锚点，裁切透明边缘后保留偏移。复杂树冠允许额外拆分前后层。
5. 输出清单记录 image_size、pivot、crop_offset、collision_footprint、camera、renderer、Blender 版本和验证状态。
6. 先完整渲染，再检查桥路可读性、透明边缘、遮挡与人物尺度；不要把生成成功等同于最终美术验收。

## 交给图像工具的修绘说明（可复制，尚未执行）

用途：森林三渲二实验的后期手绘与像素修绘。输入现有渲染图作为构图约束，森林原图作为色彩与质感参考。保持相机、道路、木桥、树桩和树根位置不变；统一深蓝绿环境与暗紫树干，保留青蓝和淡黄蘑菇。修整树干轮廓、叶簇与阴影色块，避免写实照片纹理。不要增加入口、建筑、人物或文字。透明物体保留 alpha 和接地锚点，不移动轮廓到其他位置。输出属于待验证候选，需检查实际像素尺度及透明度。

注意：这段是后续修绘指令，不是本包已包含的生成结果。无须使用付费图像服务才能运行 Blender 脚本。
''')
write("HANDOFF_PROMPT.md", '''# 给另一台电脑上的 Codex

请接手此文件夹中的《爱丽丝与未完成的旋律》森林三渲二实验。

用户已确认：先沿用当前低模小样，采用“Blender 建模与预渲染图片＋Godot 二维像素角色”的路线。三维只用于离线出图，不能把游戏改成实时三维。此包是独立实验，不是完整游戏。

先阅读 README_先读我.md、IMAGE_INSTRUCTIONS.md、tools/forest_sample/build_blender.py、data/art/forest_study.json。需要时阅读 skills/blender-modeler、skills/environment-artist、skills/hand-painted-style 下的 SKILL.md 和相关参考。它们是指导资料，不代表已连接 Blender MCP，也不必安装 MCP。

请完成以下工作：

1. 检查本机 Blender 的位置和版本，通过 VERIFY_PACKAGE.ps1 核对迁移完整性。
2. 执行 RUN_BLENDER.ps1 或文档命令，实际生成 .blend 和渲染图。这一步在来源电脑上尚未执行，必须核对 API、材质、朝向、相机和是否正确保存。
3. 若失败，读取 logs/，修复必要的兼容问题，并记录 Blender 版本和实际验证结果。
4. 隐藏尺度人物，检查树冠完整、地面朝向、木桥连接与明暗是否清楚；不要未经确认重做地图美术。
5. 在相同相机下实现 Blender 地面与每棵树/树桩的 RGBA 透明层导出，保留脚底锚点和裁切偏移。现有 build_blender.py 目前只自动输出整图。Godot 已导出的样本在 assets/forest_prerender/，可用于理解 manifest 格式，但不能冒充 Blender 出图。
6. 另存为新输出目录。不要覆盖唯一参考图，不要覆盖未备份的人工修绘；保留日志和源工程。
7. 如有 Godot 4.7.2，使用本包二维实验验证人物前后遮挡和桥面通行，并运行 tests/forest_prerender.gd。否则先交付可审查的 Blender 工程、预览图、分层图和输出清单，并明确尚未在 Godot 验证。

不要生成音乐，不要添加剧情、石门解锁或怀表新能力。最终报告区分实际已验证成果和待验证部分，不要把命令执行成功等同于美术完成。
''')
write("AGENTS.md", '''# Portable forest experiment

Read README_先读我.md and HANDOFF_PROMPT.md first. User direction: prerendered backgrounds plus 2D pixel characters. Do not change to realtime 3D. Preserve the folder structure. Blender scripts have not yet been executed in Blender; existing previews were rendered in Godot. Keep these validation states explicit. Installed-skill copies and licenses are under skills/. The optional Godot project is standalone and has no prologue or music autoloads.
''')
write("output/forest-study/.gdignore", "")

# Check runnable sources, expected shared inputs and checksum every payload file.
for path in bundle.rglob("*.py"):
    ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
layout = json.loads((bundle / "data/art/forest_study.json").read_text(encoding="utf-8"))
assert len(layout["objects"]) == 543
files = []
for path in sorted(bundle.rglob("*")):
    if path.is_file():
        files.append({"path":path.relative_to(bundle).as_posix(),"bytes":path.stat().st_size,
                      "sha256":hashlib.sha256(path.read_bytes()).hexdigest()})
write("checksums.json", json.dumps({"files":files}, ensure_ascii=False, indent=2))
archive = destination / (name + ".zip")
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as zip_out:
    for path in sorted(bundle.rglob("*")):
        if path.is_file():
            zip_out.write(path, name + "/" + path.relative_to(bundle).as_posix())
with zipfile.ZipFile(archive) as zip_in:
    assert zip_in.testzip() is None
    for item in files:
        payload = zip_in.read(name + "/" + item["path"])
        assert hashlib.sha256(payload).hexdigest() == item["sha256"], item["path"]
print(json.dumps({"zip":str(archive),"folder":str(bundle),"files":len(files)+1,
                  "bytes":archive.stat().st_size,"sha256":hashlib.sha256(archive.read_bytes()).hexdigest()},ensure_ascii=False))
