"""Blender 5.2: source-preserving layered image-card setup, not a 3D reconstruction.
Run: blender -b --python-exit-code 1 --python this.py -- --root <portable-folder>
"""
import argparse
import json
import sys
from pathlib import Path

import bpy
from mathutils.geometry import tessellate_polygon
from mathutils import Vector

args = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
parser = argparse.ArgumentParser()
parser.add_argument("--root", required=True)
options = parser.parse_args(args)
root = Path(options.root).resolve()
source = root/"images/forest-original-8k.png"
scene = bpy.data.scenes.new("Latest_Forest_Locked_Camera")
bpy.context.window.scene = scene
image = bpy.data.images.load(str(source), check_existing=False)
image.pack()
width,height = image.size
assert (width,height) == (8192,4608), (width,height)
image.colorspace_settings.name = "sRGB"
material = bpy.data.materials.new("MAT_Original_Unlit_Closest")
material.use_nodes = True
nodes = material.node_tree.nodes
nodes.clear()
texture = nodes.new("ShaderNodeTexImage")
texture.image = image
texture.interpolation = "Closest"
emission = nodes.new("ShaderNodeEmission")
output = nodes.new("ShaderNodeOutputMaterial")
material.node_tree.links.new(texture.outputs["Color"],emission.inputs["Color"])
material.node_tree.links.new(emission.outputs[0],output.inputs["Surface"])

# Coordinates refer to the 2048x1152 analysis canvas, preserving full-resolution UVs.
# These are regional cards, not clean silhouette mattes or invented hidden surfaces.
regions = [
    dict(id="00_MASTER", title="完整背景／锁定", depth=0, points=[[0,0],[2048,0],[2048,1152],[0,1152]]),
    dict(id="10_CAVE_REGION", title="洞口与古树区域／待细抠", depth=.10,
         points=[[1525,0],[2048,0],[2048,600],[1830,625],[1680,475],[1460,355]]),
    dict(id="20_CENTER_ROOT_REGION", title="中央树根区域／待细抠", depth=.20,
         points=[[1030,0],[1250,0],[1230,200],[1190,305],[1230,470],[1370,565],[1490,670],[1450,765],[1300,650],[1120,640],[1035,535],[1000,330],[930,175]]),
    dict(id="30_STELE_REGION", title="符文石碑区域／待细抠", depth=.30,
         points=[[1360,405],[1365,280],[1380,235],[1410,212],[1445,218],[1465,245],[1478,392],[1450,425],[1400,430]]),
    dict(id="40_FOREGROUND_LEFT_REGION", title="左下前景区域／待细抠", depth=.40,
         points=[[150,1152],[260,970],[300,850],[420,760],[530,800],[635,730],[700,700],[750,765],[790,650],[830,660],[895,765],[1010,780],[1060,925],[1000,1060],[1170,1152]]),
    dict(id="50_FOREGROUND_RIGHT_REGION", title="右下前景区域／待细抠", depth=.50,
         points=[[1160,1152],[1320,1070],[1330,970],[1410,900],[1510,770],[1620,665],[1700,565],[1800,530],[1860,450],[2048,430],[2048,1152]]),
]
cards = []
for region in regions:
    collection = bpy.data.collections.new(region["id"])
    scene.collection.children.link(collection)
    points = region["points"]
    verts = [Vector((x/100-10.24,5.76-y/100,region["depth"])) for x,y in points]
    triangles = tessellate_polygon([verts])
    faces = [tuple(corner if isinstance(corner,int) else next(i for i,v in enumerate(verts) if (v-corner).length < 1e-6) for corner in triangle) for triangle in triangles]
    mesh = bpy.data.meshes.new(region["id"])
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    uv = mesh.uv_layers.new(name="OriginalCoordinates")
    for face in mesh.polygons:
        for loop_index in face.loop_indices:
            vertex_index = mesh.loops[loop_index].vertex_index
            x,y = points[vertex_index]
            uv.data[loop_index].uv = (x/2048,1-y/1152)
    mesh.materials.append(material)
    obj = bpy.data.objects.new(region["id"],mesh)
    collection.objects.link(obj)
    obj["meaning"] = region["title"]
    obj["status"] = "regional card, silhouette cleanup required" if region["depth"] else "source-preserving master"
    obj.lock_location = (True,True,True)
    obj.lock_rotation = (True,True,True)
    obj.lock_scale = (True,True,True)
    cards.append(obj)

camera_data = bpy.data.cameras.new("Locked_Orthographic")
camera = bpy.data.objects.new("CAM_LOCKED_DO_NOT_MOVE",camera_data)
scene.collection.objects.link(camera)
camera.location = (0,0,20)
camera.rotation_euler = (0,0,0)
camera_data.type = "ORTHO"
camera_data.ortho_scale = 20.48
camera_data.lens = 50
scene.camera = camera
camera.lock_location = (True,True,True)
camera.lock_rotation = (True,True,True)
scene.world = bpy.data.worlds.new("Unlit_Backdrop")
scene.world.color = (0,0,0)
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = width
scene.render.resolution_y = height
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.image_settings.color_depth = "8"
scene.render.film_transparent = True
scene.render.dither_intensity = 0
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
scene["pipeline"] = "Source-preserving 2.5D image cards, not rebuilt 3D geometry"
scene["source_size"] = "8192x4608"
scene["camera_rule"] = "Fixed camera; no parallax until hidden surfaces are painted and masks refined"

for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == "VIEW_3D":
            area.spaces.active.region_3d.view_perspective = "CAMERA"
            area.spaces.active.shading.type = "MATERIAL"
bpy.ops.wm.save_as_mainfile(filepath=str(root/"forest-latest-layered.blend"))

# Preview and regional RGBA exports at 2048x1152; native 8K texture stays packed.
scene.render.resolution_percentage = 25
scene.render.filepath = str(root/"images/blender-composite-preview.png")
bpy.ops.render.render(write_still=True)
for card,region in zip(cards,regions):
    if region["depth"] == 0:
        continue
    for obj in cards:
        obj.hide_render = obj != card
    scene.render.filepath = str(root/"layers"/(region["id"]+".png"))
    bpy.ops.render.render(write_still=True)
for obj in cards:
    obj.hide_render = False
scene.render.resolution_percentage = 100
scene.render.filepath = "//images/blender-full-8k.png"
bpy.ops.wm.save_as_mainfile(filepath=str(root/"forest-latest-layered.blend"))
manifest = {"source_size":[width,height],"analysis_size":[2048,1152],
    "layer_export_size":[2048,1152],"source_preserved":True,"masks_are":"regional, not silhouette-clean",
    "blender_version":bpy.app.version_string,"regions":regions,
    "hidden_surfaces":"not painted; master stays intact", "camera":"fixed orthographic"}
(root/"layers/manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding="utf-8")
print("LATEST FOREST READY:",root)
