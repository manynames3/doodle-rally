extends Node3D
## Item boxes, track boosts and transient race effects are real 3D objects.
var boxes: Array[Node3D] = []
var shields: Array[MeshInstance3D] = []
var hazard_nodes: Array[Node3D] = []
var projectiles: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var particle_mesh: MultiMeshInstance3D
var _particle_index := 0
var _time := 0.0
var _dust_time := 0.0
var _world: Node3D
var _sim: RefCounted
var _materials: Dictionary = {}

func build(world: Node3D, sim: RefCounted) -> void:
	_world = world
	_sim = sim
	for spot in sim.pickups:
		var box := Node3D.new()
		box.position = world.sample(float(spot.distance), float(spot.lane)) + Vector3.UP * 2.2
		add_child(box)
		_cube(box, Vector3.ZERO, Vector3.ONE * 1.9, _material("box", Color(.9, .52, .16, .86), false, true))
		var edge := _material("edge", Color("64dcff"), true)
		for axis in range(3):
			for a in [-1, 1]:
				for b in [-1, 1]:
					var p := Vector3.ZERO
					var size3 := Vector3.ONE * .055
					size3[axis] = 2.06
					p[(axis + 1) % 3] = a * 1.015
					p[(axis + 2) % 3] = b * 1.015
					_cube(box, p, size3, edge)
		var question := Label3D.new()
		question.text = "?"
		question.font = load("res://assets/fonts/Kalam-Bold.ttf")
		question.font_size = 110
		question.pixel_size = .014
		question.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		question.no_depth_test = false
		question.position.y = .03
		question.outline_size = 15
		question.modulate = Color("fff1bd")
		box.add_child(question)
		boxes.append(box)
	for spot in world.boost_spots:
		var pad := Node3D.new()
		pad.transform = Transform3D(world.frame(float(spot.distance)), world.sample(float(spot.distance), float(spot.lane)) + Vector3.UP * .06)
		add_child(pad)
		_cube(pad, Vector3.ZERO, Vector3(5.5, .08, 6.5), _material("pad", Color("17333f")))
		for z in range(4):
			for side in [-1, 1]:
				var bar := _cube(pad, Vector3(side * 1.0, .06, float(z) * 1.35 - 2.0), Vector3(2.7, .05, .27), _material("boost", Color("69e5ff"), true))
				bar.rotation.y = float(side) * .40
	for i in range(8):
		var shield := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 2.4
		mesh.height = 4.8
		mesh.radial_segments = 24
		mesh.rings = 12
		shield.mesh = mesh
		shield.material_override = _material("shield", Color(.28, .82, 1, .16), true, true)
		shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shield.visible = false
		add_child(shield)
		shields.append(shield)
	for i in range(24):
		var node := Node3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = .85
		mesh.height = 1.7
		mesh.radial_segments = 14
		mesh.rings = 8
		var ball := MeshInstance3D.new()
		ball.mesh = mesh
		ball.material_override = _material("yarn", Color("ee78b7"))
		node.add_child(ball)
		for ring in range(4):
			var torus := TorusMesh.new()
			torus.inner_radius = .78
			torus.outer_radius = .85
			torus.rings = 18
			torus.ring_segments = 6
			var stripe := MeshInstance3D.new()
			stripe.mesh = torus
			stripe.rotation = Vector3(ring * .8, ring * .3, ring * .5)
			stripe.material_override = _material("yarnstripe", Color("b14988"))
			node.add_child(stripe)
		node.visible = false
		add_child(node)
		hazard_nodes.append(node)
	particle_mesh = MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var puff := QuadMesh.new()
	puff.size = Vector2.ONE * 1.8
	multimesh.mesh = puff
	multimesh.instance_count = 128
	for i in range(128):
		particles.append({"life": 0.0, "position": Vector3.ZERO, "velocity": Vector3.ZERO, "color": Color.WHITE, "spark": false})
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * .0001), Vector3(0, -500, 0)))
	particle_mesh.multimesh = multimesh
	var pm := _material("particle", Color.WHITE, false, true)
	pm.vertex_color_use_as_albedo = true
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pm.billboard_keep_scale = true
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, .35, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, .72), Color(1, 1, 1, .35), Color(1, 1, 1, 0)])
	var soft_puff := GradientTexture2D.new()
	soft_puff.width = 64
	soft_puff.height = 64
	soft_puff.gradient = gradient
	soft_puff.fill = GradientTexture2D.FILL_RADIAL
	soft_puff.fill_from = Vector2(.5, .5)
	soft_puff.fill_to = Vector2(.5, 0)
	pm.albedo_texture = soft_puff
	particle_mesh.material_override = pm
	particle_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particle_mesh)

