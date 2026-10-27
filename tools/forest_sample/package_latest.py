"""Package the verified latest source-preserving Blender study."""
import hashlib
import json
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[2]
folder = root/"output/latest-forest-20261027"
members = [folder/"forest-latest-layered.blend", folder/"教程_先读我.md"]
members += sorted((folder/"images").glob("*.png"))
members += sorted((folder/"layers").glob("*.png"))
members += sorted((folder/"layers").glob("*.json"))
members += sorted((folder/"scripts").glob("*.py"))
record = {p.relative_to(folder).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in members}
(folder/"checksums.json").write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding="utf-8")
members.append(folder/"checksums.json")
archive = root/"output/latest-forest-blender-20261027.zip"
with zipfile.ZipFile(archive,"w",zipfile.ZIP_DEFLATED) as output:
    for path in members:
        output.write(path,"latest-forest-blender/"+path.relative_to(folder).as_posix())
with zipfile.ZipFile(archive) as package:
    assert package.testzip() is None
    for path,digest in record.items():
        assert hashlib.sha256(package.read("latest-forest-blender/"+path)).hexdigest()==digest
print(json.dumps({"zip":str(archive),"files":len(members),"size_mb":round(archive.stat().st_size/1024/1024,2),
                  "sha256":hashlib.sha256(archive.read_bytes()).hexdigest()},ensure_ascii=False))
