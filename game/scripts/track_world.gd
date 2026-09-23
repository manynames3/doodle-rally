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
const DESKTOP_DECK_TOP: float = 2.8
const DESKTOP_SHEET_TOP: float = 3.0


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
		# The neon course needs enough fill to keep the racers and props readable.
		# Its previous low value made the whole scene collapse into a flat navy card.
		env.ambient_light_energy = 0.62
		env.fog_light_color = Color("1a123b")
		env.fog_density = 0.00018
	else:
		sky_material.sky_top_color = Color("1758a5")
		sky_material.sky_horizon_color = Color("a9cfdf")
		sky_material.ground_bottom_color = Color("696d59")
		sky_material.ground_horizon_color = Color("cad0b4")
		sky_material.sky_curve = 0.6
		env.ambient_light_color = Color("a1bdd5")
		env.ambient_light_energy = 0.38
		env.fog_light_color = Color("9db9ce")
		env.fog_density = 0.00012
	sky.sky_material = sky_material
	if _course != 2:
		var day_shader := Shader.new()
		day_shader.code = """shader_type sky;
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
float fbm(vec2 p){return texture(cloud_noise,p*0.095).r;}
void sky(){
float y=max(EYEDIR.y,0.0);
vec3 horizon=vec3(0.59,0.76,0.89),zenith=vec3(0.045,0.31,0.68);
COLOR=mix(horizon,zenith,pow(y,0.34));
if(y>0.025){
vec2 uv=EYEDIR.xz/(y+0.30)*2.2;
float n=fbm(uv);
float cloud=smoothstep(0.48,0.72,n)*smoothstep(0.025,0.14,y);
float sunlight=clamp((n-fbm(uv+vec2(0.16,0.22)))*1.1+0.45,0.0,1.0);
vec3 cloud_color=mix(vec3(0.52,0.65,0.77),vec3(0.89,0.91,0.88),sunlight*0.82);
COLOR=mix(COLOR,cloud_color,cloud);
}
if(EYEDIR.y<0.0){COLOR=mix(horizon,vec3(0.10,0.14,0.11),clamp(-EYEDIR.y*3.0,0.0,1.0));}
COLOR=pow(COLOR,vec3(2.0))*1.15;
}
"""
		var day_material := ShaderMaterial.new()
		day_material.shader = day_shader
		var cloud_noise := FastNoiseLite.new()
		cloud_noise.seed = 5917
		cloud_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		cloud_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		cloud_noise.frequency = 0.005
		cloud_noise.fractal_octaves = 3
		cloud_noise.fractal_lacunarity = 2.0
		cloud_noise.fractal_gain = 0.42
		cloud_noise.domain_warp_enabled = false
		var cloud_texture := NoiseTexture2D.new()
		cloud_texture.width = 1024
		cloud_texture.height = 1024
		cloud_texture.seamless = true
		cloud_texture.noise = cloud_noise
		day_material.set_shader_parameter("cloud_noise", cloud_texture)
		sky.sky_material = day_material
	# A full panorama keeps the forward vista rich as the chase camera rounds
	# the loop. It replaces the old flat procedural sky on the two stylized
	# circuits while the quarry keeps its natural sky and haze.
	var panorama_path: String = "res://assets/world/desktop_dojo_backdrop_panorama2.jpg" if _course == 0 else "res://assets/world/glitch_core_backdrop_panorama2.jpg"
	if _course != 1 and ResourceLoader.exists(panorama_path):
		var panorama := PanoramaSkyMaterial.new()
		panorama.panorama = load(panorama_path) as Texture2D
		panorama.energy_multiplier = 0.82 if _course == 0 else 0.68
		panorama.filter = true
		sky.sky_material = panorama
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_sky_contribution = 0.24 if _course != 2 else 0.30
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		env.ssao_enabled = true
		env.ssao_radius = 3.0
		env.ssao_intensity = 1.9
		env.ssao_power = 1.5
		env.ssao_light_affect = 0.30
		env.ssil_enabled = false
		env.ssil_radius = 6.0
		env.ssil_intensity = 0.35
		if _course == 1:
			env.volumetric_fog_enabled = false
			env.volumetric_fog_density = 0.0012
			env.volumetric_fog_albedo = Color("aebecd")
			env.volumetric_fog_length = 240.0
			env.volumetric_fog_anisotropy = 0.55
			env.volumetric_fog_ambient_inject = 0.08
			env.volumetric_fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.52 if _course == 2 else 0.25
	env.glow_hdr_threshold = 1.5
	env.fog_enabled = true
	env.fog_sky_affect = 0.06
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-41.0, -34.0, 0.0)
	sun.light_color = Color("e3dcff") if _course == 2 else Color("ffe4b3")
	sun.light_energy = 0.72 if _course == 2 else 1.12
	sun.light_angular_distance = 1.2
	sun.shadow_blur = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 170.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35.0, 145.0, 0.0)
	fill.light_color = Color("73baff")
	fill.light_energy = 0.20 if _course == 2 else 0.16
	add_child(fill)
	# Local pools of colored light give the two stylized courses the same layered
	# depth as the supplied postcard renderings. Shadows stay on the sun only so
	# these lights are inexpensive and never create translucent moving halos.
	if _course == 0:
		for i in range(4):
			var desk_light := OmniLight3D.new()
			desk_light.name = "DeskWarmLight%d" % i
			desk_light.position = sample(length * (0.08 + i * 0.23)) + Vector3(0, 24, 0)
			desk_light.light_color = Color("ffd29a") if i % 2 == 0 else Color("9bdde7")
			desk_light.light_energy = 3.2
			desk_light.omni_range = 120.0
			desk_light.shadow_enabled = false
			add_child(desk_light)
	elif _course == 2:
		for i in range(6):
			var neon_light := OmniLight3D.new()
			neon_light.name = "NeonPoolLight%d" % i
			neon_light.position = sample(length * (0.06 + i * 0.16)) + Vector3(0, 18 + (i % 2) * 12, 0)
			neon_light.light_color = Color("45eaff") if i % 2 == 0 else Color("ff55d8")
			neon_light.light_energy = 4.5
			neon_light.omni_range = 145.0
			neon_light.shadow_enabled = false
			add_child(neon_light)


