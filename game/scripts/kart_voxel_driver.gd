extends RefCounted
## Procedural voxel drivers. Pixel faces are original geometry, no texture files.

static var _cube: BoxMesh
static var _materials: Dictionary = {}


static func build(parent: Node3D, index: int) -> void:
	var skins: Array[Color] = [Color("b88967"), Color("f1c6a0"), Color("66a63d"), Color("22232d"), Color("659b56"), Color("c5c3b3"), Color("efa5af"), Color("b48a6c")]
	var shirts: Array[Color] = [Color("27a9b8"), Color("6b963e"), Color("5b9836"), Color("262330"), Color("2d9fa8"), Color("cfcdbe"), Color("ec9aa6"), Color("816051")]
	var pants: Array[Color] = [Color("535290"), Color("655541"), Color("3c6a2a"), Color("202029"), Color("51467d"), Color("b4b3a9"), Color("ce7b8b"), Color("5f463f")]
	var skin: Color = skins[index]
	var shirt: Color = shirts[index]
	var trouser: Color = pants[index]
	var head: Vector3 = Vector3(0, 2.56, 0.12)
	if index == 3:
		head.y += 0.10
	_box(parent, head, Vector3.ONE * 1.08, skin)
	if index == 5:
		# Open rib cage, square clavicle and pelvis keep the skeleton readable.
		_box(parent, Vector3(0, 1.56, 0.22), Vector3(0.15, 1.01, 0.18), shirt)
		for y: float in [1.23, 1.45, 1.67, 1.89]:
			_box(parent, Vector3(0, y, 0.16), Vector3(0.73, 0.10, 0.29), shirt)
	else:
		_box(parent, Vector3(0, 1.58, 0.19), Vector3(0.80 if index == 3 else 0.92, 1.05, 0.48), shirt)
		_box(parent, Vector3(0, 1.085, 0.18), Vector3(0.89, 0.13, 0.47), trouser)
	for side: float in [-1.0, 1.0]:
		var limb_width: float = 0.15 if index in [3, 5] else 0.285
		var sleeve_end: Vector3 = Vector3(side * 0.54, 1.57, -0.23)
		_segment(parent, Vector3(side * 0.54, 1.91, 0.17), sleeve_end, limb_width, shirt)
		_segment(parent, sleeve_end, Vector3(side * 0.35, 1.43, -0.60), limb_width, skin)
		_box(parent, Vector3(side * 0.35, 1.41, -0.61), Vector3(limb_width + 0.02, 0.22, 0.23), skin)
		_box(parent, Vector3(side * 0.245, 1.005, -0.015), Vector3(0.18 if index == 5 else 0.39, 0.31, 0.67), trouser)
		_box(parent, Vector3(side * 0.245, 0.981, -0.37), Vector3(0.23 if index == 5 else 0.4, 0.25, 0.22), trouser.darkened(0.27))
	var face: Array[String] = []
	var colors: Dictionary = {}
	match index:
		0:
			colors = {"s": skin, "h": Color("4d3528"), "w": Color("ede9df"), "i": Color("647aab"), "n": Color("966647"), "b": Color("634435"), "m": Color("3d2925")}
			face.assign(["hhhhhhhh", "hhhhhhhh", "hssssssh", "swissiws", "ssnnnnss", "ssbssbss", "ssbmmbss", "sssbbsss"])
			_hair(parent, head, Color("4d3528"), false)
		1:
			colors = {"s": skin, "h": Color("bf7434"), "w": Color("fff3e5"), "i": Color("668043"), "n": Color("d8a583"), "m": Color("b97660")}
			face.assign(["hhhhhhhh", "hhhhhhhs", "hhssssss", "swissiws", "ssssssss", "sssnnsss", "sssmmsss", "ssssssss"])
			_hair(parent, head, Color("bf7434"), true)
		2:
			colors = {"g": skin, "G": Color("82bd53"), "b": Color("223020")}
			face.assign(["ggGggGgg", "GggggggG", "gbbggbbg", "gbbggbbg", "gggbbggg", "ggbbbbgg", "ggbbbbgg", "ggbggbgg"])
			_pixel_noise(parent, head, skin, Color("91c65c"))
			for x: float in [-0.34, 0, 0.34]:
				_box(parent, Vector3(x, 1.56, -0.058), Vector3(0.14, 0.32, 0.016), Color("87b759"))
		3:
			colors = {"s": skin, "p": Color("bf4fdb"), "q": Color("f7bdff")}
			face.assign(["ssssssss", "ssssssss", "ssssssss", "pqqssqqp", "ssssssss", "ssssssss", "ssssssss", "ssssssss"])
			for side: float in [-1.0, 1.0]:
				_box(parent, head + Vector3(side * 0.27, 0, -0.552), Vector3(0.32, 0.10, 0.018), Color("d56bf5"), 0.8)
		4:
			colors = {"s": skin, "h": Color("496740"), "w": Color("1c3030"), "n": Color("527e45"), "b": Color("344b35"), "m": Color("354533")}
			face.assign(["hhhshhhh", "shssshss", "ssssssss", "swwsswws", "ssnnnnss", "ssssssss", "ssbmmbss", "ssbbbbss"])
			_pixel_noise(parent, head, skin, Color("85af68"))
		5:
			colors = {"s": skin, "w": Color("464741"), "b": Color("6a6b61"), "m": Color("898a7d")}
			face.assign(["ssssssss", "ssssssss", "swwsswws", "swwsswws", "sssbbsss", "ssssssss", "smbmbmbs", "ssssssss"])
		6:
			colors = {"s": skin, "w": Color("fff3f0"), "i": Color("4a393d"), "p": Color("d58497")}
			face.assign(["ssssssss", "ssssssss", "ssssssss", "siwsswis", "ssssssss", "ssppppss", "ssppppss", "ssssssss"])
			_box(parent, head + Vector3(0, -0.15, -0.617), Vector3(0.57, 0.33, 0.22), Color("e38fa3"))
			for side: float in [-1.0, 1.0]:
				_box(parent, head + Vector3(side * 0.155, -0.15, -0.736), Vector3(0.10, 0.105, 0.018), Color("aa5a77"))
				_box(parent, head + Vector3(side * 0.38, 0.56, 0.01), Vector3(0.23, 0.2, 0.35), Color("db899a"))
		7:
			colors = {"s": skin, "b": Color("664b39"), "w": Color("e1d9bd"), "i": Color("547749"), "n": Color("9c735a"), "m": Color("6c5042")}
			face.assign(["ssssssss", "ssssssss", "sbbbbbbs", "swissiws", "sssnnsss", "sssnnsss", "sssmmsss", "sssmmsss"])
			_box(parent, head + Vector3(0, -0.06, -0.655), Vector3(0.24, 0.46, 0.25), Color("a67b5b"))
			_box(parent, head + Vector3(0, -0.23, -0.79), Vector3(0.24, 0.12, 0.028), Color("91664e"))
			_box(parent, Vector3(0, 1.61, -0.059), Vector3(0.16, 0.96, 0.016), Color("ab8965"))
	_paint_face(parent, head, face, colors)
	# Pixel elbow patches and a belt add detail from the racing camera.
	if index in [0, 1, 4, 7]:
		for side: float in [-1.0, 1.0]:
			_box(parent, Vector3(side * 0.22, 1.71, 0.436), Vector3(0.15, 0.18, 0.017), shirt.lightened(0.09))
		_box(parent, Vector3(0, 1.16, 0.436), Vector3(0.88, 0.08, 0.017), trouser.darkened(0.23))


