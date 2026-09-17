extends SceneTree
## Rebuild native 128px HUD portraits from the actual game meshes:
## Godot --path game --minimized --script res://scripts/kart_render_portraits.gd
## Uses an isolated offscreen viewport; never launches or controls a race.

const Kart = preload("res://scripts/kart_visual.gd")

func _initialize() -> void:
	call_deferred("_render_portraits")


func _render_portraits() -> void:
	root.title = "Isolated kart portrait renderer"
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.mode = Window.MODE_MINIMIZED
	var output: String = ProjectSettings.globalize_path("res://assets/portraits")
	DirAccess.make_dir_recursive_absolute(output)
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var scene: Node3D = Node3D.new()
	viewport.add_child(scene)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.TRANSPARENT
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("ced9dd")
	env.environment.ambient_light_energy = 0.30
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	scene.add_child(env)
	for spec: Dictionary in [{"angle": Vector3(-25, 155, 0), "energy": 1.05, "color": Color("fff3df")}, {"angle": Vector3(-10, -120, 0), "energy": 0.28, "color": Color("b4d2e4")}, {"angle": Vector3(-40, 0, 0), "energy": 0.44, "color": Color("fff1d8")}]:
		var light: DirectionalLight3D = DirectionalLight3D.new()
		light.rotation_degrees = spec.angle
		light.light_energy = spec.energy
		light.light_color = spec.color
		scene.add_child(light)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	scene.add_child(camera)
	camera.current = true
	var count: int = 0
	for mode: String in ["cats", "minecraft"]:
		for index: int in range(8):
			var kart: Node3D = Kart.new()
			scene.add_child(kart)
			kart.build(index, mode)
			kart._tail.visible = false
			var center: float = (3.02 if index == 6 else 2.87) if mode == "cats" else 2.60 + (0.10 if index == 3 else 0.0)
			if mode == "cats":
				_isolate_cat_head(kart)
			else:
				_keep_head_geometry(kart,2.005)
			camera.size = (3.10 if index == 6 else 2.85) if mode == "cats" else 1.38
			camera.position = Vector3(0, center, -6)
			camera.look_at(Vector3(0, center, 0))
			await process_frame
			RenderingServer.force_draw(false)
			var picture: Image = viewport.get_texture().get_image()
			picture.resize(128, 128, Image.INTERPOLATE_LANCZOS)
			var filename: String = "%s_%d.png" % ["cat" if mode == "cats" else "block", index]
			var error: Error = picture.save_png(output.path_join(filename))
			if error != OK:
				push_error("Could not save portrait " + filename)
				quit(1)
				return
			count += 1
			kart.free()
	print("PORTRAIT_RENDER_PASS: ", count, " transparent 128px portraits from final game geometry")
	quit(0)


func _keep_head_geometry(kart: Node3D, cutoff: float) -> void:
	# Filter only the capture instance's triangles; shared game meshes and
	# materials are never modified. Opaque model rendering remains untouched.
	for part: MeshInstance3D in kart.find_children("*", "MeshInstance3D", true, false):
		if not part.is_visible_in_tree():
			continue
		var transform: Transform3D = kart.global_transform.affine_inverse() * part.global_transform
		var head: ArrayMesh = ArrayMesh.new()
		for surface_index: int in range(part.mesh.get_surface_count()):
			var arrays: Array = part.mesh.surface_get_arrays(surface_index).duplicate(true)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var original: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if original.is_empty():
				for vertex_index: int in range(vertices.size()):
					original.append(vertex_index)
			var kept: PackedInt32Array = []
			for triangle: int in range(0, original.size(), 3):
				var a: int = original[triangle]
				var b: int = original[triangle + 1]
				var c: int = original[triangle + 2]
				if (transform * vertices[a]).y >= cutoff and (transform * vertices[b]).y >= cutoff and (transform * vertices[c]).y >= cutoff:
					kept.append_array([a, b, c])
			if not kept.is_empty():
				arrays[Mesh.ARRAY_INDEX] = kept
				head.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if head.get_surface_count() > 0:
			part.mesh = head
		else:
			part.visible = false


func _isolate_cat_head(kart: Node3D) -> void:
	# The sculpt now exposes a coherent head group: capture its entire jaw
	# without the torso or a horizontal triangle crop. Keep the halo as well.
	for part: MeshInstance3D in kart.find_children("*","MeshInstance3D",true,false):
		var local_transform: Transform3D = kart.global_transform.affine_inverse()*part.global_transform
		var bounds: AABB = local_transform*part.get_aabb()
		part.visible = kart._head.is_ancestor_of(part) or bounds.position.y > 3.70
