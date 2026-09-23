# Build status — September 22, 2026

**Doodle Rally — Cat Racers 1.3.3** integrates the supplied eight-character core asset pack. Character Select uses each individual normalized transparent cutout and portrait, with Zizi and Mak-Doong centered. The Garage plays every racer’s numbered idle, drive, boost, and brake sequences and displays Shared_VFX on separate layers. The race HUD uses core portraits. Previous sheet-derived front crops and cat HUD portraits were removed; Track Select retains its required rear-view cutouts, while playable racing remains the existing full 3D system.

The Universal app is `builds/Doodle Rally 1.3.3.app`, packaged as `Doodle_Rally_1.3.3_Mac.zip` beside this repository. Godot 4.7.2 imports the unchanged PNGs losslessly with mipmaps, premultiplied alpha, and alpha-border repair. Source verification passed **566 functional checks**, six course/mode builds, and three temporal collision replays. The packaged app passed **24 native launch, menu, Garage, race, driving, and results cases**; all 24 screenshots were freshly captured at 1280×800. ZIP CRC and SHA-256 comparisons confirm **147 unchanged PNGs** from the supplied pack. The app signature and distribution ZIP integrity passed. Evidence and screenshots are in `docs/test-results/1.3.3/` and `screenshots/1.3.3/`. The app is locally signed, not Apple-notarized.

## Previous 1.3.2 verification

**Doodle Rally — Cat Racers 1.3.2** adds the animated course-selection lineup and visible Easy, Medium, and Hard difficulty choices. The current Universal app is **builds/Doodle Rally 1.3.2.app**, packaged as **Doodle_Rally_1.3.2_Mac.zip** in the parent output directory. Easy retains the former default rival pace and player handling. Medium and Hard progressively strengthen rival pacing, acceleration, catch-up, and item use. The selected difficulty persists and keeps personal-best records separate.

On Track Select, the rear-facing cats gently sway their visible tails and tilt their heads toward the highlighted course. The motion is confined to each illustration, and Reduced Motion disables the idle tail sway. The deterministic three-course replay shows increasing rival pressure from Easy through Hard on every course. Evidence is in `docs/test-results/1.3.2/`; native captures are in `screenshots/1.3.2/`. The 1.3.2 app is locally signed rather than Apple-notarized.

All **346 functional checks**, six course/mode builds, and three temporal collision replays passed. The scripted difficulty replay passed on all three courses. The final signed app passed **22 native launch, menu, race, driving, and results cases**, including Hard Track Select and Hard Block Quarry; its 22 screenshots were freshly captured from the final package. The app's signature and ZIP integrity both verified. These checks establish reproducible behavior and a balance trend; race outcomes still depend on the player's driving, items, and collisions.

## Previous 1.3.1 verification

**Doodle Rally — Cat Racers 1.3.1** improves race smoothness on macOS. Its Universal app is **builds/Doodle Rally 1.3.1.app**, packaged as **Doodle_Rally_1.3.1_Mac.zip** in the parent output directory.

The race now defaults to **Smooth motion** in Options. It uses FSR 1 spatial upscaling for the 3D scene, two directional-shadow cascades, and less expensive ambient lighting; the HUD remains at full resolution. The 3D scale adjusts when the game window changes size. Scenery batches are divided into nearby spatial tiles so unseen props can be culled. **Balanced** and **Full detail** retain higher rendering quality when the Mac can sustain it. Kart simulation remains at a fixed 60 Hz with interpolated render transforms.

On an Apple M1, the native eight-racer Block Quarry sample measured **22.706 → 14.289 ms median** at 1280×800, and **32.566 → 18.283 ms median** at 1920×1080, comparing Full detail with Smooth motion. This is approximately **44 → 70 fps** and **31 → 55 fps** by median frame time. The p95 values were **23.671 → 17.781 ms** and **34.614 → 20.021 ms**. Each short run measured 180 rendered frames after 60 warm-up frames. Results vary with track, race position, hardware, window size, and system load; this is not a guaranteed frame rate. Logs are in `docs/test-results/1.3.1/render-*.log`.

