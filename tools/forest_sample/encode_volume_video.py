"""Encode Godot's actual whole-route physics recording with Blender FFmpeg."""
from pathlib import Path
import bpy
root=Path(__file__).resolve().parents[2]/'output/volume-forest'
source=root/'full-route.avi'
scene=bpy.context.scene
editor=scene.sequence_editor_create()
editor.strips.new_movie('ActualTraversal',str(source),channel=1,frame_start=1)
clip=bpy.data.movieclips.load(str(source))
scene.render.resolution_x=clip.size[0];scene.render.resolution_y=clip.size[1]
scene.render.resolution_percentage=100;scene.render.fps=30
scene.frame_start=1;scene.frame_end=clip.frame_duration;scene.render.use_sequencer=True
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
scene.render.image_settings.media_type='VIDEO';scene.render.image_settings.file_format='FFMPEG'
scene.render.ffmpeg.format='MPEG4';scene.render.ffmpeg.codec='H264'
scene.render.ffmpeg.constant_rate_factor='MEDIUM';scene.render.ffmpeg.audio_codec='NONE'
scene.render.filepath=str(root/'full-route.mp4')
bpy.ops.render.render(animation=True)
print('ACTUAL_ROUTE_VIDEO_READY',scene.frame_end)
