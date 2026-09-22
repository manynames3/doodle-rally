extends Node
const Sim = preload("res://scripts/race_sim.gd")
const Hud = preload("res://scripts/race_hud.gd")
const Objects = preload("res://scripts/race_objects.gd")
const Prefs = preload("res://scripts/preferences.gd")
const Sound = preload("res://scripts/rally_sound.gd")
const Data = preload("res://scripts/rally_data.gd")
const Splash = preload("res://scripts/startup_splash.gd")
const FONT = preload("res://assets/fonts/Kalam-Bold.ttf")

var state := "menu"
var previous_state := "racing"
var preferences := Prefs.new()
var sound: Node
var menu: Control
var ui_layer: CanvasLayer
var hud: Control
var overlay: Control
var race_root: Node3D
var world: Node3D
var camera: Camera3D
var objects: Node3D
var karts: Array[Node3D] = []
var sim: RefCounted
var countdown := 3.0
var character := 0
var course := 1
var racer_mode := "cats"
var controller := -1
var _last_count := 4
var _qa := false
var _qa_driver := false
var _qa_drive_elapsed := 0.0
var _qa_frame_times: Array[float] = []
var _last_camera := Vector3.ZERO
var _last_camera_aim := Vector3.ZERO
var _graphics_window_size := Vector2i.ZERO
var startup_splash: CanvasLayer

func _ready() -> void:
	get_window().title = "Doodle Rally — Cat Racers · 1.3.1"
	_qa = "--qa" in OS.get_cmdline_user_args()
	preferences.enabled = not _qa
	preferences.load_data()
	_setup_input()
	Input.joy_connection_changed.connect(_controller_changed)
	var devices := Input.get_connected_joypads()
	if not devices.is_empty(): controller = devices[0]
	sound = Sound.new()
	add_child(sound)
	sound.set_mix(float(preferences.values.master_volume), float(preferences.values.music_volume))
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	menu = load("res://scripts/menu_ui.gd").new()
	ui_layer.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.set_preferences(preferences.values.duplicate())
	menu.selected_character = preferences.selected_character
	menu.selected_course = preferences.selected_course
	menu.selected_mode = preferences.selected_mode
	menu.start_race.connect(_start_race)
	menu.quit_requested.connect(func(): get_tree().quit())
	menu.settings_changed.connect(_settings_changed)
	if _qa and _arg("--qa-screen") not in ["splash", "startup"]:
		_begin_title()
	else:
		_show_startup()
	if _qa: call_deferred("_qa_run")

func _show_startup() -> void:
	state = "splash"
	menu.hide()
	startup_splash = Splash.new()
	startup_splash.finished.connect(_begin_title)
	add_child(startup_splash)

func _begin_title() -> void:
	startup_splash = null
	state = "menu"
	menu.show()
	menu.show_title()
	sound.play_theme(1)

func _setup_input() -> void:
	for action in ["r_left", "r_right", "r_gas", "r_brake", "r_drift", "r_boost", "r_item", "r_reset", "r_pause", "r_look"]:
		if not InputMap.has_action(action): InputMap.add_action(action, .18)
	var mappings := {"r_left": [KEY_A, KEY_LEFT], "r_right": [KEY_D, KEY_RIGHT], "r_gas": [KEY_W, KEY_UP], "r_brake": [KEY_S, KEY_DOWN], "r_drift": [KEY_SPACE], "r_boost": [KEY_SHIFT], "r_item": [KEY_E], "r_reset": [KEY_R], "r_pause": [KEY_ESCAPE], "r_look": [KEY_C]}
	for action in mappings:
		for code in mappings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)
	var buttons := {"r_drift": JOY_BUTTON_LEFT_SHOULDER, "r_boost": JOY_BUTTON_RIGHT_SHOULDER, "r_item": JOY_BUTTON_X, "r_pause": JOY_BUTTON_START, "r_reset": JOY_BUTTON_Y, "r_look": JOY_BUTTON_RIGHT_STICK}
	for action in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = buttons[action]
		InputMap.action_add_event(action, event)
	# MenuUI installs shared D-pad, stick and south/east bindings for native UI controls.

