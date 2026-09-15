"""Export subtitle reference and representative frames from the finished trailer."""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "artifacts/promo-v1"
OUT = ROOT / "output/宣传片"
FFMPEG = ROOT / "tools/video_runtime/ffmpeg-win-x86_64-v7.1.exe"
VIDEO = OUT / "十三行_茶船将发_60秒宣传片_无配乐.mp4"


def timestamp(seconds):
    value = round(seconds * 1000)
    return f"{value // 3600000:02d}:{value // 60000 % 60:02d}:{value // 1000 % 60:02d},{value % 1000:03d}"


manifest = json.loads((ART / "capture_manifest.json").read_text(encoding="utf-8"))
cues = []
for index, shot in enumerate(manifest["shots"], start=1):
    cues.append(f"{index}\n{timestamp(shot['start'])} --> {timestamp(shot['end'])}\n{shot['head']}\n{shot['sub']}\n")
(OUT / "剪辑字幕参考.srt").write_text("\n".join(cues), encoding="utf-8-sig")

for name, seconds in [("title", 2.5), ("market", 12.5), ("inspection", 19.5), ("roast", 26), ("packing", 33.5), ("storm", 40), ("acceptance", 43.5), ("profit", 48.5), ("loss", 51.5), ("outro", 57.5)]:
    subprocess.run([str(FFMPEG), "-hide_banner", "-loglevel", "error", "-ss", str(seconds), "-i", str(VIDEO), "-frames:v", "1", "-update", "1", "-y", str(ART / f"qa-{name}.jpg")], check=True)
subprocess.run([str(FFMPEG), "-hide_banner", "-loglevel", "error", "-ss", "2.5", "-i", str(VIDEO), "-frames:v", "1", "-update", "1", "-q:v", "2", "-y", str(OUT / "宣传片封面.jpg")], check=True)
print("PROMO_QA_FRAMES_AND_SUBTITLES_PASS")
