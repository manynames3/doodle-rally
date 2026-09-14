#!/usr/bin/env python3
"""Native Mac release smoke tests and unedited engine screenshots (isolated saves)."""
from pathlib import Path
import subprocess
ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "builds/Doodle Rally 1.1.app/Contents/MacOS/Doodle Rally — Cat Racers"
SHOTS = ROOT / "screenshots/1.1"
LOGS = ROOT / "docs/test-results"
SHOTS.mkdir(parents=True, exist_ok=True)
CASES = [
    ("intro", "title", "cats", 1),
    ("character_select", "characters", "cats", 1),
    ("minecraft_characters", "characters", "minecraft", 1),
    ("track_select", "tracks", "cats", 1),
    ("quarry_race", "race", "cats", 1),
    ("desktop_race", "race", "cats", 0),
    ("glitch_race", "race", "cats", 2),
    ("minecraft_race", "race", "minecraft", 1),
    ("drive_cats", "drive", "cats", 1),
    ("drive_minecraft", "drive", "minecraft", 1),
]
for name, screen, mode, course in CASES:
    command = [str(APP), "--", "--qa", "--qa-screen=" + screen, "--qa-mode=" + mode,
        "--qa-course=" + str(course), "--qa-distance=65", "--qa-output=" + str(SHOTS / (name + ".png")), "--qa-quit"]
    result = subprocess.run(command, capture_output=True, text=True, timeout=75)
    output = result.stdout + result.stderr
    (LOGS / ("release-" + name + "-1.1.log")).write_text(output)
    print(name + ": " + str(result.returncode), flush=True)
    for line in output.splitlines():
        if "QA_DRIVE" in line or "QA_FRAME_TIMES" in line: print(line, flush=True)
    if result.returncode or "ERROR:" in output or not (SHOTS / (name + ".png")).is_file():
        print(output, flush=True)
        raise SystemExit(result.returncode or 1)
print("Native release: ten views/driving checks passed.", flush=True)