func _input(event: InputEvent) -> void:
	if state == "splash":
		if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed):
			startup_splash.skip()
		# Consume releases too: the skip button must never activate the title menu.
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		controller = event.device
		if hud: hud.using_controller = true
	elif event is InputEventKey:
		if hud: hud.using_controller = false
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("r_pause"):
		if state in ["racing", "countdown"]:
			_pause()
			get_viewport().set_input_as_handled()
		elif state == "paused":
			_resume()
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not _qa and state in ["racing", "countdown"]:
		_pause("Race paused while the window is in the background.")

func _controller_changed(device: int, connected: bool) -> void:
	if connected and controller < 0: controller = device
	if not connected and device == controller:
		controller = -1
		if state in ["racing", "countdown"]: _pause("Controller disconnected. Reconnect it or use the keyboard.")

func _settings_changed(values: Dictionary) -> void:
	for key in values:
		if preferences.values.has(key): preferences.values[key] = values[key]
	sound.set_mix(float(preferences.values.master_volume), float(preferences.values.music_volume))
	preferences.save_data()

func _start_race(chosen_character: int, chosen_course: int) -> void:
	if state == "loading": return
	state = "loading"
	character = clampi(chosen_character, 0, 7)
	course = clampi(chosen_course, 0, 2)
	racer_mode = "minecraft" if menu.selected_mode == "minecraft" else "cats"
	preferences.selected_character = character
	preferences.selected_course = course
	preferences.selected_mode = racer_mode
	preferences.save_data()
	menu.hide()
	_clear_overlay()
	_show_loading()
	await get_tree().process_frame
	await get_tree().process_frame
	_clear_race()
	race_root = Node3D.new()
	race_root.name = "Race"
	add_child(race_root)
	world = load("res://scripts/track_world.gd").new()
	race_root.add_child(world)
	world.build(course, racer_mode)
	_apply_race_graphics()
	world.set_animations_enabled(not bool(preferences.values.reduced_motion))
	sim = Sim.new()
	sim.setup(world, character, int(preferences.values.difficulty), racer_mode)
	for r in sim.racers:
		var kart: Node3D = load("res://scripts/kart_visual.gd").new()
		race_root.add_child(kart)
		kart.build(int(r.character), racer_mode)
		karts.append(kart)
	objects = Objects.new()
	race_root.add_child(objects)
	objects.build(world, sim)
	camera = Camera3D.new()
	camera.near = .25
	camera.far = 1600
	camera.fov = 64
	race_root.add_child(camera)
	camera.make_current()
	_update_karts(0)
	_update_camera(1, true)
	hud = Hud.new()
	ui_layer.add_child(hud)
	hud.configure(sim, world, course, preferences.best(course, int(preferences.values.difficulty), racer_mode))
	hud.pause_requested.connect(_pause)
	hud.using_controller = controller >= 0
	hud.reduced_motion = bool(preferences.values.reduced_motion)
	countdown = 3.25
	_last_count = 4
	hud.countdown = countdown
	sound.play_theme(course)
	await get_tree().process_frame
	_clear_overlay()
	state = "countdown"

func _apply_race_graphics() -> void:
	var quality: int = clampi(int(preferences.values.graphics_quality), 0, 2)
	var viewport := get_viewport()
	_graphics_window_size = get_window().size
	if quality == 2:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = 1.0
	else:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		viewport.scaling_3d_scale = _race_render_scale(float(_graphics_window_size.x), quality)
	for environment_node in world.find_children("*", "WorldEnvironment", true, false):
		var scene_environment := environment_node as WorldEnvironment
		scene_environment.environment.ssao_enabled = quality > 0
	for light_node in world.find_children("*", "DirectionalLight3D", true, false):
		var light := light_node as DirectionalLight3D
		if light.shadow_enabled:
			light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if quality == 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS

