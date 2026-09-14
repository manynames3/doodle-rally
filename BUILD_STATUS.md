# Build status — September 13, 2026

**Doodle Rally — Cat Racers 1.1.0** addresses reported collision ghosting and visual drift. The Universal Mac app is **builds/Doodle Rally 1.1.app**; the earlier 1.0 app is separate.

## Collision and camera repair

The earlier implementation skipped contact separation during a 0.7-second bump cooldown. Native replay reproduced solid cars passing through each other while every racer material stayed opaque. The new solver separates oriented kart hulls on every physics tick, resolves crowded packs against barriers, transfers impact velocity and reserves cooldown for feedback. Measured animated geometry sets the common hull to 3.20 m wide × 4.04 m long, including turned wheels and suspension lean.

The camera now lifts gradually before a rival enters its chase corridor. Rendering interpolates the fixed 60 Hz simulation. A render-only stun rotation that could swing wheels outside their physical hull was removed. AI lateral steering now depends on forward speed, preventing sideways movement and pileups when starting from rest.

Final temporal testing covered **3,600 samples at 120 Hz** across cats on a straight stress lane, cats on the actual Quarry's sharpest curve, and Minecraft racers on that curve. Faster rear impacts, sustained side contact, an eight-car barrier pack and boosted/stunned/hopping contacts all passed with **zero projected vehicle-geometry overlap, zero opacity/visibility violations, and zero camera or near-plane intrusion**. The fixture confirms broad bounding-box contacts with convex footprints of actual transformed vertices. It excludes intentionally visible/invisible flames and drift sparks.

Maximum camera offset change was 0.0499 m per sample on the straight and 0.1061 m on the sharp turn. Ordinary nearby-rival occlusion remains possible; rivals are kept opaque. Read `docs/COLLISION_REVIEW.md` and `docs/test-results/collision-*-1.1.json` for methodology and measured results.

## Visual revision

- Broader, compact seated kittens; round cheeks, integrated dark-rimmed eyes, corrected coat colors/stripes, fine opaque fur detail and continuous curved tails.
- Wider rounded buggies, larger treaded tires, glossy fenders, rear spoilers, twin exhausts and flat printed paw emblems.
- HUD portraits rendered from the actual sixteen models, plus condensed italic racing numerals matching the supplied rank/lap/speed treatment. Clubhouse lettering stays handwritten.
- Soft dust puffs, textured tan dirt with tire wear, limestone fractures and ledges, timber grain, layered pine branches, irregular snowy mountain ridges, an embedded cat tunnel and broken white waterfall ribbons. Lighting was tuned to retain white-fur detail.
- The reference-led intro menu and its Minecraft Racing option remain available. Character and Garage previews share the race models.

This is a material improvement toward the references, while gameplay remains stylized procedural 3D. It does not reproduce their cinematic sculpting, dense fur or full environmental complexity. Course cards remain illustrations, and the three themes share a core circuit with different elevations and scenery.

## Functional and release verification

- **185 simulation/save checks:** complete deterministic three-lap races, seven AI, steering/braking, solid contacts and crowded barriers, lap-seam contact, recovery, drift/boost, all four items, hazards/shields, exact finish crossing, pause, and invalid/corrupt preferences.
- **25 menu checks** and **19 app integration checks:** mouse/keyboard/synthesized controller routes, both rosters, settings, Garage, countdown, actual gas input, item use, pause/resume, track changes, results and restart.
- All **six world/mode combinations** build with seamless course wrapping, upward-facing road normals and pausable scenery. Three-lap feedback drives finish every course with zero fence impacts (98.05–102.08 seconds in the final simulation run).
- The exported 1.1 Mac app passed **ten native view/driving checks** (intro, both rosters, tracks, all three course themes, both modes and two 12-second drives). On Apple M1 at 1280×800, cats had a median frame interval of **18.52 ms** / 95th percentile **21.21 ms**; Minecraft had **11.67 ms** / **16.67 ms**. End-of-run FPS readings were 59 and 89 respectively. These are short samples, not sustained benchmarks. Logs: `docs/test-results/release-*-1.1.log`.
- The portable final regression runner additionally passed **2,160 rendered-state samples** with zero hull overlap or camera intrusion across its three headless replays.
- Universal **arm64 + x86_64** export; local signing verification and release launch are recorded in `docs/test-results/export-1.1.log`. Native screenshots are in `screenshots/1.1/`.

Tests isolate preferences and do not operate the original Doodle Rumble app or overwrite its data. This release is single-player. Physical controller hardware/rumble, Intel Mac hardware, long sessions and external displays remain untested; the app is locally signed rather than Apple-notarized.

## Rebuild and rerun

Use standard Godot 4.7.2 and matching Mac export templates:

```sh
python3 tools/test.py --godot /path/to/Godot.app/Contents/MacOS/Godot
python3 tools/export_mac.py --godot /path/to/Godot.app/Contents/MacOS/Godot --template /path/to/macos.zip
```

The test runner includes the four functional suites plus three portable temporal collision replays. Their temporary telemetry goes to `test-output/`; no player preferences are used. Asset sources and licenses are in `docs/ASSET_PROVENANCE.md`.
