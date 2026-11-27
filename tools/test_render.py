#!/usr/bin/env python3
"""Render smoke test from source: every release case under the Forward+ renderer.

Runs on Linux with xvfb and a Vulkan driver (Mesa lavapipe works without a GPU).
It checks that each case exits cleanly, reaches its expected QA state, logs no
errors and writes a screenshot. It does not replace tools/test_release.py, which
tests the packaged Mac app under Metal.
"""
import argparse, ast, concurrent.futures, os, re, subprocess, tempfile
from pathlib import Path
ROOT = str(Path(__file__).resolve().parents[1])
parser = argparse.ArgumentParser()
parser.add_argument("--godot", required=True, help="Path to a Linux Godot 4.7.2 binary")
parser.add_argument("--out", default=tempfile.mkdtemp(prefix="doodle-render-"), help="Folder for screenshots and logs")
parser.add_argument("--jobs", type=int, default=2)
parser.add_argument("case", nargs="*", help="Case names to run; default all")
args = parser.parse_args()
G = args.godot
src = open(ROOT + "/tools/test_release.py").read()
CASES = ast.literal_eval(re.search(r"CASES = (\[.*?\n\])", src, re.S).group(1))
OUT = args.out
os.makedirs(OUT, exist_ok=True)
sel = args.case
def run(case):
    name, screen, mode, course, character = case
    difficulty = 4 if name in ("track_hard", "quarry_hard") else 2
    cmd = ["xvfb-run", "-a", "-s", "-screen 0 1280x800x24", G, "--path", ROOT + "/game", "--rendering-driver", "vulkan", "--audio-driver", "Dummy",
           "--resolution", "1280x800", "--", "--qa", "--qa-screen=" + screen, "--qa-mode=" + mode, "--qa-course=%d" % course,
           "--qa-character=%d" % character, "--qa-difficulty=%d" % difficulty, "--qa-distance=65", "--qa-output=%s/%s.png" % (OUT, name), "--qa-quit"]
    if name == "mak_doong_garage_boost": cmd.append("--qa-garage-phase=3.2")
    if name == "zizi_garage_brake": cmd.append("--qa-garage-phase=4.2")
    items = {"purrquake_race": "purrquake", "pawfect_parry_race": "paw_parry", "feather_fan_race": "feather_fan", "treat_trail_race": "treat_trail"}
    if name in items: cmd.append("--qa-item=" + items[name])
    spins = {"character_select_quarter_turn": "1.5", "character_select_half_turn": "3.0", "character_select_three_quarter_turn": "4.5"}
    if name in spins: cmd.append("--qa-spin-phase=" + spins[name])
    env = dict(os.environ, HOME=os.path.join(OUT, "home_" + name))
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=420, env=env)
    except subprocess.TimeoutExpired:
        return name, "TIMEOUT"
    out = r.stdout + r.stderr
    open("%s/%s.log" % (OUT, name), "w").write(out)
    state = "splash" if screen == "splash" else "menu" if screen in ("startup", "title", "settings", "characters", "tracks", "garage") else "results" if screen == "results" else "racing"
    marker = "QA_STATE %s screen=%s mode=%s character=%d difficulty=%d" % (state, screen, mode, character, difficulty)
    problems = []
    if r.returncode: problems.append("exit %d" % r.returncode)
    if marker not in out: problems.append("missing " + marker)
    errs = [l for l in out.splitlines() if "ERROR" in l]
    if errs: problems.append("errors: " + errs[0][:120])
    if not os.path.exists("%s/%s.png" % (OUT, name)): problems.append("no screenshot")
    return name, "ok" if not problems else "; ".join(problems)
cases = [c for c in CASES if not sel or c[0] in sel]
bad = 0
with concurrent.futures.ThreadPoolExecutor(args.jobs) as ex:
    for name, res in ex.map(run, cases):
        print(name, res, flush=True)
        bad += res != "ok"
print("RENDER SMOKE: %d cases, %d failed; output in %s" % (len(cases), bad, OUT))
raise SystemExit(1 if bad else 0)
