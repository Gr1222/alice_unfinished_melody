"""Real-volume forest study for the supplied HD-2D video reference. Blender 5.2."""
import json
import math
import random
from pathlib import Path
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"output/spatial-forest"
OUT.mkdir(parents=True,exist_ok=True)
(OUT/".gdignore").write_text("")
ASSET=ROOT/"assets/spatial_forest"
ASSET.mkdir(parents=True,exist_ok=True)
rng=random.Random(271027)
scene=bpy.data.scenes.new("Forest_Real_Volume_Study")
bpy.context.window.scene=scene
mats={}
colors={"soil":"263b3e","path":"596461","bark":"3b3a50","ridge":"55516a",
        "crease":"262b40","moss":"3d5c54","leaf":"32514e","stone":"52656a",
        "cyan":"72d9dc","rune":"c6dba0","void":"050912","purple":"584b70",
        "blueleaf":"436a86","leafhighlight":"567f99","violetleaf":"665784","leafdark":"263e57",
        "mushroomcap":"4da2ae","stem":"93a59b"}
for name,color in colors.items():
    mat=bpy.data.materials.new("MAT_"+name)
    mat.use_nodes=True
    rgb=tuple((int(color[i:i+2],16)/255)**2.2 for i in (0,2,4))
    mat.node_tree.nodes.clear()
    node=mat.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
    output=mat.node_tree.nodes.new("ShaderNodeOutputMaterial")
    mat.node_tree.links.new(node.outputs[0],output.inputs[0])
    node.inputs["Base Color"].default_value=(*rgb,1)
    node.inputs["Roughness"].default_value=1
    node.inputs["Specular IOR Level"].default_value=.05
    if name in ("cyan","rune"):
        node.inputs["Emission Color"].default_value=(*rgb,1)
        node.inputs["Emission Strength"].default_value=.65
    if name=="mushroomcap":
        node.inputs["Emission Color"].default_value=(*rgb,1)
        node.inputs["Emission Strength"].default_value=.25
    mat.diffuse_color=(*rgb,1)
    texture_file=ASSET/"bark.png"
    if name=="bark" and texture_file.exists():
        texture=mat.node_tree.nodes.new("ShaderNodeTexImage")
        texture.image=bpy.data.images.load(str(texture_file),check_existing=True)
        texture.image.pack()
        texture.interpolation="Closest"
        mat.node_tree.links.new(texture.outputs["Color"],node.inputs["Base Color"])
    mats[name]=mat

def xyz(v): return Vector((v[0],-v[2],v[1]))

def smooth(points,radii,steps=5):
    points=[Vector(p) for p in points]
    result=[]; sizes=[]
    for i in range(len(points)-1):
        a=points[max(0,i-1)]; b=points[i]
        c=points[i+1]; d=points[min(len(points)-1,i+2)]
        for j in range(steps):
            t=j/steps
            p=.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
            result.append(list(p))
            sizes.append(radii[i]*(1-t)+radii[i+1]*t)
    result.append(list(points[-1])); sizes.append(radii[-1])
    return result,sizes

def tube(name,points,radii,material,sides=10):
    if len(points)>=3:
        points,radii=smooth(points,radii,4)
    points=[xyz(p) for p in points]
    verts=[]
    for i,p in enumerate(points):
        tangent=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
        axis=tangent.cross(Vector((0,1,0)))
        if axis.length<.1: axis=tangent.cross(Vector((1,0,0)))
        axis.normalize()
        second=tangent.cross(axis).normalized()
        for j in range(sides):
            angle=j*math.tau/sides
            verts.append(p+radii[i]*(math.cos(angle)*axis+math.sin(angle)*second))
    faces=[]
    for i in range(len(points)-1):
        for j in range(sides):
            a=i*sides+j
            b=i*sides+(j+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.extend([tuple(reversed(range(sides))),tuple(range((len(points)-1)*sides,len(points)*sides))])
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    uv=mesh.uv_layers.new(name="BarkUV")
    distance=[0.0]
    for i in range(1,len(points)):
        distance.append(distance[-1]+(points[i]-points[i-1]).length)
    for polygon in mesh.polygons:
        for loop_index in polygon.loop_indices:
            vertex=mesh.loops[loop_index].vertex_index
            ring,j=divmod(vertex,sides)
            u=j/sides
            if j==0 and any(mesh.loops[k].vertex_index%sides==sides-1 for k in polygon.loop_indices): u=1.0
            uv.data[loop_index].uv=(u*1.4,distance[ring]/6)
    obj=bpy.data.objects.new(name,mesh)
    scene.collection.objects.link(obj)
    mesh.materials.append(mats[material])
    for polygon in mesh.polygons: polygon.use_smooth=True
    return obj

def cube(name,location,size,material):
    bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(location))
    obj=bpy.context.object
    obj.name=name
    obj.scale=(size[0],size[2],size[1])
    obj.data.materials.append(mats[material])
    if material=="soil":
        for uv in obj.data.uv_layers.active.data: uv.uv*=8.0
    return obj

