"""Expand the approved solid-volume/W-jump study into the whole forest map.

Uses the study's modeling primitives and bark material. No source-image plate,
camera-projected objects, or raised image silhouettes are used in this scene.
"""
import json, math, random, shutil
from pathlib import Path
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
ASSET=ROOT/'assets/volume_forest'
OUT=ROOT/'output/volume-forest'
ASSET.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
(OUT/'.gdignore').write_text('')
shutil.copy2(ROOT/'assets/spatial_forest/bark.png',ASSET/'bark.png')
# Reuse the approved, tested model primitives verbatim; don't execute the old
# study's placement/export section or mutate its assets.
shared=(Path(__file__).with_name('build_spatial_forest.py')).read_text(encoding='utf-8')
marker='# Low-contrast bare earth/moss'
assert marker in shared
shared=shared.split(marker)[0].replace('output/spatial-forest','output/volume-forest').replace('assets/spatial_forest','assets/volume_forest')
exec(compile(shared,str(Path(__file__).with_name('build_spatial_forest.py')),'exec'))
scene.name='EnchantedForest_WholeMap_SolidVolume'
rng=random.Random(271028)
collections={}
for name in ['01_Ground_Path','02_Left_Woodland','03_Distant_Woodland','04_Central_Tree',
 '05_Portal_Tree','06_Foreground_Roots','07_Plants_Stones','08_Pools_Magic','09_Lights_Cameras']:
    col=bpy.data.collections.new(name);scene.collection.children.link(col);collections[name]=col
current='01_Ground_Path'
def organize(obj):
    for col in list(obj.users_collection):col.objects.unlink(obj)
    collections[current].objects.link(obj)
    return obj
base_tube,base_sphere,base_cube,base_painted=tube,sphere,cube,painted_mesh
def tube(*args,**kwargs):return organize(base_tube(*args,**kwargs))
def sphere(*args,**kwargs):return organize(base_sphere(*args,**kwargs))
def cube(*args,**kwargs):return organize(base_cube(*args,**kwargs))
def painted_mesh(*args,**kwargs):return organize(base_painted(*args,**kwargs))

route=[[-12,0,9],[-10.4,0,7.5],[-9,0,6],[-6,0,3],[-2.5,0,.4],
       [.2,0,1.5],[3,0,1.6],[5.5,0,-.3],[7.6,0,-3.2],[9,0,-5.2]]
road,_=smooth(route,[.9]*len(route),8)
def distance_to_route(x,z):
    point=Vector((x,z));best=999
    for a,b in zip(road,road[1:]):
        aa=Vector((a[0],a[2]));bb=Vector((b[0],b[2]));d=bb-aa
        t=max(0,min(1,(point-aa).dot(d)/max(.00001,d.length_squared)))
        best=min(best,(point-aa-d*t).length)
    return best

def soil_color(x,z):
    a=.5+.22*math.sin(x*.43+z*.21)+.19*math.cos(z*.61-x*.16)
    return [.135+.03*a,.205+.04*a,.205+.038*a]
verts=[];colors=[];faces=[];nx,nz=100,82
for iz in range(nz+1):
 for ix in range(nx+1):
    x=-26+52*ix/nx;z=-22+44*iz/nz
    verts.append([x,-.025+.008*math.sin(x*.7)*math.cos(z*.5),z]);colors.append(soil_color(x,z))
for iz in range(nz):
 for ix in range(nx):
    a=iz*(nx+1)+ix;faces.append((a,a+1,a+nx+2,a+nx+1))
painted_mesh('EarthMoss',verts,faces,colors,'soil')
verts=[];colors=[];faces=[]
for i,p in enumerate(road):
    tangent=Vector(road[min(i+1,len(road)-1)])-Vector(road[max(0,i-1)])
    normal=Vector((-tangent.z,0,tangent.x)).normalized()
    for side in [-1.15,-.98,-.72,0,.72,.98,1.15]:
        v=Vector(p)+normal*side*(1+.04*math.sin(i*.9))
        edge=abs(side)>1;v.y=-.012 if edge else .012
        verts.append(list(v));f=max(0,1-abs(side)/1.15)
        base=soil_color(v.x,v.z);dirt=[.39,.36,.38]
        colors.append([base[k]*(1-min(1,f*4))+dirt[k]*min(1,f*4)+.009*math.sin(i*.6) for k in range(3)])
