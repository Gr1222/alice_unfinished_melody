"""Deterministic crops from user PSD composites; never modifies source PSDs.

Coordinates are recorded against reference-sized sheets, then mapped to source.
Only edge-connected white is removed, preserving white clothing and rabbit fur.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('C:/Users/sophi/Documents/xwechat_files/wxid_dm70ylkhmmxh22_f4e9/msg/file/2026-10')
OUT = ROOT / 'assets/user_art'
OUT.mkdir(parents=True, exist_ok=True)
SHEETS = [('1792998975.psd', (1824,1368)), ('未命名作品.psd', (1809,1375))]
SPECS = [
 ('alice_front',0,(860,790,1110,1190),None),
 ('alice_side',0,(1150,795,1405,1200),None),
 ('alice_back',0,(1460,795,1700,1200),None),
 ('rabbit_side',1,(1060,175,1240,480),None),
 ('dialogue_frame',1,(45,220,322,310),None),
]
manifest = {'source':'User-supplied PSDs; ownership/licensing not independently verified',
 'processing':'Composite crops; edge-connected white removed. No generated art or invented animation frames.',
 'animation':'Static front/side/back poses; left uses mirrored side pose. Walking cycles unavailable.',
 'assets':[]}
for name, sheet_id, box, polygon in SPECS:
 filename, reference = SHEETS[sheet_id]
 path = SOURCE / filename
 with Image.open(path) as psd:
  sx,sy = psd.width/reference[0], psd.height/reference[1]
  bounds = tuple(round(v*(sx if i%2==0 else sy)) for i,v in enumerate(box))
  im = psd.convert('RGBA').crop(bounds)
 if polygon:
  mask = Image.new('L', im.size)
  ImageDraw.Draw(mask).polygon([(round(x*sx)-bounds[0],round(y*sy)-bounds[1]) for x,y in polygon],fill=255)
  im.putalpha(mask)
 a=np.array(im)
 white=np.all(a[:,:,:3]>=244,axis=2) | (a[:,:,3]==0)
 # Padded connected mask; flood fill cannot erase enclosed white costume details.
 flood=Image.new('L',(im.width+2,im.height+2),255)
 flood.paste(Image.fromarray(np.where(white,255,0).astype('uint8')),(1,1))
 ImageDraw.floodfill(flood,(0,0),128)
 exterior=np.array(flood)[1:-1,1:-1]==128
 a[exterior,3]=0
 im=Image.fromarray(a)
 content=im.getbbox()
 im=im.crop(content)
 # Portraits stay high resolution; sprites normalize to a shared 80px foot anchor.
 target_height = 80 if name.startswith(('alice_','rabbit_')) and 'portrait' not in name else (520 if 'portrait' in name else 160)
 size=(round(im.width*target_height/im.height),target_height)
 im=im.resize(size,Image.Resampling.NEAREST if target_height==80 else Image.Resampling.LANCZOS)
 im.save(OUT/(name+'.png'))
 manifest['assets'].append({'id':name,'file':name+'.png','source':filename,'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'source_crop':bounds,'size':list(im.size),'pivot':'bottom_center' if target_height==80 else 'UI','filter':'nearest' if target_height==80 else 'linear'})
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
from extract_portraits import extract
extract()
sheet=Image.new('RGBA',(1000,650),'#31414b')
for i,name in enumerate(['alice_front','alice_side','alice_back','rabbit_side','alice_portrait','rabbit_portrait','dialogue_frame']):
 im=Image.open(OUT/(name+'.png'))
 if i<4: pos=(30+i*110,20)
 elif i<6:
  im.thumbnail((390,520));pos=(20+(i-4)*400,120)
 else:
  im.thumbnail((450,140));pos=(510,20)
 sheet.alpha_composite(im,pos)
sheet.convert('RGB').save(ROOT/'output/psd-review/imported-art.jpg')
print('Exported',len(SPECS),'assets to',OUT)