def sphere(name,location,size,material):
    if name=="MushroomCap":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=1,location=xyz(location))
    else:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=xyz(location))
    obj=bpy.context.object
    obj.name=name
    obj.scale=(size[0],size[2],size[1])
    obj.data.materials.append(mats[material])
    if name=="MushroomCap":
        for polygon in obj.data.polygons: polygon.use_smooth=True
    return obj

def tree(x,z,height,radius=.45,twist=.5):
    points=[[x,0,z],[x+.15,height*.22,z+.04],[x-twist,height*.48,z-.1],
            [x+twist*.6,height*.72,z],[x,height,z-.25]]
    radii=[radius*1.5,radius,radius*.82,radius*.63,radius*.4]
    tube("Trunk",points,radii,"bark",20 if radius>.6 else 12)
    # Sculpted longitudinal bark ridges, actual geometry on all sides.
    for j in range(6):
        angle=j*math.tau/6
        ridge=[]
        for p,r in zip(points,radii):
            ridge.append([p[0]+math.cos(angle)*r*.99,p[1],p[2]+math.sin(angle)*r*.99])
        tube("BarkRidge",ridge,[.018,.015,.012,.01,.006],"ridge" if j%3 else "crease",5)
    for j in range(5):
        a=j*math.tau/5
        end=[x+math.cos(a)*radius*3.4,.04,z+math.sin(a)*radius*3.4]
        tube("Root",[[x,.6,z],[(x+end[0])/2,.17,(z+end[2])/2],end],[radius*.35,radius*.18,.025],"bark",8)
    for side in [-1,1]:
        tube("Branch",[points[2],[x+side*1.1,height*.73,z],[x+side*1.8,height*.88,z-.2]],
             [radius*.45,radius*.25,.025],"bark",8)

route=[[-9,0,6],[-6,0,3],[-2.5,0,.4],[.2,0,1.5],[3,0,1.6],[5.5,0,-.3],[7.6,0,-3.2],[9,0,-5.2]]
def painted_mesh(name,verts,faces,vertex_colors,material_name):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata([xyz(p) for p in verts],[],faces)
    mesh.update()
    for polygon in mesh.polygons:
        if polygon.normal.z<0: polygon.flip()
    attribute=mesh.color_attributes.new(name="Paint",type="FLOAT_COLOR",domain="CORNER")
    for loop in mesh.loops:
        color=vertex_colors[loop.vertex_index]
        attribute.data[loop.index].color=(*(max(0,c)**2.2 for c in color),1)
    mat=mats[material_name].copy()
    mat.name="MAT_"+name
    node=next(n for n in mat.node_tree.nodes if n.type=="BSDF_PRINCIPLED")
    color_node=mat.node_tree.nodes.new("ShaderNodeVertexColor")
    color_node.layer_name="Paint"
    mat.node_tree.links.new(color_node.outputs["Color"],node.inputs["Base Color"])
    mesh.materials.append(mat)
    obj=bpy.data.objects.new(name,mesh)
    scene.collection.objects.link(obj)
    for face in mesh.polygons: face.use_smooth=True
    return obj

# Low-contrast bare earth/moss, with no painted objects or baked directional lighting.
terrain_verts=[]; terrain_colors=[]; terrain_faces=[]
nx,nz=84,68
for iz in range(nz+1):
    for ix in range(nx+1):
        x=-14.5+29*ix/nx; z=-11.5+23*iz/nz
        terrain_verts.append([x,-.025+.012*math.sin(x*.8)*math.cos(z*.7),z])
        variation=.5+.25*math.sin(x*.55+z*.3)+.15*math.cos(z*.85-x*.2)
        terrain_colors.append([.17+.026*variation,.24+.040*variation,.23+.033*variation])