for i in range(len(road)-1):
 for band in range(6):
    a=7*i+band;faces.append((a,a+1,a+8,a+7))
painted_mesh('DirtPath',verts,faces,colors,'path')

# Broad authored moss islands with a gradual vertex-color edge.
for cx,cz,rx,rz in [(-9,-3,2.2,3.4),(-5,-1,2.3,1.5),(-1,-5,2.8,2.1),
 (3,-3,1.7,1.8),(7,3,2.5,1.5),(11,-2,1.4,2),(-5,7,1.6,1.8),(2,8,1.7,1.9)]:
    vs=[[cx,.001,cz]];cs=[[.18,.29,.25]];fs=[]
    for r in [.55,1]:
     for j in range(32):
        a=j*math.tau/32;t=1+.13*math.sin(a*5+cx)
        x=cx+math.cos(a)*rx*r*t;z=cz+math.sin(a)*rz*r*t
        vs.append([x,.001,z]);cs.append(soil_color(x,z) if r==1 else [.17,.27,.24])
    for j in range(32):
        fs.append((0,1+j,1+(j+1)%32));fs.append((1+j,33+j,33+(j+1)%32,1+(j+1)%32))
    painted_mesh('MossIsland',vs,fs,cs,'moss')

tree_proxies=[]
def planted_tree(x,z,h,r,twist):
    tree(x,z,h,r,twist);tree_proxies.append(dict(position=[x,0,z],radius=r*.9,height=h))
current='02_Left_Woodland'
# Composed rows with unequal depths/heights and deliberate open path margins.
for row,x0 in enumerate([-15.4,-13.5,-11.6]):
 for j in range(13):
    x=x0+rng.uniform(-.4,.4);z=-12+j*1.64+rng.uniform(-.42,.42)
    if distance_to_route(x,z)<1.5:continue
    planted_tree(x,z,rng.uniform(6.7,10.2),rng.uniform(.24,.52),rng.uniform(.2,.65))
# Hanging, draped vines connect trunks; all have round cross-sections.
for j in range(24):
    z=-11+j*.86;x=-12.8+rng.uniform(-1.5,1.5);h=rng.uniform(3.5,6.8)
    tube('HangingVine',[[x,h,z],[x+.7,h-1.2,z+.2],[x+.1,h-2.2,z+.35],
         [x+.45,max(.15,h-3.5),z+.4]],[.045,.038,.032,.014],'moss',6)
for j in range(11):
    z=-11+j*1.7;h=rng.uniform(3.6,7)
    tube('DrapedVine',[[-15,h,z],[-13.9,h-.65,z+.45],[-12.6,h-.8,z+.7],[-11.7,h+.3,z+1.2]],
         [.045,.04,.035,.025],'moss',6)
current='03_Distant_Woodland'
for j in range(17):
    x=-10+j*1.45;z=-11.8+rng.uniform(-.6,.6)
    planted_tree(x,z,rng.uniform(6.3,9),rng.uniform(.25,.47),rng.uniform(.25,.7))
for x,z,h in [(-7,-5,8),(-4,-7,7),(2,-8,8),(5,-9,7.5),(13,-3,8),(14,1,7.3),(14,5,8)]:
    planted_tree(x,z,h,.48,.65)