func _race_render_scale(window_width: float, quality: int) -> float:
	var base_scale := (0.75 if course == 1 else 0.85) if quality == 0 else 0.90
	var minimum_scale := 0.50 if quality == 0 else 0.65
	return clampf(base_scale * sqrt(1280.0 / maxf(1280.0, window_width)), minimum_scale, base_scale)

func _physics_process(dt: float) -> void:
	if state == "countdown":
		countdown -= dt
		var value := int(ceilf(countdown))
		if value != _last_count:
			_last_count = value
			if value <= 3: sound.event("countdown" if value > 0 else "go")
		if countdown <= 0: state = "racing"
	elif state == "racing":
		countdown = maxf(-2, countdown - dt)
		sim.tick(dt, _controls())
		for event in sim.drain_events():
			var kind := str(event.kind)
			if kind == "projectile": objects.launch_fish(int(event.from), int(event.to))
			if event.has("text") and kind != "finish": hud.announce(str(event.text))
			sound.event(kind)
			if controller >= 0 and not bool(preferences.values.reduced_motion) and kind in ["hit", "wall", "boost", "drift"] and not _qa:
				Input.start_joy_vibration(controller, .18, .32, .13)
		if sim.finished: _show_results()
	if state in ["racing", "countdown"]:
		objects.update_visuals(dt, bool(preferences.values.reduced_motion))
		hud.countdown = countdown
		sound.update_engine(float(sim.racers[0].speed), true)

func _process(dt: float) -> void:
	if state in ["racing", "countdown"]:
		if get_window().size != _graphics_window_size:
			_apply_race_graphics()
		if _qa_driver:
			_qa_drive_elapsed += dt
			if _qa_drive_elapsed > 2.0: _qa_frame_times.append(dt * 1000.0)
		_update_karts(dt, clampf(Engine.get_physics_interpolation_fraction(), 0, 1))
		_update_camera(dt)

func _controls() -> Dictionary:
	var steer := Input.get_axis("r_left", "r_right")
	var throttle := Input.get_action_strength("r_gas")
	var brake := Input.get_action_strength("r_brake")
	if controller >= 0:
		var axis := Input.get_joy_axis(controller, JOY_AXIS_LEFT_X)
		if absf(axis) > .16: steer = axis
		if Input.is_joy_button_pressed(controller, JOY_BUTTON_DPAD_LEFT): steer = -1
		if Input.is_joy_button_pressed(controller, JOY_BUTTON_DPAD_RIGHT): steer = 1
		throttle = maxf(throttle, Input.get_joy_axis(controller, JOY_AXIS_TRIGGER_RIGHT))
		brake = maxf(brake, Input.get_joy_axis(controller, JOY_AXIS_TRIGGER_LEFT))
	if bool(preferences.values.auto_accelerate): throttle = 1.0
	if _qa_driver:
		var r: Dictionary = sim.racers[0]
		steer = clampf(-float(r.lane) * .3 - float(r.angle) * 2.0, -1, 1)
		throttle = 1
	return {"steer": steer, "throttle": throttle, "brake": brake, "drift": Input.is_action_pressed("r_drift"), "boost": Input.is_action_just_pressed("r_boost"), "item": Input.is_action_just_pressed("r_item"), "reset": Input.is_action_just_pressed("r_reset")}

func _update_karts(dt: float, interpolation: float = 1.0) -> void:
	for i in range(karts.size()):
		var r: Dictionary = sim.racers[i]
		var distance := lerpf(float(r.get("previous_distance", r.distance)), float(r.distance), interpolation)
		var lane := lerpf(float(r.get("previous_lane", r.lane)), float(r.lane), interpolation)
		var hop := lerpf(float(r.get("previous_hop", r.hop)), float(r.hop), interpolation)
		var angle := lerp_angle(float(r.get("previous_angle", r.angle)), float(r.angle), interpolation)
		var base: Basis = world.frame(distance)
		base = base.rotated(Vector3.UP, -angle)
		karts[i].transform = Transform3D(base, world.sample(distance, lane) + Vector3.UP * hop)
		var drift := float(r.drift) if bool(r.drifting) else 0.0
		karts[i].animate(dt, float(r.speed), float(r.steer), drift, float(r.turbo) > 0)
		if is_instance_valid(objects) and i < objects.shields.size():
			objects.shields[i].position = karts[i].global_position + Vector3.UP * 1.7
		# Hits slow the physical kart; do not add a render-only yaw that swings
		# its wheels through another car outside the simulation contact hull.

