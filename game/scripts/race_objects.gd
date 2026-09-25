extends Node3D
## Item boxes, track boosts and transient race effects are real 3D objects.
const PURR_WAVE_DURATION := 1.2
var boxes: Array[Node3D] = []
var shields: Array[MeshInstance3D] = []
var parries: Array[Node3D] = []
var hazard_nodes: Array[Node3D] = []
var hazard_parts: Array[Dictionary] = []
var tossed_items: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var waves: Array[Dictionary] = []
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
		var parry := Node3D.new()
		parry.name = "PawfectParry_%d" % i
		var parry_ring := MeshInstance3D.new()
		var parry_mesh := TorusMesh.new()
		parry_mesh.inner_radius = 2.45
		parry_mesh.outer_radius = 2.76
		parry_mesh.rings = 32
		parry_mesh.ring_segments = 10
		parry_ring.mesh = parry_mesh
		parry_ring.position.y = 1.12
		parry_ring.material_override = _material("paw_parry_ring", Color("ffe06d"), true)
		parry_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parry.add_child(parry_ring)
		var paw_glint := _material("paw_parry_glint", Color("fff3c4"), true)
		for glint_index in range(4):
			var angle := TAU * float(glint_index) / 4.0
			var glint_mesh := SphereMesh.new()
			glint_mesh.radius = .24
			glint_mesh.height = .42
			glint_mesh.radial_segments = 10
			glint_mesh.rings = 6
			var glint := MeshInstance3D.new()
			glint.mesh = glint_mesh
			glint.position = Vector3(cos(angle) * 2.60, 1.12, sin(angle) * 2.60)
			glint.material_override = paw_glint
			glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parry.add_child(glint)
		parry.visible = false
		add_child(parry)
		parries.append(parry)
	for i in range(40):
		var node := Node3D.new()
		var yarn := Node3D.new()
		node.add_child(yarn)
		var yarn_mesh := SphereMesh.new()
		yarn_mesh.radius = .85
		yarn_mesh.height = 1.7
		yarn_mesh.radial_segments = 14
		yarn_mesh.rings = 8
		var ball := MeshInstance3D.new()
		ball.mesh = yarn_mesh
		ball.material_override = _material("yarn", Color("ee78b7"))
		yarn.add_child(ball)
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
			yarn.add_child(stripe)
		var feather := Node3D.new()
		node.add_child(feather)
		var feather_mesh := CapsuleMesh.new()
		# These are road obstacles seen from a shallow chase camera. A small
		# ground-hugging plume is practically invisible at race speed, so make
		# each feather a broad, floating wind-sigil with a strong silhouette.
		feather_mesh.radius = .52
		feather_mesh.height = 4.0
		feather_mesh.radial_segments = 10
		feather_mesh.rings = 5
		var plume := MeshInstance3D.new()
		plume.mesh = feather_mesh
		plume.rotation.z = PI * .5
		plume.position.y = 1.58
		plume.scale = Vector3(1.0, 1.0, .88)
		plume.material_override = _material("feather_%d" % (i % 3), [Color("ffd36b"), Color("f69ac4"), Color("b4e8e5")][i % 3], true)
		feather.add_child(plume)
		var shaft := _cube(feather, Vector3(0, 1.58, 0), Vector3(3.8, .13, .18), _material("feather_shaft", Color("fff0c6"), true))
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Paired, luminous barbs give the obstacle a clear feather silhouette
		# from the shallow chase camera angle.
		var barb_material := _material("feather_barb_%d" % (i % 3), [Color("fff0c6"), Color("ffe6f5"), Color("e4fbff")][i % 3], true)
		for barb in range(4):
			var x := -1.45 + float(barb) * .96
			for side in [-1.0, 1.0]:
				var vane := _cube(feather, Vector3(x, 1.60, side * .40), Vector3(.15, .10, .88), barb_material)
				vane.rotation.y = side * .18
				vane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var treat := Node3D.new()
		node.add_child(treat)
		var treat_mesh := CylinderMesh.new()
		treat_mesh.top_radius = .96
		treat_mesh.bottom_radius = .82
		treat_mesh.height = .58
		treat_mesh.radial_segments = 20
		var biscuit := MeshInstance3D.new()
		biscuit.mesh = treat_mesh
		biscuit.position.y = .55
		biscuit.material_override = _material("treat", Color("e8a55f"), true)
		treat.add_child(biscuit)
		# Bone-shaped biscuit ends make the lure read as a cat treat at speed.
		for end in [-1.0, 1.0]:
			var bone_end_mesh := SphereMesh.new()
			bone_end_mesh.radius = .36
			bone_end_mesh.height = .52
			bone_end_mesh.radial_segments = 12
			bone_end_mesh.rings = 6
			var bone_end := MeshInstance3D.new()
			bone_end.mesh = bone_end_mesh
			bone_end.position = Vector3(end * .84, .58, 0)
			bone_end.material_override = _material("treat_bone", Color("ffd28a"), true)
			treat.add_child(bone_end)
		# A bright paw-shaped icing mark makes the shared pickup read as a
		# deliberate reward from the chase camera, instead of a small brown lump.
		for spot in range(5):
			var crumb_mesh := SphereMesh.new()
			crumb_mesh.radius = .22 if spot == 0 else .16
			crumb_mesh.height = crumb_mesh.radius * 1.8
			var crumb := MeshInstance3D.new()
			crumb.mesh = crumb_mesh
			var paw_positions := [Vector3(0, .84, .02), Vector3(-.40, .84, -.27), Vector3(-.14, .84, -.46), Vector3(.14, .84, -.46), Vector3(.40, .84, -.27)]
			crumb.position = paw_positions[spot]
			crumb.material_override = _material("treat_crumb", Color("fff0c6"), true)
			treat.add_child(crumb)
		var treat_ring_mesh := TorusMesh.new()
		treat_ring_mesh.inner_radius = 1.40
		treat_ring_mesh.outer_radius = 1.52
		treat_ring_mesh.rings = 28
		treat_ring_mesh.ring_segments = 8
		var treat_ring := MeshInstance3D.new()
		treat_ring.mesh = treat_ring_mesh
		treat_ring.position.y = .20
		treat_ring.material_override = _material("treat_ring", Color("ffd05b"), true)
		treat.add_child(treat_ring)
		for variant in [yarn, feather, treat]:
			variant.visible = false
		node.visible = false
		add_child(node)
		hazard_nodes.append(node)
		hazard_parts.append({"yarn": yarn, "feather": feather, "treat": treat, "treat_ring": treat_ring})
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
		parries[i].visible = float(_sim.racers[i].parry) > 0
		parries[i].position = _sim.racers[i].position
		parries[i].rotation.y = 0.0 if reduced else _time * 2.8
	for i in range(hazard_nodes.size()):
		var hazard_is_tossing := false
		if i < _sim.hazards.size():
			var current_id := int(_sim.hazards[i].get("id", -1))
			for toss in tossed_items:
				if int(toss.id) == current_id:
					hazard_is_tossing = true
					break
		hazard_nodes[i].visible = i < _sim.hazards.size() and not hazard_is_tossing
		if i < _sim.hazards.size():
			var hazard: Dictionary = _sim.hazards[i]
			var hazard_distance := float(hazard.distance)
			hazard_nodes[i].transform = Transform3D(_world.frame(hazard_distance), _world.sample(hazard_distance, float(hazard.lane)) + Vector3.UP * .08)
			var kind := str(hazard.get("kind", "yarn"))
			var parts: Dictionary = hazard_parts[i]
			for part_name in parts:
				(parts[part_name] as Node3D).visible = part_name == kind or (part_name == "treat_ring" and kind == "treat")
			if kind == "feather":
				hazard_nodes[i].rotation.y = sin(_time * 1.8 + i) * .30
				var feather_visual := parts.feather as Node3D
				feather_visual.position.y = 1.65 + sin(_time * 2.2 + i) * .18
				feather_visual.rotation.z = sin(_time * 2.2 + i) * .08
			elif kind == "treat":
				var treat := parts.treat as Node3D
				treat.rotation.y = _time * .75
				# Float the lure above the road so its paw icing and bone ends stay
				# legible against the track and aren't hidden by the player's kart.
				treat.position.y = 2.35 + sin(_time * 3.2 + i) * .18
	_update_tossed_items(dt, reduced)
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
	for wave in waves:
		wave.time = float(wave.time) + dt
		var owner := int(wave.owner)
		if owner >= 0 and owner < _sim.racers.size():
			var racer: Dictionary = _sim.racers[owner]
			# Lead the kart so the quake reads as a deliberate expanding attack,
			# instead of disappearing underneath the camera-followed player.
			var distance := float(racer.distance) + 5.5
			wave.node.transform = Transform3D(_world.frame(distance), _world.sample(distance, float(racer.lane)) + Vector3.UP * .32)
		for ring_index in range(wave.rings.size()):
			var ring_data: Dictionary = wave.rings[ring_index]
			var ring := ring_data.mesh as MeshInstance3D
			var material := ring_data.material as StandardMaterial3D
			var delay := float(ring_index) * .16
			var phase := clampf((float(wave.time) - delay) / PURR_WAVE_DURATION, 0, 1)
			# Start beyond the player's wheel footprint, then expand to the same
			# 26 m reach used by the simulation so the pulse is visible immediately.
			ring.scale = Vector3.ONE * (12.0 if reduced else 4.2 + phase * 21.8)
			var tint: Color = material.albedo_color
			tint.a = .72 if reduced else (.98 if float(wave.time) < delay else .98 * (1.0 - .48 * phase))
			material.albedo_color = tint
	for wave in waves:
		if float(wave.time) >= (.2 if reduced else PURR_WAVE_DURATION): wave.node.queue_free()
	waves = waves.filter(func(wave: Dictionary) -> bool: return float(wave.time) < (.2 if reduced else PURR_WAVE_DURATION))

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

