"""Build deterministic shared geometry for the Blender/Godot art study (no dependencies)."""
import json
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
rng = random.Random(271027)
objects = []
assembly = ""
palette = {
    "earth": "243c3d", "grass": "315348", "moss": "45664d",
    "path": "756658", "stone": "62796d", "rock": "354854",
    "water": "132835", "ripple": "34576a", "bark": "504448",
    "bark_light": "6b5755", "purple": "655078", "leaf": "294c45",
    "leaf_light": "406653", "wood": "79634e", "cut": "a49768",
    "cyan": "70e5db", "yellow": "ffe29c", "stem": "9dbfa4",
    "dress": "86bad6", "hair": "e4cb94", "shoe": "303440",
}


def add(name, kind, p, s, mat, group, **extra):
    objects.append(dict(name=f"SM_{name}_{len(objects):04d}", kind=kind,
                        p=p, s=s, mat=mat, group=group, assembly=assembly, **extra))


def segment(name, a, b, radius, mat, group, tip=None):
    add(name, "branch", a, [radius, radius if tip is None else tip, 0], mat, group, end=b)


def mound(name, x, z, rx, rz, y, mat, group="Ground"):
    points = []
    for i in range(20):
        angle = i * math.tau / 20
        jitter = rng.uniform(.91, 1.06)
        points.append([x + math.cos(angle)*rx*jitter, y, z + math.sin(angle)*rz*jitter])
    add(name, "patch", [x,y,z], [1,1,1], mat, group, points=points)


def mushroom(x,z,size,mat):
    add("MushroomStem", "cylinder", [x,.19*size,z], [.06*size,.38*size,.06*size], "stem", "Mushrooms")
    add("MushroomCap", "cap", [x,.41*size,z], [.3*size,.21*size,.3*size], mat, "Mushrooms")


def tree(x,z,h,leaves=True):
    global assembly
    assembly = f"tree_{x}_{z}"
    mat = "bark" if leaves else "purple"
    bend = rng.uniform(-.5,.5)
    a,b,c=[x,0,z],[x+bend,h*.52,z+.12],[x-bend*.6,h,z]
    segment("Trunk",a,b,.38,mat,"Trees",.25)
    segment("Trunk",b,c,.25,mat,"Trees",.12)
    for i in range(5):
        angle=i*math.tau/5+.3
        end=[x+math.cos(angle)*1.1,.03,z+math.sin(angle)*.8]
        segment("Root",[x,.4,z],end,.18,mat,"Trees",.025)
    for sign in [-1,1]:
        end=[x+sign*1.15,h*.85,z+rng.uniform(-.4,.4)]
        segment("Bough",b,end,.16,mat,"Trees",.055)
        segment("Twig",end,[end[0]+sign*.35,h*1.02,end[2]-.18],.06,mat,"Trees",.018)
    if leaves:
        for i in range(8):
            a=i*math.tau/8
            add("Canopy", "sphere", [x+math.cos(a)*.8,h+.05+rng.uniform(-.2,.3),z+math.sin(a)*.5],
                [rng.uniform(.7,1.1),.5,rng.uniform(.6,.85)],
                "leaf_light" if i%3==0 else "leaf", "Canopy")
    assembly = ""


# Y is vertical. The river cuts across Z; the bridge follows the walking route.
add("RiverBed","box",[0,-.37,0],[23,.3,16],"water","Ground")
for z,depth in [(-3.8,9.0),(6.2,4.2)]:
    add("Bank","box",[0,-.16,z],[23,.32,depth],"earth","Ground")
for i in range(30):
    x=rng.uniform(-11,11)
    z=rng.choice([rng.uniform(-7,-.2),rng.uniform(4.4,7.8)])
    mound("Grass",x,z,rng.uniform(.5,2.1),rng.uniform(.4,1.2),.012,"grass")

route=[(-7,7),(-6,5),(-5.6,4.1),(-5.6,.6),(-4,-1.6),(-1,-2.7),(3,-2.9)]
for (x,z),(xx,zz) in zip(route,route[1:]):
    if .7 < (z+zz)/2 < 4.2:
        continue
    distance=math.hypot(xx-x,zz-z)
    for j in range(max(2,int(distance*3))):
        t=j/max(1,int(distance*3)-1)
        mound("Path",x+(xx-x)*t,z+(zz-z)*t,.78,.57,.026,"path")

for side in [.55,4.15]:
    for i in range(26):
        x=-11+i*.87
        add("BankStone","sphere",[x,-.09,side+rng.uniform(-.16,.16)],
            [.52,rng.uniform(.22,.38),.35],"rock","Rocks")
