extends SceneTree
const Core = preload("res://scripts/cat_core_assets.gd")
const Animator = preload("res://scripts/cat_sprite_animator.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	root.size = Vector2i(1440, 900)
	var heights: Array[int] = []
	for character in range(8):
		var selection: Texture2D = load(Core.selection(character))
		var portrait: Texture2D = load(Core.portrait(character))
		check(selection != null and selection.get_size() == Vector2(1280, 1024), "Normalized selection canvas for %d" % character)
		check(portrait != null and portrait.get_size() == Vector2(1024, 1024), "Portrait canvas for %d" % character)
		var bounds: Rect2i = selection.get_image().get_used_rect()
		heights.append(bounds.size.y)
		check(bounds.position.y == 100 and bounds.end.y == 960, "Shared selection baseline and height for %d" % character)
		for state in ["idle", "drive", "boost", "brake"]:
			for number in range(1, int(Core.FRAME_COUNTS[state]) + 1):
				var frame: Texture2D = load(Core.frame(character, state, number))
				check(frame != null and frame.get_size() == Vector2(640, 640), "%s frame %d for %d" % [state, number, character])
		var player := Animator.new()
		player.character_index = character
		root.add_child(player)
		for state in ["idle", "drive", "boost", "brake"]:
			player.show_state(state)
			check(player.motion_state == state and player.texture.resource_path == Core.frame(character, state, 1), "Ordered %s sequence for %d" % [state, character])
		player.free()
	check(heights.min() == heights.max(), "Zizi and every other racer have the same content height")
	check(Core.motion_state(0, false, false) == "idle" and Core.motion_state(22, false, false) == "drive", "Motion chooses idle and drive")
	check(Core.motion_state(22, true, false) == "brake" and Core.motion_state(22, true, true) == "boost", "Boost and brake have distinct priority")
	for effect in ["dust", "boost_flame", "skid_smoke"]:
		var texture: Texture2D = load(Core.vfx(effect))
		check(texture != null and texture.get_size() == Vector2(640, 640), "Shared %s is a separate effect" % effect)
	var menu = load("res://scripts/menu_ui.gd").new()
	root.add_child(menu)
	menu.selected_mode = "cats"
	menu.show_characters()
	await process_frame
	var stage: Control = menu._lineup
	check(stage._reference_sprites.size() == 8 and stage._portrait_sprites.size() == 8, "Selection presents all eight cutouts and portraits")
	for slot in range(8):
		var character: int = menu.DISPLAY_ORDER[slot]
		var sprite: TextureRect = stage._reference_sprites[slot]
		var portrait: TextureRect = stage._portrait_sprites[slot]
		check(sprite.texture.resource_path == Core.selection(character), "Selection uses the matching core cutout")
		check(portrait.texture.resource_path == Core.portrait(character), "Selection uses the matching portrait")
		check(sprite.size == Vector2(166, 190) and sprite.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Full cutout fits a normalized card")
	menu.selected_character = 0
	menu.call("_show_garage")
	await process_frame
	var preview: Control = menu._stage.find_child("CoreSpriteAnimator", true, false)
	check(preview != null, "Garage plays the core animation frames")
	var garage: Control = preview.get_parent()
	garage.call("_process", 3.2)
	check(preview.get("motion_state") == "boost" and garage.effects.boost_flame.visible, "Boost frames and separate flame effect play together")
	check(not garage.effects.dust.visible and not garage.effects.skid_smoke.visible, "Inactive VFX layers stay hidden")
	garage.call("_process", 1.1)
	check(preview.get("motion_state") == "brake" and garage.effects.skid_smoke.visible, "Brake frames use separate skid smoke")
	garage.reduced_motion = true
	garage.call("_process", 0.1)
	check(preview.get("motion_state") == "idle" and not garage.effects.skid_smoke.visible, "Reduced motion stops the animated effects")
	print("CORE_ASSETS %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