func _make_road() -> void:
	var dirt: StandardMaterial3D
	var edge: StandardMaterial3D
	if _course == 1:
		dirt = _noise_mat("dirt", Color("b78e5e"), Color("e0b887"), 0.075)
		if _mode != "minecraft":
			dirt = _texture_mat("dirt_physical", "res://assets/world/ground.png", Color("bdbdb6"))
			dirt.uv1_scale = Vector3(3.0, 3.0, 1.0)
			_add_surface_bump(dirt, 0.045, 2.2, 0.48)
		edge = _mat("edge", Color("795c39"))
	elif _course == 0:
		dirt = _noise_mat("paper", Color("cfc6ad"), Color("f8efd8"), 0.08)
		dirt.roughness = 0.92
		_add_surface_bump(dirt, 0.12, 1.1, 0.18)
		edge = _mat("edge", Color("a9815a"))
	else:
		dirt = _noise_mat("road", Color("111832"), Color("27345a"), 0.045)
		dirt.roughness = 0.38
		dirt.metallic = 0.34
		_add_surface_bump(dirt, 0.15, 1.3, 0.22)
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
	road.name = "RacingSurface_%s" % str(left).replace(".", "_")
	road.mesh = st.commit()
	road.material_override = mat
	add_child(road)


func _quarry() -> void:
	_lake()
	var rock_colors: Array[Color] = [Color("a69b85"), Color("928f7d"), Color("b5a690"), Color("b4ac96"), Color("848675")]
	var rock_mats: Array[StandardMaterial3D] = []
	for i in range(rock_colors.size()):
		var rock_material: StandardMaterial3D = _noise_mat("rock%d" % i, rock_colors[i].darkened(0.08), rock_colors[i].lightened(0.11), 0.07)
		if _mode != "minecraft":
			rock_material = _texture_mat("stone_physical%d" % i, "res://assets/art/alpine_limestone.png", Color(0.78 + i * 0.035, 0.79 + i * 0.035, 0.75 + i * 0.035))
			rock_material.uv1_triplanar = true
			rock_material.uv1_world_triplanar = true
			rock_material.uv1_scale = Vector3.ONE * 0.035
			rock_material.uv1_triplanar_sharpness = 4.0
			_add_surface_bump(rock_material, 0.038, 4.0, 0.65)
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
				var tree_base: Vector3 = sample(d + 4, float(side) * _rng.randf_range(23, 28)) - Vector3.UP * 0.2
				_stamp("rock", tree_base - Vector3.UP * (tree_base.y + 18) * 0.5, Vector3(27, tree_base.y + 18, 31), rock_mats[i % 5], frame(d))
				_stamp("rock", tree_base - Vector3.UP * 0.6, Vector3(22, 3.2, 24), grass, frame(d))
				_tree(tree_base, _rng.randf_range(0.82, 1.19))
				if i % 4 == 0:
					_tree(tree_base + frame(d).x * float(side) * 7 + frame(d).z * 4, _rng.randf_range(0.60, 0.89))
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
		var mountain_mat: StandardMaterial3D = _texture_mat("distant_crags", "res://assets/art/alpine_limestone.png", Color("536e81"))
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
	var close_detail: bool = _distance_to_road(p) < 55.0
	var bark: StandardMaterial3D = _texture_mat("tree_bark", "res://assets/world/wood.png", Color("6e665a"))
	var needles: StandardMaterial3D = _texture_mat("pine_needles", "res://assets/world/pine.png", Color("b9c7b1"))
	needles.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	needles.alpha_scissor_threshold = 0.38
	needles.cull_mode = BaseMaterial3D.CULL_DISABLED
	needles.roughness = 0.95
	needles.emission_enabled = true
	needles.emission_texture = needles.albedo_texture
	needles.emission = Color("819874")
	needles.emission_energy_multiplier = 0.055
	var needle_volume: StandardMaterial3D = _mat("pine_volume", Color("548142"))
	needle_volume.vertex_color_use_as_albedo = true
	needle_volume.cull_mode = BaseMaterial3D.CULL_DISABLED
	_stamp("cylinder", p + Vector3.UP * 7.0 * s, Vector3(0.65, 14, 0.65) * s, bark)
	var levels: int = 11 if close_detail else 7
	for level in range(levels):
		var height: float = 2.5 + level * (1.22 if close_detail else 1.96)
		var radius: float = 4.8 * pow(1.0 - level / float(levels + 1), 0.95)
		var branches: int = (5 if level < 6 else 4) if close_detail else 4
		for i in range(branches):
			var angle: float = TAU * i / branches + level * 0.83 + p.x * 0.2
			var outward := Vector3(cos(angle), 0, sin(angle))
			var center: Vector3 = p + (Vector3.UP * height + outward * radius * 0.48) * s
			var basis: Basis = Basis.looking_at(outward + Vector3.UP * (0.17 if level % 2 == 0 else -0.08), Vector3.UP)
			_stamp("branch_card", center, Vector3(radius * 1.25, radius * 1.1, radius * 1.8) * s, needles, basis)
			if close_detail:
				_stamp("branch_card", center + Vector3.UP * 0.18 * s, Vector3(radius * 0.95, radius * 0.95, radius * 1.7) * s, needles, basis * Basis.from_euler(Vector3(0, 0, 0.88)))
			for cluster in range(3 if close_detail and level < 8 else 0):
				var at: Vector3 = p + (Vector3.UP * (height + 0.22) + outward * radius * (0.25 + cluster * 0.28)) * s
				_stamp("needle_cluster", at, Vector3(1.4, 1.25, 1.4) * s * maxf(0.4, radius * 0.4), needle_volume, basis * Basis.from_euler(Vector3(-0.7, 0, 0)))
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
		for petal in range(5):
			var a: float = petal / 5.0 * TAU
			_stamp("sphere", at + Vector3(cos(a) * 0.2, 0.03, sin(a) * 0.2), Vector3(0.31, 0.10, 0.31), yellow if i % 2 == 0 else pink)
		_stamp("sphere", at + Vector3.UP * 0.08, Vector3(0.19, 0.13, 0.19), _mat("pollen", Color("bb7838")))
		_stamp("box", at - Vector3.UP * 0.2, Vector3(0.045, 0.7, 0.045), _mat("stems", Color("486c35")))
		_stamp("sphere", at - Vector3.UP * 0.16 + Vector3.RIGHT * 0.16, Vector3(0.4, 0.07, 0.14), _mat("leaf", Color("567937")), Basis.from_euler(Vector3(0, 0, 0.4)))


