extends Node3D
## Scenic circuits assembled from shared meshes. The road and driving frame are
## sampled from the same curve, so ramps, hills and the minimap agree exactly.

var length: float = 1200.0
var road_width: float = 18.0
var curve: Curve3D
var item_spots: Array[Dictionary] = []
var boost_spots: Array[Dictionary] = []
var _course: int = 1
var _mode: String = "cats"
var _rng := RandomNumberGenerator.new()
var _materials: Dictionary = {}
var _meshes: Dictionary = {}
var _batches: Dictionary = {}
var _waterfalls: Array[MeshInstance3D] = []
var _animated: Array[Node3D] = []
var _animated_materials: Array[ShaderMaterial] = []
var _animations_enabled: bool = true
var _elapsed: float = 0.0
var _road_points: PackedVector3Array = PackedVector3Array()


func build(course_index: int, mode: String = "cats") -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_course = clampi(course_index, 0, 2)
	_mode = mode
	_rng.seed = 90817 + _course * 911
	_materials.clear()
	_batches.clear()
	_waterfalls.clear()
	_animated.clear()
	_animated_materials.clear()
	item_spots.clear()
	boost_spots.clear()
	_elapsed = 0.0
	_make_curve()
	_lighting()
	_make_road()
	match _course:
		0: _desktop()
		1: _quarry()
		2: _glitch()
	_start_gate()
	for fraction in [0.125, 0.34, 0.56, 0.78, 0.93]:
		for lane in [-5.3, 0.0, 5.3]:
			item_spots.append({"distance": length * float(fraction), "lane": float(lane)})
	for fraction in [0.23, 0.47, 0.7, 0.88]:
		boost_spots.append({"distance": length * float(fraction), "lane": -3.6 if int(float(fraction) * 100.0) % 2 == 0 else 3.6})
	_flush_batches()
	set_process(_animations_enabled and _course != 0)


func set_animations_enabled(enabled: bool) -> void:
	_animations_enabled = enabled
	set_process(enabled and _course != 0)


func sample(distance: float, lane: float = 0.0) -> Vector3:
	var d: float = fposmod(distance, length)
	var p: Vector3 = curve.sample_baked(d, true)
	if not is_zero_approx(lane):
		var forward: Vector3 = tangent(d)
		p += forward.cross(Vector3.UP).normalized() * lane
	return p


func tangent(distance: float) -> Vector3:
	var a: Vector3 = curve.sample_baked(fposmod(distance - 0.7, length), true)
	var b: Vector3 = curve.sample_baked(fposmod(distance + 0.7, length), true)
	return (b - a).normalized()


func frame(distance: float) -> Basis:
	return Basis.looking_at(tangent(distance), Vector3.UP)


func _make_curve() -> void:
	curve = Curve3D.new()
	curve.bake_interval = 1.5
	var points: Array[Vector3] = [
		Vector3(-70, 30, 180), Vector3(-70, 30, 65),
		Vector3(-73, 33, -62), Vector3(-134, 46, -147),
		Vector3(-113, 61, -246), Vector3(14, 66, -276),
		Vector3(125, 56, -222), Vector3(154, 44, -117),
		Vector3(104, 35, -26), Vector3(175, 29, 59),
		Vector3(140, 29, 172), Vector3(46, 30, 241),
		Vector3(-40, 30, 242)]
	for i in range(points.size()):
		points[i].x *= 0.9
		points[i].z *= 0.9
	if _course == 0:
		for i in range(points.size()):
			points[i].y = 7.0 + maxf(0.0, (points[i].y - 30.0) * 0.32)
	elif _course == 2:
		for i in range(points.size()):
			points[i].y = 28.0 + (points[i].y - 30.0) * 0.7
	for i in range(points.size()):
		var prev: Vector3 = points[posmod(i - 1, points.size())]
		var following: Vector3 = points[(i + 1) % points.size()]
		var direction: Vector3 = (following - prev).normalized()
		var handle: float = minf(points[i].distance_to(prev), points[i].distance_to(following)) * 0.29
		curve.add_point(points[i], -direction * handle, direction * handle)
	curve.add_point(points[0], curve.get_point_in(0), curve.get_point_out(0))
	length = curve.get_baked_length()
	_road_points.clear()
	for i in range(int(length / 7.0)):
		_road_points.append(sample(float(i) * 7.0))


func _lighting() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	if _course == 2:
		sky_material.sky_top_color = Color("090e2e")
		sky_material.sky_horizon_color = Color("322464")
		sky_material.ground_bottom_color = Color("06071c")
		sky_material.ground_horizon_color = Color("2a1b52")
		env.ambient_light_color = Color("839dff")
		env.ambient_light_energy = 0.42
		env.fog_light_color = Color("1a123b")
		env.fog_density = 0.0019
	else:
		sky_material.sky_top_color = Color("1758a5")
		sky_material.sky_horizon_color = Color("a9cfdf")
		sky_material.ground_bottom_color = Color("696d59")
		sky_material.ground_horizon_color = Color("cad0b4")
		sky_material.sky_curve = 0.6
		env.ambient_light_color = Color("a1bdd5")
		env.ambient_light_energy = 0.38
		env.fog_light_color = Color("9db9ce")
		env.fog_density = 0.00065
	sky.sky_material = sky_material
	if _course != 2:
		var day_shader := Shader.new()
		day_shader.code = """shader_type sky;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){return noise(p)*0.57+noise(p*2.03+7.0)*0.29+noise(p*4.07+15.0)*0.14;}
void sky(){float y=max(EYEDIR.y,0.0);vec3 horizon=vec3(0.68,0.82,0.91),zenith=vec3(0.10,0.41,0.78);COLOR=mix(horizon,zenith,pow(y,0.42));if(y>0.025){vec2 uv=EYEDIR.xz/(y+0.22)*2.2;float n=fbm(uv);float cloud=smoothstep(0.58,0.76,n)*smoothstep(0.025,0.15,y);vec3 cloud_color=mix(vec3(0.74,0.80,0.84),vec3(1.0,0.98,0.93),smoothstep(0.55,0.85,fbm(uv+vec2(0.1,0.17))));COLOR=mix(COLOR,cloud_color,cloud);}if(EYEDIR.y<0.0){COLOR=mix(horizon,vec3(0.11,0.15,0.12),clamp(-EYEDIR.y*3.0,0.0,1.0));}}
"""
		var day_material := ShaderMaterial.new()
		day_material.shader = day_shader
		sky.sky_material = day_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_sky_contribution = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	env.fog_enabled = true
	env.fog_sky_affect = 0.06
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-41.0, -34.0, 0.0)
	sun.light_color = Color("e3dcff") if _course == 2 else Color("fff0c7")
	sun.light_energy = 0.4 if _course == 2 else 0.60
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 170.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35.0, 145.0, 0.0)
	fill.light_color = Color("73baff")
	fill.light_energy = 0.14
	add_child(fill)


