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
		for frame_index in range(Core.TURNTABLE_FRAME_COUNT):
			var turntable: Texture2D = load(Core.turntable_frame(character, frame_index))
			check(turntable != null and turntable.get_size() == Vector2(1024, 1024), "1024px turntable view %02d for %d" % [frame_index, character])
			if turntable != null:
				var image: Image = turntable.get_image()
				var edge_alpha := [image.get_pixel(0, 0).a, image.get_pixel(1023, 0).a, image.get_pixel(0, 1023).a, image.get_pixel(1023, 1023).a]
				check(edge_alpha.max() <= 0.01, "Turntable view %02d preserves transparent canvas corners for %d" % [frame_index, character])
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
	check(stage._reference_sprites.size() == 8 and stage._turntable_sprite != null and stage._turntable_frames.size() == Core.TURNTABLE_FRAME_COUNT, "Selection presents eight previews and one 16-frame selected-racer turntable")
	for slot in range(8):
		var character: int = menu.DISPLAY_ORDER[slot]
		var sprite: TextureRect = stage._reference_sprites[slot]
		check(sprite.texture.get_size() == Vector2(1024, 1024), "Selection uses the matching full-resolution turntable canvas")
		check(sprite.size == Vector2.ONE * stage.TURNTABLE_DISPLAY_SIZE and sprite.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Every view fits the shared undistorted card box")
		check(sprite.visible and sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "Each card has one clean, visible preview")
		check(is_equal_approx(sprite.position.x + sprite.size.x * 0.5, 89.0 + slot * 174.0), "Racer %d stays centered in its roster slot" % character)
		check(is_equal_approx(sprite.position.y + stage.TURNTABLE_CANVAS_BASELINE * stage.TURNTABLE_DISPLAY_SIZE / 1024.0, stage.TURNTABLE_BASELINE_Y), "Racer %d stays on the shared pack baseline" % character)
		if character == menu.selected_character:
			check(stage._turntable_sprite == sprite and sprite.texture.resource_path == Core.turntable_frame(character, 0), "Selected card is the single frame-swapped preview")
		else:
			check(sprite.texture.resource_path == Core.turntable_frame(character, 0), "Unselected card stays on its front view")
	check(stage._turntable_sprite.texture.resource_path == Core.turntable_frame(menu.selected_character, 0), "Selected preview starts on its front view from the turntable pack")
	var timing_cases := {0.0: 0, 0.374: 0, 0.375: 1, 0.749: 1, 0.75: 2, 1.5: 4, 3.0: 8, 4.5: 12, 5.999: 15, 6.0: 0}
	for seconds: float in timing_cases:
		check(stage._turntable_frame_for_elapsed(seconds) == timing_cases[seconds], "Elapsed-time turntable frame at %.3f seconds" % seconds)
	stage._spin_elapsed = 5.999
	stage.call("_process", 0.002)
	check(stage._turntable_frame_index == 0 and stage._turntable_sprite.texture.resource_path == Core.turntable_frame(menu.selected_character, 0), "Six-second wrap swaps frame 15 directly to the front frame")
	stage._spin_elapsed = 0.374
	stage._set_turntable_frame(0)
	stage.call("_process", 0.002)
	check(stage._turntable_frame_index == 1 and stage._turntable_sprite.texture.resource_path == Core.turntable_frame(menu.selected_character, 1), "Turntable swaps directly when elapsed time crosses 0.375 seconds")
	stage.reduced_motion = true
	stage.call("_process", 0.25)
	check(is_equal_approx(stage._spin_elapsed, 0.0) and stage._turntable_frame_index == 0 and stage._turntable_sprite.texture.resource_path == Core.turntable_frame(menu.selected_character, 0), "Reduced Motion holds view_00 as the static preview")
	stage.reduced_motion = false
	menu.call("_choose_character", 6)
	await process_frame
	var mak_slot: int = menu.DISPLAY_ORDER.find(6)
	check(stage._turntable_character == 6 and stage._reference_sprites[mak_slot].visible and stage._reference_sprites[mak_slot] == stage._turntable_sprite, "Changing selection moves the single turntable to Mak-Doong's card")
	check(stage._turntable_sprite.texture.resource_path == Core.turntable_frame(6, 0) and stage._turntable_frames.size() == Core.TURNTABLE_FRAME_COUNT, "Mak-Doong starts on its own view_00 with all frames loaded")
	check(stage._reference_sprites[menu.DISPLAY_ORDER.find(0)].texture.resource_path == Core.turntable_frame(0, 0), "Previous selection returns to its static view_00 without duplicating a preview")
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