static func _paint_face(parent: Node3D, center: Vector3, rows: Array[String], colors: Dictionary) -> void:
	for y: int in range(rows.size()):
		for x: int in range(mini(rows[y].length(), 8)):
			var pixel: String = rows[y].substr(x, 1)
			var color: Color = colors.get(pixel, Color("ff00ff"))
			_box(parent, center + Vector3((x - 3.5) * 0.135, (3.5 - y) * 0.135, -0.546), Vector3(0.1351, 0.1351, 0.014), color)


static func _hair(parent: Node3D, center: Vector3, color: Color, long_hair: bool) -> void:
	_box(parent, center + Vector3(0, 0.49, 0), Vector3(1.105, 0.13, 1.105), color)
	_box(parent, center + Vector3(0, 0.11, 0.55), Vector3(1.105, 0.86, 0.06), color)
	for side: float in [-1.0, 1.0]:
		_box(parent, center + Vector3(side * 0.55, 0.31, 0.06), Vector3(0.035, 0.46 if long_hair else 0.31, 0.99), color)
		for i: int in range(3):
			_box(parent, center + Vector3(side * 0.55, 0.3 - i * 0.2, 0.31), Vector3(0.04, 0.12, 0.21), color.lightened(0.07))
	if long_hair:
		_box(parent, center + Vector3(-0.42, -0.50, 0.34), Vector3(0.28, 0.41, 0.41), color)
		_box(parent, center + Vector3(-0.30, -0.60, -0.28), Vector3(0.24, 0.54, 0.15), color)
	for x: float in [-0.36, 0.0, 0.36]:
		_box(parent, center + Vector3(x, 0.10, 0.584), Vector3(0.12, 0.63, 0.015), color.lightened(0.09))


static func _pixel_noise(parent: Node3D, center: Vector3, base: Color, highlight: Color) -> void:
	for y: int in range(8):
		for x: int in range(8):
			if (x * 17 + y * 13) % 5 < 2:
				var color: Color = highlight if (x + y) % 2 == 0 else base.darkened(0.12)
				_box(parent, center + Vector3((x - 3.5) * 0.135, (3.5 - y) * 0.135, 0.546), Vector3(0.1351, 0.1351, 0.014), color)
				for side: float in [-1.0, 1.0]:
					_box(parent, center + Vector3(side * 0.546, (3.5 - y) * 0.135, (x - 3.5) * 0.135), Vector3(0.014, 0.1351, 0.1351), color)


static func _segment(parent: Node3D, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var mesh: MeshInstance3D = _box(parent, (a + b) * 0.5, Vector3(width, a.distance_to(b), width), color)
	mesh.quaternion = Quaternion(Vector3.UP, (b - a).normalized())


static func _box(parent: Node3D, point: Vector3, dimensions: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	if _cube == null:
		_cube = BoxMesh.new()
	var key: String = color.to_html() + str(glow)
	if not _materials.has(key):
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.95
		if glow > 0:
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = glow
		_materials[key] = mat
	var result: MeshInstance3D = MeshInstance3D.new()
	result.mesh = _cube
	result.material_override = _materials[key]
	parent.add_child(result)
	result.position = point
	result.scale = dimensions
	return result
