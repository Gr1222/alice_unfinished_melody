"""Blender: apply ID-mask silhouettes to original-color image cards and export layers.
No original color repainting; generated image is used ONLY as a segmentation guide.
"""
import argparse
import json
import sys
from pathlib import Path
import bpy
import numpy as np

parser = argparse.ArgumentParser()
parser.add_argument("--root",required=True)
options = parser.parse_args(sys.argv[sys.argv.index("--")+1:])
root = Path(options.root).resolve()
root.mkdir(parents=True,exist_ok=True)
for name in ("layers","masks","previews"):
    (root/name).mkdir(exist_ok=True)
scene = bpy.data.scenes.new("LatestForest_Ready")
bpy.context.window.scene = scene
source = bpy.data.images.load(str(root/"original-8k.png"))
source.pack()
mask = bpy.data.images.load(str(root/"segmentation-guide.png"))
mask.colorspace_settings.name = "Non-Color"
mask.pack()
# Normalize the generated ID matte, discarding small disconnected color islands.
# Source RGB artwork is never processed here.
mw,mh=mask.size
buffer=np.empty(mw*mh*4,dtype=np.float32)
mask.pixels.foreach_get(buffer)
pixels=buffer.reshape((mh,mw,4))
clean=np.zeros_like(pixels)
clean[:,:,3]=1
for color in [(1,0,0),(0,1,0),(0,0,1),(1,1,0)]:
    selected=np.ones((mh,mw),dtype=bool)
    for channel,wanted in enumerate(color):
        selected &= (pixels[:,:,channel]>.5) if wanted else (pixels[:,:,channel]<.5)
    for y,x in zip(*np.nonzero(selected)):
        if not selected[y,x]:
            continue
        pending=[(int(y),int(x))]
        selected[y,x]=False
        component=[]
        while pending:
            cy,cx=pending.pop()
            component.append((cy,cx))
            for ny,nx in [(cy-1,cx),(cy+1,cx),(cy,cx-1),(cy,cx+1)]:
                if 0<=ny<mh and 0<=nx<mw and selected[ny,nx]:
                    selected[ny,nx]=False
                    pending.append((ny,nx))
        if len(component)>=24:
            yy,xx=zip(*component)
            clean[yy,xx,:3]=color
normalized=bpy.data.images.new("Clean_ID_Matte",width=mw,height=mh,alpha=True)
normalized.colorspace_settings.name="Non-Color"
normalized.pixels.foreach_set(clean.ravel())
normalized.filepath_raw=str(root/"segmentation-cleaned.png")
normalized.file_format="PNG"
normalized.save()
normalized.pack()
mask=normalized
regions = [
    {"id":"central_tree","channel":[1,0,0],"pivot":[1160,660],"order":"y"},
    {"id":"foreground_left","channel":[0,1,0],"pivot":[0,1152],"order":"front"},
    {"id":"foreground_right","channel":[0,0,1],"pivot":[0,1152],"order":"front"},
    {"id":"rune_stone","channel":[1,1,0],"pivot":[1420,425],"order":"y"},
]

