"""Blender 5.2: camera-mapped, full-map 2.5D forest and editable asset library.

The source painting defines all UVs. Geometry is a fixed-view relief, not an
invented all-angle reconstruction. Runtime uses the same projection in Godot.
"""
import json, math
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
ASSET=ROOT/'assets/complete_forest'
OUT=ROOT/'output/forest-production'
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'.gdignore').write_text('')
layout=json.loads((ASSET/'layout.json').read_text(encoding='utf-8'))
scene=bpy.data.scenes.new('Enchanted_Forest_Full_Map')
bpy.context.window.scene=scene
collections={}
for name in ['A_PaintedGround','B_Woodland','C_Landmarks','D_Foreground','E_Accents','LIB_ReusableAssets']:
    col=bpy.data.collections.new(name); scene.collection.children.link(col); collections[name]=col
e=math.radians(50); s=math.sin(e); c=math.cos(e); unit=32/2048

def world(u,v,h=0):
    return Vector(((u-1024)*unit,-((v-576)*unit+h*c)/s,h))

def project(p):
    return (p.x/unit+1024,(-p.y*s-p.z*c)/unit+576)

def link(name,verts,faces,collection,uvs=None):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces); mesh.update()
    obj=bpy.data.objects.new(name,mesh); collections[collection].objects.link(obj)
    uv=mesh.uv_layers.new(name='OriginalPaintingProjection')
    for loop in mesh.loops:
        u,v=project(mesh.vertices[loop.vertex_index].co)
        uv.data[loop.index].uv=(u/2048,1-v/1152)
    return obj

painting=bpy.data.images.load(str(ASSET/'painting.png')); painting.pack()
def art_material(name,mask=None):
    mat=bpy.data.materials.new('ART_'+name); mat.use_nodes=True
    nodes=mat.node_tree.nodes; nodes.clear(); links=mat.node_tree.links
    image=nodes.new('ShaderNodeTexImage'); image.image=painting; image.interpolation='Closest'
    emit=nodes.new('ShaderNodeEmission'); links.new(image.outputs['Color'],emit.inputs['Color'])
    out=nodes.new('ShaderNodeOutputMaterial')
    if mask:
        alpha=nodes.new('ShaderNodeTexImage'); alpha.image=bpy.data.images.load(str(mask)); alpha.image.colorspace_settings.name='Non-Color'; alpha.image.pack()
        alpha.interpolation='Closest'
        transparent=nodes.new('ShaderNodeBsdfTransparent'); mix=nodes.new('ShaderNodeMixShader')
        links.new(alpha.outputs['Color'],mix.inputs[0]); links.new(transparent.outputs[0],mix.inputs[1]); links.new(emit.outputs[0],mix.inputs[2]); links.new(mix.outputs[0],out.inputs[0])
    else: links.new(emit.outputs[0],out.inputs[0])
    return mat

materials={item['id']:art_material(item['id'],None if item['kind']=='ground' else ASSET/(item['id']+'.png')) for item in layout['layers']}

def height(item,u,v,inside):
    kind=item['kind']; anchor=item['anchor']; maximum=item['height']
    if kind=='ground': return -.025
    if kind=='portal': return max(.15,(377-v)*unit*.85)+.03
    if kind=='stone': return max(.06,(anchor[1]-v)*unit*.72)+.055
    if kind=='plant': return max(.04,(anchor[1]-v)*unit*.75)+inside*.09
    if kind=='foreground': return .12+min(maximum,max(0,(anchor[1]-v)*unit*.75))+inside*.27
    if kind=='ancient': return .1+min(maximum,max(0,(435-v)*unit*.9))+inside*.45
    # Central trunk meets the long low root without lifting it into an arch.
    if item['id']=='central_tree':
        return .10+min(maximum,max(0,(570-v)*unit*.88))+inside*.31
    return .05+min(maximum,max(0,(anchor[1]-v)*unit*.85))+inside*.22