func _update_camera(dt: float, snap: bool = false) -> void:
	if sim == null or camera == null: return
	var r: Dictionary = sim.racers[0]
	var point: Vector3 = karts[0].global_position if not karts.is_empty() else r.position
	# Match the camera's tangent to the same interpolated distance used by the
	# kart transforms. This removes a one-physics-tick yaw step at render rates
	# that are not an exact multiple of the 60 Hz simulation.
	var interpolation := clampf(Engine.get_physics_interpolation_fraction(), 0, 1)
	var render_distance := lerpf(float(r.get("previous_distance", r.distance)), float(r.distance), interpolation)
	var direction: Vector3 = world.tangent(render_distance + 5)
	var behind: Vector3 = world.tangent(render_distance - 5)
	var looking_back := Input.is_action_pressed("r_look") and state == "racing"
	var distance := 7.7
	var height := 3.6
	if looking_back:
		behind = -direction
		direction = -direction
	# Lift early as a rival approaches the chase corridor, keeping every racer opaque.
	# Broad influence starts well before the near plane could intersect a kart.
	var corridor_center := point - behind * 6.4
	for i in range(1, karts.size()):
		var relative := karts[i].global_position - corridor_center
		var planar_distance := Vector2(relative.x, relative.z).length()
		var influence := 1.0 - smoothstep(3.0, 9.0, planar_distance)
		height = maxf(height, 3.6 + 2.1 * influence)
	var desired := point - behind * distance + Vector3.UP * height
	var desired_aim := point + direction * 15 + Vector3.UP * 3.3
	if snap: camera.position = desired
	else:
		camera.position += point - _last_camera
		camera.position = camera.position.lerp(desired, 1 - exp(-dt * 8.5))
	_last_camera = point
	# Last-resort near-plane clearance after smoothing. The early lift normally
	# clears this guard already, without a sudden zoom or a camera cut.
	for i in range(1, karts.size()):
		var relative := camera.position - karts[i].global_position
		if Vector2(relative.x, relative.z).length() < 2.9:
			camera.position.y = maxf(camera.position.y, karts[i].global_position.y + 4.65)
	if snap or _last_camera_aim == Vector3.ZERO:
		_last_camera_aim = desired_aim
	else:
		_last_camera_aim = _last_camera_aim.lerp(desired_aim, 1.0 - exp(-dt * 10.0))
	camera.look_at(_last_camera_aim, Vector3.UP)
	var desired_fov := 69.0 if float(r.turbo) > 0 and not bool(preferences.values.reduced_motion) else 64.0
	camera.fov = lerpf(camera.fov, desired_fov, minf(1, dt * 4))

func _pause(reason: String = "") -> void:
	if state not in ["racing", "countdown"]: return
	previous_state = state
	state = "paused"
	world.set_animations_enabled(false)
	sound.update_engine(0, true, true)
	var box := _overlay_box("TAKE A PIT STOP", "Your race is right here when you're ready." if reason.is_empty() else reason)
	_add_button(box, "Resume race", _resume, true)
	_add_button(box, "Restart race", func(): _start_race(character, course))
	_add_button(box, "Choose track", _back_to_tracks)
	_add_button(box, "Intro menu", _back_to_title)
	_add_label(box, "WASD / arrows · drive     Space · drift     Shift · boost\nE · item     S / ↓ · brake     C · look back     R · recover", 19, Color("d8dac8"))

