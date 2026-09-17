# Game-model portraits

The sixteen 128×128 RGBA portraits are native Godot renders of the same final models used by character selection, Garage and racing. Their transparent backgrounds and head framing were checked. They are not replacement illustrations or external character assets.

Rebuild using Godot with the game project and `--script res://scripts/kart_render_portraits.gd`. Run a native renderer rather than headless to produce image pixels. The helper does not load the main scene or saved preferences.

Version 1.3: `cat_0.png` is the user's black-faced tuxedo (white chin); `cat_6.png` is the photo-matched long-haired calico with a golden halo. The calico portrait camera includes the entire halo and leaves a transparent margin above it. These heads use the same opaque materials, distinct coat patterns, and softened shallow eye lenses as the race and Garage.
