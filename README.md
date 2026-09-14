# Doodle Rally — Cat Racers

A standalone Mac 3D kart racer, rebuilt from Doodle Rally's racing direction and original music. The intro follows the supplied Cat Racers title rendering, including the wooden menu and alpine racing scene. The original Doodle Rumble project is separate and was not modified.

## Play

Download **Doodle_Rally_1.1_Mac.zip** from the [v1.1.0 GitHub release](https://github.com/manynames3/doodle-rally/releases/tag/v1.1.0), unzip it, and open **Doodle Rally 1.1.app**. If you already have the local build, double-click **builds/Doodle Rally 1.1.app**. Godot is not required to play. The Universal build contains Apple Silicon and Intel executables. It is signed locally, not Apple-notarized; a copy transferred to another Mac may need **System Settings → Privacy & Security → Open Anyway**.

Choose **Start Game** for cats or **Minecraft Racing** for block characters. Choose a racer, choose a track, then **LET'S RACE!** Hold W or ↑ to accelerate after the countdown. For a gentler start, turn on **Auto-accelerate** in Options.

## What's playable

- Eight cats: the tuxedo player, Luna, Milo, Biscuit, Mochi, Pumpkin, Nori and Shadow. If the tuxedo is an AI rival, it is named Pepper.
- Eight Minecraft-style drivers: Steve, Alex, Creeper, Enderman, Zombie, Skeleton, Pig and Villager. Their models are original procedural geometry, with square heads, pixel faces and angular karts.
- Three scenic courses: **Desktop Dojo**, **Block Quarry**, and **Glitch Core**. Each has its own surface, scenery, lighting and music. They share the core circuit shape with different elevations. Minecraft mode adds block scenery to the alpine course and replaces the drivers on every course.
- Three-lap races against seven AI rivals, three difficulty levels, actual acceleration/braking/steering, kart contact, drift hops, charged mini-turbos, refillable boosts and track boost pads.
- Rotating item boxes provide a flying fish that hits a rival ahead, a yarn ball dropped behind you, catnip turbo or a protective bubble. Bubbles last eight seconds and absorb one hit. Fish range is 125 track metres.
- Live standings, lap and race times, minimap, speedometer, boost gauge, item wheel, results, restart, track selection and a Garage model preview.
- Saved preferences and personal bests separated by course, difficulty and racing mode. Pausing freezes gameplay, timers, item effects and scenery animation. Focus loss and controller disconnection automatically pause an active race.

Version **1.1** fixes cars passing through each other during bump cooldowns. Solid, steering-aware contact now runs every simulation tick, AI steer according to their forward speed, and the chase camera lifts smoothly around close rivals. Rendering interpolates between physics ticks. Kitten proportions, eyes, coats, buggy bodies, printed paw badges, HUD typography and portraits, dust, forest materials and alpine scenery have also been revised toward the references.

This release is single-player. The new game uses a chase camera and fully modeled, stylized 3D drivers and environments. Menu illustrations closely follow the supplied renderings; gameplay now includes textured coats and fine opaque fur details, modeled scenery and textured dirt, limestone, timber and pine branches. It still uses stylized procedural models rather than the cinematic sculpting, fur density and environmental complexity of the reference illustrations. The previous 2D course editor and local multiplayer were not ported into this new racer.

## Controls

| Action | Keyboard | Controller |
| --- | --- | --- |
| Accelerate | W / ↑ | Right trigger |
| Brake | S / ↓ | Left trigger |
| Steer | A D / ← → | Left stick / D-pad |
| Hop and drift | Hold Space while steering | Hold LB / L1 while steering |
| Release drift for mini-turbo | Release Space after charge | Release LB / L1 |
| Spend boost reserve | Shift | RB / R1 |
| Use held item | E | X / Square |
| Recover to road center | R | Y / Triangle |
| Look behind | Hold C | Hold right-stick click |
| Pause / resume | Esc | Start / Options |
| Fullscreen | F11 (or Fn–F11) | — |
| Select menu / go back | Enter / Esc | A / B (Cross / Circle) |

The first drift charge arrives after 0.75 seconds, with a stronger turbo after 1.6 seconds. Boost costs 30 of the 100-point reserve and refills over time. Road barriers keep the kart on the circuit; scraping them slows you down. Steering assistance varies with difficulty. There is no reverse gear; use R if you need to recover.

## Source and rebuilding

Clone the source with `git clone https://github.com/manynames3/doodle-rally.git`, then import **doodle-rally/game/project.godot** into standard **Godot 4.7.2** and press F5. For an existing local source folder, import **game/project.godot** directly. No add-ons, game account, network service or .NET runtime is needed to run the game. The desktop build uses the Compatibility renderer and fixed 60 Hz race simulation. Generated app bundles are distributed through GitHub Releases and are not stored in the source repository.

Install matching Godot export templates, then export the **macOS** preset. Alternatively run `python3 tools/export_mac.py --godot /path/to/Godot.app/Contents/MacOS/Godot`; an optional `--template /path/to/macos.zip` supplies a template directly. The script restores the portable preset when finished and generates the app plus its ZIP.

Preferences live in Godot's separate **Doodle Rally Cat Racers** application-data folder as `rally_3d.cfg`. The app never reads or changes the original game's settings. Automated QA uses isolated preferences. See **BUILD_STATUS.md** for verification and **docs/ASSET_PROVENANCE.md** for source and license details.