func _resume() -> void:
	if state != "paused": return
	_clear_overlay()
	state = previous_state
	world.set_animations_enabled(not bool(preferences.values.reduced_motion))
	sound.update_engine(float(sim.racers[0].speed), true, false)
	if hud: hud.pause_button.release_focus()

func _show_results() -> void:
	state = "results"
	sound.update_engine(0, false)
	var seconds := float(sim.racers[0].finish_time)
	var record := preferences.record(course, int(preferences.values.difficulty), seconds, racer_mode)
	var rank: int = sim.player_place()
	var title_text := "PAWS ON THE PODIUM!" if rank <= 3 else "WHAT A RIDE!"
	if racer_mode == "minecraft": title_text = "A BLOCKBUSTER FINISH!" if rank <= 3 else "NICE RACING, BUILDER!"
	var subtitle := "%s  ·  %s  ·  %s" % [Data.COURSES[course], Data.ordinal(rank).to_upper(), Data.time_string(seconds)]
	var box := _overlay_box(title_text, subtitle, 760)
	if record: _add_label(box, "NEW PERSONAL BEST", 28, Color("ffdc64"))
	var results := GridContainer.new()
	results.columns = 3
	results.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	results.add_theme_constant_override("h_separation", 36)
	results.add_theme_constant_override("v_separation", 1)
	box.add_child(results)
	for i in range(8):
		var id: int = sim.standings()[i]
		var r: Dictionary = sim.racers[id]
		var color := Color("ffdf66") if id == 0 else Color("eee9dc")
		_add_label(results, "%02d" % [i + 1], 22, color)
		var name_text: String = Data.BLOCK_NAMES[int(r.character)] if racer_mode == "minecraft" else Data.NAMES[int(r.character)]
		if id == 0: name_text = "You · " + name_text
		_add_label(results, name_text, 22, color)
		_add_label(results, Data.time_string(float(r.finish_time)) if float(r.finish_time) >= 0 else "On track", 22, color)
	_add_button(box, "Race again", func(): _start_race(character, course), true)
	_add_button(box, "Choose track", _back_to_tracks)
	_add_button(box, "Intro menu", _back_to_title)

func _back_to_tracks() -> void:
	_clear_overlay()
	_clear_race()
	state = "menu"
	menu.show()
	menu.show_tracks()
	sound.play_theme(1)

func _back_to_title() -> void:
	_clear_overlay()
	_clear_race()
	state = "menu"
	menu.show()
	menu.show_title()
	sound.play_theme(1)

func _clear_race() -> void:
	_graphics_window_size = Vector2i.ZERO
	get_viewport().scaling_3d_scale = 1.0
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	sound.update_engine(0, false)
	if is_instance_valid(hud):
		hud.get_parent().remove_child(hud)
		hud.queue_free()
	hud = null
	if is_instance_valid(race_root):
		remove_child(race_root)
		race_root.queue_free()
	race_root = null
	world = null
	camera = null
	_last_camera = Vector3.ZERO
	_last_camera_aim = Vector3.ZERO
	karts.clear()
	sim = null

func _clear_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.get_parent().remove_child(overlay)
		overlay.queue_free()
	overlay = null

func _show_loading() -> void:
	_overlay_box("WARMING UP THE KARTS…", "%s  ·  %s" % [Data.COURSES[course], "Minecraft Racing" if racer_mode == "minecraft" else "Cat Racers"], 630)

func _overlay_box(title_text: String, subtitle: String, width: float = 660) -> VBoxContainer:
	_clear_overlay()
	overlay = Control.new()
	ui_layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(.016, .025, .04, .74)
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	center.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("212a2d")
	style.border_color = Color("ae8050")
	style.set_border_width_all(5)
	style.set_corner_radius_all(22)
	style.content_margin_left = 35
	style.content_margin_right = 35
	style.content_margin_top = 26
	style.content_margin_bottom = 24
	style.shadow_color = Color(0, 0, 0, .35)
	style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)
	_add_label(box, title_text, 38, Color("ffdc67"))
	_add_label(box, subtitle, 21, Color("efe6cf"))
	return box

