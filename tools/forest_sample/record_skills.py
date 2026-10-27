"""Verify installed Blender guidance against pinned Git objects and retain its license."""
import hashlib
import json
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = Path.home() / ".codex/skills"
REF = "8f778d2405a214b508d4c7d80742be8e43acdd52"
REPO = "arjun988/blender-skills"
PREFIX = ".claude/skills/"
NAMES = ["blender-modeler", "environment-artist", "hand-painted-style", "anime-style",
         "materials", "lighting", "rendering", "compositing", "pixel-art-style",
         "camera-cinematography"]


def fetch(url):
    with urllib.request.urlopen(url, timeout=30) as response:
        return response.read()


tree = json.loads(fetch(f"https://api.github.com/repos/{REPO}/git/trees/{REF}?recursive=1"))
assert not tree.get("truncated"), "Incomplete upstream tree"
blobs = {item["path"]: item for item in tree["tree"] if item["type"] == "blob"}


def verify(content, remote):
    digest = hashlib.sha1(b"blob " + str(len(content)).encode() + b"\0" + content).hexdigest()
    if digest != blobs[remote]["sha"]:
        raise RuntimeError("Upstream mismatch: " + remote)


license_bytes = fetch(f"https://raw.githubusercontent.com/{REPO}/{REF}/LICENSE")
verify(license_bytes, "LICENSE")
record = {"repo": "https://github.com/"+REPO, "commit": REF,
          "verified_date": "2026-10-27", "skills": {}, "shared_references": {}}
for name in NAMES:
    folder = BASE/name
    members = [p for p in blobs if p.startswith(PREFIX+name+"/")]
    for remote in members:
        relative = remote.removeprefix(PREFIX+name+"/")
        content = (folder/relative).read_bytes()
        verify(content, remote)
        if not relative.endswith(".md"):
            raise RuntimeError("Unexpected executable or other file: "+remote)
    (folder/"LICENSE").write_bytes(license_bytes)
    record["skills"][name] = {p.relative_to(folder).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
        for p in sorted(folder.rglob("*")) if p.is_file()}

# Preserve the upstream ../references links without modifying unrelated skill files.
shared = [p for p in blobs if p.startswith(PREFIX+"references/") and p.endswith(".md")]


def download_reference(remote):
    content = fetch(f"https://raw.githubusercontent.com/{REPO}/{REF}/"+remote)
    verify(content, remote)
    target = BASE/remote.removeprefix(PREFIX)
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() and target.read_bytes() != content:
        raise RuntimeError("Existing shared reference differs; refusing overwrite: "+str(target))
    target.write_bytes(content)
    return target.relative_to(BASE).as_posix(), hashlib.sha256(content).hexdigest()


with ThreadPoolExecutor(max_workers=4) as pool:
    record["shared_references"] = dict(pool.map(download_reference, shared))
license_path = BASE/"references/LICENSE.blender-skills"
if license_path.exists() and license_path.read_bytes() != license_bytes:
    raise RuntimeError("Existing shared license differs")
license_path.write_bytes(license_bytes)
record["shared_references"]["references/LICENSE.blender-skills"] = hashlib.sha256(license_bytes).hexdigest()
(ROOT/"docs/forest-skills.lock.json").write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding="utf-8")
print(f"Verified {len(NAMES)} skills against pinned upstream; installed {len(shared)} shared Markdown references; licenses retained.")
