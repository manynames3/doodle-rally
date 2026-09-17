# World rendering checkpoint — 1.3 development

Files under review at this checkpoint: `game/scripts/track_world.gd`, `game/scripts/world_meshes.gd`, `[rendering]` settings in `project.godot`, and the generated `game/assets/art/alpine_limestone.png` texture with mipmaps enabled. Exact earlier texture prompts and the new texture's generation brief are in `game/assets/world/world_material_prompts.md`.

## Scenery-only checkpoint measurement

Godot 4.7.2, Forward+ Metal on Apple M1. Actual viewport image: **1280 × 800**. World-only quarry at route distance 80 m, camera offset 7.7 m behind / 3.6 m above, FOV 65°. No other team native preview or regression process running during this measurement.

- 180 measured rendered frames after initial world setup.
- Median: **19.134 ms**.
- 95th percentile: **19.571 ms**.
- Reported draw calls: **395**.
- Final image: `../../../screenshots/1.3/world_quarry.png`.
- Harness: `world_benchmark.gd` in this folder.

The harness fixes `Window.CONTENT_SCALE_MODE_VIEWPORT` and a 1280 × 800 content scale size, disables the automatic RenderingServer render loop, then issues one explicit `force_draw(false)` for each iteration. This measures a world-only rendering loop; it does not establish the full eight-kart game's frame rate. The final source subsequently softened the cached clouds and switched racing from 4× to 2× MSAA. The final, integrated ordinary-renderer measurement is in `render-benchmark-final.log`; this earlier scenery-only checkpoint is historical evidence.

**Discard the intermediate 40–56 ms measurements:** those runs did not reliably preserve viewport dimensions (one saved a 5120 × 2880 image), some overlapped other team work, and automatic/manual drawing could overlap. Initial renderer comparison screenshots remain useful visual evidence, but the final fixed-resolution single-draw harness is the valid performance result.

## Final settings and validation

Forward+ Metal, ACES exposure 0.95, warm sun energy 1.1 with soft shadows, cool ambient 0.28, medium half-resolution SSAO, restrained glow and distance fog. SSIL and volumetric fog are disabled. The cloud shader samples a precomputed FastNoiseLite texture instead of evaluating many noise octaves per pixel. Distant pines use fewer boughs; foreground trees retain cupped textured boughs and three-dimensional needle clusters.

All six course/mode builds passed world validation: zero route seam separation, three upward-facing road/shoulder surfaces, 15 item placements per course and reduced-motion processing disabled correctly. Road surface nodes now have `RacingSurface_*` names so mesh assertions do not mistake new curved waterfall ArrayMeshes for road surfaces. Root also updated the official test suite's corresponding filter.

No route topology or mechanics changed. Native preview processes have exited. Geometry was frozen at this checkpoint; the final cloud and antialiasing adjustments are described above.
