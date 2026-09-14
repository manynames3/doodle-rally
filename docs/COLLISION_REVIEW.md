# Collision visual review — native Godot replay

The apparent vehicle ghosting is reproduced as **opaque geometry interpenetrating**, rather than a transparency or temporal-renderer effect. This conclusion is backed by the preserved v1 implementation and an isolated native replay.

## Reproduction

`game/tests/test_collision_visual.gd` builds an isolated straight test lane and runs the real simulation, kart visuals, camera update methods, and race objects. It does not instantiate the main scene, change saved preferences, play audio, or operate the user's running app. Each run contains three 150-frame cases at fixed 60 Hz: a fast rear-end approach; steering into a side-by-side rival; and an eight-kart pack against the barrier. It writes telemetry every frame and a native rendered image every 15 frames.

The fixture loads baseline or current scripts by command-line path. Baseline runs used the exact copies in `work/v1-baseline/`. The stage is deliberately plain to expose silhouettes and depth occlusion; it is not a visual mockup of the actual game environment.

## Evidence

| Case | v1 frames with visual footprint overlap | v1 max penetration | v2 simulation overlap frames |
| --- | ---: | ---: | ---: |
| Rear end | 15 / 150 | 1.86 m | 0 / 150 |
| Side contact | 29 / 150 | 3.37 m | 0 / 150 |
| Barrier pack | 150 / 150 | 3.17 m (up to 19 pairs) | 0 / 150 |

The collision footprint diagnostic uses SAT against conservative oriented rectangles derived from each actual built model's visible geometry, rather than an assumed kart width. It is a sufficient separation check, not a triangle-level intersection solver. The v1 player model's measured visible bounds were approximately 2.890 m wide × 3.378 m tall × 3.727 m long.

All 465 initially visible solid mesh instances remained visible with opaque material state across the 450-frame v1 replay and each v2 replay. Only item boxes, shield spheres, and dust use transparent materials; they do not toggle racer opacity. The project uses Godot's Compatibility renderer and MSAA, with no temporal anti-aliasing configured.

`work/collision_visual_v1/side_contact_015.png` clearly shows the red and blue kart bodies, wheels, spoilers, and cats occupying the same space. The blue and red surfaces alternate occlusion as they move through one another. In this case penetration increases while the v1 shared bump cooldown falls from 0.7 to 0.47 seconds. This directly matches the source logic that skips all contact resolution during cooldown and initially moves each kart sideways by only 0.6 m.

`work/collision_visual_v2_sim/side_contact_015.png` is the identical scenario after the contact-solver change, with the old visuals and camera kept constant. The two vehicles remain separate. `work/collision_visual_v2_sim/barrier_pack_015.png` likewise shows a separated pack rather than fused vehicles.

## Camera follow-up (intermediate revision, subsequently fixed)

The single-upper-anchor camera revision removes the remaining rival occlusion along the camera-to-player line in the side-contact test (16 frames to zero). Exact camera-center containment in a rival's visible bounds is also zero. Three frames touch the more conservative visible-bounds-plus-near-plane margin; these are not proof of rendered clipping.

A follow-up camera motion issue was found at side-contact frame 98 / 1.633 s: the camera's offset relative to the player changes by 3.447 m and rotates by 12.47 degrees in a single 60 Hz step. The chase framing briefly zooms enough to cut off the lower kart. Compare `work/collision_visual_v2_camera_clearance/side_contact_090.png`, `side_contact_105.png`, and `side_contact_120.png`. Earlier gradual avoidance or a predicted clearance corridor could reduce this snap while retaining the solid safety check.

Telemetry and camera motion metrics are in each replay directory's `telemetry.json`. The earliest telemetry files used `camera_inside_rival` for the conservative near margin; the latest fixture separates true containment from `camera_near_margin` explicitly.

## Visual fidelity priorities from comparison with the five supplied renderings