func launch_purr_wave(from: int) -> void:
	var node := Node3D.new()
	var rings: Array[Dictionary] = []
	var colors := [Color("ff63ba"), Color("ffe8a1")]
	for ring_index in range(2):
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		# A broader tube survives the chase camera's shallow view of the road.
		# The former hairline ring disappeared behind the kart at gameplay scale.
		mesh.inner_radius = .82
		mesh.outer_radius = 1.0
		mesh.rings = 48
		mesh.ring_segments = 10
		ring.mesh = mesh
		# Godot's TorusMesh is already horizontal (XZ), matching the track plane.
		ring.position.y = .24 + float(ring_index) * .05
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(colors[ring_index].r, colors[ring_index].g, colors[ring_index].b, .98)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = colors[ring_index]
		material.emission_energy_multiplier = 3.0
		ring.material_override = material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(ring)
		rings.append({"mesh": ring, "material": material})
	add_child(node)
	waves.append({"node": node, "ring": rings[0].mesh, "rings": rings, "owner": from, "time": 0.0})

func launch_yarn_toss(from: int, reduced: bool = false) -> void:
	_launch_hazard_toss(from, _sim.hazards.size() - 1, "yarn", reduced)

func launch_feather_fan(from: int, reduced: bool = false) -> void:
	for hazard_index in range(maxi(0, _sim.hazards.size() - 3), _sim.hazards.size()):
		_launch_hazard_toss(from, hazard_index, "feather", reduced)