func _lake() -> void:
	if _mode == "minecraft":
		_stamp("box", Vector3(0, -20, 0), Vector3(1900, 2, 1900), _mat("water", Color("267ead"), 0.22, 0.15))
		return
	var shader := Shader.new()
	shader.code = """shader_type spatial;
uniform float flow_time=0.0;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){vec2 p=world_pos.xz;float a=sin(p.x*0.54+p.y*0.32+flow_time*0.9);float b=sin(p.x*-0.36+p.y*0.66+flow_time*1.3);float c=sin(p.x*1.23+p.y*0.47+flow_time*1.7);NORMAL_MAP=normalize(vec3(a*0.18+c*0.035,b*0.18,1.0))*0.5+0.5;ALBEDO=vec3(0.025,0.15,0.19)*(0.93+(a+b)*0.035);METALLIC=0.3;ROUGHNESS=0.17;SPECULAR=0.7;}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_animated_materials.append(mat)
	var lake := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1900, 1900)
	lake.mesh = plane
	lake.material_override = mat
	lake.position.y = -19.0
	lake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lake)


func _waterfall(top: Vector3, height: float, width: float, basis: Basis) -> void:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform float flow_time=0.0;
uniform float strand=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){return noise(p)*0.56+noise(p*2.03+4.0)*0.29+noise(p*4.01)*0.15;}
void vertex(){VERTEX.x+=sin(UV.y*18.0-flow_time*1.4+strand)*0.11;}
void fragment(){
vec2 uv=vec2(UV.x*6.0+strand,UV.y*15.0-flow_time*2.2);
float turbulent=fbm(uv);
float water=fbm(vec2(UV.x*18.0+strand,UV.y*5.0-flow_time*1.2));
float froth=smoothstep(0.43,0.72,turbulent+UV.y*0.12);
vec3 wet=vec3(0.20,0.39,0.46),foam=vec3(0.89,0.94,0.93);
ALBEDO=pow(mix(wet,foam,froth),vec3(2.0));
float edge=smoothstep(0.0,0.20,min(UV.x,1.0-UV.x)+turbulent*0.14-0.055);
ALPHA=edge*(0.28+froth*0.57)*smoothstep(0.22,0.39,water);
ROUGHNESS=mix(0.12,0.62,froth);
NORMAL=normalize(NORMAL+vec3(dFdx(turbulent)*0.4,dFdy(turbulent)*0.4,0.0));
}
"""
	for band in range(3):
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("strand", band * 1.73)
		_animated_materials.append(mat)
		var waterfall := MeshInstance3D.new()
		var mesh: ArrayMesh = load("res://scripts/world_meshes.gd").cascade(width * 0.52, height, band * 1.73)
		waterfall.mesh = mesh
		waterfall.material_override = mat
		waterfall.transform = Transform3D(basis, top + basis.x * (band - 1) * width * 0.24 + basis.z * (2.0 + band * 0.16))
		waterfall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(waterfall)
		_waterfalls.append(waterfall)
	var foam := _mat("foam", Color("bfd3ce"), 0.6)
	for i in range(8):
		var at: Vector3 = top + basis.x * _rng.randf_range(-width * 0.55, width * 0.55) - Vector3.UP * height
		_stamp("sphere", at + Vector3.UP * _rng.randf_range(0, 1.6), Vector3(_rng.randf_range(2.5, 5), 1.3, _rng.randf_range(2.5, 5)), foam)


