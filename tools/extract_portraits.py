"""Extract original transparent PSD portrait layers without changing proportions.

Requires psd-tools 1.26, Pillow and numpy. Sources remain untouched.
"""
from pathlib import Path
import hashlib
import json
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'output/asset-tools'))
from psd_tools import PSDImage

SOURCE = Path('C:/Users/sophi/Documents/xwechat_files/wxid_dm70ylkhmmxh22_f4e9/msg/file/2026-10')
OUT = ROOT / 'assets/user_art'

def extract():
    records = []
    specs = [
        ('alice_portrait', '未命名作品(1).psd', 1, None, (1300, 1000)),
        ('rabbit_portrait', '未命名作品.psd', 5, (4557, 1293, 5673, 4290), (500, 1700)),
    ]
    for name, filename, index, viewport, seed in specs:
        source = SOURCE / filename
        psd = PSDImage.open(source)
        layer = psd[index]
        image = (layer.composite(viewport=viewport) if layer.is_group() else layer.topil()).convert('RGBA')
        # Keep the connected character, dropping isolated design-page specks.
        # A small dilation retains the original antialiasing outside the solid core.
        alpha = image.getchannel('A')
        component = alpha.point(lambda value: 255 if value >= 16 else 0)
        assert component.getpixel(seed) == 255, 'Character seed must be opaque'
        ImageDraw.floodfill(component, seed, 128)
        keep = component.point(lambda value: 255 if value == 128 else 0).filter(ImageFilter.MaxFilter(5))
        image.putalpha(ImageChops.multiply(alpha, keep))
        bounds = image.getbbox()
        image = image.crop(bounds)
        # Native pixel dimensions: no independent width/height resize or masking polygon.
        image.save(OUT / (name + '.png'))
        records.append({'id': name, 'file': name+'.png', 'source': filename,
            'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'source_layer_index': index, 'source_layer_name': layer.name,
            'source_viewport': viewport, 'alpha_crop': bounds, 'size': list(image.size),
            'pivot': 'bottom_center', 'filter': 'linear',
            'processing': 'Original alpha preserved; isolated alpha specks removed; tight crop only; no resizing'})
        print(name, image.size, flush=True)
    path = OUT / 'manifest.json'
    manifest = json.loads(path.read_text(encoding='utf8'))
    manifest['assets'] = [a for a in manifest['assets'] if a['id'] not in {r['id'] for r in records}] + records
    manifest['portrait_processing'] = 'Independent transparent PSD layers; native pixel ratio retained. Runtime uses one uniform scale per portrait.'
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf8')

if __name__ == '__main__':
    extract()
