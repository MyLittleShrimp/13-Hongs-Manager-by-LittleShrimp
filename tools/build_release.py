"""Build a clean Windows portable ZIP, then test the actual unpacked artifact."""
from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import subprocess
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ENGINE = "Godot_v4.7.2-stable_win64"
MUSIC = ("main_theme.mp3", "13_hongs.mp3")


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def run_game(package, logs, name, *args):
    env = os.environ.copy()
    for key, child in (("APPDATA", "roaming"), ("LOCALAPPDATA", "local")):
        folder = logs / "runtime" / child
        folder.mkdir(parents=True, exist_ok=True)
        env[key] = str(folder)
    command = [str(package / "tools/godot" / (ENGINE + "_console.exe")),
               "--path", str(package / "prototype"), *args]
    result = subprocess.run(command, cwd=package, env=env, capture_output=True, timeout=180)
    output = result.stdout.decode("utf-8", "replace") + result.stderr.decode("utf-8", "replace")
    (logs / (name + ".log")).write_text(output, encoding="utf-8")
    errors = [line for line in output.splitlines()
              if ("ERROR:" in line or "SCRIPT ERROR:" in line)
              and "Failed to read the root certificate store" not in line]
    if result.returncode or errors:
        raise RuntimeError(f"{name} failed; see {logs / (name + '.log')}: {errors}")
    markers = [line for line in output.splitlines() if "PASS" in line]
    print(name + ": " + ("; ".join(markers) or "passed"), flush=True)
    return markers


def main():
    if git("status", "--porcelain"):
        raise SystemExit("Commit the release source first; packaging requires a clean working tree.")
    config = (ROOT / "prototype/project.godot").read_text(encoding="utf-8")
    version = re.search(r'^config/version="(\d+\.\d+\.\d+)"$', config, re.M).group(1)
    tag = "v" + version
    name = f"13-Hongs-Manager-{tag}-Windows-x64"
    out = ROOT / "output/releases" / tag
    out.mkdir(parents=True, exist_ok=True)
    archive = out / (name + ".zip")
    if archive.exists():
        raise SystemExit(f"Refusing to replace existing artifact: {archive}")
    work = ROOT / "build/releases" / (tag + "-" + uuid.uuid4().hex[:8])
    work.mkdir(parents=True)
    candidate = work / archive.name
    package = work / name
    source = work / "source.zip"
    subprocess.run(["git", "archive", "--format=zip", f"--output={source}", "HEAD"], cwd=ROOT, check=True)
    with zipfile.ZipFile(source) as z:
        z.extractall(package)
        included = [n for n in z.namelist() if not n.endswith("/")]
    # CMD files must stay readable on Windows regardless of Git's archive EOLs.
    for path in package.glob("*.cmd"):
        data = path.read_bytes().replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")
        path.write_bytes(data)
    engine_dir = package / "tools/godot"
    engine_dir.mkdir(parents=True)
    for filename in [ENGINE + ".exe", ENGINE + "_console.exe", "_sc_", "download_manifest.json"]:
        shutil.copy2(ROOT / "tools/godot" / filename, engine_dir / filename)
        included.append("tools/godot/" + filename)
    audio = {}
    for filename in MUSIC:
        path = package / "prototype/assets/audio" / filename
        if not path.is_file() or path.stat().st_size < 1_000_000:
            raise RuntimeError("Missing full-length music: " + filename)
        audio[filename] = {"bytes": path.stat().st_size, "sha256": digest(path)}
    metadata = {"version": version, "commit": git("rev-parse", "HEAD"), "music": audio,
                "engine": "4.7.2", "package": name}
    (package / "BUILD.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    instructions = (f"十三行 · 茶船将发 {tag}\n\n完整解压后双击「启动游戏.cmd」。\n"
                    "两首背景音乐、便携Godot与导入资源均已包含；不需要安装Python或Godot。\n"
                    "音乐默认开启，音量35%；可在「声音设置」调整。\n"
                    "旧版Windows触摸设备请用「启动兼容模式.cmd」，F11切换全屏。\n"
                    "请使用新解压的文件夹启动，避免误开旧版本。\n")
    (package / "先看这里.txt").write_text(instructions, encoding="utf-8-sig")
    included.extend(["BUILD.json", "先看这里.txt"])
    run_game(package, out, "import", "--headless", "--editor", "--import")
    cache = package / "prototype/.godot"
    for path in cache.rglob("*"):
        if path.is_file() and ("imported" in path.relative_to(cache).parts
                               or path.name in ["uid_cache.bin", "global_script_class_cache.cfg"]):
            included.append(path.relative_to(package).as_posix())
    with zipfile.ZipFile(candidate, "x", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for relative in sorted(set(included)):
            z.write(package / relative, name + "/" + relative)
    with zipfile.ZipFile(candidate) as z:
        bad = z.testzip()
        if bad:
            raise RuntimeError("Corrupt ZIP entry: " + bad)
        unpack = work / "verify"
        z.extractall(unpack)
        file_count = len(z.namelist())
    verified = unpack / name
    for filename in MUSIC:
        if digest(verified / "prototype/assets/audio" / filename) != audio[filename]["sha256"]:
            raise RuntimeError("Music changed during packaging")
    results = []
    for script in ["test_music", "test_characters", "test_performance", "test_compatibility", "test_weather_history", "test_commissions_loading", "test_gestures"]:
        results += run_game(verified, out, "unpacked-" + script, "--headless", "--script",
                            "res://tests/" + script + ".gd", "--", "--self-test")
    run_game(verified, out, "unpacked-startup", "--resolution", "1280x720", "--position",
             "-2400,-2400", "--audio-driver", "Dummy", "--script", "res://tests/test_music.gd",
             "--", "--self-test", "--capture-music")
    results += run_game(verified, out, "unpacked-compatibility", "--resolution", "1280x720",
                        "--position", "-2400,-2400", "--rendering-method", "gl_compatibility",
                        "--max-fps", "30", "--audio-driver", "Dummy", "--script",
                        "res://tests/test_compatibility.gd", "--", "--self-test", "--compatibility", "--capture-compat")
    results += run_game(verified, out, "unpacked-gestures-gpu", "--resolution", "1280x720",
                        "--position", "-2400,-2400", "--rendering-method", "gl_compatibility",
                        "--max-fps", "30", "--audio-driver", "Dummy", "--script",
                        "res://tests/test_gestures.gd", "--", "--self-test", "--compatibility", "--capture-gestures")
    # Only promote a final artifact after every unpacked-package check passes.
    shutil.copy2(candidate, archive)
    checksum = digest(archive)
    (out / "SHA256SUMS.txt").write_text(f"{checksum}  {archive.name}\n", encoding="utf-8")
    info = metadata | {"archive": archive.name, "bytes": archive.stat().st_size,
                       "sha256": checksum, "files": file_count, "verification": results,
                       "verified_package": str(verified)}
    (out / "build-info.json").write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding="utf-8")
    notes = (package / "docs/releases" / (tag + ".md")).read_text(encoding="utf-8")
    notes += (f"\n## 成品包验证\n\n从最终ZIP重新解压，无需编辑器导入，音乐循环、"
              f"角色交易、工序演出、手势互动与重复触摸兼容专项均通过，并完成实际GPU启动和30帧手势完整交易检查。两首MP3的SHA256与工程原文件一致。\n\n"
              f"源码提交：`{metadata['commit']}`。附件SHA256：`{checksum}`。\n")
    (out / "release-notes.md").write_text(notes, encoding="utf-8")
    print(json.dumps(info, ensure_ascii=True, indent=2), flush=True)


if __name__ == "__main__":
    main()
