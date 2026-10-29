"""Portable source and runnable Godot handoff for the selected solid map."""
from pathlib import Path
import zipfile, json, hashlib
ROOT=Path(__file__).resolve().parents[2]
dest=ROOT/'output/transfer/forest-volume-whole-map.zip'
dest.parent.mkdir(parents=True,exist_ok=True)
entries={}
def add(source,target):entries[target]=source.read_bytes()
for folder in ['assets/volume_forest','assets/user_art','scenes/prologue','scenes/music','scripts','data']:
    for source in (ROOT/folder).rglob('*'):
        if source.is_file() and source.suffix not in ('.import','.uid'):
            add(source,'game/'+str(source.relative_to(ROOT)).replace('\\','/'))
for relative in ['scenes/art/SpatialForest.gd','scenes/forest/VolumeForest.gd','scenes/forest/VolumeForest.tscn',
 'tests/volume_forest.gd','tests/prologue_flow.gd','tools/forest_sample/build_volume_map.py',
 'tools/forest_sample/build_spatial_forest.py','tools/forest_sample/encode_volume_video.py',
 'assets/spatial_forest/bark.png','tests/project_entry.gd','docs/START-HERE.zh-CN.md','试玩森林.cmd','打开最新工程.cmd']:
    add(ROOT/relative,'game/'+relative)
project=(ROOT/'project.godot').read_text(encoding='utf-8').replace('res://scenes/prologue/Prologue.tscn','res://scenes/forest/VolumeForest.tscn')
entries['game/project.godot']=project.encode('utf-8')
add(ROOT/'output/volume-forest/forest-whole-map.blend','Blender/forest-whole-map.blend')
add(ROOT/'assets/latest_forest/original-8k.png','reference/original-8k.png')
for filename in ['whole-map.png','root.png','root-side.png','portal.png','full-route.mp4']:
    add(ROOT/'output/volume-forest'/filename,'preview/'+filename)
add(ROOT/'docs/volume-forest-map.md','制作与验证记录.md')
entries['先看这里.md']='''# 森林整图 · 实体版

这是采用 W 跳过低横木的实体三维版本，不是原画投影浮雕。

1. Blender：打开 Blender/forest-whole-map.blend。纹理已内嵌，模型按区域放入九个集合，可检查侧面与厚度。
2. Godot：用 Godot 4.7.2 打开 game/project.godot，按 F5。
3. WASD / 方向键移动，空格跳跃，P 自动走全程，Tab 看整图，C 看侧面，E 调查/进入洞口，R 回入口，Esc 暂停。对白 E / Enter 下一句。
4. preview/full-route.mp4 是实际物理巡游录像；preview/whole-map.png 是全景。

整图区域与可玩路线已扩建，模型细节仍比原画简化。完整边界与实际验证见《制作与验证记录.md》。此便携副本默认启动森林，原项目的主序章未改。
'''.encode('utf-8')
manifest={name:dict(bytes=len(content),sha256=hashlib.sha256(content).hexdigest()) for name,content in entries.items()}
entries['manifest.json']=json.dumps(manifest,ensure_ascii=False,indent=2).encode('utf-8')
with zipfile.ZipFile(dest,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for name,content in entries.items():archive.writestr('forest-volume-whole-map/'+name,content)
with zipfile.ZipFile(dest) as archive:
    assert archive.testzip() is None
    assert all(hashlib.sha256(archive.read('forest-volume-whole-map/'+name)).hexdigest()==item['sha256'] for name,item in manifest.items())
print('VERIFIED_PACKAGE',dest,len(entries),'files',dest.stat().st_size,'bytes')
