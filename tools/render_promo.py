"""Render and encode the 60s trailer without changing the playable game's settings."""
from pathlib import Path
import json
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "artifacts" / "promo-v1"
CAPTURE_PROJECT = WORK / "render_project"
OUTPUT = ROOT / "output" / "宣传片"
GODOT = ROOT / "tools/godot/Godot_v4.7.2-stable_win64_console.exe"
FFMPEG = next((ROOT / "tools/video_runtime").glob("ffmpeg*.exe"))

for directory in (WORK, CAPTURE_PROJECT, OUTPUT):
    directory.mkdir(parents=True, exist_ok=True)
for name in ("assets", "data", "scenes", "scripts", "promo"):
    shutil.copytree(ROOT / "prototype" / name, CAPTURE_PROJECT / name, dirs_exist_ok=True)
config = (ROOT / "prototype/project.godot").read_text(encoding="utf-8")
config = config.replace("window_width_override=1280", "window_width_override=1920")
config = config.replace("window_height_override=720", "window_height_override=1080")
(CAPTURE_PROJECT / "project.godot").write_text(config, encoding="utf-8")

env = os.environ.copy()
env["HONGS_PROMO_OUTPUT"] = str(WORK)
for key, child in (("APPDATA", "roaming"), ("LOCALAPPDATA", "local")):
    directory = ROOT / "runtime-data" / child
    directory.mkdir(parents=True, exist_ok=True)
    env[key] = str(directory)

def run(command, log):
    print("RUN", log.name, flush=True)
    with log.open("w", encoding="utf-8") as handle:
        result = subprocess.run([str(x) for x in command], cwd=ROOT, env=env,
                                stdout=handle, stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError(f"Command failed; inspect {log}")

run([GODOT, "--path", CAPTURE_PROJECT, "--headless", "--editor", "--import"], WORK / "import-hd.log")
master = WORK / "gameplay_master_1080.avi"
run([GODOT, "--path", CAPTURE_PROJECT, "--scene", "res://promo/trailer.tscn",
     "--resolution", "1920x1080", "--position", "-3000,-3000", "--audio-driver", "Dummy",
     "--fixed-fps", "30", "--write-movie", master, "--disable-vsync", "--quit-after", "1820",
     "--", "--self-test"], WORK / "capture-hd.log")
capture_log = (WORK / "capture-hd.log").read_text(encoding="utf-8")
if "PROMO_CAPTURE_PASS" not in capture_log or "SCRIPT ERROR" in capture_log:
    raise RuntimeError("Director did not finish successfully")
if "1920" not in capture_log or "1080" not in capture_log:
    raise RuntimeError("Capture was not native Full HD")
final = OUTPUT / "十三行_茶船将发_60秒宣传片_无配乐.mp4"
run([FFMPEG, "-hide_banner", "-y", "-i", master, "-t", "60", "-map", "0:v:0", "-an",
     "-vf", "scale=in_range=pc:out_range=tv:in_color_matrix=bt601:out_color_matrix=bt709,format=yuv420p",
     "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-r", "30",
     "-color_range", "tv", "-colorspace", "bt709", "-color_trc", "bt709", "-color_primaries", "bt709",
     "-movflags", "+faststart", "-metadata", "title=十三行 · 茶船将发｜60秒游戏介绍",
     "-metadata", "comment=Godot v0.4 gameplay; edited real seeded playthroughs; no audio track.",
     final], WORK / "encode.log")
run([FFMPEG, "-hide_banner", "-i", final, "-map", "0:v:0", "-f", "null", "-"], WORK / "decode-check.log")
manifest = json.loads((WORK / "capture_manifest.json").read_text(encoding="utf-8"))
manifest["file"] = str(final)
manifest["bytes"] = final.stat().st_size
manifest["codec"] = "H.264 / yuv420p / BT.709"
manifest["silent"] = "No audio track"
(OUTPUT / "制作信息.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
print("PROMO_EXPORT_PASS", final, final.stat().st_size, flush=True)