current='04_Central_Tree'
planted_tree(.7,-1.1,7.4,.7,.9)
obstacle_points=[[.7,.32,-1.1],[2,.26,-.2],[3.5,.23,1],[4.5,.22,2.7],[5.5,.12,4.5],[7,.04,5.5]]
obstacle_radii=[.30,.25,.21,.19,.12,.025]
tube('LowJumpLog',obstacle_points,obstacle_radii,'bark',20)
tube('RootGroove',[[.7,.56,-1.1],[2,.47,-.2],[3.5,.41,1],[4.5,.38,2.7],[5.5,.21,4.5]],[.014]*5,'ridge',5)
for pts in [ [[4.4,.18,2.6],[3.7,.12,3.9],[2.1,.035,4.8]],[[5.5,.13,4.4],[6.4,.07,3.7],[7.7,.02,3.5]] ]:
    tube('RootFork',pts,[.14,.08,.018],'bark',10)

current='05_Portal_Tree'
x,z=9,-6.8
for side in [-1,1]:
    tube('AncientTreeButtress',[[x+side*2.1,0,z],[x+side*1.85,2,z],[x+side*1.6,4.1,z-.1],
         [x+side*.7,7,z-.4],[x+side*1.2,10,z-.7]],[1,.9,.8,1,.6],'bark',20)
tube('AncientUpperTrunk',[[x,5.3,z-.5],[x+.4,7,z-.8],[x-.5,9,z-1],[x+.3,11,z-1.3]],
     [1.8,1.65,1.3,.8],'bark',24)
ellipse=[]
for i in range(65):
    a=i*math.tau/64;ellipse.append([x+math.cos(a)*1.6,2.45+math.sin(a)*2.15,z+.52])
tube('PortalOuterBark',ellipse,[.32+.035*math.sin(i*.8) for i in range(65)],'bark',16)
for depth,rx,ry,color in [(0,1.38,1.95,'void'),(-.22,1.30,1.87,'void')]:
    vs=[xyz([x,2.45,z+depth])]
    for j in range(64):
        a=j*math.tau/64;vs.append(xyz([x+math.cos(a)*rx,2.45+math.sin(a)*ry,z+depth]))
    mesh=bpy.data.meshes.new('RecessedPortalInterior');mesh.from_pydata(vs,[],[(0,j+1,(j+1)%64+1) for j in range(64)])
    obj=bpy.data.objects.new('RecessedPortalInterior',mesh);scene.collection.objects.link(obj);organize(obj);mesh.materials.append(mats[color])
for side in [-1,1]:
    tube('AncientBranch',[[x+side*.8,6,z-.3],[x+side*2.7,7,z-.6],[x+side*4.2,8,z-.8]],
         [.72,.44,.05],'bark',14)
for j,a in enumerate([-.3,.2,.7,1.2,2.1,2.7,3.2,3.8,4.2,5.2,5.8]):
    end=[x+math.cos(a)*4.1,.025,z+math.sin(a)*3.2]
    # Keep the intended approach to the portal free of high roots.
    if end[2]>-4.5 and abs(end[0]-9)<1.5:continue
    tube('AncientExposedRoot',[[x,.55,z],[x+math.cos(a)*2.1,.22,z+math.sin(a)*1.8],end],
         [.48,.27,.025],'bark',12)
for a in [.22,.6,.95,1.3,1.65,2.02,2.35,2.68,3.25,3.65,4.1,4.45,4.8,5.1,5.6,5.95]:
    pts=[]
    for d in [-.035,.035]:pts.append([x+math.cos(a+d)*1.68,2.45+math.sin(a+d)*2.22,z+.83])
    tube('PortalRuneStroke',pts,[.018,.018],'rune',5)

# Irregular monolith, beveled solid mesh, glyphs have individual strokes.
tablet=cube('RuneStone',[6.8,.94,-5],[.85,1.88,.48],'stone')
bevel=tablet.modifiers.new('WornStoneEdges','BEVEL');bevel.width=.16;bevel.segments=2
for row in range(5):
 for col in range(2):
    px=6.55+col*.34;py=1.55-row*.25
    tube('StandingStoneGlyph',[[px,py,-4.75],[px+.13,py+.04,-4.75],[px+.15,py-.10,-4.75]],
         [.014]*3,'cyan',5)
    if (row+col)%2: tube('GlyphAccent',[[px-.01,py-.06,-4.75],[px+.08,py-.10,-4.75]],[.012]*2,'cyan',5)

