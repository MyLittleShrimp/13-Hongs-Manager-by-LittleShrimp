"""Fetch a verified PyPI FFmpeg wheel into this workspace; no system installation."""
from pathlib import Path
import hashlib
import json
import urllib.request
import zipfile

root = Path(__file__).resolve().parents[1]
dest = root / "tools" / "video_runtime"
dest.mkdir(parents=True, exist_ok=True)
url = "https://pypi.org/pypi/imageio-ffmpeg/0.6.0/json"
with urllib.request.urlopen(url, timeout=45) as response:
    package = json.load(response)
wheel = next(x for x in package["urls"] if x["filename"].endswith("win_amd64.whl"))
archive = dest / wheel["filename"]
with urllib.request.urlopen(wheel["url"], timeout=90) as response:
    with archive.open("wb") as output:
        while chunk := response.read(1024 * 1024):
            output.write(chunk)
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
assert digest == wheel["digests"]["sha256"], "Wheel checksum mismatch"
with zipfile.ZipFile(archive) as bundle:
    for member in bundle.namelist():
        if member.endswith(".exe") or "LICENSE" in member or "COPYING" in member:
            target = dest / Path(member).name
            target.write_bytes(bundle.read(member))
(dest / "download_manifest.json").write_text(json.dumps({
    "source": url, "wheel": wheel["url"], "sha256": digest,
    "package": "imageio-ffmpeg", "version": "0.6.0"
}, indent=2), encoding="utf-8")
print("FFmpeg ready:", *dest.glob("*.exe"))
