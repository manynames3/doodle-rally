# Menu artwork and provenance

The game renders all buttons, labels, selection states, statistics, and controller prompts as real Godot UI. Character and Garage previews render the same 3D geometry used during races. These background illustrations are not screenshots of gameplay.

Raster assets were produced using the built-in `image_gen.imagegen` tool on September 13–14, 2026. No CLI or external API key was used. Generated originals are retained in the creator's local image-generation archive; the project uses the copies in this directory. `ui_slider_knob.svg` is a small native vector UI asset drawn in code, not generated.

The user's five Cat Racers renderings provided the visual direction. `title_race_v2.png` specifically edits the user's title reference, `ChatGPT Image Sep 13, 2026, 05_25_20 PM.png`, into clean background-only artwork, preserving its racing composition while replacing the overlaid interface with real controls. Other images were generated from the written scene specifications below. The original repository's Kalam-Bold font provides native chalk-style lettering; see `../fonts/`.

## Final asset prompts

### `title_race_v2.png` — title background used in version 1.1, retained as the edit source

Original generation filename: `exec-f0271b29-fda8-4c1f-a84b-60d1bb569671.png`. Reference image: the user's September 13, 2026, 05_25_20 PM rendering.

> Use case: precise-object-edit. Asset type: clean title-screen background for a real native cat racing game, widescreen. Edit target: the supplied game title-screen rendering. Keep the exciting racing scene, central-right tuxedo cat with green eyes in red paw-logo kart, all other racing cats, bright alpine waterfall landscape, mountain tunnel and bridges, camera angle, glossy highly detailed 3D art style, and overall warm color/light exactly as close to the original as possible. Remove ALL user interface overlays: large CAT RACERS title sign at upper left and subtitle sign, every menu button along the left, every UI word and letter, all bottom button prompts, bottom-right paper note, Ready Set Meow text. Fill those vacated areas naturally with softly defocused deep green pine foliage and matching landscape. Also remove text on any small distant environmental banner. Keep road racing action on right and lower center. Leave a quiet open area across left third for separately rendered real wooden game menu buttons. Do not add text, words, titles, logos, buttons, cards, panels or interface graphics. Simple white paw emblems on karts may remain. This output will be consumed as background-only art; every control and title is drawn by the actual game.

### `clubhouse.png` — character, track, Garage, and Options background

Original generation filename: `exec-bc9ddc63-5565-4445-86d8-a60e6cd3bf6a.png`.

> Use case: stylized-concept. Asset type: background artwork for actual 3D cat racing game character and course selection menu, wide 16:10 frame. Cozy alpine racing clubhouse interior, warm wooden beams, big windows opening onto blue sky, pine trees and mountains, golden afternoon lighting, soft dust motes, open dark slate chalkboard hanging across upper center with only tiny simple white chalk paw drawings in corners, shelves at sides with tiny toy go-karts, trophy and stacked sketchbooks, pencil cups, racing helmet, cozy desk objects, bunting. Empty broad wooden workbench surface occupies the bottom third with perspective vanishing into middle center. Whimsical animated-feature 3D art direction, beautifully detailed tactile wood grain, amber and teal palette, softly defocused environment so real UI and 3D character previews can be overlaid. Composition straight-on looking at workbench, large calm open middle area for game cards, no cats or racers on workbench. Constraints: no text, no letters, no logos, no UI, no borders, no menu cards, no buttons. This is environment art to use behind real game controls, not a UI mockup.

### `course_dojo.png` — Desktop Dojo postcard

Original generation filename: `exec-321a8368-8b28-409a-af1f-27615b6cf38a.png`.

> Use case: stylized-concept. Asset type: artwork for a real game track selection card. Portrait 4:5 course postcard artwork, polished whimsical animated feature 3D rendering, close overhead view of a tiny toy cat kart racing circuit built on a sunlit wooden artist's desk. Wide cream paper road looping and rising around colorful towering books and sticky note ramps, chunky pencils and crayons form roadside barriers, huge white mug with simple paw emblem, a miniature checkered start banner between wooden posts, pink eraser and blue ruler bridge, a notebook with cat doodles, warm blue and amber light, densely charming tactile materials. Racing circuit clearly continuous, no UI, no words or letters, no title, no cards, no borders, no menu controls, no watermark. Asset for Desktop Dojo track selection, no cats necessary.

### `course_quarry.png` — Block Quarry postcard

Original generation filename: `exec-633df1ee-3b83-45a5-b99f-b30a3d6b2247.png`.

> Use case: stylized-concept. Asset type: artwork for a real game track selection card. Portrait 4:5 course postcard artwork, polished whimsical animated feature 3D rendering. An exciting tiny cat kart mountain racing circuit of wide golden dirt paths and wooden trestle bridges, winding around dramatic alpine gray cliffs, turquoise lake, multiple white waterfalls, rich pine forests and pink flowering trees. Cute cat-ear shaped tunnel facade carved into rock by one stretch, festive orange flags, snowy distant blue mountains beneath sunny sky. A readable elevated sweeping view of the course from above, detailed bright landscape with depth, colorful and inviting. No UI, no words or letters, no title, no cards, no borders, no menu controls, no watermark. Asset for Block Quarry track selection.

### `course_glitch.png` — Glitch Core postcard

Original generation filename: `exec-a1b19419-e2a5-4df1-babc-fbedafcdfaa1.png`.