for iz in range(nz):
    for ix in range(nx):
        a=iz*(nx+1)+ix
        terrain_faces.append((a,a+1,a+nx+2,a+nx+1))
painted_mesh("EarthMoss",terrain_verts,terrain_faces,terrain_colors,"soil")
# Continuous curved road surface receives the same real-time light as its surroundings.
road,_=smooth(route,[.9]*len(route),10)
verts=[]; road_colors=[]
for i,p in enumerate(road):
    tangent=Vector(road[min(i+1,len(road)-1)])-Vector(road[max(0,i-1)])
    normal=Vector((-tangent.z,0,tangent.x)).normalized()
    for side in [-1.13,-.77,.77,1.13]:
        width=side*(1+.045*math.sin(i*1.7))
        v=Vector(p)+normal*width
        edge=abs(side)>1
        v.y=-.012 if edge else .016
        verts.append(list(v))
        shade=.012*math.sin(i*.7)
        road_colors.append([.18,.26,.25] if edge else [.39+shade,.42+shade,.37+shade])
faces=[]
for i in range(len(road)-1):
    for band in range(3):
        a=4*i+band
        faces.append((a,a+1,a+5,a+4))
painted_mesh("DirtPath",verts,faces,road_colors,"path")
for a,b in zip(route,route[1:]):
    direction=Vector((b[0]-a[0],b[2]-a[2]))
    length=direction.length
    for i in range(max(2,int(length*4))):
        t=i/max(1,int(length*4)-1)
        x=a[0]*(1-t)+b[0]*t
        z=a[2]*(1-t)+b[2]*t
        sphere("WornPaving",[x+rng.uniform(-.5,.5),.035,z+rng.uniform(-.2,.2)],
               [.18,.025,.12],"stone")
    for i in range(max(1,int(length))):
        t=(i+.4)/max(1,int(length))
        x=a[0]*(1-t)+b[0]*t
        z=a[2]*(1-t)+b[2]*t
        mark=cube("VisualFootprint",[x,.05,z],[.12,.018,.22],"cyan")
        mark.rotation_euler.z=rng.uniform(-.3,.3)

# Dense left forest wall and the distant canopy line preserve the reference zoning.
for i in range(13):
    tree(-11+rng.uniform(-.5,.5),-9+i*1.25,rng.uniform(5.5,8),rng.uniform(.25,.42),.25)
for i in range(10):
    tree(-8+i*1.8,-8+rng.uniform(-.6,.6),rng.uniform(5,7.5),.4,.5)
for x,z,h in [(-7,-3,6),(-5,-5,6.5),(5,-6,7),(12,-1,7),(12,4,6)]:
    tree(x,z,h,.5,.7)
tree(.7,-1.1,7.4,.7,.9)
# Low solid obstacle, not an arch. Crown height is below Alice's knee.
obstacle_points=[[.7,.32,-1.1],[2,.26,-.2],[3.5,.23,1],[4.5,.22,2.7],[5.5,.12,4.5],[7,.04,5.5]]
obstacle_radii=[.30,.25,.21,.19,.12,.025]
tube("LowJumpLog",obstacle_points,obstacle_radii,"bark",20)
tube("RootGroove",[[.7,.56,-1.1],[2,.47,-.2],[3.5,.41,1],[4.5,.38,2.7],[5.5,.21,4.5]],
     [.015]*5,"ridge",5)

# Hollow portal tree: open front, thick side walls and a three-dimensional arch.
x,z=9,-6.2
for side in [-1,1]:
    tube("DoorTreeSide",[[x+side*1.6,0,z],[x+side*1.4,2,z],[x+side*1.2,3.4,z],[x+side*.8,5.8,z]],
         [.7,.6,.65,.8],"bark",12)
arch=[]
for i in range(19):
    angle=math.pi*i/18
    arch.append([x+math.cos(angle)*1.45,1.55+math.sin(angle)*2.0,z+.22])
tube("DoorArch",arch,[.42]*len(arch),"bark",12)
cube("DarkCavity",[x,1.6,z-.4],[2.2,3.0,.18],"void")
tube("DoorTreeUpper",[[x,3.6,z-.35],[x+.7,5,z-.5],[x-.3,7,z-.8],[x+.5,9,z-1]],
     [1.55,1.3,1.0,.65],"bark",16)
