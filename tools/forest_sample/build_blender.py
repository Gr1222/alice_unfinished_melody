"""Blender 4.2+ / 5.x: --background --python this_file.py [-- --render].

Creates a NEW scene and retains existing scenes. Outputs never overwrite earlier runs.
Shared input: data/art/forest_study.json. No addons, network or external dependencies.
"""
import json
import math
import sys
from datetime import datetime
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
data = json.loads((ROOT/"data/art/forest_study.json").read_text(encoding="utf-8"))
stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
out = ROOT/"output/forest-study"/stamp
out.mkdir(parents=True, exist_ok=False)
scene = bpy.data.scenes.new("Forest_Bridge_Study_"+stamp)
bpy.context.window.scene = scene
groups = {}
materials = {}
mesh_cache = {}


def xyz(v):
    # Shared Godot Y-up -> Blender Z-up, preserve handedness.
    return Vector((v[0], -v[2], v[1]))


def linear(c):
    return c/12.92 if c < .04045 else ((c+.055)/1.055)**2.4


for name, color in data["palette"].items():
    mat = bpy.data.materials.new("MAT_"+name)
    rgb = tuple(linear(int(color[i:i+2],16)/255) for i in (0,2,4))
    mat.diffuse_color = (*rgb,1)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    if name in ("cyan","yellow"):
        emission = nodes.new("ShaderNodeEmission")
        emission.inputs["Color"].default_value = (*rgb,1)
        emission.inputs["Strength"].default_value = 1.5
        mat.node_tree.links.new(emission.outputs[0],output.inputs[0])
    else:
        diffuse = nodes.new("ShaderNodeBsdfDiffuse")
        diffuse.inputs["Color"].default_value = (1,1,1,1)
        to_rgb = nodes.new("ShaderNodeShaderToRGB")
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "CONSTANT"
        ramp.color_ramp.elements.remove(ramp.color_ramp.elements[1])
        for i,(threshold,factor) in enumerate([(0,.38),(.28,.68),(.58,1.0)]):
            element = ramp.color_ramp.elements[0] if i==0 else ramp.color_ramp.elements.new(threshold)
            element.position = threshold
            element.color = (*(c*factor for c in rgb),1)
        emission = nodes.new("ShaderNodeEmission")
        mat.node_tree.links.new(diffuse.outputs[0],to_rgb.inputs[0])
        mat.node_tree.links.new(to_rgb.outputs[0],ramp.inputs[0])
        mat.node_tree.links.new(ramp.outputs[0],emission.inputs[0])
        mat.node_tree.links.new(emission.outputs[0],output.inputs[0])
    materials[name] = mat

for item in data["objects"]:
    kind,s = item["kind"],item["s"]
    loc = xyz(item["p"])
    if kind=="patch":
        verts = [xyz(p) for p in item["points"]]
        mesh = bpy.data.meshes.new(item["name"])
        mesh.from_pydata(verts,[],[list(reversed(range(len(verts))))])
        mesh.update()
        obj = bpy.data.objects.new(item["name"],mesh)
        scene.collection.objects.link(obj)
    else:
        if kind=="box":
            bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
            obj=bpy.context.object
            obj.scale=(s[0],s[2],s[1])
        elif kind in ("sphere","cap"):
            bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=6,radius=1,location=loc)
            obj=bpy.context.object
            obj.scale=(s[0],s[2],s[1])
        elif kind=="ring":
            bpy.ops.mesh.primitive_torus_add(major_segments=20,minor_segments=4,
                location=loc,major_radius=s[0],minor_radius=.015)
            obj=bpy.context.object
            obj.scale.y=s[2]/s[0]
        elif kind=="branch":
            end=xyz(item["end"])
            direction=end-loc
            bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=s[0],radius2=s[1],
                depth=direction.length,location=(loc+end)*.5)
            obj=bpy.context.object
            obj.rotation_euler=direction.to_track_quat("Z","Y").to_euler()
        else:
            bpy.ops.mesh.primitive_cone_add(vertices=10,radius1=s[0],
                radius2=.07 if kind=="cone" else s[0],depth=s[1],location=loc)
            obj=bpy.context.object
            obj.scale.y=s[2]/s[0]
        obj.rotation_euler.z += item.get("yaw",0)
    obj.name=item["name"]
    obj.data.materials.append(materials[item["mat"]])
    # Link identical mesh data; scale and transform remain independently editable.
    if kind not in ("patch","branch"):
        key=(kind,item["mat"],*([] if kind in ("sphere","cap","box") else s))
        if key in mesh_cache:
            unused=obj.data
            obj.data=mesh_cache[key]
            bpy.data.meshes.remove(unused)
        else:
            mesh_cache[key]=obj.data
    group=item["group"]
    if group not in groups:
        groups[group]=bpy.data.collections.new("COL_"+group)
        scene.collection.children.link(groups[group])
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    groups[group].objects.link(obj)

camera_data=bpy.data.cameras.new("Orthographic")
camera=bpy.data.objects.new("CAM_Forest",camera_data)
scene.collection.objects.link(camera)
camera.location=xyz(data["camera"]["position"])
camera.rotation_euler=(xyz(data["camera"]["target"])-camera.location).to_track_quat("-Z","Y").to_euler()
camera_data.type="ORTHO"
camera_data.ortho_scale=data["camera"]["ortho_size"]
scene.camera=camera
sun_data=bpy.data.lights.new("Moon",type="SUN")
sun_data.energy=2
sun=bpy.data.objects.new("LIGHT_Moon",sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler=(math.radians(25),math.radians(-28),math.radians(-30))
scene.world=bpy.data.worlds.new("ForestNight")
scene.world.use_nodes=True
scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.04,.07,.09,1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value=.5
try:
    scene.render.engine="BLENDER_EEVEE_NEXT"
except TypeError:
    scene.render.engine="BLENDER_EEVEE"
scene.render.resolution_x=960
scene.render.resolution_y=540
scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
scene.render.film_transparent=False
scene.render.filepath=str(out/"blender-preview.png")
scene.view_settings.view_transform="Standard"
scene["status"]="Initial geometry study; requires pixel paint-over and native-scale review."
# Save a copy: do not change the path of any user's open .blend.
bpy.ops.wm.save_as_mainfile(filepath=str(out/"forest-bridge.blend"),copy=True)
if "--render" in sys.argv:
    bpy.ops.render.render(write_still=True)
print("Forest study saved:",out)