func _cat_tunnel(distance: float, rocks: Array[StandardMaterial3D], wood: StandardMaterial3D) -> void:
	var center: Vector3 = sample(distance)
	var basis: Basis = frame(distance)
	var moss: StandardMaterial3D = _noise_mat("moss_cap", Color("36522b"), Color("698740"), 0.045)
	# Tall asymmetrical cliff faces frame a carved entrance; the route stays clear.
	for mass in [Vector4(-33, 7, -5, 1.0), Vector4(38, 18, -20, 1.25), Vector4(-57, 13, -28, 1.35)]:
		var at: Vector3 = center + basis * Vector3(mass.x, mass.y, mass.z)
		_stamp("rock", at, Vector3(44, 57, 42) * mass.w, rocks[1], basis * Basis.from_euler(Vector3(0, mass.x * 0.03, 0.03)))
		var top: Vector3 = at + Vector3.UP * 26.0 * mass.w
		_stamp("rock", top, Vector3(28, 3, 26) * mass.w, moss, basis)
		for t in range(7):
			_tree(top + basis * Vector3(sin(t * 2.4) * 11, 0.9, cos(t * 2.4) * 9), 0.7 + (t % 3) * 0.12)
	# A natural broad cap joins the two faces above the tunnel, above the clearance envelope.
	_stamp("rock", center + basis * Vector3(-3, 27, -13), Vector3(53, 28, 46), rocks[2], basis)
	_stamp("rock", center + basis * Vector3(2, 40, -13), Vector3(30, 3.1, 31), moss, basis)
	for t in range(5):
		_tree(center + basis * Vector3(-10 + t * 5, 41, -15 + sin(t) * 5), 0.7 + t * 0.05)
	for side in [-1.0, 1.0]:
		for j in range(4):
			var at: Vector3 = center + basis * Vector3(float(side) * (22 + j * 5), j * 8 + 1, 10 - j * 4)
			_stamp("rock", at, Vector3(14 + j * 2, 11, 16), rocks[(j + 1) % 5], basis * Basis.from_euler(Vector3(0, j * 0.41, float(side) * 0.12)))
			_stamp("rock", at + Vector3.UP * 4.9, Vector3(8, 1.0, 9), moss, basis)
			_flowers(at + Vector3.UP * 5.5, 5)
	# The thickness of the arched vault extends through the rocky spur.
	for z in [-13.0, -7.0, -1.0, 5.0]:
		for i in range(23):
			var angle: float = float(i) / 22.0 * PI
			var pos := Vector3(cos(angle) * 14.2, 4.1 + sin(angle) * 14.2, float(z))
			_stamp("box", center + basis * pos, Vector3(2.5, 4.1, 6.3), rocks[3], basis * Basis.from_euler(Vector3(0, 0, angle - PI * 0.5)))
		for side in [-1.0, 1.0]:
			_stamp("box", center + basis * Vector3(float(side) * 14.2, 1.0, float(z)), Vector3(4.1, 7, 6.3), rocks[3], basis)
	var portal := MultiMeshInstance3D.new()
	var portal_mesh := MultiMesh.new()
	portal_mesh.transform_format = MultiMesh.TRANSFORM_3D
	portal_mesh.mesh = load("res://scripts/world_meshes.gd").tunnel_portal()
	portal_mesh.instance_count = 1
	portal_mesh.set_instance_transform(0, Transform3D.IDENTITY)
	portal.multimesh = portal_mesh
	portal.material_override = rocks[2]
	portal.transform = Transform3D(basis, center)
	add_child(portal)
	for side in [-1.0, 1.0]:
		for row in range(3):
			_stamp("box", center + basis * Vector3(float(side) * 15.05, row * 2.8 - 1.5, 13.0), Vector3(4.9, 2.7, 4.0), rocks[2], basis)
	# A single stone cat mask sits against the rock with shallow carved eyes and muzzle.
	var sculpt: StandardMaterial3D = _texture_mat("sculpted_limestone", "res://assets/art/alpine_limestone.png", Color("b3b09f"))
	sculpt.uv1_triplanar = true
	sculpt.uv1_world_triplanar = true
	sculpt.uv1_scale = Vector3.ONE * 0.06
	sculpt.cull_mode = BaseMaterial3D.CULL_DISABLED
	_stamp("sphere", center + basis * Vector3(0, 23.4, 10.2), Vector3(29, 16, 11.0), sculpt, basis)
	for side in [-1.0, 1.0]:
		_stamp("cat_ear", center + basis * Vector3(float(side) * 10.0, 29.0, 11.3), Vector3(7.7, 10.0, 5.5), sculpt, basis * Basis.from_euler(Vector3(0, 0, float(side) * -0.17)))
		_stamp("cat_ear_inlay", center + basis * Vector3(float(side) * 10.0, 29.2, 14.1), Vector3(3.9, 5.8, 0.2), _mat("ear_stone", Color("93826a"), 0.95, 0, 0.08), basis * Basis.from_euler(Vector3(0, 0, float(side) * -0.17)))
		_stamp("sphere", center + basis * Vector3(float(side) * 5.9, 25.2, 14.9), Vector3(3.1, 1.6, 0.20), _mat("carved_eye", Color("6d7550")), basis)
		_stamp("sphere", center + basis * Vector3(float(side) * 5.9, 25.2, 15.02), Vector3(0.45, 1.4, 0.08), _mat("pupil", Color("313a2a")), basis)
		_stamp("sphere", center + basis * Vector3(float(side) * 3.2, 22.4, 14.1), Vector3(7.5, 4.0, 3.3), sculpt, basis)
		for whisker in range(3):
			_beam(center + basis * Vector3(float(side) * 7, 21.5 - whisker * 0.65, 15.0), center + basis * Vector3(float(side) * 12, 22.5 - whisker * 1.1, 13.8), 0.11, _mat("carving_crease", Color("55584a")))
	_stamp("sphere", center + basis * Vector3(0, 22.0, 15.6), Vector3(2.2, 1.25, 0.8), _mat("nose_stone", Color("705240")), basis)
	_waterfall(center + basis * Vector3(51, 48, -5), center.y + 68.0, 13.5, basis)
	# Suspended timber walkway spans the upper cliffs, echoing the scenic racing reference.
	_scenic_bridge(center + basis * Vector3(-48, 47, -31), center + basis * Vector3(54, 54, -33), wood)
	for z in [-10, -2, 6, 13]:
		for side in [-1.0, 1.0]:
			var light_pos: Vector3 = center + basis * Vector3(float(side) * 10.1, 5.3, float(z))
			_stamp("box", light_pos, Vector3(0.35, 2.3, 0.35), wood, basis)
			_stamp("sphere", light_pos + Vector3.UP * 1.4, Vector3(0.6, 0.95, 0.6), _mat("lantern_glow", Color("ffb140"), 0.4, 0, 3.0))
			if z == 6 or z == -10:
				var lamp := OmniLight3D.new()
				lamp.position = light_pos + Vector3.UP * 1.4
				lamp.light_color = Color("ffb34f")
				lamp.light_energy = 3.0
				lamp.omni_range = 16
				add_child(lamp)


