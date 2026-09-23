# Character-selection turntable frames

These PNGs are the individual transparent `view_00.png` through `view_15.png`
files copied from the sibling `Cat_Racers_2D_Turntable_Asset_Pack_1024/sprites/`
folders. They are the pack's 1024×1024 runtime images, copied byte-for-byte.
The source pack, including its 1254×1254 source renders, remains unchanged.

Each racer keeps all 16 supplied RGBA images at their original resolution.
`view_00.png` is the front view; display the remaining views in numeric order.
The selected character advances by elapsed time at one frame every 0.375 seconds
(a six-second, 16-step 2D rotation). Other cards hold `view_00.png`. Reduced
Motion also holds `view_00.png`. These are approximate sprite viewpoints, not a
continuous 3D model.

No offline image conversion is required. The adjacent `.import` metadata keeps
the source PNGs at 1024×1024 and enables mipmaps, alpha-border repair, and
premultiplied alpha for clean downscaling over the dark roster cards and the
lighter garage background. To regenerate Godot's import cache after refreshing
the individual PNGs, run:

```sh
godot --headless --path game --editor --import
```

The atlas files are intentionally omitted so the game can swap full-resolution
frames directly without slicing or changing their transparent canvases. Do not
resize these runtime PNGs to the old 512px preview resolution.