current='06_Foreground_Roots'
for x,z,h,r,t in [(-8,10.5,5,.65,.8),(9.8,9.2,5.7,.8,.9),(13.4,8,7,.8,1.1),(-15,9,8,.75,.7)]:
    if distance_to_route(x,z)>1.4:planted_tree(x,z,h,r,t)
for i,(pts,rs) in enumerate([
 ([[13.4,.5,8],[10.8,.4,7],[8.6,.3,5.9],[7.1,.15,4.8]],[.5,.38,.25,.025]),
 ([[11,.5,7],[9,.32,9.4],[6.6,.12,11.7]],[.35,.25,.025]),
 ([[9,.3,8.5],[7.4,.18,8.5],[5.8,.04,9.6]],[.26,.16,.025]),
 ([[13.5,.5,7.9],[14,.2,4.8],[12.5,.05,2.7]],[.4,.24,.025]),
 ([[-7.5,.4,10],[-5.2,.21,10.3],[-4,.04,12.4]],[.3,.18,.025])]):
    tube('ForegroundRoot_%02d'%i,pts,rs,'bark',14)
for cx,cz in [(10,9.5),(12,5.5),(-5,11),(-7.8,8.9)]:
    for j in range(5):
        a=j*math.tau/5
        tube('TangledForegroundTwig',[[cx,.05,cz],[cx+math.cos(a)*.4,.7+j*.15,cz+math.sin(a)*.3],
          [cx+math.cos(a+.8)*.8,1.4+j*.15,cz+math.sin(a+.8)*.5]],
          [.08,.05,.014],'bark',7)

current='07_Plants_Stones'
def shrub(cx,cz,color,radius=.65):
    verts=[];faces=[]
    for j in range(70):
        a=rng.uniform(0,math.tau);r=rng.random()**.5*radius
        y=.12+.55*(1-r/(radius*1.1))+rng.uniform(0,.12)
        center=Vector((cx+math.cos(a)*r,y,cz+math.sin(a)*r));axis=Vector((math.cos(a),0,math.sin(a)));side=Vector((-axis.z,0,axis.x))
        length=rng.uniform(.10,.22);width=length*.52;start=len(verts)
        verts.extend([xyz(center-axis*length),xyz(center+side*width),xyz(center+axis*length),xyz(center-side*width),xyz(center+Vector((0,.045,0)))])
        faces.extend([tuple(start+k for k in f) for f in [(0,1,4),(1,2,4),(2,3,4),(3,0,4)]])
    mesh=bpy.data.meshes.new('ShrubLeafCluster');mesh.from_pydata(verts,[],faces)
    obj=bpy.data.objects.new('Shrub_'+color,mesh);scene.collection.objects.link(obj);organize(obj);mesh.materials.append(mats[color])
    return obj
shrubs=[(-5.4,-2.1,'violetleaf',.9),(-4.5,-2.5,'blueleaf',.85),(-2.8,3.1,'blueleaf',.85),
 (5.7,3.7,'violetleaf',.85),(4.8,-3.1,'blueleaf',.8),(-3,-2.6,'violetleaf',.7),
 (-7.7,2,'leaf',.9),(-8,6.8,'leaf',.65),(-6,7.3,'blueleaf',.6),(-1,6,'violetleaf',.8),
 (1.5,6.9,'blueleaf',.9),(5.4,8.5,'violetleaf',.8),(8.3,7,'leaf',.9),(11.5,4,'violetleaf',.8),
 (12,-1.5,'blueleaf',.85),(10,-3,'leaf',.6),(4,-6,'violetleaf',.8),(-1,-7,'blueleaf',.6)]