All **331 functional checks** and three temporal collision replays passed. The signed 1.3.1 app passed **20 native launch, screen, and driving cases**, including all tracks and both rosters. The 12-second packaged cat drive recorded **12.5 ms median / 16.7 ms p95** frame intervals, and Mak-Doong recorded **12.5 ms / 18.1 ms**; these are short samples. Export, regression, native case, and benchmark logs are in `docs/test-results/1.3.1/`. Native screenshots are in `screenshots/1.3.1/`. The app remains locally signed rather than Apple-notarized.

## Previous 1.3.0 verification

**Doodle Rally — Cat Racers 1.3.0** updates Zizi and Mak-Doong, the character lineup, alpine rendering, and the launch sequence. The Universal Mac app is **builds/Doodle Rally 1.3.app**, packaged as **Doodle_Rally_1.3_Mac.zip**. Earlier builds and their evidence are preserved separately.

## What changed

- **Zizi**, slot 0: black face, black nose, white chin, white chest and paws, yellow-green eyes. **Mak-Doong**, slot 6: photo-guided black/burnt-orange/white calico markings, black chin, white chest and paws, and a floating gold halo. Names now agree across selection, Garage, standings and results. Existing saved slots and driving statistics remain compatible.
- Larger sculpted kitten faces, integrated cheeks and muzzle, cupped ears, curved whiskers, radial irises and denser opaque fur. HUD portraits come from these same models. Fine groom detail uses a smaller silhouette-focused mesh, a cheap opaque shader, and distance culling; the solid cat body and head remain opaque. Mak-Doong’s halo is tilted slightly so it reads as an oval in the front-facing lineup.
- One shared 3D lineup with higher-resolution antialiasing replaces the separate character thumbnails. Native selection cards, player marker, labels, keyboard, mouse and controller navigation remain interactive. Hidden previews stop rendering and animating during a race. Track selection includes the selected racer in the rear-facing lineup.
- The character display order now places Zizi and Mak-Doong in the two middle slots. Pumpkin has a russet-and-cream pattern distinct from Biscuit, while the iris lenses use a shallow, lower-gloss material so the cats keep the soft illustrated look of the reference.
- Mak-Doong's calico mask now continues over the crown and back of the head with broad black, ginger and white patches, so the chase camera shows the same identity as the front-facing menu model instead of random circular spots.
- Kart transforms and the chase camera use the same interpolated physics distance and a smoothed aim target, reducing render-rate steering and yaw stepping without changing simulation collision timing.
- The three course soundtracks are regenerated as evolving 64-bar mixes lasting roughly 118, 126 and 132 seconds. Their final 0.9 seconds are crossfaded into the opening, and runtime loop endpoints use the decoded stream duration so compressed imports never cut the music short.
- Forward+ Metal rendering, revised limestone cliffs and cat tunnel, layered pine boughs, greenery, flowing waterfalls and updated lighting. Racing uses 2× MSAA; menu previews retain 4× MSAA and supersampling. Expensive effects were checked on Apple M1; final renderer measurements are recorded below.
- The supplied **BenJam Games** logo appears once at launch, fades in, holds, and opens the title menu after approximately **2.05 seconds**. Any key, click or controller button skips it; the skip event is consumed before menu input begins.
- The supplied Luna, Milo, Biscuit, Mochi and Pumpkin asset sheets now have transparent front-left stage crops and matching portrait crops used by Character Select and Garage. Zizi and Mak-Doong use the same high-resolution presentation path, with Mak-Doong's halo, broad calico mask, and cleaned rear alpha retained. Nori is the eighth playable cat, replacing the prior Shadow slot; the roster is Zizi, Luna, Milo, Biscuit, Mochi, Pumpkin, Mak-Doong, and Nori.
- Character Select uses aspect-preserving, bilinear-mipmapped presentation sprites so ears, whiskers, kart bodies, and wheels stay centered without the earlier dark matte fringe. Desktop Dojo's paper grid was removed because its shallow-angle strips shimmered outside the road; the textured sheet, lifted stationery props, and mipmapped panorama now remain stable as the chase camera moves.
- Collision half-width increases to **1.70 m** to enclose the enlarged characters' animated lean envelope; half-length remains **2.02 m**. The previous solid contact and camera protections remain active. QA captures explicitly request a render frame so an inactive macOS window cannot hang waiting for automatic redraw.