func _make_road() -> void:
	var dirt: StandardMaterial3D
	var edge: StandardMaterial3D
	if _course == 1:
		dirt = _noise_mat("dirt", Color("b78e5e"), Color("e0b887"), 0.075)
		if _mode != "minecraft":
			dirt = _texture_mat("dirt_physical", "res://assets/world/ground.png", Color("bdbdb6"))
			dirt.uv1_scale = Vector3(3.0, 3.0, 1.0)
		edge = _mat("edge", Color("795c39"))
	elif _course == 0:
		dirt = _noise_mat("paper", Color("ddd5b8"), Color("f7ebce"), 0.08)
		edge = _mat("edge", Color("a9815a"))
	else:
		dirt = _mat("road", Color("222b49"), 0.45, 0.25)
		edge = _mat("edge", Color("07111f"), 0.5, 0.3)
	_ribbon(-road_width * 0.5, road_width * 0.5, 0.0, dirt)
	_ribbon(-road_width * 0.5 - 1.1, -road_width * 0.5, -0.09, edge)
	_ribbon(road_width * 0.5, road_width * 0.5 + 1.1, -0.09, edge)
	var curb_a: StandardMaterial3D = _mat("curb_a", Color("e76d56") if _course != 2 else Color("27d4ed"), 0.7, 0.0, 0.0 if _course != 2 else 1.2)
	var curb_b: StandardMaterial3D = _mat("curb_b", Color("fff4d5") if _course != 2 else Color("543083"))
	var dash: StandardMaterial3D = _mat("dash", Color("eee0b7") if _course != 2 else Color("78bfff"), 0.8, 0, 0 if _course != 2 else 0.6)
	for i in range(int(length / 5.0)):
		var d: float = float(i) * 5.0
		var basis: Basis = frame(d)
		for side in [-1.0, 1.0]:
			_stamp("box", sample(d, float(side) * 8.9) + Vector3(0, 0.055, 0), Vector3(0.6, 0.13, 5.05), curb_a if i % 2 == 0 else curb_b, basis)
		if _course == 0 and i % 2 == 0:
			_stamp("box", sample(d) + Vector3(0, 0.035, 0), Vector3(0.12, 0.03, 3.0), dash, basis)
		elif _course == 2:
			_stamp("box", sample(d) + Vector3(0, 0.045, 0), Vector3(17, 0.04, 0.08), _mat("grid", Color("337da4"), 0.7, 0.0, 0.8), basis)
	for i in range(12):
		for row in range(2):
			var lane: float = -8.25 + i * 1.5
			_stamp("box", sample(float(row) * 1.5, lane) + Vector3(0, 0.055, 0), Vector3(1.5, 0.065, 1.5), _mat("checker_white", Color("fff5d4")) if (i + row) % 2 == 0 else _mat("checker_black", Color("20212d")), frame(0.0))
	for d in [13.0, 22.0, 31.0, 40.0]:
		for lane in [-4.0, 4.0]:
			for side in [-1.0, 1.0]:
				_stamp("box", sample(length - float(d), float(lane) + float(side) * 1.7) + Vector3(0, 0.055, 0), Vector3(0.12, 0.045, 4.4), dash, frame(length - float(d)))