> Use case: stylized-concept. Asset type: artwork for a real game track selection card. Portrait 4:5 course postcard artwork, polished whimsical animated feature 3D rendering. An exciting floating futuristic toy kart racing circuit built from giant dark computer circuit boards and server towers. The continuous broad dark asphalt racetrack snakes through the frame above a glowing cyan digital abyss, luminous magenta and turquoise track edges, bridge jump ramps, neon direction chevrons, tiny friendly simple pixel cat face on a central hologram. Beautiful dramatic violet night atmosphere, shimmering digital particles and electric blue lighting, eye-catching vibrant neon course vista. No UI, no words or letters, no title, no cards, no borders, no menu controls, no watermark. Asset for Glitch Core track selection.

### `wood_sign.png` — reusable transparent wooden sign texture

Original generation filename: `exec-3fec2032-ec32-4abf-9569-1b93e177a976.png`. The transparent alpha channel is preserved.

> Use case: stylized-concept. Asset type: reusable wooden sign texture sprite for a premium cute 3D cat kart game, landscape 4:1 proportions, actual transparent background with alpha. Single empty rustic wooden plank sign made from three tightly joined horizontal honey-gold wooden slats, straight-on orthographic front view. Beautiful tactile realistic 3D cartoon sculpted wood with knots, carved fibers, worn darkened edges and tiny nicks, subtle nail heads near corners, warm honey brown varnished wood lit evenly from top-left. Broad completely empty central face for real UI text to overlay. Rounded slightly irregular outer corners. Occupies almost full image with a tiny transparent margin. No words, text, symbols, logos, paw marks, illustration, characters, ropes or background. No drop shadow beyond a subtle narrow rim shadow. Only one empty horizontal wooden sign on genuinely transparent background, not on a colored or checkered field.

### `title_race.png` — alternate intro concept, retained but not used by the game

Original generation filename: `exec-266c49ba-2eb1-4aea-baaf-5fa93fdb9a87.png`.

> Use case: stylized-concept. Asset type: widescreen background artwork for a real playable cute 3D cat kart racing game intro menu, 16:10 aspect ratio, high quality polished animated-feature 3D rendering. Primary request: an exciting joyful cat race in a sunlit alpine woodland gorge, tiny cute cats in glossy colorful paw-branded go-karts, waterfall cliffs, wooden track bridges, distant snowy blue mountains and pine trees, little pennant flags. Main subject: adorable black and white tuxedo cat, enormous expressive yellow eyes, front three-quarter view, driving a shiny red racing kart with white paw emblem, drifting toward viewer in the RIGHT HALF of the picture, with orange cat in orange kart and white cat in pink kart racing behind at far right. Sweeping golden dirt road entering from lower right and curving into waterfall landscape, blue boost trails and soft flying leaves convey energy. Composition: spacious cinematic wide view, entire LEFT THIRD mostly airy deep teal pine-tree shade with low visual complexity, as negative space for overlay title and real menu buttons. Cats and vehicles richly sculpted, soft fluffy fur, rounded toy proportions, warm sunset lighting and blue sky, adventurous wholesome mood, strong depth of field. Constraints: do not render any title, text, menus, UI, buttons, signs with writing, borders, watermark or logos except simple white paw symbols on karts. This is finished game background art, not a UI mockup.

## Photo-matched character update — September 14, 2026

### `title_race_v3.png` — active title background in versions 1.2 and 1.3

Built-in `image_gen.imagegen` edit; original generation filename `exec-bd467132-177b-45ff-9268-3189f5a6bc4d.png`. The edit target was `title_race_v2.png`. Four user-supplied photo references guided identity: tuxedo IMG_7399 / IMG_2055 and calico IMG_7888 / IMG_1698. All seven supplied cat photographs were inspected for the playable models. Personal source photos remain outside the distributable project; this file contains only the generated game artwork. `title_race_v2.png` is retained as historical artwork and is no longer loaded.

Final prompt:

> Use case: identity-preserve. Asset type: actual game intro background, cinematic wide 16:9 animated-feature 3D cat kart racing artwork. Image1 is the EDIT TARGET. Images2-3 are identity references for the main tuxedo cat. Images4-5 are identity references for a second calico cat. Preserve Image1's exact composition, camera, alpine mountain waterfall scenery, sunlit lighting, rich fur quality, glossy karts, and left third quiet background reserved for real UI. Make only these character edits: (1) Match the large central main cat in the RED kart to the real tuxedo in images2-3: ALL face fur is jet black including cheeks, upper muzzle, nose bridge and forehead, black nose; no white blaze whatsoever, no pink nose. White only on the small chin BELOW the mouth, chest bib, and all paws. Rest of body, ears and tail black. Long white whiskers, warm yellow-green eyes. Keep cheerful expression and existing dynamic pose, size and red kart. (2) Replace only the distant rightmost gray cat in blue kart with the photo calico in a golden YELLOW kart with the same white paw emblem, same existing size/position. Match calico's fluffy long-haired black, burnt-orange and ivory-white coat and asymmetrical face: from viewer front, left forehead black, right forehead broad irregular orange patch, narrow white nose blaze, orange moustache around pink-brown nose, distinctive black chin beneath muzzle, white broad fluffy chest bib/paws, irregular orange patches over black body, olive-green eyes. Give calico a clearly visible delicate luminous GOLD HALO RING floating horizontally above ears, separate from head, not a crown. Preserve the other white/pink, Siamese/purple and orange/orange racers unchanged. No added text, no letters, no UI, no buttons, no logos except existing white paw emblems. Do not add a white stripe, white cheeks or white upper muzzle to main tuxedo. Keep its face BLACK with only WHITE CHIN underneath. Match reference coat identities as closely as possible within the existing high-quality stylized 3D artwork.

The native SVG app icon was edited directly to carry the main tuxedo's black face and nose, small white chin and yellow-green eyes. HUD portraits are Godot renders of the playable models rather than generated paintings.