def card(name,depth,selection=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([(-10.24,-5.76,depth),(10.24,-5.76,depth),(10.24,5.76,depth),(-10.24,5.76,depth)],[],[(0,1,2,3)])
    uv=mesh.uv_layers.new()
    for loop,xy in zip(uv.data,[(0,0),(1,0),(1,1),(0,1)]):
        loop.uv=xy
    obj=bpy.data.objects.new(name,mesh)
    scene.collection.objects.link(obj)
    mat=bpy.data.materials.new("MAT_"+name)
    mat.use_nodes=True
    nodes=mat.node_tree.nodes
    nodes.clear()
    links=mat.node_tree.links
    tex=nodes.new("ShaderNodeTexImage")
    tex.image=source
    tex.interpolation="Closest"
    emit=nodes.new("ShaderNodeEmission")
    links.new(tex.outputs["Color"],emit.inputs["Color"])
    output=nodes.new("ShaderNodeOutputMaterial")
    factor=None
    if selection is not None:
        ids=nodes.new("ShaderNodeTexImage")
        ids.image=mask
        ids.interpolation="Closest"
        separate=nodes.new("ShaderNodeSeparateColor")
        links.new(ids.outputs["Color"],separate.inputs[0])
        for i,target in enumerate(selection):
            threshold=nodes.new("ShaderNodeMath")
            threshold.operation="GREATER_THAN" if target else "LESS_THAN"
            threshold.inputs[1].default_value=.5
            links.new(separate.outputs[i],threshold.inputs[0])
            if factor is None:
                factor=threshold.outputs[0]
            else:
                multiply=nodes.new("ShaderNodeMath")
                multiply.operation="MULTIPLY"
                links.new(factor,multiply.inputs[0])
                links.new(threshold.outputs[0],multiply.inputs[1])
                factor=multiply.outputs[0]
        transparent=nodes.new("ShaderNodeBsdfTransparent")
        mix=nodes.new("ShaderNodeMixShader")
        links.new(factor,mix.inputs[0])
        links.new(transparent.outputs[0],mix.inputs[1])
        links.new(emit.outputs[0],mix.inputs[2])
        links.new(mix.outputs[0],output.inputs[0])
    else:
        links.new(emit.outputs[0],output.inputs[0])
    mesh.materials.append(mat)
    obj.lock_location=(True,)*3
    obj.lock_rotation=(True,)*3
    return obj,mat,factor,emit,output

master=card("MASTER_ORIGINAL",0)[0]
cards=[]
for i,region in enumerate(regions):
    cards.append(card(region["id"],(i+1)*.1,region["channel"]))
camera_data=bpy.data.cameras.new("LockedOrtho")
camera=bpy.data.objects.new("CAMERA_LOCKED",camera_data)
scene.collection.objects.link(camera)
camera.location=(0,0,20)
camera_data.type="ORTHO"
camera_data.ortho_scale=20.48
scene.camera=camera
scene.render.engine="BLENDER_EEVEE"
scene.render.resolution_x=2048
scene.render.resolution_y=1152
scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.render.image_settings.file_format="PNG"
scene.render.image_settings.color_mode="RGBA"
scene.render.dither_intensity=0
scene.view_settings.view_transform="Standard"
scene.view_settings.look="None"
scene.world=bpy.data.worlds.new("Unlit")
scene.world.color=(0,0,0)
scene.render.filepath=str(root/"previews/blender-composite.png")
bpy.ops.render.render(write_still=True)
master.hide_render=True
for entry,region in zip(cards,regions):
    obj,mat,factor,emit,output=entry
    for candidate in cards:
        candidate[0].hide_render=candidate[0]!=obj
    scene.render.filepath=str(root/"layers"/(region["id"]+".png"))
    bpy.ops.render.render(write_still=True)
    # Export the exact shader selection as a standalone grayscale runtime mask.
    links=mat.node_tree.links
    mask_emission=mat.node_tree.nodes.new("ShaderNodeEmission")
    links.new(factor,mask_emission.inputs["Color"])
    surface_link=output.inputs[0].links[0]
    prior=surface_link.from_socket
    links.remove(surface_link)
    links.new(mask_emission.outputs[0],output.inputs[0])
    scene.render.filepath=str(root/"masks"/(region["id"]+".png"))
    bpy.ops.render.render(write_still=True)
    links.remove(output.inputs[0].links[0])
    links.new(prior,output.inputs[0])
    mat.node_tree.nodes.remove(mask_emission)
master.hide_render=False
for entry in cards:
    entry[0].hide_render=False
scene["source_preserved"]="Original RGB retained; generated ID guide used only as alpha masks"
scene["projection"]="Locked 2.5D image cards; no unobserved surfaces invented"
scene.render.resolution_x=8192
scene.render.resolution_y=4608
scene.render.filepath="//previews/full-8k.png"
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=="VIEW_3D":
            area.spaces.active.region_3d.view_perspective="CAMERA"
            area.spaces.active.shading.type="MATERIAL"
bpy.ops.wm.save_as_mainfile(filepath=str(root/"forest-ready.blend"))
(root/"manifest.json").write_text(json.dumps({"source_size":[8192,4608],"canvas_size":[2048,1152],
    "layers":regions,"blender_version":bpy.app.version_string,"generated_color_used":False,
    "hidden_surfaces_painted":False},indent=2),encoding="utf-8")
print("FINISHED_LATEST_FOREST",root)