for j in range(7):
    a=j*math.tau/7
    tube("DoorTreeRoot",[[x,.65,z],[x+math.cos(a)*2,.2,z+math.sin(a)*1.5],
          [x+math.cos(a)*3.2,.03,z+math.sin(a)*2.4]],[.35,.23,.03],"bark",9)
for i in range(19):
    angle=math.pi*i/18
    sphere("DoorGlow",[x+math.cos(angle)*1.35,1.55+math.sin(angle)*1.9,z+.65],[.045,.07,.035],"rune")

tablet=cube("RuneStone",[6.9,.9,-4.4],[.65,1.8,.38],"stone")
tablet.rotation_euler.y=.08
for row in range(5):
    for col in range(2):
        cube("StoneRune",[6.75+col*.25,1.4-row*.23,-4.18],[.1,.035,.018],"cyan")
        cube("StoneRune",[6.72+col*.25,1.35-row*.23,-4.18],[.025,.12,.018],"cyan")

def distance_to_route(x,z):
    p=Vector((x,z))
    best=999
    for a,b in zip(route,route[1:]):
        aa=Vector((a[0],a[2])); bb=Vector((b[0],b[2]))
        direction=bb-aa
        t=max(0,min(1,(p-aa).dot(direction)/direction.length_squared))
        best=min(best,(p-(aa+direction*t)).length)
    return best

grass_verts=[]; grass_faces=[]; grass_colors=[]
for i in range(2200):
    local=i%3!=0
    px=rng.uniform(-4,8) if local else rng.uniform(-12,12)
    pz=rng.uniform(-4,6) if local else rng.uniform(-9,8)
    if distance_to_route(px,pz)<1.05: continue
    if math.sin(px*1.3+pz*.5)+math.cos(pz*1.4-px*.2)<-.8: continue
    for blade in range(rng.randint(5,8)):
        angle=rng.uniform(0,math.tau)
        x=px+rng.uniform(-.12,.12); z=pz+rng.uniform(-.12,.12)
        h=rng.uniform(.15,.37)
        w=rng.uniform(.018,.035)
        axis=Vector((math.cos(angle),0,math.sin(angle)))
        side=Vector((-axis.z,0,axis.x))
        start=len(grass_verts)
        for t in [0,.42,.78]:
            center=Vector((x,-.018+h*t,z))+axis*(t*t*.14)
            for sign in [-1,1]:
                grass_verts.append(list(center+side*w*(1-t*.8)*sign))
                grass_colors.append([.17+.11*t,.29+.16*t,.24+.13*t])
        grass_verts.append([x+axis.x*.14,h-.018,z+axis.z*.14])
        grass_colors.append([.32,.48,.39])
        grass_faces.extend([(start,start+1,start+3,start+2),(start+2,start+3,start+5,start+4),(start+4,start+5,start+6)])
painted_mesh("LivingGrass",grass_verts,grass_faces,grass_colors,"moss")
for x,z in [(-4,1.4),(1.8,-2.8),(4,3.8),(7,-2.6),(-8,4.8)]:
    for i in range(5):
        px=x+rng.uniform(-.4,.4); pz=z+rng.uniform(-.4,.4)
        h=rng.uniform(.18,.45)
        tube("MushroomStem",[[px,0,pz],[px,h,pz]],[.025,.035],"stem",8)
        sphere("MushroomCap",[px,h,pz],[.19,.1,.16],"mushroomcap")
        for j in range(3):
            a=j*math.tau/3
            sphere("CapSpot",[px+math.cos(a)*.09,h+.087,pz+math.sin(a)*.07],[.018,.007,.018],"cyan")
for i in range(80):
    px=rng.uniform(-11,11); pz=rng.uniform(-8,8)
    if distance_to_route(px,pz)<1: continue
    sphere("Rock",[px,.08,pz],[rng.uniform(.08,.3),.15,.22],"stone")