func launch_treat_toss(from: int, reduced: bool = false) -> void:
	_launch_hazard_toss(from, _sim.hazards.size() - 1, "treat", reduced)

func _launch_hazard_toss(from: int, hazard_index: int, kind: String, reduced: bool) -> void:
	if hazard_index < 0 or hazard_index >= _sim.hazards.size(): return
	var hazard: Dictionary = _sim.hazards[hazard_index]
	var hazard_id := int(hazard.get("id", -1))
	var source_racer: Dictionary = _sim.racers[from]
	var source_height := 2.65 if kind == "yarn" else 4.25 if kind == "feather" else 3.55
	var destination_height := .72 if kind == "yarn" else .46 if kind == "feather" else 1.65
	var duration := .52 if kind == "yarn" else .82 if kind == "feather" else .74
	var arc := 1.6 if kind == "yarn" else 3.1 if kind == "feather" else 2.5
	if reduced:
		duration = .18
		arc = .15
	var original := hazard_parts[hazard_index][kind] as Node3D
	var visual := original.duplicate() as Node3D
	visual.name = "Tossed_" + kind.capitalize()
	visual.visible = true
	for child in visual.get_children():
		(child as Node3D).visible = true
	visual.scale = Vector3.ONE
	add_child(visual)
	tossed_items.append({"id": hazard_id, "kind": kind, "visual": visual,
		"hazard": hazard, "source": source_racer.position + Vector3.UP * source_height,
		"destination_height": destination_height, "arc": arc, "duration": duration, "elapsed": 0.0})

func _update_tossed_items(dt: float, reduced: bool) -> void:
	for toss in tossed_items:
		toss.elapsed = float(toss.elapsed) + dt
		var phase := clampf(float(toss.elapsed) / float(toss.duration), 0, 1)
		var eased := phase * phase * (3.0 - 2.0 * phase)
		var hazard: Dictionary = toss.hazard
		var distance := float(hazard.distance)
		var target: Vector3 = _world.sample(distance, float(hazard.lane)) + Vector3.UP * float(toss.destination_height)
		var arc_height := 0.0 if reduced else float(toss.arc)
		var position: Vector3 = (toss.source as Vector3).lerp(target, eased) + Vector3.UP * sin(phase * PI) * arc_height
		var spin := 0.0 if reduced else sin(phase * PI) * .22
		var basis: Basis = _world.frame(distance) * Basis(Vector3.UP, spin)
		toss.visual.global_transform = Transform3D(basis, position)
		if phase >= 1.0:
			# Reveal only the landed hazard; queue_free is deferred until frame end.
			(toss.visual as Node3D).visible = false
			(toss.visual as Node3D).queue_free()
	tossed_items = tossed_items.filter(func(toss: Dictionary) -> bool: return float(toss.elapsed) < float(toss.duration))

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
