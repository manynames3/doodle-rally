# Character surface assets

`fur_microdetail.png` is grayscale kitten-fur microdetail generated with the built-in `image_gen.imagegen` tool on September 14, 2026. It is sampled beneath the 3D character coat masks; it contains no character identity or colored coat markings. Original output: `exec-80fe1813-3a82-4f00-b30f-4e26890eee5c.png`.

Final prompt:

> Use case: product-mockup. Asset type: seamless grayscale fur microtexture for a high-quality 3D cat racing game's physically shaded kitten models. Generate one square1024x1024 full-bleed seamless tileable macro photograph of extremely dense, fine, short soft cat fur. Neutral MIDGRAY monochrome only, evenly diffuse unlit material capture, mostly small gently curved individual fine hairs flowing approximately vertically downward with slight natural variation, delicate natural overlapping strands with shallow tiny creases. It must read like actual velvety kitten fur at close range, not grass, not fabric, not burlap, not long human hair, no thick ropes or large wavy clumps. Low-to-moderate contrast centered on midgray, no purewhite highlights or black shadows, no directional light, no castshadow, no vignette, no perspective, no animalface/body outline, no background. Uniform density and detail across tile edges so repeated texture shows no border. Intended for luminancealbedomicrovariation and bump sampling underneath black/orange/white photo-matched cat coat masks in Godot; avoid any baked colored markings or features. No text, no labels, no borders.
# Character art

`core/` contains the eight individual character folders and `Shared_VFX` from
the supplied **Cat_Racers_Core_Assets.zip**. PNG bytes are extracted unchanged.
Each racer has `selection/select_sprite.png`, `selection/portrait.png`, and
numbered `animation/idle`, `drive`, `boost`, and `brake` frames. `asset_manifest.json`
records the shared 1280×1024 selection canvas, 640×640 animation canvas, and
normalization metadata. Zizi shares the same 860-pixel cutout height and ground
baseline as the other seven racers.

Godot imports each PNG as a lossless texture with mipmaps, alpha-border repair,
and premultiplied alpha; the per-file `.png.import` files are committed so a
fresh checkout uses the same settings. Open `game/project.godot` in Godot 4.7.2
or run `godot --headless --path game --editor --import --quit` before a command-line
export. No atlas conversion or composite sheet extraction is required.

Character Select uses each complete side-view cutout and a separate portrait.
The HUD uses the same portrait. The Garage plays all four numbered frame
sequences, and layers dust, boost flame, and skid smoke from `Shared_VFX` as
separate sprites. The race camera and collision model remain full 3D; these
side-view frames cannot faithfully replace a rear-view 3D racer. `reference/`
keeps only the eight rear-facing cutouts needed by Track Select.