## Verification

- **327 functional checks passed**: 185 simulation/save, 25 menu, 80 roster projection/identity/selection, 28 integration, and 9 soundtrack checks. Integration covers automatic splash completion and skip without clicking through for keyboard, mouse and controller input; soundtrack checks load all three imported WAVs and verify their full durations.
- All **six course/mode combinations** built successfully. Three-lap simulated drives completed each course with zero fence impacts.
- **2,160 temporal collision states** sampled across three replays at 120 Hz: straight cat traffic, cats on the Quarry's sharpest curve, and Minecraft traffic on that curve. Rear contact, side contact, crowded barriers, boost, stun and hopping produced zero projected mesh overlap, opacity/visibility violations, camera intrusion or near-plane violations. These are headless geometry/state checks; ordinary rival occlusion can still occur.
- Evidence: `docs/test-results/1.3/regression.log` and `collision_*.json`.

- **19 native release cases passed**: studio logo, automatic launch transition, title, both custom-cat selections, Minecraft selection, track selection, both custom-cat Garage views, both custom-cat Quarry race views, Desktop Dojo, Glitch Core, Minecraft racing, three 12-second drives, and both custom-cat results. Every case wrote a fresh 1280×800 screenshot and confirmed the requested character in the app’s QA state. Evidence: `native-release.log` and `release-*.log` in `docs/test-results/1.3/`.
- The final visual review raised and shortened overhead pennants to keep the chase-camera sightline clear. All six world builds were rechecked; the four affected native race views were recaptured successfully from the rebuilt app. Evidence: `world-final.log` and `native-final-scenery.log`.
- The **arm64 + x86_64 Universal** app exported as **1.3.0**, build **4**, and passed local signing verification. Evidence: `docs/test-results/1.3/export.log`. New native screenshots are in `screenshots/1.3/`; the eight model review images are in its `characters/` folder.

At **1280 × 800 on Apple M1**, a short full eight-racer native render sample recorded **27.008 ms median / 30.827 ms p95**, with 264 confirmed rendered frames (180 measured after warm-up). It follows the normal track-menu launch route and includes simulation, camera, HUD and scenery. This is approximately 37 fps at the median, not a sustained or all-hardware benchmark. The harness fixes the measured viewport dimensions and uses ordinary automatic rendering, counting `frame_post_draw` signals. Evidence: `docs/test-results/1.3/render-benchmark-final.log`; reproducible harness: `game/tests/benchmark_render.gd` with `-- --qa --automatic`.

Earlier manual-force-draw samples include extra waiting and do not represent normal gameplay frame rate. One earlier automatic harness run completed its measured frames and then crashed during engine shutdown; the harness now disconnects its render callback and releases the scene before shutdown. The final harness exits cleanly. All 19 packaged-app launch/quit cases exited cleanly; their checks are listed above.

## Rebuild

Use Godot **4.7.2** with matching macOS export templates:

```sh
python3 tools/test.py --godot /path/to/Godot.app/Contents/MacOS/Godot
python3 tools/export_mac.py --godot /path/to/Godot.app/Contents/MacOS/Godot --template /path/to/macos.zip
python3 tools/test_release.py
```

The native runner exercises both custom cats, Minecraft, all tracks, Garage, results, launch screens and three 12-second drives, using isolated preferences. Generated apps and temporary telemetry are excluded from source control.

The game remains single-player. The reference images are cinematic illustrations; this update improves the playable models and scenery, but does not reproduce their full fur density, environmental detail or offline-rendered image quality. The app is signed locally, not Apple-notarized. Intel hardware, physical controller hardware/rumble, external displays and long-session performance remain untested. Original pet photographs are excluded from the app and distributable source. Asset provenance is in `docs/ASSET_PROVENANCE.md`; prior verification is archived in `docs/releases/1.1.md` and `docs/releases/1.2.md`.