func _scenic_bridge(start: Vector3, finish: Vector3, wood: StandardMaterial3D) -> void:
	var direction: Vector3 = (finish - start).normalized()
	var side: Vector3 = direction.cross(Vector3.UP).normalized()
	var basis: Basis = Basis.looking_at(direction, Vector3.UP)
	var spans: int = 32
	for i in range(spans + 1):
		var t: float = i / float(spans)
		var at: Vector3 = start.lerp(finish, t) - Vector3.UP * sin(t * PI) * 4.8
		_stamp("plank", at, Vector3(8.0, 0.6, start.distance_to(finish) / spans * 0.95), wood, basis)
		if i % 3 == 0:
			for sign_side in [-1.0, 1.0]:
				_stamp("box", at + side * float(sign_side) * 3.8 + Vector3.UP * 2.3, Vector3(0.55, 5.2, 0.55), wood, basis)
		if i > 0:
			var prev_t: float = (i - 1) / float(spans)
			var prev: Vector3 = start.lerp(finish, prev_t) - Vector3.UP * sin(prev_t * PI) * 4.8
			for sign_side in [-1.0, 1.0]:
				for h in [1.7, 4.1]:
					_beam(prev + side * float(sign_side) * 3.8 + Vector3.UP * float(h), at + side * float(sign_side) * 3.8 + Vector3.UP * float(h), 0.28, wood)


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
	# Keep the racing sightline clear even when the chase camera lifts in traffic.
	height += 2.0
	var colors: Array[Color] = [Color("e56f5b"), Color("ecc65c"), Color("66b7ad"), Color("bc85b4")]
	var wood := _mat("bark", Color("6d4f36"))
	for side in [-1.0, 1.0]:
		_stamp("cylinder", sample(d, float(side) * 13) + Vector3.UP * (height * 0.5), Vector3(0.45, height + 1, 0.45), wood)
	for i in range(count):
		var lane: float = lerpf(-12.5, 12.5, float(i) / maxf(1, count - 1))
		var p: Vector3 = sample(d, lane) + Vector3.UP * (height - 1.0 * sin(float(i) / maxf(1, count - 1) * PI))
		_stamp("pine", p - Vector3.UP * .66, Vector3(1.35, 1.55, 0.10), _mat("flag%d" % (i % 4), colors[i % 4]), frame(d) * Basis.from_euler(Vector3(PI, 0, 0)))
		if i > 0:
			var old_lane: float = lerpf(-12.5, 12.5, float(i - 1) / maxf(1, count - 1))
			var old: Vector3 = sample(d, old_lane) + Vector3.UP * (height - 1.0 * sin(float(i - 1) / maxf(1, count - 1) * PI))
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
	# Use the same tactile timber tile as the quarry bridges. The old low-contrast
	# noise floor read as a flat brown plane at racing speed.
	var wood: StandardMaterial3D = _texture_mat("desk_wood_physical", "res://assets/world/wood.png", Color("c39a6c"))
	wood.uv1_triplanar = true
	wood.uv1_world_triplanar = true
	wood.uv1_scale = Vector3.ONE * 0.018
	wood.uv1_triplanar_sharpness = 3.0
	wood.roughness = 0.91
	_add_surface_bump(wood, 0.065, 1.45, 0.22)
	# Keep the deck and paper top faces apart. They used to share y=3 exactly,
	# which made the depth buffer flicker across the tabletop as the chase camera moved.
	_stamp("box", Vector3(0, DESKTOP_DECK_TOP - 10.0, -15), Vector3(980, 20, 1080), wood)
	var paper := _noise_mat("sheet", Color("d5cbb2"), Color("f4ead2"), 0.065)
	paper.roughness = 0.94
	_add_surface_bump(paper, 0.18, 0.7, 0.12)
	# The old graph-paper grid was made from hundreds of razor-thin boxes.
	# Those strips alias at the shallow chase-camera angle and produced a
	# shimmering checkerboard outside the road as the kart moved.  Keep the
	# sheet itself textured and reserve drawn markings for the actual road.
	_stamp("box", Vector3(0, DESKTOP_SHEET_TOP - 0.5, 0), Vector3(900, 1, 950), paper)
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
	var wall_wood: StandardMaterial3D = _texture_mat("desk_backdrop_wood", "res://assets/world/wood.png", Color("76523f"))
	wall_wood.uv1_triplanar = true
	wall_wood.uv1_world_triplanar = true
	wall_wood.uv1_scale = Vector3.ONE * 0.024
	wall_wood.roughness = 0.95
	_stamp("box", Vector3(0, 93, -435), Vector3(970, 185, 8), wall_wood)
	# Thick beams and shelves frame the windows, adding real foreground depth to
	# the little paper circuit instead of a wall of flat pastel boxes.
	for x in [-470.0, -315.0, -155.0, 5.0, 165.0, 325.0, 470.0]:
		_stamp("box", Vector3(x, 94, -420), Vector3(8, 182, 12), wood)
	for y in [26.0, 72.0, 118.0, 161.0]:
		_stamp("box", Vector3(0, y, -411), Vector3(950, 6, 19), wood)
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
		# Lift the stationery clear of the sheet so its underside never
		# intersects the paper surface and creates a second source of shimmer.
		var p := Vector3(_rng.randf_range(-390, 390), 3.95, _rng.randf_range(-340, 340))
		if _distance_to_road(p) > 28:
			_stamp("box", p, Vector3(18, 1.3, 12), _mat("eraser%d" % (i % 3), [Color("e6a4b0"), Color("a5c8da"), Color("edc368")][i % 3]), Basis.from_euler(Vector3(0, _rng.randf_range(-1, 1), 0)))
	# Keep the first sign as a readable landmark without letting it cover the
	# whole left side of the camera view.
	_sign(85, -28, "DRAW. RACE.\nREPEAT.", Color("f1d88e"), 8.5, 5.7)
	_sign(length * 0.3, 18, "DESKTOP\nDOJO →", Color("bce2dd"), 12, 8)
	_sign(length * 0.69, -18, "GOOD IDEAS\nGO FAST", Color("eebac4"), 12, 8)
	_bunting(115, 10, 9)
	_bunting(length * 0.55, 11, 9)
	# Oversized stationery landmarks echo the reference card: a ruler bridge,
	# sticky-note ramps and scattered paper clips around the racing line.
	var ruler := _mat("ruler_blue", Color("74b6d0"), 0.65, 0.05)
	for fraction in [0.18, 0.48, 0.77]:
		var marker_d: float = length * float(fraction)
		var marker_basis: Basis = frame(marker_d)
		for side in [-1.0, 1.0]:
			var note_p: Vector3 = sample(marker_d, float(side) * 26.0) + Vector3.UP * 0.85
			_stamp("box", note_p, Vector3(15, 0.18, 10), _mat("sticky_%d" % int(fraction * 100), [Color("e8a1ad"), Color("e5c05b"), Color("82bdd2")][int(fraction * 100) % 3]), marker_basis * Basis.from_euler(Vector3(0.0, 0.0, 0.035 * side)))
		_stamp("box", sample(marker_d) + Vector3.UP * 1.15, Vector3(20.0, 0.20, 1.2), ruler, marker_basis)


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
	var dark := _noise_mat("city_dark", Color("0c1026"), Color("252957"), 0.055)
	dark.roughness = 0.43
	dark.metallic = 0.48
	_add_surface_bump(dark, 0.12, 1.0, 0.18)
	var cyan := _mat("cyan", Color("28cde3"), 0.26, 0.3, 2.45)
	var pink := _mat("pink", Color("e755bc"), 0.26, 0.3, 2.25)
	var purple := _mat("purple", Color("6f53cc"), 0.33, 0.2, 1.18)
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
	# A repeating pair of illuminated server pylons gives the route a readable
	# vanishing point and breaks up the random-box skyline.
	for i in range(9):
		var d: float = length * (0.06 + i * 0.105)
		var pylon_basis: Basis = frame(d)
		for side in [-1.0, 1.0]:
			var pylon_p: Vector3 = sample(d, float(side) * 24.0)
			_stamp("box", pylon_p + Vector3.UP * 19.0, Vector3(4.8, 38.0, 4.8), dark, pylon_basis)
			for level in range(4):
				var level_p: Vector3 = pylon_p + Vector3.UP * (7.0 + level * 8.0)
				_stamp("box", level_p + pylon_basis.z * 2.48, Vector3(3.7, 1.25, 0.14), cyan if (i + level) % 2 == 0 else pink, pylon_basis)
			_stamp("box", pylon_p + Vector3.UP * 39.2, Vector3(6.4, 1.0, 6.4), cyan if side < 0 else pink, pylon_basis)
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
	_sign(95, -28, "GLITCH\nCORE →", Color("253050"), 9.5, 6.4, Color("7df0f6"))
	_sign(length * 0.49, 18, "WARP. DRIFT.\nSURVIVE.", Color("2b224e"), 14, 9, Color("f69de6"))
	# Giant floating pixel cat sign and particle-like light cubes.
	_pixel_cat(Vector3(-10, 132, -240), 4.1, cyan)
	_pixel_cat(Vector3(290, 118, 150), 2.8, pink)
	for i in range(72):
		var p := Vector3(_rng.randf_range(-330, 330), _rng.randf_range(12, 135), _rng.randf_range(-330, 330))
		if _distance_to_road(p) > 20:
			_stamp("box", p, Vector3.ONE * _rng.randf_range(0.28, 0.95), cyan if i % 2 == 0 else pink)


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