1. Cat silhouette and surface detail: the original real-time drivers have small smooth spherical heads, long thin torsos and arms, and very graphic ears. The references have oversized plush heads, short necks, rounded cheeks, chubby bodies seated low in the cockpit, fluffy ears and tails. This is the biggest character mismatch.
2. World materials and lighting: the original quarry screenshots have a saturated orange noisy road, broad angular cliff blocks, uniform cone trees, and clipped white surfaces. The references feature tan dirt with subtle directional wear, gray stratified rock, irregular dense foliage, rich shadows, and warm highlights with readable white fur. Geometry alone does not explain the gap; lighting and material roughness/texture matter.
3. Racing HUD typography: the layout and color hierarchy are already close, but handwritten Kalam numerals differ from the heavy condensed italic rank/lap/speed numerals in the references. Preserve handwritten type for clubhouse menus and use bold outlined numeric typography during races.
4. Portrait/item polish: the leaderboard and map show tiny flat cat drawings, while the supplied screens show detailed face portraits. Power-up icons are clean but schematic rather than shaded objects.
5. Menus: the title backdrop and wooden controls are already close to the latest supplied intro. Character and track screens capture the broad structure and warmth. The rendered character models remain the dominant fidelity gap there, rather than UI positioning.

No production simulation, camera, visual model, world, or HUD code was changed by this review. The reviewer owns only the collision visual test and work-directory evidence.

## Final regression — measured moving models, solid hull, smooth camera

The final simulation uses a 1.60 m half-width and 2.02 m half-length, chosen from the measured animated model envelope. Exact transformed vertices across 648 poses per roster (steering ±1, full drift, boost, suspension and wheel spin; flame/spark effects excluded) measured cats at X ±1.583513 m and Z −1.992805…+1.914333 m. The voxel roster fits inside these common dimensions. This also covers movement that the neutral-pose width alone missed.

The final replay samples the production kart interpolation at fractions 0.5 and 1.0 between 60 Hz physics ticks, for 120 Hz temporal coverage. Animated visible bounds are refreshed for each sample. Broad oriented AABB overlaps are confirmed with SAT against the convex projected footprints of the actual transformed mesh vertices. This prevents empty corners around spinning tires from being misreported as collisions. These hulls remain conservative: a pass establishes separation, while a tiny hull overlap need not mean actual triangles intersect.

| Final replay | Samples | Projected geometry overlap | Opaque/visible violations | Camera / near-plane intrusion |
| --- | ---: | ---: | ---: | ---: |
| Cats, straight stress lane | 1,200 | 0 | 0 | 0 |
| Cats, actual Quarry sharpest curve, native rendering | 1,200 | 0 | 0 | 0 |
| Minecraft, actual Quarry sharpest curve | 1,200 | 0 | 0 | 0 |

Each replay includes faster rear-end contact, sustained side steering contact, an eight-car pack against a rail, and contacts during boosts, stuns and hops. Every final cat sample audits 484 solid meshes; the Minecraft run audits 359. Shader inspection also rejects ALPHA writes or discard in solid racer materials. Boost flames and drift sparks are explicitly excluded from collision and opacity assertions because their visible state is an intentional effect.

The earlier camera snap was fixed with gradual clearance lift. Final maximum changes in camera offset relative to the player were 0.0499 m per 120 Hz sample on the straight and 0.1061 m on the sharpest Quarry turn. Maximum angle changes were 0.1252° and 1.2827° respectively, with no camera-center or near-margin intrusion. Eleven Quarry samples have ordinary rival occlusion along the conservative camera-to-body ray; inspected native frames show an opaque nearby rival rather than missing geometry. No sudden zoom or split/fused vehicles appeared in the final frame review.

Final output directories:

- `work/collision_visual_final_straight/telemetry.json`
- `work/collision_visual_final_quarry/telemetry.json` and native screenshots
- `work/collision_visual_final_voxel/telemetry.json`

Source SHA-256 hashes are recorded in the final telemetry. A short portable headless regression (about 8 seconds on this Mac) is:

```sh
godot --headless --path game --script res://tests/test_collision_visual.gd -- \
  --no-capture --frames=90 --render-hz=120 --effects --assert-clearance \
  --max-penetration=.025 --output=/absolute/work/collision-qa
```

Add `--course=1` to exercise the actual Quarry curve and `--mode=minecraft` for the voxel roster. Omit `--headless` and `--no-capture` to capture temporal PNG frames; all paths to production resources remain portable. The test deliberately resolves its manually planted impossible initial pack before interpolating between valid states.

## Updated visual review

The rebuilt cat heads, broader buggies, modeled tread/exhaust/spoilers, and fur shader materially improve the silhouette and surface detail. The tan road and gray rocks also bring the Quarry palette closer to the supplied rendering. The largest remaining scenic difference visible in the sharpest-curve replay is the tall, simple cliff-pillar silhouette relative to the reference's varied stratified outcrops and denser foliage; this was passed to the world artist. The test stage's deliberately plain lighting is for contact diagnostics and should not be used as a promotional game image.
