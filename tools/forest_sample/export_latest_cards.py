"""Open the supplied .blend, then run this in Blender's Text Editor.
Exports the current edited cards; never regenerates or replaces their geometry.
"""
from datetime import datetime
from pathlib import Path
import bpy

EXPORT_PERCENT = 25  # 25 = 2048x1152; 50 = 4096x2304; 100 = 8192x4608
if not bpy.data.filepath:
    raise RuntimeError("Save the .blend before exporting")
scene = bpy.context.scene
root = Path(bpy.data.filepath).parent
folder = root/"exports"/datetime.now().strftime("%Y%m%d-%H%M%S")
folder.mkdir(parents=True,exist_ok=False)
objects = [obj for obj in scene.objects if obj.type == "MESH"]
state = {obj.name:obj.hide_render for obj in objects}
old_percent = scene.render.resolution_percentage
old_path = scene.render.filepath
old_transparent = scene.render.film_transparent
try:
    scene.render.resolution_percentage = EXPORT_PERCENT
    scene.render.film_transparent = True
    scene.render.image_settings.color_mode = "RGBA"
    for obj in objects:
        obj.hide_render = False
    scene.render.filepath = str(folder/"COMPOSITE.png")
    bpy.ops.render.render(write_still=True)
    for target in objects:
        for obj in objects:
            obj.hide_render = obj != target
        scene.render.filepath = str(folder/(target.name+".png"))
        bpy.ops.render.render(write_still=True)
finally:
    for obj in objects:
        obj.hide_render = state[obj.name]
    scene.render.resolution_percentage = old_percent
    scene.render.filepath = old_path
    scene.render.film_transparent = old_transparent
print("Exported:",folder)
