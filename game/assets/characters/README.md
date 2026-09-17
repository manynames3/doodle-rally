# Character surface assets

`fur_microdetail.png` is grayscale kitten-fur microdetail generated with the built-in `image_gen.imagegen` tool on September 14, 2026. It is sampled beneath the 3D character coat masks; it contains no character identity or colored coat markings. Original output: `exec-80fe1813-3a82-4f00-b30f-4e26890eee5c.png`.

Final prompt:

> Use case: product-mockup. Asset type: seamless grayscale fur microtexture for a high-quality 3D cat racing game's physically shaded kitten models. Generate one square1024x1024 full-bleed seamless tileable macro photograph of extremely dense, fine, short soft cat fur. Neutral MIDGRAY monochrome only, evenly diffuse unlit material capture, mostly small gently curved individual fine hairs flowing approximately vertically downward with slight natural variation, delicate natural overlapping strands with shallow tiny creases. It must read like actual velvety kitten fur at close range, not grass, not fabric, not burlap, not long human hair, no thick ropes or large wavy clumps. Low-to-moderate contrast centered on midgray, no purewhite highlights or black shadows, no directional light, no castshadow, no vignette, no perspective, no animalface/body outline, no background. Uniform density and detail across tile edges so repeated texture shows no border. Intended for luminancealbedomicrovariation and bump sampling underneath black/orange/white photo-matched cat coat masks in Godot; avoid any baked colored markings or features. No text, no labels, no borders.
# Character art

The game keeps the cat drivers as live opaque 3D meshes so their collisions,
lighting, and rear-facing animation remain deterministic. Cats with supplied
asset sheets also have transparent presentation sprites:

- `reference/zizi_stage_frontleft.png` — Zizi's red-kart front-left pose.
- `reference/luna_stage_frontleft.png` — Luna's blue-kart front-left pose.
- `reference/biscuit_stage_frontleft.png` — Biscuit's orange-kart front-left
  pose.
- `reference/mochi_stage_frontleft.png` — Mochi's purple-kart front-left pose.
- `reference/pumpkin_stage_frontleft.png` — Pumpkin's green-kart front-left
  pose.
- `reference/mak_doong_stage_frontleft.png` — Mak-Doong's calico front-left
  pose with her gold halo.
- `reference/nori_stage_frontleft.png` — Nori's yellow-kart front-left pose.

The matching `*_stage_back.png` crops are used by the rear-facing racer lineup
on Track Select (Mak-Doong uses the sheet's back-left pose because her sheet
does not include a straight-back frame).

Matching `*_portrait_default.png` crops are kept beside the stage poses and
are copied into the HUD portrait slots at build time.

Those sprites are used in the character-select lineup and the Garage, where
they match the supplied cinematic references closely. The source sheets remain
outside the repository; these cropped presentation assets are the project-bound
copies.
