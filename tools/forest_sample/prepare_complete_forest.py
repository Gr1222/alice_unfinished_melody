"""Deterministic source-art separation. No generative repainting or new colors.

Masks are bounded by authored landmark regions. Original 8K source is retained.
"""
from pathlib import Path
import json, math, hashlib
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'assets/complete_forest'
DEST.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / 'assets/latest_forest/original-8k.png'
original = Image.open(SOURCE).convert('RGBA')
original.resize((4096,2304),Image.Resampling.NEAREST).save(DEST/'painting.png')
small = original.resize((2048,1152),Image.Resampling.NEAREST)
rgb = np.array(small)[:,:,:3].astype(float)/255
W,H=small.size
layers=[]

def polygon(points):
    im=Image.new('L',(W,H)); ImageDraw.Draw(im).polygon(points,fill=255)
    return im

def store(name,mask,kind,anchor,height,**extras):
    mask=mask.convert('L')
    mask.save(DEST/(name+'.png'))
    layers.append(dict(id=name,kind=kind,anchor=anchor,height=height,**extras))

store('painted_ground',Image.new('L',(W,H),255),'ground',[1024,1152],0)
# Existing source-preserving mattes: reused rather than redrawn.
for name,kind,anchor,height in [
    ('central_tree','tree',[1158,570],6.2),
    ('foreground_left','foreground',[520,1140],3.1),
    ('foreground_right','foreground',[1680,1140],2.6),
    ('rune_stone','stone',[1423,425],1.7)]:
    mask=Image.open(ROOT/'assets/latest_forest/masks'/(name+'.png')).convert('L').resize((W,H),Image.Resampling.NEAREST)
    store(name,mask,kind,anchor,height)
# Major ancient-tree silhouette, including outer bark and its grounded roots.
giant=polygon([(1612,0),(2048,0),(2048,790),(2020,752),(2010,627),(1975,580),
 (1994,476),(1960,434),(1933,505),(1899,540),(1844,570),(1760,616),
 (1720,612),(1800,542),(1830,462),(1812,418),(1742,432),(1653,432),
 (1582,471),(1520,503),(1466,480),(1518,435),(1532,394),(1510,363),
 (1460,385),(1420,407),(1450,352),(1480,309),(1457,288),(1513,259),
 (1474,232),(1495,206),(1566,193),(1595,134)])
# Portal interior is a separate recessed object, never an emissive blue disk.
void=Image.new('L',(W,H)); ImageDraw.Draw(void).ellipse((1650,145,1862,377),fill=255)
giantarr=np.array(giant); giantarr[np.array(void)>0]=0
store('ancient_tree',Image.fromarray(giantarr),'ancient',[1774,435],7.4)
store('portal_interior',void,'portal',[1756,377],1.3)
# Individual left trunks have their own ground anchors; the distant illustration
# remains a continuous backplate behind them, preserving the vine silhouettes.
for i,(points,anchor,h) in enumerate([
 ([(0,0),(126,0),(129,490),(212,793),(125,955),(0,995)],[80,970],6.5),
 ([(178,0),(306,0),(271,406),(359,692),(288,804),(208,718),(214,387)],[280,785],6.2),
 ([(390,0),(489,0),(490,283),(557,529),(605,703),(542,749),(473,526),(410,312)],[553,735],6),
 ([(604,0),(716,0),(719,253),(790,446),(758,507),(678,448),(649,241)],[728,493],5.4),
 ([(844,0),(960,0),(915,230),(946,374),(885,403),(829,321)],[900,390],4.8),
 ([(1290,0),(1395,0),(1362,138),(1436,183),(1474,206),(1374,198),(1325,151)],[1377,195],3.8)
 ]):
    store('woodland_%02d'%i,polygon(points),'tree',anchor,h)

# Authored vegetation islands, not uniform scattering. Restrict selection to
# colors already belonging to the shrubs, stones or mushrooms in each island.
islands=[('violet_west',(608,474,727,630),'purple',[675,620],.65),
 ('blue_west',(674,458,811,582),'blue',[748,575],.55),
 ('violet_middle',(883,727,1047,895),'purple',[967,872],.8),
 ('blue_middle',(957,828,1118,995),'blue',[1047,972],.65),
 ('violet_foreground',(1356,1050,1527,1152),'purple',[1450,1150],.65),
 ('violet_east',(1788,800,1962,944),'purple',[1880,930],.65),
 ('mushroom_west',(399,679,476,761),'cyan',[435,751],.35),
 ('mushroom_center',(1034,493,1161,585),'cyan',[1090,574],.48),
 ('mushroom_east',(1534,952,1666,1050),'cyan',[1600,1040],.4),
 ('mushroom_pool',(1305,909,1390,1014),'cyan',[1355,1004],.4)]
for name,box,tone,anchor,height in islands:
    area=np.zeros((H,W),bool); x0,y0,x1,y1=box; area[y0:y1,x0:x1]=True
    r,g,b=rgb[:,:,0],rgb[:,:,1],rgb[:,:,2]
    if tone=='purple': chosen=(b>g*1.1)&(r>g*.95)&(b>.19)
    elif tone=='blue': chosen=(b>r*1.2)&(b>g*1.03)&(b>.25)
    else: chosen=(g>r*1.08)&(b>r*1.08)&(g>.35)
    matte=Image.fromarray(np.uint8(area&chosen)*255).filter(ImageFilter.MaxFilter(3))
    store(name,matte,'plant',anchor,height)

# Full centerline is in reference-image pixels, not the unrelated earlier map.
route=[[60,1070],[200,934],[410,850],[644,778],[820,670],[940,648],
       [1070,716],[1212,734],[1348,674],[1470,598],[1588,534],[1684,452],[1770,388]]
manifest=dict(source=str(SOURCE.relative_to(ROOT)),source_size=list(original.size),
 source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
 canvas=[2048,1152],world_width=32,camera_elevation=50,
 route=route,layers=layers,
 pools=[dict(center=[902,478],radii=[76,31]),dict(center=[1177,1062],radii=[100,48])],
 sources=[[1090,560],[1608,1021],[1756,255],[1424,307],[435,725]],
 obstacle=dict(a=[1264,608],b=[1413,735],height=.32,radius=.19),
 interactions=[dict(id='runes',point=[1432,450],radius=1.35,text='石碑上的光纹沿着树皮延伸。洞口仍然敞开。'),
 dict(id='pool',point=[931,552],radius=1.4,text='水洼映着青色微光，细小的光点在水面聚散。'),
 dict(id='portal',point=[1770,388],radius=1.25,text='树洞深处传来微光的回应。按 E 进入第一章入口。')])
(DEST/'layout.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print('PREPARED',len(layers),'painted depth regions; source',original.size)
