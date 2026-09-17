extends SceneTree
## Native-only rendered race sample. Run with -- --qa to isolate preferences.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 800)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var automatic := "--automatic" in OS.get_cmdline_user_args()
	RenderingServer.render_loop_enabled = automatic
	var rendered_frames := [0]
	var count_frame := func(): rendered_frames[0] += 1
	RenderingServer.frame_post_draw.connect(count_frame)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in range(20): await process_frame
	# Exercise the ordinary menu route, including hiding its 3D preview at launch.
	main.menu.show_tracks()
	await process_frame
	await main._start_race(0, 1)
	main.set_physics_process(false)
	main.set_process(false)
	main.state = "racing"
	main.countdown = -2
	main._qa_driver = true
	for i in range(8):
		main.sim.racers[i].distance = 65.0 + [0, 16, 25, 8, 11, 39, 32, -14][i]
		main.sim.racers[i].lane = [-1.0, 3.5, -3.0, -5.4, 5.4, 0.0, 4.0, 2.0][i]
		main.sim.racers[i].speed = 35.0
	main.sim._update_transforms()
	main.sim.snap_interpolation()
	main._update_karts(0)
	main._update_camera(1, true)
	if "--world-only" in OS.get_cmdline_user_args():
		for kart in main.karts: kart.hide()
	var samples: Array[float] = []
	var phase_totals := Vector3.ZERO
	for i in range(240):
		var start := Time.get_ticks_usec()
		await process_frame
		var waited := Time.get_ticks_usec()
		main._physics_process(1.0/60.0)
		main._update_karts(1.0/60.0)
		main._update_camera(1.0/60.0)
		var simulated := Time.get_ticks_usec()
		if not automatic: RenderingServer.force_draw(false)
		var ended := Time.get_ticks_usec()
		if i >= 60:
			samples.append((ended-start)/1000.0)
			phase_totals += Vector3(waited-start,simulated-waited,ended-simulated)/1000.0
	samples.sort()
	RenderingServer.force_draw(false)
	var picture := root.get_texture().get_image()
	print("RACE_RENDER_SAMPLE renderer=", RenderingServer.get_current_rendering_method(), " image=", picture.get_size(), " samples=", samples.size(), " median_ms=", samples[90], " p95_ms=", samples[171], " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("RACE_RENDER_PHASES mean_wait_sim_draw_ms=",phase_totals/samples.size()," world_only=","--world-only" in OS.get_cmdline_user_args())
	print("RACE_RENDER_MODE automatic=",automatic," confirmed_rendered_frames=",rendered_frames[0])
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): picture.save_png(argument.trim_prefix("--output="))
	RenderingServer.frame_post_draw.disconnect(count_frame)
	RenderingServer.render_loop_enabled = false
	main.queue_free()
	for i in range(3): await process_frame
	quit()