func _add_label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _add_button(parent: Control, text: String, action: Callable, selected: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 49
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 25)
	for key in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("edbc55") if key != "normal" or selected else Color("554338")
		style.border_color = Color("fff0b4") if key != "normal" else Color("a37950")
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		button.add_theme_stylebox_override(key, style)
	button.add_theme_color_override("font_color", Color("29232b") if selected else Color("fff4d8"))
	button.add_theme_color_override("font_hover_color", Color("29232b"))
	button.add_theme_color_override("font_focus_color", Color("29232b"))
	button.pressed.connect(action)
	parent.add_child(button)
	if selected:
		(func():
			if is_instance_valid(button) and button.is_inside_tree(): button.grab_focus()).call_deferred()
	return button

func _arg(name: String, fallback: String = "") -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(name + "="): return arg.substr(name.length() + 1)
	return fallback

func _qa_run() -> void:
	var screen := _arg("--qa-screen", "title")
	if screen == "startup":
		while state == "splash": await get_tree().process_frame
	menu.selected_mode = _arg("--qa-mode", "cats")
	menu.selected_course = int(_arg("--qa-course", "1"))
	menu.selected_character = clampi(int(_arg("--qa-character", "0")), 0, 7)
	if screen == "splash":
		startup_splash.set_process(false)
		startup_splash._process(.8)
	elif screen == "characters": menu.show_characters()
	elif screen == "tracks": menu.show_tracks()
	elif screen == "settings": menu.show_settings()
	elif screen == "garage": menu._show_garage()
	elif screen in ["race", "pause", "results", "drive"]:
		await _start_race(menu.selected_character, menu.selected_course)
		countdown = -2
		state = "racing"
		var distance := float(_arg("--qa-distance", "65"))
		for i in range(8):
			var r: Dictionary = sim.racers[i]
			r.distance = distance + ([0, 16, 25, 8, 11, 39, 32, -14][i] as float)
			r.lane = [-1.0, 3.5, -3.0, -5.4, 5.4, 0.0, 4.0, 2.0][i]
			r.speed = 35.0
			r.turbo = 1.2 if i == 0 else 0.0
		sim.race_time = 48.27
		sim.racers[0].item = "fish"
		sim._update_transforms()
		sim.snap_interpolation()
		_update_karts(.016)
		_update_camera(1, true)
		_qa_driver = true
		if screen == "pause": _pause()
		if screen == "results":
			sim.racers[0].finish_time = 108.42
			sim.racers[0].distance = float(world.length) * 3
			_show_results()
		if screen == "drive":
			for i in range(720): await get_tree().physics_frame
			print("QA_DRIVE distance=", sim.racers[0].distance, " speed=", sim.racers[0].speed, " fps=", Engine.get_frames_per_second())
			if not _qa_frame_times.is_empty():
				_qa_frame_times.sort()
				print("QA_FRAME_TIMES samples=", _qa_frame_times.size(), " median_ms=", _qa_frame_times[_qa_frame_times.size() / 2], " p95_ms=", _qa_frame_times[int(_qa_frame_times.size() * .95)])
	for i in range(18): await get_tree().process_frame
	var filename := _arg("--qa-output")
	if not filename.is_empty() and DisplayServer.get_name() != "headless":
		# An inactive macOS test window may suspend automatic draws. Request
		# the capture frame explicitly rather than awaiting a signal forever.
		RenderingServer.force_draw(false)
		var result := get_viewport().get_texture().get_image().save_png(filename)
		print("QA_SCREENSHOT ", filename, " result=", result)
	print("QA_STATE ", state, " screen=", screen, " mode=", menu.selected_mode, " character=", menu.selected_character)
	if "--qa-quit" in OS.get_cmdline_user_args(): get_tree().quit()
