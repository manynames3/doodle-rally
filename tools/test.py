#!/usr/bin/env python3
"""Run the standalone game regression suites with isolated preferences."""
from pathlib import Path
import argparse
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--godot", default=shutil.which("godot"))
args = parser.parse_args()
if not args.godot:
    parser.error("Pass --godot /path/to/Godot.app/Contents/MacOS/Godot")
for suite in ("test_race.gd", "test_menu.gd", "test_roster_stage.gd", "test_integration.gd", "test_world.gd", "test_audio.gd"):
    result = subprocess.run([args.godot, "--headless", "--path", str(ROOT / "game"), "--script", "res://tests/" + suite, "--", "--qa"], capture_output=True, text=True, timeout=60)
    output = result.stdout + result.stderr
    print(output.strip())
    if result.returncode or "ERROR:" in output:
        raise SystemExit(result.returncode or 1)
for label, extra in (("straight", []), ("quarry", ["--course=1"]), ("minecraft", ["--course=1", "--mode=minecraft"])):
    output_dir = ROOT / "test-output" / ("collision_" + label)
    result = subprocess.run([args.godot, "--headless", "--path", str(ROOT / "game"), "--script", "res://tests/test_collision_visual.gd", "--", "--no-capture", "--frames=90", "--render-hz=120", "--effects", "--assert-clearance", "--max-penetration=.025", "--output=" + str(output_dir), *extra], capture_output=True, text=True, timeout=60)
    output = result.stdout + result.stderr
    print(output.strip())
    if result.returncode or "ERROR:" in output:
        raise SystemExit(result.returncode or 1)
print("All six functional suites and three temporal collision replays passed.")