func _scenic_backdrop(path: String, tint: Color, radius: float, center_y: float) -> void:
	# Four distant, inward-facing quads form a lightweight scenic horizon. They
	# are deliberately far beyond the playable props, so the generated vista
	# supplies atmosphere while the real road, karts and landmarks remain 3D.
	if not ResourceLoader.exists(path): return
	var texture := load(path) as Texture2D
	if texture == null: return
	var aspect: float = float(texture.get_width()) / maxf(1.0, float(texture.get_height()))
	var width: float = 1850.0
	var height: float = width / maxf(1.0, aspect)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = texture
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 0.12 if _course == 0 else 0.20
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for side in range(4):
		var angle: float = side * PI * 0.5
		var quad := QuadMesh.new()
		quad.size = Vector2(width, height)
		var backdrop := MeshInstance3D.new()
		backdrop.name = "ScenicBackdrop%d" % side
		backdrop.mesh = quad
		backdrop.material_override = material
		backdrop.position = Vector3(cos(angle) * radius, center_y, sin(angle) * radius)
		backdrop.rotation_degrees = Vector3(0, rad_to_deg(angle), 0)
		backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(backdrop)


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


func _add_surface_bump(material: StandardMaterial3D, frequency: float, strength: float, normal_scale: float) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 1831
	noise.frequency = frequency
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	texture.as_normal_map = true
	texture.bump_strength = strength
	material.normal_enabled = true
	material.normal_texture = texture
	material.normal_scale = normal_scale


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
	if shape.begins_with("boulder"):
		mesh = load("res://scripts/world_meshes.gd").boulder(int(shape.right(1)))
		_meshes[shape] = mesh
		return mesh
	if shape == "needle_cluster":
		mesh = load("res://scripts/world_meshes.gd").needle_cluster()
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
	if shape in ["cat_ear", "cat_ear_inlay"]:
		mesh = load("res://scripts/world_meshes.gd").cat_ear()
		_meshes[shape] = mesh
		return mesh
	if shape == "plank":
		mesh = load("res://scripts/world_meshes.gd").plank()
		_meshes[shape] = mesh
		return mesh
	if shape == "branch_card":
		mesh = load("res://scripts/world_meshes.gd").pine_bough()
		_meshes[shape] = mesh
		return mesh
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
		var organic_shape: String = "cliff" if size.y > maxf(size.x, size.z) * 0.72 else "boulder"
		actual_shape = "box" if _mode == "minecraft" else organic_shape + str(posmod(int(p.x * 0.7 + p.z * 0.3), 3))
		material.vertex_color_use_as_albedo = true
	var key: String = "%s:%s" % [actual_shape, material.get_instance_id()]
	# Cull repeated near-field props by spatial tile; distant cliff meshes stay
	# grouped to avoid hundreds of one-rock draw calls and long launch times.
	if shape in ["branch_card", "needle_cluster", "foliage_shadow", "cylinder", "sphere", "box"]:
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
		if data["shape"] in ["branch_card", "needle_cluster", "cat_ear_inlay", "grass", "ridge", "ridge_snow"]:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif data["shape"] == "foliage_shadow":
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		add_child(instance)
	_batches.clear()


func _process(delta: float) -> void:
	_elapsed += delta
	for material in _animated_materials:
		material.set_shader_parameter("flow_time", _elapsed)
