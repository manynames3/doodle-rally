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
	main.menu._start_blocks()
	check(main.menu.selected_mode == "minecraft" and main.menu.screen == "characters", "Minecraft title route")
	await key(KEY_RIGHT, true)
	await key(KEY_RIGHT, false)
	check(main.menu.selected_character == 3, "Character arrows use display order")
	await key(KEY_ENTER, true)
	await key(KEY_ENTER, false)
	check(main.menu.screen == "tracks", "Enter opens track selection")
	await key(KEY_LEFT, true)
	await key(KEY_LEFT, false)
	check(main.menu.selected_course == 0, "Track arrows choose Desktop Dojo")
	await key(KEY_ENTER, true)
	await key(KEY_ENTER, false)
	for i in range(30):
		if main.state == "countdown": break
		await frame()
	check(main.state == "countdown" and main.racer_mode == "minecraft", "Minecraft launch reaches countdown")
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
