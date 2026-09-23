extends SceneTree
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func frame(count: int = 1) -> void:
	for i in range(count): await process_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await frame(2)

func run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frame(8)
	check(main.state == "menu" and main.menu.screen == "title", "App starts at intro")
	check(not main.preferences.enabled, "QA uses isolated preferences")
	main._show_startup()
	var splash: CanvasLayer = main.startup_splash
	splash.set_process(false)
	check(main.state == "splash" and not main.menu.visible, "Studio splash blocks the title menu")
	splash._process(.8)
	check(splash.artwork.modulate.a == 1 and main.state == "splash", "Logo holds at full visibility")
	splash._process(1.3)
	await frame(2)
	check(main.state == "menu" and main.menu.screen == "title" and main.startup_splash == null, "Splash automatically enters title after about two seconds")
	for input_kind in ["keyboard", "mouse", "controller"]:
		main._show_startup()
		splash = main.startup_splash
		splash.set_process(false)
		splash._process(.5)
		var event: InputEvent
		if input_kind == "keyboard":
			event = InputEventKey.new()
			event.keycode = KEY_ENTER
			event.physical_keycode = KEY_ENTER
		elif input_kind == "mouse":
			event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = Vector2(220, 340)
		else:
			event = InputEventJoypadButton.new()
			event.button_index = JOY_BUTTON_A
		event.pressed = true
		Input.parse_input_event(event)
		await frame(2)
		check(splash.skipping, input_kind + " skips studio splash")
		event.pressed = false
		Input.parse_input_event(event)
		splash._process(.17)
		await frame(2)
		check(main.state == "menu" and main.menu.screen == "title", input_kind + " skip does not activate a title button")
	main.menu._start_blocks()
	check(main.menu.selected_mode == "minecraft" and main.menu.screen == "characters", "Minecraft title route")
	await key(KEY_RIGHT, true)
	await key(KEY_RIGHT, false)
	check(main.menu.selected_character == 6, "Character arrows use display order with Zizi and Mak-Doong centered")
	await key(KEY_ENTER, true)
	await key(KEY_ENTER, false)
	check(main.menu.screen == "tracks", "Enter opens track selection")
	await key(KEY_LEFT, true)
	await key(KEY_LEFT, false)
	check(main.menu.selected_course == 0, "Track arrows choose Desktop Dojo")
	main.menu._difficulty_buttons[2].pressed.emit()
	check(main.preferences.values.difficulty == 4, "Track-screen Hard choice reaches saved preferences")
	await key(KEY_ENTER, true)
	await key(KEY_ENTER, false)
	for i in range(30):
		if main.state == "countdown": break
		await frame()
	check(main.state == "countdown" and main.racer_mode == "minecraft" and main.sim.difficulty == 4, "Minecraft launch carries selected Hard pace into simulation")
	check(main.get_viewport().scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR and main.get_viewport().scaling_3d_scale < 1.0, "Smooth graphics reduce only the 3D race resolution")
	check(main._race_render_scale(1920.0, 0) < main._race_render_scale(1280.0, 0), "Smooth graphics scale down for a larger race window")
	check(main.karts.size() == 8 and main.sim.racers.size() == 8, "Eight actual 3D karts and racers")
	main.countdown = .04
	await key(KEY_W, true)
	for i in range(90): await physics_frame
	print("Input drive: state=", main.state, " time=", main.sim.race_time, " speed=", main.sim.racers[0].speed, " distance=", main.sim.racers[0].distance, " lane=", main.sim.racers[0].lane, " gas=", Input.get_action_strength("r_gas"))
	check(main.state == "racing" and main.sim.racers[0].speed > 10, "Gas key accelerates in native input loop")
	await key(KEY_ESCAPE, true)
	await key(KEY_ESCAPE, false)
	check(main.state == "paused", "Escape opens pause overlay")
	var snapshot: Dictionary = main.sim.racers[0].duplicate(true)
	var time: float = main.sim.race_time
	for i in range(15): await physics_frame
	check(main.sim.race_time == time and main.sim.racers[0] == snapshot, "Pause freezes race and every player timer")
	await key(KEY_ESCAPE, true)
	await key(KEY_ESCAPE, false)
	check(main.state == "racing", "Escape resumes")
	await key(KEY_W, false)
	main.sim.racers[0].item = "bubble"
	await key(KEY_E, true)
	await key(KEY_E, false)
	for i in range(2): await physics_frame
	check(main.sim.racers[0].shield > 0 and main.sim.racers[0].item == "", "E uses the held item")
	main._pause()
	main._back_to_tracks()
	await frame(3)
	check(main.state == "menu" and main.menu.screen == "tracks" and main.race_root == null, "Choose track cleans up race")
	check(main.get_viewport().scaling_3d_scale == 1.0, "Menu returns to full-resolution 3D previews")
	main._back_to_title()
	main.menu._start_cats()
	check(main.menu.selected_mode == "cats", "Cat route switches back from Minecraft")
	main.menu.selected_course = 2
	main.menu.show_tracks()
	main.menu._launch()
	for i in range(30):
		if main.state == "countdown": break
		await frame()
	check(main.state == "countdown" and main.course == 2 and main.racer_mode == "cats", "Cat Glitch Core launch")
	main.sim.racers[0].distance = main.world.length * 3 - .1
	main.sim.racers[0].speed = 35.0
	main.countdown = -2
	main.state = "racing"
	for i in range(3): await physics_frame
	check(main.state == "results" and main.sim.finished, "Finish line reaches usable results screen")
	await main._start_race(4, 1)
	check(main.state == "countdown" and main.character == 4 and main.course == 1, "Rematch/restart builds a fresh race")
	check(main.sim.race_time == 0 and main.sim.racers[0].item == "", "Restart clears race clock and items")
	main._back_to_title()
	main.queue_free()
	await frame(3)
	print("INTEGRATION_TESTS ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