geometry=[]
for item in layout['layers']:
    name=item['id']; kind=item['kind']
    im=bpy.data.images.load(str(ASSET/(name+'.png')),check_existing=True)
    raw=np.empty(im.size[0]*im.size[1]*4,dtype=np.float32); im.pixels.foreach_get(raw)
    mask=np.flipud(raw.reshape(im.size[1],im.size[0],4)[:,:,0])
    # All meshes share an 8 pixel grid; transparent boundaries retain the 2K matte.
    step=8 if kind!='ground' else 32
    verts=[]; faces=[]; cache={}
    def vertex(u,v):
        key=(u,v)
        if key not in cache:
            yy=min(1151,max(0,int(v))); xx=min(2047,max(0,int(u)))
            block=mask[max(0,yy-12):min(1152,yy+13),max(0,xx-12):min(2048,xx+13)]
            inside=float(block.mean())
            cache[key]=len(verts); verts.append(world(u,v,height(item,u,v,inside)))
        return cache[key]
    for v in range(0,1152,step):
        for u in range(0,2048,step):
            if kind!='ground' and mask[v:min(v+step+1,1152),u:min(u+step+1,2048)].max()<.5: continue
            faces.append(tuple(vertex(x,y) for x,y in [(u,v),(u+step,v),(u+step,v+step),(u,v+step)]))
    collection='A_PaintedGround' if kind=='ground' else 'D_Foreground' if kind=='foreground' else 'B_Woodland' if name.startswith('woodland') else 'E_Accents' if kind=='plant' else 'C_Landmarks'
    obj=link(name,verts,faces,collection); obj.data.materials.append(materials[name]); geometry.append(obj)
    for face in obj.data.polygons: face.use_smooth=True
    obj['source_art']='User forest painting, camera UV projection'
    obj['mask']=name+'.png'; obj['depth_role']=kind
    # Editable solidify supplies real thickness; keep it live in the Blender file.
    if kind not in ('ground','portal'):
        modifier=obj.modifiers.new('Bark_or_plant_thickness','SOLIDIFY'); modifier.thickness=.12 if kind=='plant' else .27; modifier.offset=-1

plain=art_material('projected_bark')
# Explicit oval tube with actual back/side walls; the dark cavity is recessed.
verts=[]; faces=[]
center=world(1754,265,1.7)
right=Vector((1,0,0)); up=Vector((0,c,s)); normal=Vector((0,-s,c))
for i in range(128):
    a=i*math.tau/128
    radial=(right*math.cos(a)+up*math.sin(a)).normalized()
    point=center+right*(math.cos(a)*1.91)+up*(math.sin(a)*2.15)
    for j in range(12):
        b=j*math.tau/12
        irregular=1+.065*math.sin(a*7)+.035*math.cos(a*13)
        verts.append(point+radial*(math.cos(b)*.21*irregular)+normal*(math.sin(b)*.29))
for i in range(128):
    for j in range(12): faces.append((i*12+j,i*12+(j+1)%12,((i+1)%128)*12+(j+1)%12,((i+1)%128)*12+j))
rim=link('portal_bark_rim',verts,faces,'C_Landmarks'); rim.data.materials.append(plain); geometry.append(rim)
for p in rim.data.polygons:p.use_smooth=True

def painted_tube(name,points,radii,collection='C_Landmarks',sides=12):
    points=[world(u,v,h) for u,v,h in points]; verts=[]; faces=[]
    for i,p in enumerate(points):
        tangent=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
        axis=tangent.cross(Vector((0,0,1)))
        if axis.length<.01:axis=Vector((1,0,0))
        axis.normalize(); second=tangent.cross(axis).normalized()
        for j in range(sides):
            a=j*math.tau/sides
            verts.append(p+radii[i]*(math.cos(a)*axis+math.sin(a)*second))
    for i in range(len(points)-1):
        for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    faces.extend([tuple(reversed(range(sides))),tuple(range((len(points)-1)*sides,len(points)*sides))])
    obj=link(name,verts,faces,collection); obj.data.materials.append(plain); geometry.append(obj)
    for p in obj.data.polygons:p.use_smooth=True
    return obj