# Layered folded leaves: real small surfaces, not a rectangular foliage billboard.
for cx,cz,color in [(-2.8,3.1,"blueleaf"),(5.7,3.7,"violetleaf"),(4.8,-3.1,"blueleaf"),(-3,-2.6,"violetleaf")]:
    for j in range(120):
        angle=rng.uniform(0,math.tau)
        radius=rng.random()**.5*.85
        x=cx+math.cos(angle)*radius
        z=cz+math.sin(angle)*radius
        y=.15+.65*(1-radius/.9)+rng.uniform(0,.12)
        length=rng.uniform(.13,.25)
        width=length*.45
        axis=Vector((math.cos(angle),0,math.sin(angle)))
        side=Vector((-axis.z,0,axis.x))
        center=Vector((x,y,z))
        verts=[xyz(center-axis*length),xyz(center+side*width),xyz(center+axis*length),
               xyz(center-side*width),xyz(center+Vector((0,.045,0)))]
        mesh=bpy.data.meshes.new("FoldedLeaf")
        mesh.from_pydata(verts,[],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)])
        obj=bpy.data.objects.new("Leaf",mesh)
        scene.collection.objects.link(obj)
        mesh.materials.append(mats["leafhighlight" if j%7==0 else ("leafdark" if j%6==0 else color)])

# Merge by material to keep a real-time scene inexpensive.
for mat in mats.values():
    candidates=[o for o in scene.objects if o.type=="MESH" and o.data.materials and o.data.materials[0]==mat]
    if not candidates: continue
    bpy.ops.object.select_all(action="DESELECT")
    for obj in candidates: obj.select_set(True)
    bpy.context.view_layer.objects.active=candidates[0]
    if len(candidates)>1: bpy.ops.object.join()
    candidates[0].name="Forest_"+mat.name

# Blender source lighting is provided for editable previews; runtime lights live in Godot.
camera_data=bpy.data.cameras.new("SpatialPreview")
camera=bpy.data.objects.new("CAM_Spatial",camera_data)
scene.collection.objects.link(camera)
camera.location=xyz([2,12,16])
camera.rotation_euler=(xyz([2,1,0])-camera.location).to_track_quat("-Z","Y").to_euler()
camera_data.lens=42
scene.camera=camera
sun_data=bpy.data.lights.new("Moon",type="SUN"); sun_data.energy=.85
sun_data.angle=math.radians(1.5)
sun=bpy.data.objects.new("LGT_Moon",sun_data); scene.collection.objects.link(sun)
sun.rotation_euler=Vector((.303,.486,-.819)).to_track_quat("-Z","Y").to_euler()
scene.world=bpy.data.worlds.new("Night")
scene.world.use_nodes=True
scene.world.node_tree.nodes.clear()
background=scene.world.node_tree.nodes.new("ShaderNodeBackground")
world_output=scene.world.node_tree.nodes.new("ShaderNodeOutputWorld")
scene.world.node_tree.links.new(background.outputs[0],world_output.inputs[0])
background.inputs["Color"].default_value=(.1,.13,.16,1)
background.inputs["Strength"].default_value=.35
for x,y,z in [(-4,.4,1.4),(1.8,.4,-2.8),(4,.4,3.8),(7,.4,-2.6),(-8,.4,4.8),(9,1.8,-5.5)]:
    data=bpy.data.lights.new("Mushroom" if y<1 else "Runes",type="POINT")
    data.energy=18
    data.color=(.49,.72,.76) if y<1 else (.77,.81,.60)
    data.shadow_soft_size=.15
    light=bpy.data.objects.new("LGT_"+data.name,data)
    light.location=xyz([x,y,z])
    scene.collection.objects.link(light)
scene.render.engine="BLENDER_EEVEE"
scene.render.resolution_x=1280; scene.render.resolution_y=720
scene.render.resolution_percentage=100
scene.view_settings.view_transform="Standard"
scene.render.filepath=str(OUT/"blender-spatial.png")
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"forest-spatial.blend"))
bpy.ops.object.select_all(action="DESELECT")
for obj in scene.objects:
    obj.select_set(obj.type=="MESH")
bpy.ops.export_scene.gltf(filepath=str(ASSET/"forest.glb"),export_format="GLB",use_selection=True,use_active_scene=True,export_cameras=False,export_lights=False)
(ASSET/"layout.json").write_text(json.dumps({"route":route,"jump_obstacle":{"points":obstacle_points,"radii":obstacle_radii},"reference":"user supplied forest and MP4 spatial style","stage":"spatial look-development study, not original-image reproduction"},indent=2))
bpy.ops.render.render(write_still=True)
camera.location=xyz([2.5,7.2,10.5])
camera.rotation_euler=(xyz([1.2,2,-.5])-camera.location).to_track_quat("-Z","Y").to_euler()
camera_data.lens=46
scene.render.filepath=str(OUT/"blender-art-focus.png")
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"forest-art-study.blend"))
print("SPATIAL_FOREST_BUILT",len([o for o in scene.objects if o.type=="MESH"]))
