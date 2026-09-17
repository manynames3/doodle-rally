extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = Vector2i(1280, 800)
	RenderingServer.render_loop_enabled = false
	root.disable_3d = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var world: Node3D = load("res://scripts/track_world.gd").new()
	root.add_child(world)
	world.build(1, "cats")
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.fov = 65
	camera.far = 2200
	camera.current = true
	camera.position = world.sample(80) + world.frame(80).z * 7.7 + Vector3.UP * 3.6
	camera.look_at(world.sample(108) + Vector3.UP * 3.0, Vector3.UP)
	await create_timer(2.5).timeout
	var times: Array[float] = []
	var before: int = Time.get_ticks_usec()
	for i in range(180):
		await process_frame
		RenderingServer.force_draw(false)
		var now: int = Time.get_ticks_usec()
		times.append((now - before) / 1000.0)
		before = now
	times.sort()
	print("WORLD_BENCH renderer=", RenderingServer.get_current_rendering_method(), " median_ms=", times[90], " p95_ms=", times[171], " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " image_size=", root.get_texture().get_size())
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../screenshots/1.3/world_quarry.png"))
	quit()