# These centerlines follow visible roots in the original, not random tree scatter.
for name,pts,rs in [
 ('low_crossing_root',[(1215,559,.12),(1270,610,.23),(1343,666,.25),(1400,720,.21),(1440,794,.13)],[.12,.18,.19,.14,.035]),
 ('east_root_primary',[(1895,442,.34),(1856,528,.25),(1775,601,.13),(1680,668,.08)],[.31,.26,.14,.025]),
 ('foreground_root_spine',[(1998,1119,.48),(1844,1032,.55),(1684,904,.7),(1596,791,.65),(1544,680,.38)],[.28,.29,.25,.18,.035]),
 ('foreground_root_fork',[(1700,919,.51),(1610,1030,.36),(1562,1120,.2)],[.22,.16,.025]),
 ('central_root_west',[(1172,530,.25),(1089,582,.18),(1041,635,.04)],[.25,.16,.02])]:
    painted_tube(name,pts,rs)

# Separate non-glossy pool surfaces, source-art UVs, no mirror-water treatment.
for i,pool in enumerate(layout['pools']):
    cx,cy=pool['center']; rx,ry=pool['radii']; verts=[world(cx,cy,.015)]
    for j in range(64):
        a=j*math.tau/64; t=1+.08*math.sin(a*5)+.05*math.cos(a*9)
        verts.append(world(cx+rx*math.cos(a)*t,cy+ry*math.sin(a)*t,.015))
    faces=[(0,j+1,(j+1)%64+1) for j in range(64)]
    obj=link('puddle_%d'%i,verts,faces,'E_Accents'); obj.data.materials.append(plain); geometry.append(obj)

# Reusable library is intentionally separate from the composed scene.
def library_material(name,color):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);return m
libmat=library_material('LIB_MutedTeal',(.08,.2,.2))
for i in range(3):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.35,location=(40+i,0,.25))
    obj=bpy.context.object;obj.name='LIB_Stone_%d'%i;obj.scale=(1,.65,.7+i*.1)
    for col in list(obj.users_collection):col.objects.unlink(obj)
    collections['LIB_ReusableAssets'].objects.link(obj);obj.data.materials.append(libmat)
for i in range(3):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=.25,location=(40+i,1,.4))
    obj=bpy.context.object;obj.name='LIB_MushroomCap_%d'%i;obj.scale=(1,.9,.45+i*.08)
    for col in list(obj.users_collection):col.objects.unlink(obj)
    collections['LIB_ReusableAssets'].objects.link(obj);obj.data.materials.append(libmat)
collections['LIB_ReusableAssets'].hide_render=True

# Solidify creates new rim UVs by copying border texels. Reproject those faces
# too, otherwise a fixed-view painting develops visible doubled outline seams.
for obj in geometry:
    if obj.modifiers:
        bpy.context.view_layer.objects.active=obj
        obj.select_set(True)
        for modifier in list(obj.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
    uv=obj.data.uv_layers.active
    for loop in obj.data.loops:
        u,v=project(obj.matrix_world@obj.data.vertices[loop.vertex_index].co)
        uv.data[loop.index].uv=(u/2048,1-v/1152)

camera_data=bpy.data.cameras.new('FixedGameplayCamera')
camera=bpy.data.objects.new('CAM_FixedGameplay',camera_data);scene.collection.objects.link(camera)
camera.location=(0,-40*c,40*s);camera.rotation_euler=(-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO';camera_data.ortho_scale=32;camera_data.clip_end=150
scene.camera=camera
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=2048;scene.render.resolution_y=1152;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
scene.world=bpy.data.worlds.new('ForestNight');scene.world.color=(.025,.04,.06)
scene['method']='Fixed-camera original-art projection over authored depth relief and volumetric roots. Alternate-camera unseen surfaces are not reconstructed.'
scene['reference_sha256']=layout['source_sha256']
scene['runtime']='res://scenes/forest/EnchantedForest.tscn'
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'enchanted-forest-full.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in geometry:obj.select_set(True)
bpy.context.view_layer.objects.active=geometry[0]
bpy.ops.export_scene.gltf(filepath=str(ASSET/'forest.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_materials='NONE',export_cameras=False,export_lights=False)
scene.render.filepath=str(OUT/'blender-full-scene.png')
bpy.ops.render.render(write_still=True)
(OUT/'build-report.json').write_text(json.dumps(dict(blender=bpy.app.version_string,objects=len(geometry),vertices=sum(len(o.data.vertices) for o in geometry),projection='fixed orthographic 50 degrees, 32m width',source_sha256=layout['source_sha256']),indent=2))
print('COMPLETE_FOREST_BUILT',len(geometry))
