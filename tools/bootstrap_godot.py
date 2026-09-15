"""Fetch a pinned, portable official Godot editor inside this workspace."""
from pathlib import Path
import hashlib
import json
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = "4.7.2-stable"
DEST = ROOT / "tools" / "godot"
DEST.mkdir(parents=True, exist_ok=True)
BASE = f"https://github.com/godotengine/godot/releases/download/{VERSION}/"
NAME = f"Godot_v{VERSION}_win64.exe.zip"

def fetch(name):
    target = DEST / name
    if not target.exists():
        print(f"Downloading {name}...", flush=True)
        with urllib.request.urlopen(BASE + name, timeout=120) as response:
            with target.open("wb") as out:
                while chunk := response.read(1024 * 1024):
                    out.write(chunk)
    return target

archive = fetch(NAME)
sums = fetch("SHA512-SUMS.txt").read_text()
expected = next(line.split()[0] for line in sums.splitlines() if line.split()[-1].lstrip("*") == NAME)
actual = hashlib.sha512(archive.read_bytes()).hexdigest()
if actual != expected:
    raise RuntimeError("Godot archive checksum mismatch. Do not execute it.")
with zipfile.ZipFile(archive) as zipped:
    for member in zipped.infolist():
        target = (DEST / member.filename).resolve()
        if not target.is_relative_to(DEST.resolve()):
            raise RuntimeError("Unexpected archive path")
    zipped.extractall(DEST)
(DEST / "_sc_").touch()
(DEST / "download_manifest.json").write_text(json.dumps({"version": VERSION, "url": BASE + NAME, "sha512": actual}, indent=2))
print(f"Verified Godot {VERSION}: {DEST}", flush=True)