func _ribbon(left: float, right: float, y_offset: float, mat: StandardMaterial3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = ceili(length / 3.5)
	for i in range(steps):
		var d0: float = float(i) / steps * length
		var d1: float = float(i + 1) / steps * length
		var p0: Vector3 = sample(d0, left) + Vector3.UP * y_offset
		var p1: Vector3 = sample(d0, right) + Vector3.UP * y_offset
		var p2: Vector3 = sample(d1, left) + Vector3.UP * y_offset
		var p3: Vector3 = sample(d1, right) + Vector3.UP * y_offset
		for vertex in [[p0, Vector2(0, d0 / 15.0)], [p2, Vector2(0, d1 / 15.0)], [p1, Vector2(1, d0 / 15.0)], [p1, Vector2(1, d0 / 15.0)], [p2, Vector2(0, d1 / 15.0)], [p3, Vector2(1, d1 / 15.0)]]:
			st.set_uv(vertex[1])
			st.add_vertex(vertex[0])
	st.generate_normals()
	var road := MeshInstance3D.new()
	road.mesh = st.commit()
	road.material_override = mat
	add_child(road)


func _quarry() -> void:
	var water := _mat("water", Color("1d7c91"), 0.22, 0.35)
	_stamp("box", Vector3(0, -20, 0), Vector3(1900, 2, 1900), water)
	var rock_colors: Array[Color] = [Color("a69b85"), Color("928f7d"), Color("b5a690"), Color("b4ac96"), Color("848675")]
	var rock_mats: Array[StandardMaterial3D] = []
	for i in range(rock_colors.size()):
		var rock_material: StandardMaterial3D = _noise_mat("rock%d" % i, rock_colors[i].darkened(0.08), rock_colors[i].lightened(0.11), 0.07)
		if _mode != "minecraft":
			rock_material = _texture_mat("stone_physical%d" % i, "res://assets/world/rock.png", Color(0.78 + i * 0.035, 0.79 + i * 0.035, 0.75 + i * 0.035))
			rock_material.uv1_triplanar = true
			rock_material.uv1_world_triplanar = true
			rock_material.uv1_scale = Vector3.ONE * 0.07
			rock_material.uv1_triplanar_sharpness = 4.0
		rock_mats.append(rock_material)
	var grass := _mat("grass", Color("486b33"))
	var grass_light := _mat("grass_light", Color("66833b"))
	var wood: StandardMaterial3D = _noise_mat("wood", Color("6d4428"), Color("a36d38"), 0.08)
	var golden_wood: StandardMaterial3D = _mat("wood_light", Color("af8249"))
	if _mode != "minecraft":
		wood = _texture_mat("wood_physical", "res://assets/world/wood.png", Color("bcb3a4"))
		golden_wood = _texture_mat("wood_sunlit", "res://assets/world/wood.png", Color("eee5cf"))
	var rope := _mat("rope", Color("dfc790"))
	for i in range(int(length / 12.0)):
		var d: float = i * 12.0
		var p: Vector3 = sample(d)
		var bridge: bool = _is_bridge(d)
		if not bridge:
			_stamp("rock", p - Vector3(0, (p.y + 19.0) * 0.5 + 5.5, 0), Vector3(_rng.randf_range(29, 43), p.y + 19, _rng.randf_range(25, 39)), rock_mats[i % rock_mats.size()], Basis.from_euler(Vector3(0, _rng.randf() * TAU, 0)))
			for side in [-1.0, 1.0]:
				var verge: Vector3 = sample(d, float(side) * 15.0) - Vector3.UP * 0.6
				_stamp("rock", verge, Vector3(9.0, 2.2, 16), grass_light if i % 3 == 0 else grass, frame(d))
		else:
			for side in [-1.0, 1.0]:
				var foot: Vector3 = sample(d, float(side) * 9.8)
				_beam(foot - Vector3.UP * 1.0, Vector3(foot.x, -19, foot.z), 1.3, wood)
				_beam(foot - Vector3.UP * 12.0, sample(d + 12, float(side) * 9.8) - Vector3.UP * 2, 0.7, golden_wood)
		for side in [-1.0, 1.0]:
			var p0: Vector3 = sample(d, float(side) * 10.5)
			var p1: Vector3 = sample(d + 12, float(side) * 10.5)
			_stamp("box", p0 + Vector3(0, 1.85, 0), Vector3(0.62, 4.25, 0.62), wood, frame(d))
			_stamp("cylinder", p0 + Vector3(0, 4.02, 0), Vector3(0.65, 0.10, 0.65), golden_wood)
			_beam(p0 + Vector3.UP * 2.9, p1 + Vector3.UP * 2.9, 0.43, golden_wood)
			_beam(p0 + Vector3.UP * 1.35, p1 + Vector3.UP * 1.35, 0.36, wood)
			if bridge:
				_beam(p0 + Vector3.UP * 3.5, p1 + Vector3.UP * 3.5, 0.12, rope)
			elif i % 2 == 0:
				_tree(sample(d + 4, float(side) * _rng.randf_range(23, 32)) - Vector3.UP, _rng.randf_range(0.50, 0.89))
				if i % 4 == 0:
					_flowers(sample(d + 5, float(side) * 12.8), 7)
					var shrub: Vector3 = sample(d + 8, float(side) * 15.8)
					for lobe in range(3):
						_stamp("sphere", shrub + Vector3((lobe - 1) * 1.0, 0.7 + sin(lobe) * 0.3, 0), Vector3(2.3, 1.8, 2.4), _mat("shrub", Color("315c31")))
					var stone: Vector3 = sample(d + 2, float(side) * 18.5)
					_stamp("rock", stone + Vector3.UP * 1.3, Vector3(4, 4, 5), rock_mats[i % 5], frame(d))
				if _mode != "minecraft":
					for offset in [1.0, 5.0, 9.0]:
						_stamp("grass", sample(d + float(offset), float(side) * 12.8), Vector3(2.6, 1.4, 2.0), _mat("meadow_blades", Color("3e6330")), frame(d))
	for i in range(int(length / 1.8)):
		var d: float = i * 1.8
		if _is_bridge(d):
			_stamp("plank", sample(d) + Vector3(0, 0.03, 0), Vector3(20.3, 0.33, 1.65), golden_wood if i % 5 != 0 else wood, frame(d))
		elif _mode != "minecraft" and i % 3 == 0:
			for side in [-1.0, 1.0]:
				var pebble: Vector3 = sample(d + _rng.randf_range(0, 3), float(side) * _rng.randf_range(7.1, 8.4))
				_stamp("rock", pebble + Vector3.UP * 0.035, Vector3(0.16, 0.10, 0.22) * _rng.randf_range(0.7, 1.4), rock_mats[i % 5])
	# A ring of stone islands gives the route a layered mountain skyline.
	for i in range(30):
		var angle: float = i / 30.0 * TAU
		var radius: float = _rng.randf_range(400, 620)
		var p := Vector3(cos(angle) * radius, -20, sin(angle) * radius - 30)
		var h: float = _rng.randf_range(75, 165)
		_stamp("rock", p + Vector3.UP * h * 0.5, Vector3(_rng.randf_range(75, 130), h, _rng.randf_range(75, 145)), rock_mats[i % 5], Basis.from_euler(Vector3(0, angle, 0)))
		for spur in range(3):
			var spur_angle: float = angle + spur * 2.1
			var spur_pos: Vector3 = p + Vector3(cos(spur_angle) * 36, h * (0.25 + spur * 0.10), sin(spur_angle) * 38)
			_stamp("rock", spur_pos, Vector3(42, h * (0.55 + spur * 0.12), 48), rock_mats[(i + spur + 2) % 5], Basis.from_euler(Vector3(0, spur_angle, 0)))
		_stamp("rock", p + Vector3.UP * h, Vector3(48, 2.2, 55), grass, Basis.from_euler(Vector3(0, angle, 0)))
		for j in range(4):
			_tree(p + Vector3(cos(j * 1.57) * 12, h + 0.2, sin(j * 1.57) * 12), _rng.randf_range(0.55, 1.0))
		if i % 4 == 0:
			_waterfall(p + Vector3(0, h, -42), h + 20, _rng.randf_range(13, 23), Basis.IDENTITY)
	for i in range(22):
		var angle: float = i / 22.0 * TAU
		var p := Vector3(cos(angle) * 790, 190, sin(angle) * 790)
		var h: float = _rng.randf_range(220, 390)
		p.y = h * 0.5 - 30.0
		var mountain_mat: StandardMaterial3D = _texture_mat("distant_crags", "res://assets/world/rock.png", Color("536e81"))
		mountain_mat.uv1_triplanar = true
		mountain_mat.uv1_world_triplanar = true
		mountain_mat.uv1_scale = Vector3.ONE * 0.018
		_stamp("ridge", p, Vector3(280, h, 290), mountain_mat, Basis.from_euler(Vector3(0, angle, 0)))
		for spur in [-1.0, 1.0]:
			_stamp("ridge", p + Vector3(cos(angle + 1.4) * 78 * float(spur), -45, sin(angle + 1.4) * 78 * float(spur)), Vector3(190, h * 0.81, 195), mountain_mat, Basis.from_euler(Vector3(0, angle + float(spur) * 0.5, 0)))
		_stamp("ridge_snow", p, Vector3(280, h, 290), _mat("snow", Color("d1dfe3")), Basis.from_euler(Vector3(0, angle, 0)))
	# Close, stepped interior mesas make waterfalls part of the first vista.
	for mesa in [Vector3(0, 102, -118), Vector3(53, 69, 68), Vector3(-178, 83, -20)]:
		var height: float = mesa.y + 20.0
		_stamp("rock", Vector3(mesa.x, (mesa.y - 20.0) * 0.5, mesa.z), Vector3(61, height, 66), rock_mats[1])
		_stamp("rock", mesa - Vector3.UP * 0.5, Vector3(36, 2.2, 38), grass)
		for j in range(5):
			_tree(mesa + Vector3(_rng.randf_range(-10, 10), -0.2, _rng.randf_range(-10, 10)), _rng.randf_range(0.65, 0.95))
		_waterfall(mesa + Vector3(-7, 0, 30), height, 13, Basis.IDENTITY)
		for step in range(4):
			_stamp("rock", Vector3(mesa.x + 19, mesa.y * (0.15 + step * 0.18), mesa.z + 24), Vector3(20, 17, 14), rock_mats[(step + 2) % 5], Basis.from_euler(Vector3(0, step * 0.35, 0)))
	# Waterfalls beside both bridge approaches are visible at racing speed.
	for fraction in [0.27, 0.59, 0.73]:
		var d: float = length * float(fraction)
		var pos: Vector3 = sample(d, -31.0)
		_stamp("rock", pos - Vector3.UP * (pos.y + 17) * 0.5, Vector3(30, pos.y + 17, 31), rock_mats[2])
		_waterfall(pos + Vector3.UP * 4, pos.y + 24, 13.5, frame(d))
	if _mode == "minecraft":
		_block_tunnel(177.0, rock_mats)
		for fraction in [0.09, 0.39, 0.71, 0.86]:
			_voxel_mob(sample(length * float(fraction), 20), frame(length * float(fraction)))
	else:
		_cat_tunnel(177.0, rock_mats, wood)
	_sign(84, -18, "GOOD CATS\nFAST CATS", Color("e6bb7b"), 9.5, 8.5)
	_sign(length * 0.30 - 28, 17, "WOODLAND\nWAY →", Color("e2b678"), 11, 7.5)
	_sign(length * 0.59 - 15, -18, "MEOW!", Color("e5c998"), 12, 6.5)
	_sign(length * 0.83, 17, "PAWS ON\nTHE GAS", Color("e5be81"), 11, 8)
	_bunting(110, 10, 7)
	_bunting(length * 0.5, 12, 9)
	_watchtower(length * 0.28, 34, wood, golden_wood)
	_watchtower(length * 0.62, -35, wood, golden_wood)
	_balloon(Vector3(60, 155, -90), Color("d98642"))
	_balloon(Vector3(-220, 168, -250), Color("e9c469"))


func _is_bridge(distance: float) -> bool:
	var f: float = fposmod(distance, length) / length
	return (f > 0.265 and f < 0.345) or (f > 0.575 and f < 0.645)


func _tree(p: Vector3, scale_factor: float = 1.0) -> void:
	var wood := _mat("bark", Color("6d4f36"))
	if _mode == "minecraft":
		_stamp("box", p + Vector3.UP * 5.2 * scale_factor, Vector3(2.4, 10.4, 2.4) * scale_factor, wood)
		for tier in range(3):
			_stamp("box", p + Vector3.UP * (9.4 + tier * 3.2) * scale_factor, Vector3(10.8 - tier * 2.8, 4.4, 10.8 - tier * 2.8) * scale_factor, _mat("voxel_leaves%d" % tier, [Color("48733a"), Color("588740"), Color("6d994c")][tier]))
		return
	if ResourceLoader.exists("res://assets/world/pine.png"):
		_real_pine(p, scale_factor)
		return
	_stamp("cylinder", p + Vector3.UP * 4.6 * scale_factor, Vector3(1.1, 9.2, 1.1) * scale_factor, wood)
	var greens: Array[Color] = [Color("153d28"), Color("24512c"), Color("3b6733")]
	for tier in range(3):
		var mat: StandardMaterial3D = _mat("pine%d" % tier, greens[tier])
		mat.vertex_color_use_as_albedo = true
		_stamp("foliage", p + Vector3.UP * (7.2 + tier * 4.2) * scale_factor, Vector3(10.5 - tier * 2.4, 11.0 - tier * 1.5, 10.5 - tier * 2.4) * scale_factor, mat, Basis.from_euler(Vector3(0, tier * 0.4 + p.x, 0)))


func _real_pine(p: Vector3, s: float) -> void:
	var bark: StandardMaterial3D = _texture_mat("tree_bark", "res://assets/world/wood.png", Color("6e665a"))
	var needles: StandardMaterial3D = _texture_mat("pine_needles", "res://assets/world/pine.png", Color("b9c7b1"))
	needles.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	needles.alpha_scissor_threshold = 0.38
	needles.cull_mode = BaseMaterial3D.CULL_DISABLED
	needles.roughness = 0.95
	needles.emission_enabled = true
	needles.emission_texture = needles.albedo_texture
	needles.emission = Color("819874")
	needles.emission_energy_multiplier = 0.16
	_stamp("cylinder", p + Vector3.UP * 7.0 * s, Vector3(0.65, 14, 0.65) * s, bark)
	for level in range(9):
		var height: float = 3.5 + level * 1.45
		var radius: float = 4.6 * pow(1.0 - level / 10.0, 0.85)
		var branches: int = 5 if level < 6 else 4
		for i in range(branches):
			var angle: float = TAU * i / branches + level * 0.83 + p.x * 0.2
			var outward := Vector3(cos(angle), 0, sin(angle))
			var center: Vector3 = p + (Vector3.UP * height + outward * radius * 0.48) * s
			var basis: Basis = Basis.looking_at(outward + Vector3.UP * (0.10 if level % 2 == 0 else -0.04), Vector3.UP)
			_stamp("branch_card", center, Vector3(radius * 1.3, 1, radius * 1.8) * s, needles, basis)
			_stamp("branch_card", center + Vector3.UP * 0.18 * s, Vector3(radius * 0.93, 1, radius * 1.7) * s, needles, basis * Basis.from_euler(Vector3(0, 0, 0.55)))
			if level < 5:
				_beam(p + Vector3.UP * height * s, p + (Vector3.UP * (height - 0.10) + outward * radius * 0.8) * s, 0.065 * s, bark)
	# Compact shadow proxy avoids drawing every alpha-tested needle into shadows.
	for tier in range(3):
		_stamp("foliage_shadow", p + Vector3.UP * (6.0 + tier * 3.6) * s, Vector3(8.5 - tier * 2.2, 9.5 - tier * 1.2, 8.5 - tier * 2.2) * s, _mat("pine_shadow", Color("22422d")))


func _flowers(p: Vector3, count: int) -> void:
	var yellow := _mat("flower_yellow", Color("ffd669"))
	var pink := _mat("flower_pink", Color("f7a8a1"))
	for i in range(count):
		var at: Vector3 = p + Vector3(_rng.randf_range(-3, 3), 0.35, _rng.randf_range(-3, 3))
		_stamp("sphere", at, Vector3(0.6, 0.35, 0.6), yellow if i % 2 == 0 else pink)
		_stamp("box", at - Vector3.UP * 0.2, Vector3(0.07, 0.7, 0.07), _mat("stems", Color("486c35")))


func _waterfall(top: Vector3, height: float, width: float, basis: Basis) -> void:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform float flow_time=0.0;
uniform float strand=0.0;
void vertex(){VERTEX.x+=sin(UV.y*13.0-flow_time*1.4+strand)*0.20;VERTEX.z+=sin(UV.y*17.0-flow_time*2.0+strand)*0.09;}
void fragment(){float ribbons=sin(UV.x*17.0+sin(UV.y*10.0-flow_time*3.0+strand))*0.5+0.5;float rip=sin(UV.y*45.0-flow_time*8.0+strand)*0.045;ALBEDO=mix(vec3(0.50,0.66,0.73),vec3(0.90,0.94,0.95),ribbons)+rip;ALPHA=smoothstep(0.0,0.19,min(UV.x,1.0-UV.x))*(0.53+ribbons*0.24);ROUGHNESS=0.28;}
"""
	for band in range(5):
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("strand", band * 1.73)
		_animated_materials.append(mat)
		var waterfall := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(width * (0.24 + 0.035 * sin(band * 1.7)), height)
		mesh.orientation = PlaneMesh.FACE_Z
		mesh.subdivide_depth = 18
		mesh.subdivide_width = 3
		waterfall.mesh = mesh
		waterfall.material_override = mat
		waterfall.transform = Transform3D(basis, top + basis.x * (band - 2) * width * 0.18 + basis.z * (2.0 + band * 0.06) - Vector3.UP * height * 0.5)
		waterfall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(waterfall)
		_waterfalls.append(waterfall)
	var foam := _mat("foam", Color("e0f8ed"), 0.6)
	for i in range(8):
		var at: Vector3 = top + basis.x * _rng.randf_range(-width * 0.55, width * 0.55) - Vector3.UP * height
		_stamp("sphere", at + Vector3.UP * _rng.randf_range(0, 1.6), Vector3(_rng.randf_range(2.5, 5), 1.3, _rng.randf_range(2.5, 5)), foam)


func _cat_tunnel(distance: float, rocks: Array[StandardMaterial3D], wood: StandardMaterial3D) -> void:
	var center: Vector3 = sample(distance)
	var basis: Basis = frame(distance)
	# The entrance is carved into a grassy rock spur, rather than a free-standing hoop.
	for side in [-1.0, 1.0]:
		_stamp("rock", center + basis * Vector3(float(side) * 28, 5, 8), Vector3(30, 22, 30), rocks[1], basis)
		_stamp("rock", center + basis * Vector3(float(side) * 31, 20, 0), Vector3(32, 25, 34), rocks[2], basis * Basis.from_euler(Vector3(0, float(side) * 0.25, 0)))
		_stamp("rock", center + basis * Vector3(float(side) * 28, 32, -7), Vector3(28, 19, 32), rocks[3], basis)
		_stamp("rock", center + basis * Vector3(float(side) * 47, 10, -10), Vector3(36, 45, 42), rocks[2], basis)
		for ledge in range(4):
			var at: Vector3 = center + basis * Vector3(float(side) * (20 + ledge * 3), 11 + ledge * 7, 11)
			_stamp("rock", at, Vector3(13, 4.5, 9), rocks[2], basis)
			_stamp("grass", at + Vector3.UP * 2.2, Vector3(8, 1.5, 4), _mat("meadow_blades", Color("3e6330")), basis)
	_stamp("rock", center + basis * Vector3(0, 31, -10), Vector3(35, 19, 27), rocks[2], basis)
	for side in [-1.0, 1.0]:
		_stamp("rock", center + basis * Vector3(float(side) * 15, 34, -11), Vector3(26, 23, 30), rocks[2], basis)
		_stamp("rock", center + basis * Vector3(float(side) * 22, 43, -8), Vector3(17, 13, 19), rocks[2], basis)
		_tree(center + basis * Vector3(float(side) * 22, 47, -8), 0.66)
		_tree(center + basis * Vector3(float(side) * 39, 28, -6), 0.54)
	_tree(center + basis * Vector3(0, 39.0, -10), 0.67)
	_waterfall(center + basis * Vector3(49, 32, 13), center.y + 52.0, 10, basis)
	for z in [-13.0, -7.0, -1.0, 5.0, 11.0]:
		for i in range(17):
			var angle: float = float(i) / 16.0 * PI
			var pos := Vector3(cos(angle) * 13.3, 4.5 + sin(angle) * 13.3, float(z))
			_stamp("box", center + basis * pos, Vector3(3.2, 5.4, 6.3), rocks[2] if i % 5 != 0 else rocks[3], basis * Basis.from_euler(Vector3(0, 0, angle - PI * 0.5)))
		for side in [-1.0, 1.0]:
			_stamp("box", center + basis * Vector3(float(side) * 13.3, 2.0, float(z)), Vector3(5.0, 7, 6.3), rocks[2], basis)
	# Giant cat ears and face decorate the entrance, with the arch as its mouth.
	for side in [-1.0, 1.0]:
		_stamp("cat_ear", center + basis * Vector3(float(side) * 10.1, 24, 23), Vector3(9, 13, 5.0), rocks[2], basis * Basis.from_euler(Vector3(0, 0, float(side) * -0.15)))
		_stamp("cat_ear", center + basis * Vector3(float(side) * 10.1, 24.8, 25.5), Vector3(4.5, 7.6, 0.35), _mat("ear_stone", Color("946d56")), basis)
		_stamp("sphere", center + basis * Vector3(float(side) * 4.4, 20.6, 21.8), Vector3(8.8, 5.5, 6.0), rocks[2], basis)
		_stamp("sphere", center + basis * Vector3(float(side) * 5.2, 19.5, 25.0), Vector3(2.3, 3.0, 0.7), _mat("tunnel_eyes", Color("4a6341")), basis)
		_stamp("sphere", center + basis * Vector3(float(side) * 5.2, 19.5, 25.4), Vector3(0.55, 2.3, 0.24), _mat("pupil", Color("29322a")), basis)
	_stamp("sphere", center + basis * Vector3(0, 19.0, 25.8), Vector3(2.4, 1.3, 1.2), _mat("nose_stone", Color("735749")), basis)
	for z in [-10, -2, 6, 13]:
		for side in [-1.0, 1.0]:
			var light_pos: Vector3 = center + basis * Vector3(float(side) * 9.8, 5.3, float(z))
			_stamp("box", light_pos, Vector3(0.5, 2.7, 0.5), wood, basis)
			_stamp("sphere", light_pos + Vector3.UP * 1.8, Vector3(0.85, 1.25, 0.85), _mat("lantern_glow", Color("ffba49"), 0.4, 0, 2.3))
			if z == 6 or z == -10:
				var lamp := OmniLight3D.new()
				lamp.position = light_pos + Vector3.UP * 1.5
				lamp.light_color = Color("ffc16a")
				lamp.light_energy = 2.0
				lamp.omni_range = 13
				add_child(lamp)


func _block_tunnel(distance: float, rocks: Array[StandardMaterial3D]) -> void:
	var center: Vector3 = sample(distance)
	var basis: Basis = frame(distance)
	for z in range(-12, 13, 6):
		for side in [-1.0, 1.0]:
			for h in range(3):
				_stamp("box", center + basis * Vector3(float(side) * 13.5, h * 5 + 2, z), Vector3(6, 5, 6), rocks[(h + z + 15) % 5], basis)
		for x in range(-12, 13, 6):
			_stamp("box", center + basis * Vector3(x, 17, z), Vector3(6, 6, 6), rocks[posmod(x + z, 5)], basis)
		_stamp("box", center + basis * Vector3(0, 21, z), Vector3(33, 2, 6), _mat("voxel_grass", Color("6a963e")), basis)
	_label("BLOCK PASS", center + basis * Vector3(0, 20, 15.2), basis, 0.04, Color("e4f2c1"))
	for side in [-1.0, 1.0]:
		var p: Vector3 = center + basis * Vector3(float(side) * 10, 5.3, 10)
		_stamp("box", p, Vector3(0.8, 3.4, 0.8), _mat("torch_stick", Color("775433")), basis)
		_stamp("box", p + Vector3.UP * 2, Vector3(1.2, 1.8, 1.2), _mat("voxel_fire", Color("ffc953"), 0.5, 0, 2.0), basis)


func _voxel_mob(p: Vector3, basis: Basis) -> void:
	var green := _mat("mob_green", Color("68a44d"))
	var green_dark := _mat("mob_green_dark", Color("48843e"))
	var black := _mat("mob_eyes", Color("203129"))
	_stamp("box", p + Vector3.UP * 5.0, Vector3(3.8, 6.2, 2.8), green, basis)
	_stamp("box", p + Vector3.UP * 10.0, Vector3(5.8, 5.8, 5.8), green, basis)
	for side in [-1.0, 1.0]:
		_stamp("box", p + basis.x * float(side) * 2.1 + Vector3.UP * 1.4, Vector3(2.4, 2.8, 4.0), green_dark, basis)
		_stamp("box", p + basis * Vector3(float(side) * 1.4, 10.7, 2.96), Vector3(1.3, 1.3, 0.2), black, basis)
		_stamp("box", p + basis * Vector3(float(side) * 0.9, 8.1, 2.96), Vector3(0.7, 1.3, 0.2), black, basis)
	_stamp("box", p + basis * Vector3(0, 9.0, 2.96), Vector3(2.5, 1.6, 0.2), black, basis)


func _watchtower(d: float, lane: float, wood: StandardMaterial3D, trim: StandardMaterial3D) -> void:
	var p: Vector3 = sample(d, lane) - Vector3.UP * 9
	for x in [-4.5, 4.5]:
		for z in [-4.5, 4.5]:
			_stamp("box", p + Vector3(float(x), 16, float(z)), Vector3(1.2, 37, 1.2), wood)
	for h in [9, 18, 29]:
		_stamp("box", p + Vector3.UP * float(h), Vector3(12, 0.8, 12), trim)
		for side in [-1.0, 1.0]:
			_beam(p + Vector3(-4.5, float(h) - 8, float(side) * 4.5), p + Vector3(4.5, float(h), float(side) * 4.5), 0.6, wood)
	for x in [-5.5, 5.5]:
		_beam(p + Vector3(float(x), 32.5, -5.5), p + Vector3(float(x), 32.5, 5.5), 0.55, trim)
	for z in [-5.5, 5.5]:
		_beam(p + Vector3(-5.5, 32.5, float(z)), p + Vector3(5.5, 32.5, float(z)), 0.55, trim)
	_stamp("pine", p + Vector3(0, 39, 0), Vector3(18, 10, 18), _mat("roof", Color("b65b3e")), Basis.from_euler(Vector3(0, PI * 0.25, 0)))
	_stamp("sphere", p + Vector3(0, 33.6, 0), Vector3(4.4, 4, 4.0), _mat("cat_gold", Color("f0a744")))
	for side in [-1.0, 1.0]:
		_stamp("pine", p + Vector3(float(side) * 1.35, 35.7, 0), Vector3(1.8, 2.9, 1.8), _mat("cat_gold", Color("f0a744")))
		_stamp("sphere", p + Vector3(float(side) * 0.8, 34.0, 1.85), Vector3(0.55, 0.85, 0.25), _mat("pupil", Color("29322a")))


func _bunting(d: float, height: float, count: int) -> void:
	var colors: Array[Color] = [Color("e56f5b"), Color("ecc65c"), Color("66b7ad"), Color("bc85b4")]
	var wood := _mat("bark", Color("6d4f36"))
	for side in [-1.0, 1.0]:
		_stamp("cylinder", sample(d, float(side) * 13) + Vector3.UP * (height * 0.5), Vector3(0.45, height + 1, 0.45), wood)
	for i in range(count):
		var lane: float = lerpf(-12.5, 12.5, float(i) / maxf(1, count - 1))
		var p: Vector3 = sample(d, lane) + Vector3.UP * (height - 1.9 * sin(float(i) / maxf(1, count - 1) * PI))
		_stamp("pine", p - Vector3.UP * 1.1, Vector3(2.1, 2.6, 0.16), _mat("flag%d" % (i % 4), colors[i % 4]), frame(d) * Basis.from_euler(Vector3(PI, 0, 0)))
		if i > 0:
			var old_lane: float = lerpf(-12.5, 12.5, float(i - 1) / maxf(1, count - 1))
			var old: Vector3 = sample(d, old_lane) + Vector3.UP * (height - 1.9 * sin(float(i - 1) / maxf(1, count - 1) * PI))
			_beam(old, p, 0.1, _mat("rope", Color("dfc790")))


func _balloon(p: Vector3, color: Color) -> void:
	var mat := _mat("balloon_%s" % color.to_html(), color)
	_stamp("sphere", p, Vector3(22, 29, 22), mat)
	_stamp("sphere", p + Vector3(0, 0, 9.5), Vector3(13, 14, 2), _mat("balloon_cream", Color("f3dfb3")))
	for side in [-1.0, 1.0]:
		_stamp("pine", p + Vector3(float(side) * 4, 5, 10.8), Vector3(4, 5, 1), _mat("balloon_ink", Color("5d4436")))
		_stamp("sphere", p + Vector3(float(side) * 2.8, 0.5, 11.2), Vector3(1.5, 2, 0.5), _mat("balloon_ink", Color("5d4436")))
	_stamp("sphere", p + Vector3(0, -2.2, 11.2), Vector3(1.8, 1.2, 0.5), _mat("balloon_ink", Color("5d4436")))
	_stamp("box", p - Vector3.UP * 21, Vector3(7, 5, 7), _mat("basket", Color("9b6839")))
	for side in [-1.0, 1.0]:
		_beam(p + Vector3(float(side) * 5, -11, 0), p + Vector3(float(side) * 3.2, -20, 0), 0.16, _mat("rope", Color("dfc790")))


func _desktop() -> void:
	var wood := _noise_mat("desk_wood", Color("885530"), Color("b27b48"), 0.018)
	_stamp("box", Vector3(0, -7, -15), Vector3(980, 20, 1080), wood)
	var paper := _mat("sheet", Color("ece6d2"))
	var ink := _mat("graph_ink", Color("abc8c5"))
	for x in range(-450, 451, 15):
		_stamp("box", Vector3(float(x), 3.03, 0), Vector3(0.17, 0.05, 950), ink)
	for z in range(-450, 451, 15):
		_stamp("box", Vector3(0, 3.04, float(z)), Vector3(900, 0.05, 0.17), ink)
	_stamp("box", Vector3(0, 2.5, 0), Vector3(900, 1, 950), paper)
	var rail_dark := _mat("desk_barrier_dark", Color("945c38"))
	var rail_light := _mat("desk_barrier_light", Color("d8a65b"))
	for i in range(int(length / 12)):
		var d: float = i * 12.0
		var p: Vector3 = sample(d)
		_stamp("box", p - Vector3.UP * 1.5, Vector3(21, 3, 13), _mat("cardboard", Color("b99a6c")), frame(d))
		for side in [-1.0, 1.0]:
			var at: Vector3 = sample(d, float(side) * 10.5)
			_stamp("box", at + Vector3.UP * 1.45, Vector3(0.65, 3.4, 0.65), rail_dark, frame(d))
			_beam(at + Vector3.UP * 2.1, sample(d + 12, float(side) * 10.5) + Vector3.UP * 2.1, 0.48, rail_light)
			if i % 4 == 0:
				var outside: Vector3 = sample(d, float(side) * _rng.randf_range(44, 56))
				outside.y = 3.3
				_book_stack(outside, _rng.randi_range(2, 4), _rng.randf_range(0.65, 1.12), _rng.randf_range(-0.7, 0.7))
			elif i % 4 == 2:
				var outside: Vector3 = sample(d, float(side) * 38)
				outside.y = 4.5
				_pencil(outside, _rng.randf_range(22, 39), _rng.randf_range(0, TAU), i)
	# Cozy studio: a window wall, painted shelves, stationery and an open laptop.
	_stamp("box", Vector3(0, 93, -435), Vector3(970, 185, 8), _mat("wall", Color("a5c5c4")))
	var window := _mat("window", Color("9bd5f3"), 0.3, 0, 0.4)
	for x in [-290, -100, 100, 290]:
		_stamp("box", Vector3(float(x), 105, -429), Vector3(163, 148, 2), _mat("window_wood", Color("eddbb5")))
		_stamp("box", Vector3(float(x), 105, -427), Vector3(147, 132, 2), window)
		_stamp("box", Vector3(float(x), 105, -424), Vector3(4, 132, 3), _mat("window_wood", Color("eddbb5")))
		_stamp("box", Vector3(float(x), 105, -424), Vector3(147, 4, 3), _mat("window_wood", Color("eddbb5")))
	_stamp("box", Vector3(-260, 14, -322), Vector3(180, 9, 125), _mat("laptop_shell", Color("687a91")))
	_stamp("box", Vector3(-260, 64, -369), Vector3(180, 104, 7), _mat("laptop_shell", Color("687a91")), Basis.from_euler(Vector3(-0.12, 0, 0)))
	_stamp("box", Vector3(-260, 66, -363), Vector3(163, 88, 1), _mat("laptop_screen", Color("e4e9e4"), 0.7, 0, 0.2))
	_label("/\\_/\\\n( o.o )\nDOODLE CLUB", Vector3(-260, 65, -361), Basis.IDENTITY, 0.22, Color("354959"))
	for row in range(4):
		for col in range(13):
			_stamp("box", Vector3(-329 + col * 11.5, 19, -332 + row * 13.5), Vector3(8.5, 1.4, 8.0), _mat("keys", Color("253443")))
	_mug(Vector3(-7, 3, -145), 1.25, Color("f4e7c6"), "GOOD IDEAS\nMEOW")
	_mug(Vector3(270, 3, 110), 1.1, Color("b8dce4"), "FUELED BY\nTREATS")
	_mug(Vector3(-205, 3, 130), 0.8, Color("e6b5ac"), "RACE.\nCREATE.")
	for i in range(11):
		var p := Vector3(300 + _rng.randf_range(-15, 15), 3, -295 + i * 6)
		_pencil(p, 75, 0.3, i)
	for i in range(7):
		var p := Vector3(-310, 7 + i * 12.0, 230)
		_book_stack(p, 1, 1.8, sin(i) * 0.16)
	for i in range(20):
		var p := Vector3(_rng.randf_range(-390, 390), 3.6, _rng.randf_range(-340, 340))
		if _distance_to_road(p) > 28:
			_stamp("box", p, Vector3(18, 1.3, 12), _mat("eraser%d" % (i % 3), [Color("e6a4b0"), Color("a5c8da"), Color("edc368")][i % 3]), Basis.from_euler(Vector3(0, _rng.randf_range(-1, 1), 0)))
	_sign(85, -18, "DRAW. RACE.\nREPEAT.", Color("f1d88e"), 12, 8)
	_sign(length * 0.3, 18, "DESKTOP\nDOJO →", Color("bce2dd"), 12, 8)
	_sign(length * 0.69, -18, "GOOD IDEAS\nGO FAST", Color("eebac4"), 12, 8)
	_bunting(115, 10, 9)
	_bunting(length * 0.55, 11, 9)


func _book_stack(p: Vector3, count: int, s: float, angle: float) -> void:
	var colors: Array[Color] = [Color("dc7978"), Color("67a6bd"), Color("e3b853"), Color("7eae85"), Color("b99dba")]
	for i in range(count):
		var basis: Basis = Basis.from_euler(Vector3(0, angle + i * 0.12, 0))
		var at: Vector3 = p + Vector3.UP * (i * 7.0 + 3.5) * s
		var cover := _mat("book%d" % posmod(i + int(p.x), 5), colors[posmod(i + int(p.x), 5)])
		_stamp("box", at, Vector3(30, 5.2, 40) * s, _mat("book_pages", Color("ede4c8")), basis)
		for y in [-3.2, 3.2]:
			_stamp("box", at + Vector3.UP * float(y) * s, Vector3(31, 1.1, 41) * s, cover, basis)
		_stamp("box", at + basis.x * -15 * s, Vector3(1.8, 7.0, 41) * s, cover, basis)
		for y in [-1.5, 0, 1.5]:
			_stamp("box", at + Vector3.UP * float(y) * s + basis.x * 15.05 * s, Vector3(0.1, 0.13, 39) * s, _mat("page_lines", Color("c8bda1")), basis)


func _pencil(p: Vector3, pencil_length: float, angle: float, color_index: int) -> void:
	var colors: Array[Color] = [Color("e8b341"), Color("d5675d"), Color("5ea7bb"), Color("78a872"), Color("b78cb1")]
	var basis: Basis = Basis.from_euler(Vector3(PI * 0.5, 0, angle))
	var axis: Vector3 = basis.y
	_stamp("hex", p + Vector3.UP * 1.5, Vector3(3.3, pencil_length, 3.3), _mat("pencil%d" % posmod(color_index, 5), colors[posmod(color_index, 5)]), basis)
	_stamp("pine", p + Vector3.UP * 1.5 + axis * (pencil_length * 0.5 + 3), Vector3(3.3, 6.0, 3.3), _mat("pencil_wood", Color("ddbd83")), basis)
	_stamp("pine", p + Vector3.UP * 1.5 + axis * (pencil_length * 0.5 + 5.5), Vector3(1.3, 2.3, 1.3), _mat("graphite", Color("343845")), basis)
	_stamp("cylinder", p + Vector3.UP * 1.5 - axis * (pencil_length * 0.5 - 0.6), Vector3(3.5, 3.3, 3.5), _mat("pencil_metal", Color("b8c3c1"), 0.3, 0.65), basis)
	_stamp("cylinder", p + Vector3.UP * 1.5 - axis * (pencil_length * 0.5 + 2), Vector3(3.4, 3, 3.4), _mat("pencil_eraser", Color("e29899")), basis)


func _mug(p: Vector3, s: float, color: Color, text: String) -> void:
	var ceramic := _mat("mug_%s" % color.to_html(), color, 0.24)
	_stamp("cylinder", p + Vector3.UP * 17 * s, Vector3(27, 34, 27) * s, ceramic)
	_stamp("cylinder", p + Vector3.UP * 34.05 * s, Vector3(23, 0.25, 23) * s, _mat("coffee", Color("4a3026")))
	for i in range(20):
		var a: float = float(i) / 20 * TAU
		var b: float = float(i + 1) / 20 * TAU
		_beam(p + Vector3(cos(a) * 7 + 16, sin(a) * 11 + 17, 0) * s, p + Vector3(cos(b) * 7 + 16, sin(b) * 11 + 17, 0) * s, 2.4 * s, ceramic)
	_label(text, p + Vector3(0, 19, 13.7) * s, Basis.IDENTITY, 0.115 * s, Color("514138"))


func _glitch() -> void:
	var dark := _mat("city_dark", Color("151731"), 0.5, 0.4)
	var cyan := _mat("cyan", Color("28cde3"), 0.3, 0.2, 1.9)
	var pink := _mat("pink", Color("e755bc"), 0.3, 0.2, 1.8)
	var purple := _mat("purple", Color("6f53cc"), 0.4, 0.1, 0.85)
	_stamp("box", Vector3(0, -42, 0), Vector3(2200, 2, 2200), _mat("abyss", Color("06091c"), 0.4, 0.4))
	for i in range(int(length / 8)):
		var d: float = i * 8.0
		var p: Vector3 = sample(d)
		_stamp("box", p - Vector3.UP * 2, Vector3(23, 3.8, 8.2), dark, frame(d))
		for side in [-1.0, 1.0]:
			var edge: Vector3 = sample(d, float(side) * 10.3)
			_stamp("box", edge + Vector3.UP * 1.0, Vector3(0.7, 2.5, 8.2), _mat("rail", Color("284160"), 0.4, 0.5), frame(d))
			_stamp("box", edge + Vector3.UP * 2.4, Vector3(0.8, 0.22, 8.3), cyan if side < 0 else pink, frame(d))
			if i % 3 == 0:
				_stamp("box", edge + Vector3.UP * 3, Vector3(1.2, 3.7, 0.9), purple, frame(d))
		if i % 6 == 0:
			_stamp("box", p - Vector3.UP * (p.y + 40) * 0.5, Vector3(6, p.y + 40, 7), dark, frame(d))
	# Individual stepped towers leave the course clear and build a neon canyon.
	for i in range(125):
		var p := Vector3(_rng.randf_range(-440, 440), -40, _rng.randf_range(-450, 410))
		if _distance_to_road(p) < 35:
			continue
		var h: float = _rng.randf_range(32, 180)
		var w: float = _rng.randf_range(16, 34)
		var depth: float = _rng.randf_range(19, 40)
		_stamp("box", p + Vector3.UP * h * 0.5, Vector3(w, h, depth), dark)
		_stamp("box", p + Vector3.UP * h, Vector3(w + 1, 1.1, depth + 1), cyan if i % 3 == 0 else purple)
		for level in range(3, int(h / 6)):
			var y: float = level * 6.0
			if _rng.randf() > 0.3:
				_stamp("box", p + Vector3(0, y, depth * 0.5 + 0.08), Vector3(w * 0.7, 1.6, 0.12), cyan if i % 2 == 0 else pink)
			if level % 2 == 0:
				_stamp("box", p + Vector3(w * 0.5 + 0.08, y, 0), Vector3(0.12, 1.5, depth * 0.7), purple)
		if i % 5 == 0:
			_stamp("box", p + Vector3(w * 0.5 + 0.1, h * 0.55, 0), Vector3(0.2, h * 0.8, 2), pink)
	for i in range(20):
		var a: float = i / 20.0 * TAU
		var p := Vector3(cos(a) * 700, -10, sin(a) * 700)
		_stamp("box", p, Vector3(70, _rng.randf_range(180, 380), 90), _mat("far_city", Color("202343")))
	for fraction in [0.1, 0.35, 0.6, 0.82]:
		var d: float = length * float(fraction)
		for side in [-1.0, 1.0]:
			_stamp("box", sample(d, float(side) * 12) + Vector3.UP * 9, Vector3(1.8, 18, 1.8), dark, frame(d))
			_stamp("box", sample(d, float(side) * 11.4) + Vector3.UP * 9, Vector3(0.4, 18, 0.5), cyan if side < 0 else pink, frame(d))
		_stamp("box", sample(d) + Vector3.UP * 18, Vector3(26, 2, 2), dark, frame(d))
		_stamp("box", sample(d) + Vector3.UP * 17.6, Vector3(24, 0.35, 2.2), cyan, frame(d))
		_label("» » »   HYPERPAWS   » » »", sample(d) + Vector3.UP * 20.5, frame(d), 0.026, Color("7feaff"))
	_sign(95, -18, "GLITCH\nCORE →", Color("253050"), 12, 8, Color("7df0f6"))
	_sign(length * 0.49, 18, "WARP. DRIFT.\nSURVIVE.", Color("2b224e"), 14, 9, Color("f69de6"))
	# Giant floating pixel cat sign and particle-like light cubes.
	_pixel_cat(Vector3(-10, 132, -240), 4.1, cyan)
	_pixel_cat(Vector3(290, 118, 150), 2.8, pink)
	for i in range(100):
		var p := Vector3(_rng.randf_range(-330, 330), _rng.randf_range(12, 135), _rng.randf_range(-330, 330))
		if _distance_to_road(p) > 20:
			_stamp("box", p, Vector3.ONE * _rng.randf_range(0.35, 1.3), cyan if i % 2 == 0 else pink)


func _pixel_cat(p: Vector3, s: float, mat: StandardMaterial3D) -> void:
	var rows: Array[String] = ["110000000011", "101000000101", "100111111001", "100000000001", "100000000001", "101100001101", "100000000001", "100001100001", "010010010010", "001100001100"]
	for row in range(rows.size()):
		for col in range(rows[row].length()):
			if rows[row][col] == "1":
				_stamp("box", p + Vector3((col - 5.5) * s, (5 - row) * s, 0), Vector3(s * 0.86, s * 0.86, s * 0.35), mat)


func _start_gate() -> void:
	var d: float = 38.0
	var p: Vector3 = sample(d)
	var basis: Basis = frame(d)
	var wood := _mat("gate_posts", Color("754d31") if _course != 2 else Color("263047"))
	var sign_color := Color("ab6e38") if _course != 2 else Color("263051")
	for side in [-1.0, 1.0]:
		_stamp("box", sample(d, float(side) * 12.5) + Vector3.UP * 9.1, Vector3(1.3, 19.3, 1.4), wood, basis)
		_stamp("sphere", sample(d, float(side) * 12.5) + Vector3.UP * 19.1, Vector3(1.9, 1.7, 1.9), _mat("gate_cap", Color("e6bb70")))
	for row in range(3):
		_stamp("box", p + Vector3.UP * (16.2 + row * 1.6), Vector3(30.0 + (1.3 if row == 1 else 0.0), 1.55, 1.05), _mat("gate_sign", sign_color), basis * Basis.from_euler(Vector3(0, 0, 0.01 * (row - 1))))
	_label("MINECRAFT RACING" if _mode == "minecraft" else "DOODLE RALLY", p + Vector3.UP * 18.0 + basis.z * 0.66, basis, 0.031 if _mode == "minecraft" else 0.039, Color("30241d") if _course != 2 else Color("7cebf6"), 23.3)
	_stamp("box", p + Vector3.UP * 13.5, Vector3(21, 2.8, 0.8), wood, basis)
	_label("BUILD. RACE. REPEAT." if _mode == "minecraft" else "SMALL CATS. BIG ADVENTURES.", p + Vector3.UP * 13.5 + basis.z * 0.53, basis, 0.013, Color("fff0d0"), 19.0)
	for side in [-1.0, 1.0]:
		var flag_p: Vector3 = sample(d, float(side) * 15.4) + Vector3.UP * 13.0
		for row in range(4):
			for col in range(3):
				_stamp("box", flag_p + basis.x * ((col - 1) * 1.2) + Vector3.UP * ((row - 1.5) * 1.2), Vector3(1.2, 1.2, 0.11), _mat("checker_white", Color("fff5d4")) if (row + col) % 2 == 0 else _mat("checker_black", Color("20212d")), basis)


func _sign(distance: float, lane: float, text: String, color: Color, width: float, height: float, ink: Color = Color("4e3324")) -> void:
	var basis: Basis = frame(distance)
	var p: Vector3 = sample(distance, lane)
	var wood := _mat("sign_stake", Color("86603b"))
	for side in [-1.0, 1.0]:
		_stamp("box", p + basis.x * float(side) * width * 0.35 + Vector3.UP * 3.9, Vector3(0.65, 9.0, 0.7), wood, basis)
	_stamp("box", p + Vector3.UP * 7.5, Vector3(width + 0.6, height + 0.6, 0.8), wood, basis)
	_stamp("box", p + Vector3.UP * 7.5 + basis.z * 0.5, Vector3(width, height, 0.45), _mat("sign_%s" % color.to_html(), color), basis)
	_label(text, p + Vector3.UP * 7.5 + basis.z * 0.79, basis, width / maxf(8.0, float(text.length())) * 0.023, ink, width * 0.88)


func _label(text: String, p: Vector3, basis: Basis, pixel_size: float, color: Color, max_width: float = 0.0) -> void:
	var label := Label3D.new()
	label.text = text
	if ResourceLoader.exists("res://assets/fonts/Kalam-Bold.ttf"):
		label.font = load("res://assets/fonts/Kalam-Bold.ttf") as Font
	label.font_size = 96
	label.pixel_size = pixel_size
	if max_width > 0.0:
		var chosen_font: Font = label.font if label.font != null else ThemeDB.fallback_font
		var widest: float = 1.0
		for line in text.split("\n"):
			widest = maxf(widest, chosen_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 96).x)
		label.pixel_size = minf(pixel_size, max_width / widest)
	label.modulate = color
	label.outline_size = 1
	label.outline_modulate = color
	label.no_depth_test = false
	label.shaded = false
	label.transform = Transform3D(basis, p)
	add_child(label)


func _distance_to_road(p: Vector3) -> float:
	var best: float = INF
	for road_p in _road_points:
		var a := Vector2(p.x, p.z)
		var b := Vector2(road_p.x, road_p.z)
		best = minf(best, a.distance_squared_to(b))
	return sqrt(best)


func _mat(key: String, color: Color, roughness: float = 0.83, metallic: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission > 0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	_materials[key] = material
	return material


func _texture_mat(key: String, path: String, tint: Color = Color.WHITE) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material: StandardMaterial3D = _mat(key, tint)
	if ResourceLoader.exists(path):
		material.albedo_texture = load(path) as Texture2D
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


func _noise_mat(key: String, low: Color, high: Color, frequency: float) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var mat: StandardMaterial3D = _mat(key, Color.WHITE)
	var noise := FastNoiseLite.new()
	noise.seed = 1719
	noise.frequency = frequency
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([low.srgb_to_linear(), high.srgb_to_linear()])
	texture.color_ramp = gradient
	mat.albedo_texture = texture
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat


func _mesh(shape: String) -> Mesh:
	if _meshes.has(shape):
		return _meshes[shape] as Mesh
	var mesh: Mesh
	if shape.begins_with("cliff"):
		mesh = load("res://scripts/world_meshes.gd").cliff(int(shape.right(1)))
		_meshes[shape] = mesh
		return mesh
	if shape in ["foliage", "foliage_shadow"]:
		mesh = load("res://scripts/world_meshes.gd").pine_branches()
		_meshes[shape] = mesh
		return mesh
	if shape == "grass":
		mesh = load("res://scripts/world_meshes.gd").grass()
		_meshes[shape] = mesh
		return mesh
	if shape in ["ridge", "ridge_snow"]:
		mesh = load("res://scripts/world_meshes.gd").ridge(shape == "ridge_snow")
		_meshes[shape] = mesh
		return mesh
	if shape == "cat_ear":
		mesh = load("res://scripts/world_meshes.gd").cat_ear()
		_meshes[shape] = mesh
		return mesh
	if shape == "plank":
		mesh = load("res://scripts/world_meshes.gd").plank()
		_meshes[shape] = mesh
		return mesh
	if shape == "branch_card":
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		_meshes[shape] = plane
		return plane
	match shape:
		"box":
			var box := BoxMesh.new()
			box.size = Vector3.ONE
			mesh = box
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			sphere.radial_segments = 16
			sphere.rings = 8
			mesh = sphere
		_:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.0 if shape in ["pine", "mountain"] else (0.43 if shape == "rock" else 0.5)
			cylinder.bottom_radius = 0.5
			cylinder.height = 1.0
			cylinder.radial_segments = 6 if shape in ["hex", "mountain"] else (8 if shape in ["pine", "rock"] else 12)
			cylinder.rings = 1
			mesh = cylinder
	_meshes[shape] = mesh
	return mesh


func _stamp(shape: String, p: Vector3, size: Vector3, material: StandardMaterial3D, basis: Basis = Basis.IDENTITY) -> void:
	var actual_shape: String = shape
	if shape == "rock":
		actual_shape = "box" if _mode == "minecraft" else "cliff%d" % posmod(int(p.x * 0.7 + p.z * 0.3), 3)
		material.vertex_color_use_as_albedo = true
	var key: String = "%s:%s" % [actual_shape, material.get_instance_id()]
	if shape == "branch_card":
		key += ":%d:%d" % [floori(p.x / 120.0), floori(p.z / 120.0)]
	if not _batches.has(key):
		_batches[key] = {"mesh": _mesh(actual_shape), "material": material, "transforms": [], "shape": shape}
	var entries: Array = _batches[key]["transforms"]
	entries.append(Transform3D(basis * Basis.from_scale(size), p))


func _beam(a: Vector3, b: Vector3, width: float, material: StandardMaterial3D) -> void:
	var delta: Vector3 = b - a
	var direction: Vector3 = delta.normalized()
	var axis_x: Vector3 = Vector3.UP.cross(direction).normalized()
	if axis_x.length_squared() < 0.5:
		axis_x = Vector3.RIGHT
	var axis_z: Vector3 = axis_x.cross(direction).normalized()
	_stamp("cylinder", (a + b) * 0.5, Vector3(width, delta.length(), width), material, Basis(axis_x, direction, axis_z))


func _flush_batches() -> void:
	for key in _batches:
		var data: Dictionary = _batches[key]
		var transforms: Array = data["transforms"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = data["mesh"] as Mesh
		mm.instance_count = transforms.size()
		for i in range(transforms.size()):
			mm.set_instance_transform(i, transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = mm
		instance.material_override = data["material"] as Material
		if data["shape"] in ["branch_card", "grass", "ridge", "ridge_snow"]:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif data["shape"] == "foliage_shadow":
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		add_child(instance)
	_batches.clear()


func _process(delta: float) -> void:
	_elapsed += delta
	for material in _animated_materials:
		material.set_shader_parameter("flow_time", _elapsed)