func update_visuals(dt: float, reduced: bool = false) -> void:
	_time += dt
	for i in range(boxes.size()):
		boxes[i].visible = float(_sim.pickups[i].cooldown) <= 0
		if not reduced:
			boxes[i].rotation.y = _time * .75 + i
			var road: Vector3 = _world.sample(float(_sim.pickups[i].distance), float(_sim.pickups[i].lane))
			boxes[i].position.y = road.y + 2.3 + sin(_time * 2.8 + i) * .25
	for i in range(shields.size()):
		shields[i].visible = float(_sim.racers[i].shield) > 0
		shields[i].position = _sim.racers[i].position + Vector3.UP * 1.7
	for i in range(hazard_nodes.size()):
		hazard_nodes[i].visible = i < _sim.hazards.size()
		if i < _sim.hazards.size():
			var hazard: Dictionary = _sim.hazards[i]
			hazard_nodes[i].position = _world.sample(float(hazard.distance), float(hazard.lane)) + Vector3.UP * .8
	_dust_time += dt
	if _dust_time > .10 and not reduced:
		_dust_time = 0
		for r in _sim.racers:
			if float(r.speed) < 6: continue
			var behind: Vector3 = _world.tangent(float(r.distance)) * -1.7
			var right: Vector3 = _world.frame(float(r.distance)).x * 1.2
			for side in [-1, 1]:
				var spark: bool = bool(r.drifting) and float(r.drift) > .5
				var color := Color("ffd05b") if spark and float(r.drift) >= 1.6 else Color("59cfff") if spark else Color("dfc7a3")
				_spawn_particle(r.position + behind + right * side + Vector3.UP * .5, color, spark)
	for i in range(particles.size()):
		var p := particles[i]
		if float(p.life) <= 0: continue
		p.life = maxf(0, float(p.life) - dt)
		p.position += p.velocity * dt
		var amount := float(p.life)
		var scale3 := (.22 if bool(p.spark) else 1.7 - amount * .9) * minf(1, amount * 5)
		particle_mesh.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * maxf(.0001, scale3)), p.position))
		var c: Color = p.color
		c.a = amount * .45
		particle_mesh.multimesh.set_instance_color(i, c)
	for p in projectiles:
		p.time = float(p.time) + dt
		var t := clampf(float(p.time) / .45, 0, 1)
		var destination: Vector3 = _sim.racers[int(p.target)].position + Vector3.UP * 1.8
		p.node.position = (p.start as Vector3).lerp(destination, t) + Vector3.UP * sin(t * PI) * 3
		if t >= 1: p.node.queue_free()
	projectiles = projectiles.filter(func(p: Dictionary) -> bool: return float(p.time) < .45)

func launch_fish(from: int, to: int) -> void:
	var fish := Node3D.new()
	var mat := _material("fish", Color("fff2c8"), true)
	var body := _cube(fish, Vector3.ZERO, Vector3(.65, .45, 1.5), mat)
	body.rotation.z = .3
	_cube(fish, Vector3(0, 0, .7), Vector3(1.0, .15, .35), mat)
	var start: Vector3 = _sim.racers[from].position + Vector3.UP * 2
	fish.position = start
	add_child(fish)
	projectiles.append({"node": fish, "start": start, "target": to, "time": 0.0})

func _spawn_particle(point: Vector3, color: Color, spark: bool) -> void:
	var p := particles[_particle_index]
	_particle_index = (_particle_index + 1) % particles.size()
	p.position = point
	p.velocity = Vector3(randf_range(-1, 1), 1.1 if not spark else .3, randf_range(-1, 1))
	p.life = .85
	p.color = color
	p.spark = spark

func _material(key: String, color: Color, glow: bool = false, alpha: bool = false) -> StandardMaterial3D:
	if _materials.has(key): return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = .6
	if glow:
		mat.emission_enabled = true
		mat.emission = Color(color.r, color.g, color.b)
		mat.emission_energy_multiplier = 1.1
	if alpha: mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials[key] = mat
	return mat

func _cube(parent: Node3D, pos: Vector3, size3: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size3
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node
