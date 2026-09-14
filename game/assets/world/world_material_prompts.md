# World material assets

Generated with the built-in imagegen tool on September 13, 2026. These original assets are applied to actual three-dimensional geometry. All four textures use mipmaps; pine.png contains a genuine alpha channel.

- `ground.png`: 2048-square requested; generated 1254 × 1254. Fine tan compacted dirt and restrained tire impressions.
- `rock.png`: 2048-square requested; generated 1254 × 1254. Weathered fractured limestone/granite, applied in world-space triplanar coordinates.
- `wood.png`: 2048-square requested; generated 1254 × 1254. Timber grain for posts, rails and individual bridge planks.
- `pine.png`: 2048-square requested; generated 1254 × 1254. Transparent fir bough repeated as spatial branches around real trunks. Shadow proxy geometry keeps foliage economical.

## Final generation prompts

### ground.png

Use case: photorealistic-natural. Asset type: seamless tileable albedo texture for the actual drivable terrain of a 3D kart racing game. Create one square 2048x2048 orthographic, perfectly top-down texture of compacted dry tan sandy earth: warm light ochre-beige dirt, very fine gritty sand, faint lengthwise tire impressions running vertically, tiny embedded grey and cream pebbles sparsely scattered, a little variation from worn travel. Natural believable surface detail with restrained contrast. The average color should be muted tan approximately #B99A70, NOT orange or yellow. Diffuse flat neutral lighting, no cast shadows or directional lighting, no perspective, no borders, no text, no objects. All four edges must seamlessly tile.

### rock.png

Use case: photorealistic-natural. Asset type: seamless tileable albedo texture for rocky cliffs in a lush alpine 3D kart racing game. One square 2048x2048 orthographic facing texture of weathered warm grey limestone/granite, interlocking irregular fractured stone faces with convincing fine grain, mineral flecks, restrained cracks and soft striations. Small traces of olive moss in a few cracks, no large green areas. Average muted grey-brown approximately #898578, believable compact rough rock. Diffuse flat neutral illumination, no baked directional lighting or strong cast shadows, no perspective, no landscape, no text, no border, no objects. All four edges seamlessly tile. Highly detailed natural game material with subtle stylized animation-film softness.

### wood.png

Use case: photorealistic-natural. Asset type: seamless tileable albedo texture for honey-brown timber posts, rails and bridge decking in a 3D woodland racing game. One square 2048x2048 orthographic view of weathered clean golden brown timber grain running vertically: long fine darker fibers, gentle knots, subtle scuffs, natural warm cedar/oak. Average muted medium brown approximately #916336. No separation into boards, no nails, no objects. Diffuse flat neutral lighting, no directional shadows, no shine, no border or text. All four edges must seamlessly tile.

### pine.png

Use case: photorealistic-natural. Asset type: transparent foliage cutout texture for layered 3D pine branches in a racing game. One square 2048x2048 image with genuinely transparent background, no floor or backdrop. A single full alpine fir branch spray, spread horizontally across the frame, realistic delicate deep-green needles and many branchlets, dense but with natural transparent gaps between needles. Brown central branch from bottom center to upper center, six to eight smaller feathered boughs extending left and right. Rich pine green with subtle lighter tips, neutral diffuse light, avoid yellow or neon green. View directly from above, isolated with every needle edge visible, generous transparent padding, no text, no frame, no scenery, no shadow. High quality natural foliage suitable for real-time alpha-tested 3D vegetation.
