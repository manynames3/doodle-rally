extends SceneTree

func _initialize() -> void:
	var script: Script = load("res://scripts/track_world.gd")
	if script == null:
		quit(1)
		return
	for mode in ["cats", "minecraft"]:
		for index in range(3):
			var world: Node3D = script.new()
			root.add_child(world)
			world.build(index, mode)
			var checked_surfaces: int = 0
			for child in world.get_children():
				if child is MeshInstance3D and child.name.begins_with("RacingSurface_") and child.mesh is ArrayMesh:
					var arrays: Array = child.mesh.surface_get_arrays(0)
					var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
					for normal in normals:
						assert(normal.y > 0.8, "Road normals must face upward")
					checked_surfaces += 1
			assert(checked_surfaces == 3, "Validate road and both shoulders")
			world.set_animations_enabled(false)
			assert(not world.is_processing(), "Reduced motion must stop shader time updates")
			world.set_animations_enabled(true)
			print("WORLD_VALID ", mode, " course=", index, " length=", world.length, " nodes=", world.get_child_count(), " seam=", world.sample(0).distance_to(world.sample(world.length)), " items=", world.item_spots.size())
			root.remove_child(world)
			world.free()
	quit()