for i in range(18):
    x=rng.uniform(-10,10)
    z=rng.uniform(1.1,3.6)
    add("WaterRipple","sphere",[x,-.198,z],[rng.uniform(.12,.4),.006,.05],"ripple","Water")

for i in range(13):
    z=.35+i*.325
    add("BridgePlank","box",[-5.6,.13,z],[1.75,.16,.27],"wood","Bridge",yaw=rng.uniform(-.035,.035))
for x in [-6.5,-4.7]:
    for z in [.25,4.4]:
        add("BridgePost","cylinder",[x,.55,z],[.09,1.1,.09],"bark_light","Bridge")
    for i in range(8):
        z=.25+i*.51875
        zz=z+.51875
        y=.93-.2*math.sin(i*math.pi/8)
        yy=.93-.2*math.sin((i+1)*math.pi/8)
        segment("BridgeRope",[x,y,z],[x,yy,zz],.025,"wood","Bridge")

for i in range(24):
    t=i/23
    x=-5.6+8.5*t+rng.uniform(-.24,.24)
    z=.2-3.3*math.sin(t*math.pi/2)+rng.uniform(-.25,.25)
    add("Paving","cylinder",[x,.051,z],[.24,.06,.2],"stone","Path",yaw=rng.random())

for x,z,h,leaf in [(-10,-5,4.2,True),(-7.8,-6,3.9,True),(-3.4,-6.5,4.5,True),
                     (0,-6.8,4.4,True),(3.4,-6.3,4.7,True),(7,-5.9,4.9,True),
                     (9.5,-3.7,4.2,True),(-10,-.4,3.5,True),(10.2,.3,3.2,False),
                     (-9,6.9,3.4,True),(1,7,3.0,False),(9,6.9,3.8,True),
                     (1,-.3,2.9,False)]:
    tree(x,z,h,leaf)

for x,z in [(-6,-3.8),(5,0)]:
    assembly = f"stump_{x}_{z}"
    for i in range(5):
        a=i*math.tau/5
        segment("StumpRoot",[x,.35,z],[x+math.cos(a)*1.05,.02,z+math.sin(a)*.72],.2,"bark","Props",.04)
    add("Stump","cylinder",[x,.42,z],[.64,.84,.57],"bark","Props")
    add("CutSurface","cylinder",[x,.855,z],[.58,.035,.52],"cut","Props")
    # Nested disks communicate growth rings without a texture dependency.
    for i in range(4):
        r=.47-i*.095
        add("GrowthRing","ring",[x,.88+i*.001,z],[r,.012,r*.88],"wood","Props")
    for i in range(9):
        a=i*math.tau/9
        mushroom(x+math.cos(a)*1.18,z+math.sin(a)*.92,rng.uniform(.6,1.05),"yellow")
    assembly = ""

for x,z in [(-7,.2),(-3.7,-1.2),(2.2,-4.3),(7,3.9)]:
    for i in range(4):
        mushroom(x+rng.uniform(-.45,.45),z+rng.uniform(-.35,.35),rng.uniform(.7,1.3),"cyan")

for i in range(50):
    x=rng.uniform(-10.5,10.5)
    z=rng.uniform(-7,7)
    if abs(x+5.6)<1.8 or .5<z<4.2 or (-3<x<4 and -4<z<-1.2):
        continue
    add("Shrub","sphere",[x,.24,z],[.45,.35,.4],"leaf_light" if i%3==0 else "leaf","Shrubs")

segment("FallenLog",[3,.22,5.7],[6,.25,5.2],.23,"bark","Props",.19)
# A scale mannequin, deliberately not a final Alice sprite.
add("ScaleDress","cone",[-3.5,.5,-2.1],[.25,.65,.25],"dress","ScaleReference")
add("ScaleHead","sphere",[-3.5,1,-2.1],[.21,.24,.21],"hair","ScaleReference")
for x in [-3.61,-3.39]:
    add("ScaleFoot","box",[x,.1,-2.1],[.13,.2,.17],"shoe","ScaleReference")

document=dict(version=1, seed=271027, palette=palette, objects=objects,
              camera=dict(position=[0,18.5,19], target=[0,1.5,0], ortho_size=29),
              note="Reference-inspired bridge study. Not a production map or pixel-painted asset.")
out=ROOT/"data/art/forest_study.json"
out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(document,ensure_ascii=False,indent=2),encoding="utf-8")
print(f"Wrote {len(objects)} objects to {out}")
