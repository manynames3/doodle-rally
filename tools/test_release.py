#!/usr/bin/env python3
"""Native Mac release smoke tests and unedited engine screenshots (isolated saves)."""
from pathlib import Path
import argparse
import subprocess
import struct
ROOT = Path(__file__).resolve().parents[1]
VERSION = "1.3.8"
APP = ROOT / f"builds/Doodle Rally {VERSION}.app/Contents/MacOS/Doodle Rally — Cat Racers"
SHOTS = ROOT / f"screenshots/{VERSION}"
LOGS = ROOT / f"docs/test-results/{VERSION}"
SHOTS.mkdir(parents=True, exist_ok=True)
LOGS.mkdir(parents=True, exist_ok=True)
CASES = [
    ("studio_splash", "splash", "cats", 1, 0),
    ("startup_transition", "startup", "cats", 1, 0),
    ("intro", "title", "cats", 1, 0),
    ("settings", "settings", "cats", 1, 0),
    ("character_select", "characters", "cats", 1, 0),
    ("character_select_luna", "characters", "cats", 1, 1),
    ("character_select_milo", "characters", "cats", 1, 2),
    ("character_select_biscuit", "characters", "cats", 1, 3),
    ("character_select_mochi", "characters", "cats", 1, 4),
    ("character_select_pumpkin", "characters", "cats", 1, 5),
    ("character_select_nori", "characters", "cats", 1, 7),
    ("character_select_quarter_turn", "characters", "cats", 1, 0),
    ("character_select_half_turn", "characters", "cats", 1, 0),
    ("character_select_three_quarter_turn", "characters", "cats", 1, 0),
    ("mak_doong_character_select", "characters", "cats", 1, 6),
    ("minecraft_characters", "characters", "minecraft", 1, 0),
    ("track_select", "tracks", "cats", 1, 0),
    ("track_hard", "tracks", "cats", 2, 0),
    ("zizi_garage", "garage", "cats", 1, 0),
    ("mak_doong_garage", "garage", "cats", 1, 6),
    ("mak_doong_garage_boost", "garage", "cats", 1, 6),
    ("zizi_garage_brake", "garage", "cats", 1, 0),
    ("quarry_race", "race", "cats", 1, 0),
    ("quarry_hard", "race", "cats", 1, 0),
    ("mak_doong_race", "race", "cats", 1, 6),
    ("desktop_race", "race", "cats", 0, 0),
    ("glitch_race", "race", "cats", 2, 0),
    ("minecraft_race", "race", "minecraft", 1, 0),
    ("drive_cats", "drive", "cats", 1, 0),
    ("drive_desktop_dojo", "drive", "cats", 0, 0),
    ("drive_mak_doong", "drive", "cats", 1, 6),
    ("drive_minecraft", "drive", "minecraft", 1, 0),
    ("results_zizi", "results", "cats", 1, 0),
    ("results_mak_doong", "results", "cats", 1, 6),
]
parser = argparse.ArgumentParser()
parser.add_argument("--case", action="append", choices=[case[0] for case in CASES], help="Run only this case; repeat to select several.")
args = parser.parse_args()
selected_cases = [case for case in CASES if not args.case or case[0] in args.case]
for name, screen, mode, course, character in selected_cases:
    screenshot = SHOTS / (name + ".png")
    # A previous capture must not make a failed run appear successful.
    screenshot.unlink(missing_ok=True)
    difficulty = 4 if name in ("track_hard", "quarry_hard") else 2
    command = [str(APP), "--resolution", "1280x800", "--windowed", "--", "--qa", "--qa-screen=" + screen, "--qa-mode=" + mode,
        "--qa-course=" + str(course), "--qa-character=" + str(character),
        "--qa-difficulty=" + str(difficulty),
        "--qa-distance=65", "--qa-output=" + str(screenshot), "--qa-quit"]
    if name == "mak_doong_garage_boost": command.append("--qa-garage-phase=3.2")
    if name == "zizi_garage_brake": command.append("--qa-garage-phase=4.2")
    spin_phases = {
        "character_select_quarter_turn": "1.5",
        "character_select_half_turn": "3.0",
        "character_select_three_quarter_turn": "4.5",
    }
    if name in spin_phases: command.append("--qa-spin-phase=" + spin_phases[name])
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=75)
    except subprocess.TimeoutExpired as error:
        def decode(value):
            return value.decode(errors="replace") if isinstance(value, bytes) else (value or "")
        output = decode(error.stdout) + decode(error.stderr)
        output += "\nQA_TIMEOUT: no completion within 75 seconds.\n"
        (LOGS / ("release-" + name + ".log")).write_text(output.replace(str(ROOT), "<project-root>"))
        print(output, flush=True)
        raise SystemExit(1) from None
    output = result.stdout + result.stderr
    (LOGS / ("release-" + name + ".log")).write_text(output.replace(str(ROOT), "<project-root>"))
    print(name + ": " + str(result.returncode), flush=True)
    for line in output.splitlines():
        if "QA_DRIVE" in line or "QA_FRAME_TIMES" in line: print(line, flush=True)
    expected_state = "splash" if screen == "splash" else "menu" if screen in ("startup", "title", "settings", "characters", "tracks", "garage") else "results" if screen == "results" else "racing"
    expected_marker = f"QA_STATE {expected_state} screen={screen} mode={mode} character={character} difficulty={difficulty}"
    expected_animation = "QA_GARAGE state=boost" if name == "mak_doong_garage_boost" else "QA_GARAGE state=brake" if name == "zizi_garage_brake" else ""
    expected_spins = {
        "character_select_quarter_turn": "QA_SPIN phase=1.5 frame=4",
        "character_select_half_turn": "QA_SPIN phase=3.0 frame=8",
        "character_select_three_quarter_turn": "QA_SPIN phase=4.5 frame=12",
    }
    expected_spin = expected_spins.get(name, "")
    if result.returncode or "ERROR:" in output or expected_marker not in output or (expected_animation and expected_animation not in output) or (expected_spin and expected_spin not in output) or not screenshot.is_file():
        print(output, flush=True)
        if expected_marker not in output:
            print("Missing expected QA state: " + expected_marker, flush=True)
        if expected_spin and expected_spin not in output:
            print("Missing expected turntable phase: " + expected_spin, flush=True)
        raise SystemExit(result.returncode or 1)
    dimensions = struct.unpack(">II", screenshot.read_bytes()[16:24])
    if dimensions != (1280, 800):
        raise SystemExit(f"Unexpected native capture dimensions for {name}: {dimensions}")
print(f"Native release: {len(selected_cases)} views/driving checks passed.", flush=True)
