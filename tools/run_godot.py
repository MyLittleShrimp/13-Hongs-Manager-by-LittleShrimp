"""Project-local Godot runner. Does not modify machine-wide environment settings."""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / "tools/godot/Godot_v4.7.2-stable_win64_console.exe"
if not EXE.exists():
    raise SystemExit("Run python tools/bootstrap_godot.py first.")
env = os.environ.copy()
for key, child in (("APPDATA", "roaming"), ("LOCALAPPDATA", "local")):
    folder = ROOT / "runtime-data" / child
    folder.mkdir(parents=True, exist_ok=True)
    env[key] = str(folder)
args = [str(EXE), "--path", str(ROOT / "prototype"), *sys.argv[1:]]
completed = subprocess.run(args, env=env, cwd=ROOT)
raise SystemExit(completed.returncode)
