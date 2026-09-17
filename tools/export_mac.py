#!/usr/bin/env python3
"""Rebuild the Mac app with Godot 4.7.2 and its matching export templates."""
from pathlib import Path
import argparse
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--godot", default=shutil.which("godot"), help="Path to standard Godot executable")
parser.add_argument("--template", help="Optional path to matching macos.zip export template")
args = parser.parse_args()
if not args.godot:
    parser.error("Pass --godot /path/to/Godot.app/Contents/MacOS/Godot")
preset = ROOT / "game/export_presets.cfg"
original = preset.read_text()
try:
    if args.template:
        template = str(Path(args.template).resolve())
        if not Path(template).is_file():
            parser.error("Export template does not exist")
        preset.write_text(original.replace('custom_template/debug=""', f'custom_template/debug="{template}"').replace('custom_template/release=""', f'custom_template/release="{template}"'))
    subprocess.run([args.godot, "--headless", "--path", str(ROOT / "game"), "--editor", "--import", "--quit"], check=True)
    subprocess.run([args.godot, "--headless", "--path", str(ROOT / "game"), "--export-release", "macOS"], check=True)
finally:
    preset.write_text(original)
app = ROOT / "builds/Doodle Rally 1.3.app"
shutil.copytree(ROOT / "docs/licenses", app / "Contents/Resources/Licenses", dirs_exist_ok=True)
subprocess.run(["codesign", "--force", "--deep", "--sign", "-", "--preserve-metadata=entitlements,requirements,flags,runtime", str(app)], check=True)
subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
subprocess.run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(app), str(ROOT.parent / "Doodle_Rally_1.3_Mac.zip")], check=True)
print("Built", app)