for cx,cz,color,r in shrubs:shrub(cx,cz,color,r)
# Authored fern/grass islands; density is subordinate to clear soil and paths.
grass_verts=[];grass_faces=[];grass_colors=[]
islands=[(-8,1,1.3),(-4,-1.5,1.2),(-2,4,1.5),(4,4,1.1),(6,-3.6,1),(11,-2,1.2),(-8,7,1), (2,8,1.5), (11,6,1.5)]
for cx,cz,r in islands:
 for i in range(65):
    a=rng.uniform(0,math.tau);d=math.sqrt(rng.random())*r;px=cx+math.cos(a)*d;pz=cz+math.sin(a)*d
    if distance_to_route(px,pz)<1.13:continue
    for j in range(rng.randint(4,7)):
        a=rng.uniform(0,math.tau);axis=Vector((math.cos(a),0,math.sin(a)));side=Vector((-axis.z,0,axis.x))
        h=rng.uniform(.13,.32);w=rng.uniform(.018,.03);start=len(grass_verts)
        for t in [0,.4,.8]:
         for sign in [-1,1]:
            grass_verts.append(list(Vector((px,h*t,pz))+axis*t*t*.13+side*w*(1-t*.8)*sign));grass_colors.append([.16+.10*t,.27+.12*t,.23+.10*t])
        grass_verts.append([px+axis.x*.13,h,pz+axis.z*.13]);grass_colors.append([.26,.39,.33])
        grass_faces.extend([(start,start+1,start+3,start+2),(start+2,start+3,start+5,start+4),(start+4,start+5,start+6)])
painted_mesh('LivingGrass',grass_verts,grass_faces,grass_colors,'moss')
for cx,cz in [(-7,1.4),(-5,-3),(1,-5),(5,5),(11,-2),(-7,7),(12,7),(-1,8)]:
 for i in range(rng.randint(3,7)):
    x=cx+rng.uniform(-.8,.8);z=cz+rng.uniform(-.7,.7)
    if distance_to_route(x,z)<1.1:continue
    sphere('Rock',[x,.12,z],[rng.uniform(.13,.42),rng.uniform(.12,.31),rng.uniform(.15,.35)],'stone')
sources=[[-4,.4,1.4],[1.8,.4,-2.8],[4,.4,3.8],[7,.4,-2.6],[-8,.4,4.8],[-6,.4,8.1],[3,.4,8.4],[11,.4,5.4]]
for x,y,z in sources:
 for i in range(5):
    px=x+rng.uniform(-.35,.35);pz=z+rng.uniform(-.35,.35);h=rng.uniform(.19,.45)
    tube('MushroomStem',[[px,0,pz],[px+.02,h,pz]],[.025,.035],'stem',8)
    sphere('MushroomCap',[px,h,pz],[.18,.09,.15],'mushroomcap')
    for j in range(3):
        a=j*math.tau/3;sphere('MushroomSpot',[px+math.cos(a)*.08,h+.077,pz+math.sin(a)*.06],[.014,.008,.014],'cyan')
current='08_Pools_Magic'
pool_data=[dict(center=[-3.8,-4.3],radius=[1.2,.72]),dict(center=[1.8,9.6],radius=[1.65,1.0])]
for pool in pool_data:
    cx,cz=pool['center'];rx,rz=pool['radius'];vs=[[cx,.005,cz]];cs=[[.19,.34,.38]]
    for j in range(64):
        a=j*math.tau/64;t=1+.08*math.sin(a*5)+.05*math.cos(a*9)
        vs.append([cx+math.cos(a)*rx*t,.005,cz+math.sin(a)*rz*t]);cs.append([.10,.21,.25])
    painted_mesh('StillPuddle',vs,[(0,j+1,(j+1)%64+1) for j in range(64)],cs,'soil')
    for j in range(7):
        a=rng.uniform(0,math.tau);r=rng.uniform(.2,.8)
        sphere('PuddleGlint',[cx+math.cos(a)*rx*r,.02,cz+math.sin(a)*rz*r],[.025,.006,.018],'cyan')
# Paired footprints follow the whole curved path, with quiet gaps.
for i in list(range(4,len(road)-4,4)):
    if i%12==0:continue
    p=Vector(road[i]);d=Vector(road[i+1])-p;d.normalize();side=Vector((-d.z,0,d.x))
    for sign in [-1,1]:
        q=p+side*.16*sign+d*.09*sign;q.y=.035
        mark=sphere('CyanFootprint',q,[.055,.008,.12],'cyan');mark.rotation_euler.z=-math.atan2(d.z,d.x)+math.pi/2
for j in range(30):
    sphere('FloatingMote',[rng.uniform(-4,11),rng.uniform(.5,2.5),rng.uniform(-7,5)],[.018,.018,.018],'cyan')

# Save the editable source before joining geometry for a compact GLB.
current='09_Lights_Cameras'
camera_data=bpy.data.cameras.new('WholeMapCamera');camera=bpy.data.objects.new('CAM_WholeMap',camera_data);collections[current].objects.link(camera)
camera.location=xyz([0,29,29]);camera.rotation_euler=(xyz([0,1,-1])-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO';camera_data.ortho_scale=38;camera_data.clip_end=150;scene.camera=camera
sun_data=bpy.data.lights.new('CanopyMoon',type='SUN');sun_data.energy=.9;sun_data.angle=math.radians(2)
sun=bpy.data.objects.new('LGT_CanopyMoon',sun_data);collections[current].objects.link(sun)
sun.rotation_euler=Vector((.3,.5,-.8)).to_track_quat('-Z','Y').to_euler()
scene.world=bpy.data.worlds.new('ForestNight');scene.world.use_nodes=True
nodes=scene.world.node_tree.nodes;nodes.clear();bg=nodes.new('ShaderNodeBackground');wo=nodes.new('ShaderNodeOutputWorld');scene.world.node_tree.links.new(bg.outputs[0],wo.inputs[0])
bg.inputs['Color'].default_value=(.11,.15,.18,1);bg.inputs['Strength'].default_value=.45
sources.extend([[9,2.5,-5.8],[6.8,1.3,-4.6]])
for p in sources:
    data=bpy.data.lights.new('VisibleMagicSource','POINT');data.energy=22;data.color=(.45,.8,.8);data.shadow_soft_size=.2
    light=bpy.data.objects.new('LGT_MushroomOrRune',data);light.location=xyz(p);collections[current].objects.link(light)
scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1920;scene.render.resolution_y=1080;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='Standard'
scene['method']='Actual closed tree/root sections, no image relief or illustrated forest floor.'
scene['scope']='Whole-map expansion of the approved W-jump spatial study; editable semantic collections.'
for screen in bpy.data.screens:
 for area in screen.areas:
    if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'forest-whole-map.blend'))
scene.render.filepath=str(OUT/'blender-whole-map.png');bpy.ops.render.render(write_still=True)
# Export merges only a temporary in-memory version. Saved source keeps objects.
for col in collections.values():
    for mat in list(bpy.data.materials):
        objects=[o for o in col.objects if o.type=='MESH' and o.data.materials and o.data.materials[0]==mat]
        if not objects:continue
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        if len(objects)>1:bpy.ops.object.join()
        objects[0].name=col.name+'_'+mat.name
bpy.ops.object.select_all(action='DESELECT')
for obj in scene.objects:obj.select_set(obj.type=='MESH')
bpy.ops.export_scene.gltf(filepath=str(ASSET/'forest.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_cameras=False,export_lights=False)
manifest=dict(route=road,control_route=route,jump_obstacle=dict(points=obstacle_points,radii=obstacle_radii),
 tree_proxies=tree_proxies,sources=sources,pools=pool_data,bounds=[-17,17,-14,14],
 interactions=[dict(id='stone',point=[6.8,0,-4],radius=1.5,text='石碑上的光纹通向树洞。'),dict(id='portal',point=[9,0,-5.2],radius=1.2,text='洞口始终敞开，按 E 前往第一章入口。')],
 method='solid volume; no source-art backplate',stage='whole-map layout in approved spatial-study style')
(ASSET/'layout.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print('WHOLE_VOLUME_MAP_BUILT',len(tree_proxies),'trees',len(road),'route points')
