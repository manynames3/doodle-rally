extends Node3D
## Shared, self-contained 3D kart model. Coordinates: -Z forward, Y up.
## Every visible part is geometry; all eight drivers can be viewed from any angle.

const PALETTE: Array[Color] = [Color("e52f37"), Color("168ff0"), Color("f159b0"), Color("ff921d"), Color("9446e8"), Color("48b73d"), Color("ffd044"), Color("343849")]
const COATS: Array[Color] = [Color("24262e"), Color("9296a4"), Color("ddd7d0"), Color("e99136"), Color("e6d2b3"), Color("eb8e30"), Color("90918c"), Color("232631")]
const IRIS: Array[Color] = [Color("edcb45"), Color("9edd83"), Color("63c9ed"), Color("b8d75f"), Color("67bff9"), Color("92db76"), Color("80bcac"), Color("c9df4b")]
const VOXEL_DRIVER = preload("res://scripts/kart_voxel_driver.gd")
const FUR_SHADER = preload("res://scripts/kart_fur.gdshader")
static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}

var character_index: int = 0
var mode: String = "cats"
var _body: Node3D
var _driver: Node3D
var _tail: Node3D
var _steering: Node3D
var _front_pivots: Array[Node3D] = []
var _wheels: Array[Node3D] = []
var _flames: Array[Node3D] = []
var _sparks: Array[MeshInstance3D] = []
var _clock: float = 0.0
var _blink_clock: float = 2.6
var _eyes: Array[Node3D] = []


func build(index: int, selected_mode: String = "cats") -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_front_pivots.clear()
	_wheels.clear()
	_flames.clear()
	_sparks.clear()
	_eyes.clear()
	_clock = 0.0
	character_index = clampi(index, 0, 7)
	mode = selected_mode
	_blink_clock = 2.6 + character_index * 0.27
	_body = _node(self, "Suspension")
	_build_kart()
	if mode == "minecraft":
		_driver = _node(_body, "VoxelDriver")
		_tail = _node(_driver, "AnimationAnchor")
		VOXEL_DRIVER.build(_driver, character_index)
	else:
		_build_cat()
	_build_exhaust()
	_merge_static(_body)
	# The moving parts are separate branches; merging reduces draw calls without
	# preventing wheels, the driver, steering, eyes, and tail from moving.
	_merge_static(_driver)
	_merge_static(_tail)
	_merge_static(_steering)
	for wheel: Node3D in _wheels:
		_merge_static(wheel)
	for eye: Node3D in _eyes:
		_merge_static(eye)
	for flame: Node3D in _flames:
		flame.visible = false


func animate(delta: float, speed: float, steer: float, drift: float, boosting: bool) -> void:
	if not is_instance_valid(_body):
		return
	_clock += delta
	var moving: float = clampf(absf(speed) / 28.0, 0.0, 1.0)
	var smoothing: float = 1.0 - exp(-delta * 12.0)
	_body.position.y = sin(_clock * 17.0) * 0.016 * moving
	_body.rotation.z = lerpf(_body.rotation.z, steer * moving * 0.055, smoothing)
	_body.rotation.x = lerpf(_body.rotation.x, -0.025 if boosting else sin(_clock * 12.0) * 0.006 * moving, smoothing)
	_driver.rotation.z = lerpf(_driver.rotation.z, -steer * (0.045 + moving * 0.09) - drift * 0.035, smoothing)
	_driver.rotation.y = lerpf(_driver.rotation.y, -steer * 0.08, smoothing)
	_tail.rotation.z = sin(_clock * 3.2 + character_index) * 0.12 + steer * 0.12
	_steering.rotation.z = steer * -0.42
	for pivot: Node3D in _front_pivots:
		pivot.rotation.y = -steer * 0.35
	for wheel: Node3D in _wheels:
		wheel.rotation.x = fmod(wheel.rotation.x - speed * delta / (0.591 if mode == "cats" else 0.5), TAU)
	for i: int in range(_flames.size()):
		var flame: Node3D = _flames[i]
		flame.visible = boosting
		flame.scale = Vector3(0.8 + sin(_clock * 45.0 + i) * 0.16, 0.8 + cos(_clock * 39.0 + i) * 0.12, 0.8 + sin(_clock * 27.0 + i) * 0.24)
	for i: int in range(_sparks.size()):
		var spark: MeshInstance3D = _sparks[i]
		var phase: float = fmod(_clock * 4.0 + i * 0.17, 1.0)
		spark.visible = absf(drift) > 0.25 and moving > 0.3
		spark.position = Vector3((-1.24 if i % 2 == 0 else 1.24) + sin(i * 7.0) * phase * 0.4, 0.12 + sin(phase * PI) * 0.35, 1.1 + phase * 1.7)
		spark.scale = Vector3.ONE * (1.0 - phase)
	_blink_clock -= delta
	var eye_open: float = 1.0
	if _blink_clock < 0.0:
		eye_open = clampf(absf(_blink_clock + 0.09) / 0.09, 0.06, 1.0)
		if _blink_clock < -0.18:
			_blink_clock = 3.2 + character_index * 0.21
	for eye: Node3D in _eyes:
		eye.scale.y = eye_open


func _build_kart() -> void:
	if mode == "minecraft":
		_build_classic_kart()
		return
	var paint: StandardMaterial3D = _material(PALETTE[character_index], 0.28, 0.23)
	paint.clearcoat_enabled = true
	paint.clearcoat = 0.48
	paint.clearcoat_roughness = 0.23
	var paint_light: StandardMaterial3D = _material(PALETTE[character_index].lightened(0.065), 0.27, 0.22)
	paint_light.clearcoat_enabled = true
	paint_light.clearcoat = 0.42
	var paint_dark: StandardMaterial3D = _material(PALETTE[character_index].darkened(0.38), 0.38, 0.18)
	var rubber: StandardMaterial3D = _material(Color("20242b"), 0.91)
	var graphite: StandardMaterial3D = _material(Color("363a40"), 0.50, 0.34)
	var chrome: StandardMaterial3D = _material(Color("a4b6bd"), 0.30, 0.75)
	var cream: StandardMaterial3D = _material(Color("f6eddb"), 0.37)
	var seat: StandardMaterial3D = _material(Color("292931"), 0.89)
	# A rounded off-road buggy: generous nose, deep cockpit, wide wheel arches,
	# visible suspension and a large rear shield beneath the spoiler.
	_rounded_box(_body, Vector3(0, 0.53, 0.02), Vector3(1.88, 0.26, 3.02), graphite, 0.14)
	_rounded_box(_body, Vector3(0, 0.82, 0.10), Vector3(1.95, 0.63, 2.73), paint, 0.22)
	_rounded_box(_body, Vector3(0, 1.015, -1.235), Vector3(1.90, 0.84, 1.155), paint_light, 0.22)
	_sphere(_body, Vector3(0, 1.248, -1.02), Vector3(1.67, 0.36, 1.09), paint_light)
	_rounded_box(_body, Vector3(0, 1.225, 0.33), Vector3(1.44, 0.17, 1.64), seat, 0.18)
	# The hood badge is centered on the tall front panel, as in the references.
	_paw(_body, Vector3(0, 1.083, -1.819), 0.78, cream, true)
	for x: float in [-0.255, 0.255]:
		_rounded_box(_body, Vector3(x, 1.431, -0.995), Vector3(0.052, 0.019, 0.38), cream, 0.10)
	for x: float in [-0.26, -0.13, 0.0, 0.13, 0.26]:
		_rounded_box(_body, Vector3(x, 0.757, -1.816), Vector3(0.074, 0.084, 0.019), graphite, 0.20)
	for side: float in [-1.0, 1.0]:
		_rounded_box(_body, Vector3(side * 0.96, 0.79, 0.02), Vector3(0.23, 0.50, 1.59), paint_light, 0.20)
		_rounded_box(_body, Vector3(side * 1.075, 0.715, 0.1), Vector3(0.07, 0.22, 1.30), paint_dark, 0.15)
		for z: float in [-0.30, -0.05, 0.20, 0.45]:
			_box(_body, Vector3(side * 1.116, 0.75, z), Vector3(0.018, 0.10, 0.055), graphite)
		# Rounded fender bodies cap the large tires and extend down the rear.
		for z: float in [-1.08, 1.08]:
			_rounded_box(_body, Vector3(side * 1.105, 1.075, z), Vector3(0.75, 0.34, 1.17), paint, 0.27)
			_sphere(_body, Vector3(side * 1.105, 1.208, z), Vector3(0.70, 0.17, 0.92), paint_light)
			_cylinder_between(_body, Vector3(side * 0.66, 0.52, z - 0.18), Vector3(side * 1.105, 0.59, z), 0.070, graphite)
			_cylinder_between(_body, Vector3(side * 0.66, 0.52, z + 0.18), Vector3(side * 1.105, 0.59, z), 0.055, chrome)
			_cylinder_between(_body, Vector3(side * 0.81, 0.56, z), Vector3(side * 0.92, 0.94, z - 0.1), 0.050, chrome)
		_cylinder_between(_body, Vector3(side * 1.07, 0.57, -0.66), Vector3(side * 1.07, 0.57, 0.65), 0.062, chrome)
		_sphere(_body, Vector3(side * 0.72, 0.955, -1.794), Vector3(0.34, 0.30, 0.13), graphite)
		_sphere(_body, Vector3(side * 0.72, 0.96, -1.862), Vector3(0.245, 0.205, 0.060), _material(Color("fff0bb"), 0.18, 0.05, 0.22))
		_cylinder_between(_body, Vector3(side * 0.74, 0.73, 1.03), Vector3(side * 0.82, 1.695, 1.44), 0.068, chrome)
		_rounded_box(_body, Vector3(side * 1.285, 1.695, 1.46), Vector3(0.115, 0.33, 0.56), paint, 0.14)
		_rounded_box(_body, Vector3(side * 0.755, 0.975, 1.602), Vector3(0.22, 0.57, 0.12), graphite, 0.25)
		for y: float in [0.815, 0.96, 1.105]:
			_sphere(_body, Vector3(side * 0.755, y, 1.676), Vector3(0.123, 0.091, 0.042), _material(Color("f8434c"), 0.26, 0.07, 0.28))
		# Rivets and small bumper ends catch light without overpowering the paint.
		for y: float in [0.71, 1.425]:
			_sphere(_body, Vector3(side * 0.46, y, 1.69), Vector3(0.046, 0.046, 0.022), chrome)
		_sphere(_body, Vector3(side * 0.92, 0.65, 1.48), Vector3(0.26, 0.15, 0.13), chrome)
	_cylinder_between(_body, Vector3(-0.87, 0.53, -1.89), Vector3(0.87, 0.53, -1.89), 0.089, graphite)
	_cylinder_between(_body, Vector3(-0.78, 0.61, -1.88), Vector3(0.78, 0.61, -1.88), 0.045, chrome)
	_rounded_box(_body, Vector3(0, 1.685, 1.47), Vector3(2.68, 0.19, 0.52), paint, 0.18)
	_sphere(_body, Vector3(0, 1.772, 1.47), Vector3(2.42, 0.069, 0.32), paint_light)
	# Deep cushion and a brushed-metal roll hoop frame the kitten's lower back.
	_sphere(_body, Vector3(0, 1.225, 0.47), Vector3(1.20, 0.29, 1.11), seat)
	_rounded_box(_body, Vector3(0, 1.455, 0.94), Vector3(1.17, 0.90, 0.24), seat, 0.22)
	_rounded_box(_body, Vector3(0, 1.47, 0.805), Vector3(0.94, 0.69, 0.055), paint_dark, 0.17)
	var roll_points: Array[Vector3] = [Vector3(-0.69, 1.02, 0.84), Vector3(-0.71, 1.49, 0.88), Vector3(-0.49, 1.74, 0.93), Vector3(0.49, 1.74, 0.93), Vector3(0.71, 1.49, 0.88), Vector3(0.69, 1.02, 0.84)]
	_polyline(_body, roll_points, 0.075, chrome)
	for y: float in [0.50, 0.57, 0.64, 0.71]:
		_box(_body, Vector3(0, y, 1.47), Vector3(0.76, 0.028, 0.42), graphite)
	_rounded_box(_body, Vector3(0, 1.045, 1.575), Vector3(1.18, 1.015, 0.18), paint_dark, 0.18)
	_rounded_box(_body, Vector3(0, 1.06, 1.68), Vector3(1.075, 0.92, 0.060), paint, 0.18)
	_paw(_body, Vector3(0, 1.11, 1.722), 0.87, cream, false)
	_steering = _node(_body, "SteeringWheel", Vector3(0, 1.50, -0.65))
	var wheel_ring: MeshInstance3D = _torus(_steering, Vector3.ZERO, 0.33, 0.394, rubber)
	wheel_ring.rotation.x = PI / 2.0
	_cylinder_between(_steering, Vector3(-0.30, 0, 0), Vector3(0.30, 0, 0), 0.025, chrome)
	_cylinder_between(_steering, Vector3(0, -0.32, 0), Vector3(0, 0, 0), 0.025, chrome)
	_sphere(_steering, Vector3.ZERO, Vector3(0.155, 0.155, 0.085), paint)
	_cylinder_between(_body, Vector3(0, 1.08, -0.77), Vector3(0, 1.49, -0.62), 0.049, graphite)
	for side: float in [-1.0, 1.0]:
		for z: float in [-1.08, 1.08]:
			_build_wheel(side, z, paint, chrome, graphite, rubber)


func _build_classic_kart() -> void:
	var paint: StandardMaterial3D = _material(PALETTE[character_index], 0.26, 0.42)
	var paint_light: StandardMaterial3D = _material(PALETTE[character_index].lightened(0.18), 0.22, 0.35)
	var paint_dark: StandardMaterial3D = _material(PALETTE[character_index].darkened(0.43), 0.3, 0.3)
	var rubber: StandardMaterial3D = _material(Color("222733"), 0.88)
	var graphite: StandardMaterial3D = _material(Color("303743"), 0.43, 0.48)
	var chrome: StandardMaterial3D = _material(Color("b8cedb"), 0.21, 0.85)
	var cream: StandardMaterial3D = _material(Color("fff4d9"), 0.32)
	var black: StandardMaterial3D = _material(Color("141923"), 0.64)
	# A compact, low-slung go-kart rather than a car with an enclosed cabin.
	_box(_body, Vector3(0, 0.37, 0.05), Vector3(1.53, 0.19, 2.75), graphite)
	if mode == "minecraft":
		_box(_body, Vector3(0, 0.67, -0.18), Vector3(1.86, 0.48, 2.98), paint)
		_box(_body, Vector3(0, 0.74, -1.35), Vector3(1.59, 0.53, 0.86), paint_light)
		_box(_body, Vector3(0, 1.013, -1.15), Vector3(0.3, 0.022, 1.07), cream)
		for side: float in [-1.0, 1.0]:
			_box(_body, Vector3(side * 1.06, 0.83, 0), Vector3(0.32, 0.31, 1.36), paint_dark)
	else:
		_sphere(_body, Vector3(0, 0.67, -0.18), Vector3(1.9, 0.64, 3.05), paint)
		_sphere(_body, Vector3(0, 0.73, -1.34), Vector3(1.59, 0.67, 0.88), paint_light)
	_box(_body, Vector3(0, 0.96, 0.38), Vector3(1.29, 0.16, 1.43), black)
	# Cream racing stripe down the nose, raised very slightly above the paint.
	_sphere(_body, Vector3(0, 1.008, -1.11), Vector3(0.155, 0.035, 1.03), cream)
	for side: float in [-1.0, 1.0]:
		_sphere(_body, Vector3(side * 0.91, 0.67, 0.06), Vector3(0.33, 0.42, 2.39), paint_light)
		_box(_body, Vector3(side * 0.91, 0.46, 0.2), Vector3(0.2, 0.16, 1.7), paint_dark)
		# Fender lips, side rails, and a front bumper with polished ends.
		for z: float in [-1.11, 1.1]:
			_sphere(_body, Vector3(side * 1.05, 0.89, z), Vector3(0.62, 0.19, 0.9), paint)
			_cylinder_between(_body, Vector3(side * 0.7, 0.46, z), Vector3(side * 1.18, 0.46, z), 0.055, graphite)
		_cylinder_between(_body, Vector3(side * 1.015, 0.5, -0.62), Vector3(side * 1.015, 0.5, 0.65), 0.055, chrome)
		_sphere(_body, Vector3(side * 0.61, 0.68, -1.706), Vector3(0.33, 0.27, 0.11), graphite)
		_sphere(_body, Vector3(side * 0.61, 0.7, -1.765), Vector3(0.24, 0.15, 0.07), _material(Color("fff2bf"), 0.14, 0.12, 0.45))
		_box(_body, Vector3(side * 0.65, 0.73, 1.515), Vector3(0.17, 0.32, 0.08), graphite)
		for y: float in [0.65, 0.75, 0.85]:
			_sphere(_body, Vector3(side * 0.65, y, 1.565), Vector3(0.115, 0.072, 0.035), _material(Color("ff3849"), 0.24, 0.15, 0.4))
		for z: float in [-0.25, 0.0, 0.25, 0.5]:
			_box(_body, Vector3(side * 0.997, 0.72, z), Vector3(0.019, 0.12, 0.055), graphite)
		# Chrome spoiler struts and curved colored rear wing.
		_cylinder_between(_body, Vector3(side * 0.7, 0.68, 1.13), Vector3(side * 0.76, 1.44, 1.47), 0.045, chrome)
		_box(_body, Vector3(side * 1.22, 1.43, 1.46), Vector3(0.085, 0.28, 0.51), paint)
		_sphere(_body, Vector3(side * 0.83, 0.64, 1.5), Vector3(0.22, 0.12, 0.12), chrome)
	_cylinder_between(_body, Vector3(-0.79, 0.4, -1.74), Vector3(0.79, 0.4, -1.74), 0.075, chrome)
	_sphere(_body, Vector3(0, 1.44, 1.48), Vector3(2.53, 0.145, 0.48), paint)
	_sphere(_body, Vector3(0, 1.5, 1.5), Vector3(2.29, 0.045, 0.24), paint_light)
	# Cockpit seat, roll bar, and engine fins make the rear view feel mechanical.
	_sphere(_body, Vector3(0, 1.03, 0.57), Vector3(1.0, 0.26, 0.84), graphite)
	_sphere(_body, Vector3(0, 1.31, 0.85), Vector3(0.97, 0.83, 0.18), black)
	_sphere(_body, Vector3(0, 1.28, 0.743), Vector3(0.77, 0.62, 0.055), paint_dark)
	var roll_points: Array[Vector3] = [Vector3(-0.63, 0.85, 0.87), Vector3(-0.64, 1.28, 0.9), Vector3(-0.4, 1.54, 0.93), Vector3(0.4, 1.54, 0.93), Vector3(0.64, 1.28, 0.9), Vector3(0.63, 0.85, 0.87)]
	_polyline(_body, roll_points, 0.06, chrome)
	for y: float in [0.44, 0.51, 0.58, 0.65]:
		_box(_body, Vector3(0, y, 1.41), Vector3(0.72, 0.028, 0.34), graphite)
	_box(_body, Vector3(0, 0.81, 1.505), Vector3(0.77, 0.68, 0.11), paint_dark)
	_box(_body, Vector3(0, 0.81, 1.567), Vector3(0.68, 0.59, 0.03), paint)
	if mode == "minecraft":
		_voxel_crest(_body, Vector3(0, 0.86, 1.599), 0.49, cream)
		_voxel_crest(_body, Vector3(0, 0.765, -1.794), 0.40, cream)
	else:
		_paw(_body, Vector3(0, 0.87, 1.598), 0.51, cream, false)
		_paw(_body, Vector3(0, 0.765, -1.79), 0.41, cream, true)
	for x: float in [-0.3, 0.3]:
		for y: float in [0.57, 1.065]:
			_sphere(_body, Vector3(x, y, 1.601), Vector3(0.041, 0.041, 0.016), chrome)
	_steering = _node(_body, "SteeringWheel", Vector3(0, 1.38, -0.65))
	var wheel_ring: MeshInstance3D = _torus(_steering, Vector3.ZERO, 0.31, 0.365, rubber)
	wheel_ring.rotation.x = PI / 2.0
	_cylinder_between(_steering, Vector3(-0.28, 0, 0), Vector3(0.28, 0, 0), 0.024, chrome)
	_cylinder_between(_steering, Vector3(0, -0.29, 0), Vector3(0, 0, 0), 0.024, chrome)
	_sphere(_steering, Vector3.ZERO, Vector3(0.14, 0.14, 0.08), paint)
	_cylinder_between(_body, Vector3(0, 0.88, -0.76), Vector3(0, 1.37, -0.61), 0.04, graphite)
	for side: float in [-1.0, 1.0]:
		for z: float in [-1.08, 1.08]:
			_build_wheel(side, z, paint, chrome, graphite, rubber)


func _build_wheel(side: float, z: float, paint: StandardMaterial3D, chrome: StandardMaterial3D, graphite: StandardMaterial3D, rubber: StandardMaterial3D) -> void:
	var pivot: Node3D = _node(self, "FrontAxle" if z < 0 else "RearAxle", Vector3(side * 1.12, 0.591 if mode == "cats" else 0.5, z))
	if z < 0:
		_front_pivots.append(pivot)
	var wheel: Node3D = _node(pivot, "SpinningWheel")
	if mode == "cats": wheel.scale = Vector3(1.16, 1.17, 1.17)
	_wheels.append(wheel)
	var tire: MeshInstance3D = _cylinder(wheel, Vector3.ZERO, 0.47, 0.43, rubber)
	tire.rotation.z = PI / 2.0
	for x: float in [-0.175, 0.175]:
		var shoulder: MeshInstance3D = _torus(wheel, Vector3(x, 0, 0), 0.32, 0.505, rubber)
		shoulder.rotation.z = PI / 2.0
	var rim: MeshInstance3D = _cylinder(wheel, Vector3(side * 0.239, 0, 0), 0.303, 0.025, chrome)
	rim.rotation.z = PI / 2.0
	var inset: MeshInstance3D = _cylinder(wheel, Vector3(side * 0.26, 0, 0), 0.248, 0.024, graphite)
	inset.rotation.z = PI / 2.0
	var ring: MeshInstance3D = _torus(wheel, Vector3(side * 0.274, 0, 0), 0.255, 0.286, paint)
	ring.rotation.z = PI / 2.0
	for i: int in range(5):
		var angle: float = i * TAU / 5.0
		_cylinder_between(wheel, Vector3(side * 0.282, cos(angle) * 0.07, sin(angle) * 0.07), Vector3(side * 0.282, cos(angle + 0.17) * 0.22, sin(angle + 0.17) * 0.22), 0.029, chrome)
		_sphere(wheel, Vector3(side * 0.316, cos(angle) * 0.095, sin(angle) * 0.095), Vector3(0.018, 0.026, 0.026), chrome)
	var hub: MeshInstance3D = _cylinder(wheel, Vector3(side * 0.289, 0, 0), 0.08, 0.049, paint)
	hub.rotation.z = PI / 2.0
	var tread_material: StandardMaterial3D = _material(Color("303542"), 0.94)
	for i: int in range(18):
		var angle: float = i * TAU / 18.0
		var tread: MeshInstance3D = _box(wheel, Vector3(0, cos(angle) * 0.479, sin(angle) * 0.479), Vector3(0.31, 0.025, 0.058), tread_material)
		tread.rotation.x = angle


func _build_cat() -> void:
	var base_color: Color = COATS[character_index]
	var pattern: int = 1 if character_index in [1, 3, 5] else 2 if character_index in [0, 6] else 3 if character_index == 4 else 0
	var coat: Material = _fur_material(base_color, pattern)
	var soft_coat: Material = _fur_material(base_color.lightened(0.055), pattern)
	var white: Material = _fur_material(Color("ded9d0"))
	var pink: Material = _material(Color("d58d9b"), 0.72)
	var mouth: Material = _material(Color("483237"), 0.82)
	var point_coat: Material = _fur_material(Color("594849")) if character_index == 4 else coat
	var muzzle_coat: Material = white if character_index != 7 else _fur_material(base_color.lightened(0.10))
	_driver = _node(_body, "CatDriver")
	# The kitten sits deep in the buggy. A short pear-shaped body supports a
	# broad baby-cat head, with a soft bib and paws rather than human arms.
	_sphere(_driver, Vector3(0, 1.65, 0.29), Vector3(1.22, 1.01, 1.08), coat)
	_sphere(_driver, Vector3(0, 1.64, -0.13), Vector3(0.82, 0.70, 0.26), muzzle_coat)
	for side: float in [-1.0, 1.0]:
		_sphere(_driver, Vector3(side * 0.39, 1.23, 0.13), Vector3(0.56, 0.43, 0.73), coat)
		_sphere(_driver, Vector3(side * 0.34, 1.15, -0.24), Vector3(0.46, 0.29, 0.48), point_coat)
	var scarf: Material = _material(PALETTE[character_index].lightened(0.07), 0.77)
	_sphere(_driver, Vector3(0, 2.065, 0.14), Vector3(1.13, 0.15, 0.91), scarf)
	var scarf_end: MeshInstance3D = _sphere(_driver, Vector3(0.46, 2.035, 0.71), Vector3(0.55, 0.15, 0.24), scarf)
	scarf_end.rotation.y = -0.35
	var scarf_end_two: MeshInstance3D = _sphere(_driver, Vector3(0.35, 1.975, 0.77), Vector3(0.49, 0.12, 0.20), scarf)
	scarf_end_two.rotation.y = -0.70
	_sphere(_driver, Vector3(0, 2.034, -0.348), Vector3(0.18, 0.18, 0.061), _material(Color("e7b942"), 0.31, 0.48))
	_paw(_driver, Vector3(0, 2.04, -0.382), 0.11, _material(Color("91662c"), 0.48), true)
	# An organic head silhouette and full cheek ruffs replace the smooth ball.
	var head_center: Vector3 = Vector3(0, 2.64, 0.12)
	var head_size: Vector3 = Vector3(1.89, 1.47, 1.42)
	_fur_sphere(_driver, head_center, head_size, coat)
	_fur_outline(_driver, head_center, head_size, coat, 192)
	for side: float in [-1.0, 1.0]:
		_fur_sphere(_driver, Vector3(side * 0.60, 2.36, -0.075), Vector3(0.70, 0.66, 0.78), soft_coat)
		for j: int in range(4):
			var fluff: MeshInstance3D = _sphere(_driver, Vector3(side * (0.79 + j * 0.012), 2.50 - j * 0.105, -0.08 + j * 0.028), Vector3(0.29, 0.15, 0.33), coat)
			fluff.rotation.z = side * (0.12 + j * 0.20)
		# Rounded triangular ears have a curved outer shell and inset velvet.
		var ear: MeshInstance3D = _ear(_driver, Vector3(side * 0.63, 3.06, 0.12), Vector3(0.80, 0.57, 0.55), point_coat)
		ear.rotation.z = -side * 0.16
		var inside: MeshInstance3D = _ear(_driver, Vector3(side * 0.638, 3.109, -0.105), Vector3(0.52, 0.405, 0.065), pink)
		inside.rotation.z = -side * 0.16
		_sphere(_driver, Vector3(side * 0.59, 3.04, -0.13), Vector3(0.33, 0.21, 0.18), coat)
		for j: int in range(8):
			var ear_fuzz: MeshInstance3D = _instance(_driver, _meshes["fur_fibre"], Vector3(side * (0.49 + j * 0.021), 3.025 + j * 0.013, -0.20), Vector3(0.012, 0.11 + sin(j * 1.3) * 0.03, 0.018), soft_coat)
			ear_fuzz.rotation.z = side * 0.54
	if character_index == 5:
		_sphere(_driver, Vector3(0, 2.29, -0.40), Vector3(1.39, 0.55, 0.49), white)
	# Substantial paired whisker pads and a soft chin form a feline muzzle.
	for side: float in [-1.0, 1.0]:
		_build_eye(side)
		_fur_sphere(_driver, Vector3(side * 0.235, 2.345, -0.598), Vector3(0.61, 0.395, 0.445), muzzle_coat)
		for j: int in range(3):
			_sphere(_driver, Vector3(side * (0.255 + (j % 2) * 0.072), 2.38 - (j / 2) * 0.064, -0.806 + j * 0.006), Vector3(0.019, 0.019, 0.012), mouth)
		var whisker_material: Material = _material(Color("ddd3c4"), 0.85)
		for j: int in range(3):
			var start: Vector3 = Vector3(side * 0.39, 2.345 - j * 0.048, -0.763)
			var middle: Vector3 = Vector3(side * 0.76, 2.40 - j * 0.11, -0.747)
			var end: Vector3 = Vector3(side * (1.07 + (0.04 if j == 1 else 0.0)), 2.455 - j * 0.155, -0.676)
			_polyline(_driver, [start, middle, end], 0.007, whisker_material)
		# The forelegs are short soft ovals tucked against the body. Mittens
		# drape over the wheel rim, with tiny toe grooves instead of fingers.
		_soft_limb(_driver, Vector3(side * 0.44, 1.77, -0.04), Vector3(side * 0.385, 1.535, -0.48), 0.20, coat)
		var paw_mat: Material = point_coat if character_index == 4 else white if character_index in [0, 2, 5, 6] else soft_coat
		_fur_sphere(_driver, Vector3(side * 0.37, 1.545, -0.605), Vector3(0.43, 0.325, 0.40), paw_mat)
		for j: int in range(2):
			_cylinder_between(_driver, Vector3(side * 0.37 - 0.052 + j * 0.104, 1.57, -0.795), Vector3(side * 0.37 - 0.052 + j * 0.104, 1.495, -0.779), 0.006, _material(base_color.darkened(0.28), 0.9))
	_fur_sphere(_driver, Vector3(0, 2.208, -0.50), Vector3(0.80, 0.255, 0.47), muzzle_coat)
	_sphere(_driver, Vector3(0, 2.458, -0.828), Vector3(0.181, 0.105, 0.082), pink)
	_sphere(_driver, Vector3(0, 2.414, -0.835), Vector3(0.113, 0.084, 0.064), pink)
	_sphere(_driver, Vector3(-0.025, 2.483, -0.866), Vector3(0.055, 0.025, 0.014), _material(Color("f4c2c8"), 0.50))
	_polyline(_driver, [Vector3(0, 2.395, -0.846), Vector3(0, 2.333, -0.837), Vector3(-0.075, 2.286, -0.813), Vector3(-0.14, 2.306, -0.789)], 0.010, mouth)
	_polyline(_driver, [Vector3(0, 2.333, -0.837), Vector3(0.075, 2.286, -0.813), Vector3(0.14, 2.306, -0.789)], 0.010, mouth)
	_tail = _node(_driver, "FluffyTail", Vector3(0.38, 1.27, 0.66))
	var tail_points: Array[Vector3] = [Vector3.ZERO, Vector3(0.21, 0.10, 0.15), Vector3(0.39, 0.28, 0.22), Vector3(0.48, 0.49, 0.20), Vector3(0.47, 0.67, 0.13), Vector3(0.35, 0.75, 0.03)]
	_curved_tail(_tail, tail_points, point_coat if character_index == 4 else coat)
	if character_index == 2:
		_build_bow(_driver, Vector3(-0.40, 3.257, -0.13), _material(Color("e563ab"), 0.61))


func _build_eye(side: float) -> void:
	var eye: Node3D = _node(_driver, "Eye", Vector3(side * 0.409, 2.71, -0.523))
	eye.scale.z = 0.42
	_eyes.append(eye)
	var lid_color: Color = Color("655155") if character_index == 4 else COATS[character_index]
	var lid: Material = _fur_material(lid_color)
	# Eyes sit in the face behind a thin dark lash line; no beige eyeball rings.
	_sphere(eye, Vector3(0, 0, 0.018), Vector3(0.603, 0.636, 0.13), lid)
	_sphere(eye, Vector3(0, -0.012, -0.04), Vector3(0.543, 0.581, 0.129), _material(Color("1e1c24"), 0.64))
	_sphere(eye, Vector3(-side * 0.013, -0.007, -0.085), Vector3(0.496, 0.538, 0.113), _material(IRIS[character_index].darkened(0.26), 0.30))
	_sphere(eye, Vector3(-side * 0.013, -0.009, -0.104), Vector3(0.449, 0.495, 0.092), _material(IRIS[character_index].darkened(0.05), 0.25))
	_sphere(eye, Vector3(-side * 0.012, -0.002, -0.143), Vector3(0.340, 0.440, 0.058), _material(Color("12151c"), 0.16))
	_sphere(eye, Vector3(-0.084, 0.116, -0.178), Vector3(0.101, 0.123, 0.028), _material(Color("fffaf1"), 0.12))
	_sphere(eye, Vector3(0.075, -0.111, -0.177), Vector3(0.030, 0.038, 0.013), _material(Color("d6e9f5"), 0.14))
	var brow: MeshInstance3D = _sphere(eye, Vector3(0, 0.283, 0.003), Vector3(0.515, 0.095, 0.16), lid)
	brow.rotation.z = -side * 0.07
	if character_index == 2:
		for j: int in range(2):
			_cylinder_between(eye, Vector3(side * 0.23, 0.12 + j * 0.056, -0.027), Vector3(side * (0.30 + j * 0.006), 0.17 + j * 0.080, -0.018), 0.014, _material(Color("66505f"), 0.92))


func _build_bow(parent: Node3D, point: Vector3, mat: Material) -> void:
	for side: float in [-1.0, 1.0]:
		var bow: MeshInstance3D = _sphere(parent, point + Vector3(side * 0.15, 0, 0), Vector3(0.28, 0.27, 0.15), mat)
		bow.rotation.z = side * 0.5
	_sphere(parent, point + Vector3(0, 0, -0.045), Vector3(0.14, 0.14, 0.16), mat)


func _build_exhaust() -> void:
	var chrome: StandardMaterial3D = _material(Color("b1c5d2"), 0.25, 0.84)
	var inside: StandardMaterial3D = _material(Color("141824"), 0.83)
	var blue: StandardMaterial3D = _material(Color("16baff"), 0.2, 0.0, 2.5)
	var hot: StandardMaterial3D = _material(Color("d6fbff"), 0.2, 0.0, 2.2)
	for side: float in [-1.0, 1.0]:
		var pipe: MeshInstance3D = _cylinder(_body, Vector3(side * 0.49, 0.37, 1.6), 0.18, 0.54, chrome)
		pipe.rotation.x = PI / 2.0
		var opening: MeshInstance3D = _cylinder(_body, Vector3(side * 0.49, 0.37, 1.879), 0.135, 0.022, inside)
		opening.rotation.x = PI / 2.0
		var lip: MeshInstance3D = _torus(_body, Vector3(side * 0.49, 0.37, 1.89), 0.131, 0.177, chrome)
		lip.rotation.x = PI / 2.0
		var flame: Node3D = _node(_body, "BoostFlame", Vector3(side * 0.49, 0.37, 1.9))
		_flames.append(flame)
		_sphere(flame, Vector3(0, 0, 0.5), Vector3(0.22, 0.22, 1.07), blue)
		_sphere(flame, Vector3(0, 0, 0.21), Vector3(0.13, 0.13, 0.54), hot)
		_merge_static(flame)
	for i: int in range(8):
		var spark: MeshInstance3D = _sphere(self, Vector3.ZERO, Vector3(0.056, 0.056, 0.23), blue)
		spark.visible = false
		_sparks.append(spark)


func _paw(parent: Node3D, point: Vector3, size: float, mat: StandardMaterial3D, front: bool) -> void:
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var key: String = "printed_paw_front" if front else "printed_paw_rear"
	if not _meshes.has(key):
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pad: PackedVector2Array = PackedVector2Array([Vector2(-0.245,-0.22), Vector2(-0.232,-0.15), Vector2(-0.19,-0.08), Vector2(-0.15,0.003), Vector2(-0.09,0.065), Vector2(0,0.083), Vector2(0.09,0.065), Vector2(0.15,0.003), Vector2(0.19,-0.08), Vector2(0.232,-0.15), Vector2(0.245,-0.22), Vector2(0.226,-0.283), Vector2(0.167,-0.31), Vector2(0.091,-0.295), Vector2(0,-0.271), Vector2(-0.091,-0.295), Vector2(-0.167,-0.31), Vector2(-0.226,-0.283)])
		_stamp_polygon(surface, pad, front)
		for i: int in range(4):
			var center: Vector2 = Vector2([-0.32, -0.12, 0.12, 0.32][i], [0.13, 0.30, 0.30, 0.13][i])
			var angle: float = -[-0.38, -0.15, 0.15, 0.38][i]
			var toe: PackedVector2Array = []
			for segment: int in range(28):
				var theta: float = float(segment) / 28.0 * TAU
				toe.append(center + Vector2(cos(theta) * 0.093, sin(theta) * 0.125).rotated(angle))
			_stamp_polygon(surface, toe, front)
		surface.index()
		_meshes[key] = surface.commit()
	_instance(parent, _meshes[key], point, Vector3(size, size, 1), mat)


static func _stamp_polygon(surface: SurfaceTool, polygon: PackedVector2Array, front: bool) -> void:
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	for i: int in range(0, triangles.size(), 3):
		var order: Array[int] = []
		order.assign([2, 1, 0] if front else [0, 1, 2])
		for index: int in order:
			var point: Vector2 = polygon[triangles[i + index]]
			surface.set_normal(Vector3(0, 0, -1 if front else 1))
			surface.set_uv(point + Vector2.ONE * 0.5)
			surface.add_vertex(Vector3(point.x, point.y, 0))


func _voxel_crest(parent: Node3D, point: Vector3, size: float, mat: StandardMaterial3D) -> void:
	for x: float in [-0.25, 0.25]:
		_box(parent, point + Vector3(x * size, size * 0.23, 0), Vector3(size * 0.24, size * 0.24, 0.02), mat)
	_box(parent, point + Vector3(0, -size * 0.1, 0), Vector3(size * 0.22, size * 0.36, 0.02), mat)
	_box(parent, point + Vector3(0, -size * 0.3, 0), Vector3(size * 0.56, size * 0.19, 0.02), mat)


static func _material(color: Color, roughness: float = 0.7, metallic: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var key: String = "%s/%.2f/%.2f/%.2f" % [color.to_html(), roughness, metallic, emission]
	if _materials.has(key):
		return _materials[key]
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	# Vehicle parts stay opaque even during impacts, boosts and animation.
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_DISABLED
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	_materials[key] = mat
	return mat


static func _fur_material(color: Color, pattern: int = 0) -> ShaderMaterial:
	var key: String = "fur_%s_%d" % [color.to_html(), pattern]
	if _materials.has(key):
		return _materials[key]
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = FUR_SHADER
	mat.set_shader_parameter("coat_color", color)
	mat.set_shader_parameter("coat_pattern", pattern)
	mat.set_shader_parameter("dark_color", Color("59474b") if pattern == 3 else color.darkened(0.58))
	mat.set_shader_parameter("cream_color", Color("ded9d0"))
	_materials[key] = mat
	return mat


static func _node(parent: Node3D, title: String, point: Vector3 = Vector3.ZERO) -> Node3D:
	var result: Node3D = Node3D.new()
	result.name = title
	parent.add_child(result)
	result.position = point
	return result


static func _instance(parent: Node3D, mesh: Mesh, point: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	var result: MeshInstance3D = MeshInstance3D.new()
	result.mesh = mesh
	result.material_override = mat
	parent.add_child(result)
	result.position = point
	result.scale = dimensions
	return result


static func _sphere(parent: Node3D, point: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	if not _meshes.has("sphere"):
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		mesh.radial_segments = 24
		mesh.rings = 12
		_meshes["sphere"] = mesh
	return _instance(parent, _meshes["sphere"], point, dimensions, mat)


static func _fur_sphere(parent: Node3D, point: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	if not _meshes.has("organic_fur"):
		var base: SphereMesh = SphereMesh.new()
		base.radius = 0.5
		base.height = 1.0
		base.radial_segments = 48
		base.rings = 28
		var arrays: Array = base.get_mesh_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i: int in range(vertices.size()):
			var p: Vector3 = vertices[i]
			var ripple: float = sin(p.x * 43.0 + p.y * 17.0) * sin(p.z * 37.0 - p.y * 23.0) * 0.006
			vertices[i] = p * (1.0 + ripple)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_meshes["organic_fur"] = mesh
	return _instance(parent, _meshes["organic_fur"], point, dimensions, mat)


static func _fur_outline(parent: Node3D, center: Vector3, dimensions: Vector3, mat: Material, count: int) -> void:
	# Fine tapered solid fibres soften the edge without alpha shells or knobs.
	if not _meshes.has("fur_fibre"):
		var fibre: CylinderMesh = CylinderMesh.new()
		fibre.top_radius = 0.0
		fibre.bottom_radius = 0.5
		fibre.height = 1.0
		fibre.radial_segments = 5
		_meshes["fur_fibre"] = fibre
	for i: int in range(count):
		var angle: float = float(i) * TAU / float(count)
		var direction: Vector3 = Vector3(sin(angle), cos(angle), 0)
		var point: Vector3 = center + Vector3(direction.x * dimensions.x * 0.493, direction.y * dimensions.y * 0.493, sin(i * 2.17) * dimensions.z * 0.021)
		var tuft: MeshInstance3D = _instance(parent, _meshes["fur_fibre"], point, Vector3(0.012, 0.075 + sin(i * 3.7) * 0.019, 0.014), mat)
		tuft.quaternion = Quaternion(Vector3.UP, direction)


static func _soft_limb(parent: Node3D, start: Vector3, end: Vector3, radius: float, mat: Material) -> void:
	var limb: MeshInstance3D = _sphere(parent, (start + end) * 0.5, Vector3(radius * 2, start.distance_to(end) + radius * 1.6, radius * 2), mat)
	limb.quaternion = Quaternion(Vector3.UP, (end - start).normalized())


static func _curved_tail(parent: Node3D, points: Array[Vector3], mat: Material) -> void:
	var path: Curve3D = Curve3D.new()
	for i: int in range(points.size()):
		var before: Vector3 = points[maxi(0, i - 1)]
		var after: Vector3 = points[mini(points.size() - 1, i + 1)]
		var handle: Vector3 = (after - before) * 0.16
		path.add_point(points[i], -handle, handle)
	path.bake_interval = 0.025
	var length: float = path.get_baked_length()
	var vertices: PackedVector3Array = []
	var normals: PackedVector3Array = []
	var uv: PackedVector2Array = []
	var indices: PackedInt32Array = []
	var rings: int = 36
	var sides: int = 14
	for i: int in range(rings + 1):
		var u: float = float(i) / rings
		var point: Vector3 = path.sample_baked(u * length)
		var before: Vector3 = path.sample_baked(maxf(0, u * length - 0.015))
		var after: Vector3 = path.sample_baked(minf(length, u * length + 0.015))
		var forward: Vector3 = (after - before).normalized()
		var frame: Basis = Basis.looking_at(forward, Vector3.FORWARD)
		var radius: float = lerpf(0.17, 0.075, u)
		for j: int in range(sides + 1):
			var angle: float = float(j) / sides * TAU
			var normal: Vector3 = frame.x * cos(angle) + frame.y * sin(angle)
			vertices.append(point + normal * radius)
			normals.append(normal)
			uv.append(Vector2(float(j) / sides, u))
			if i < rings and j < sides:
				var a: int = i * (sides + 1) + j
				var b: int = a + sides + 1
				indices.append_array([a, a + 1, b, a + 1, b + 1, b])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_instance(parent, mesh, Vector3.ZERO, Vector3.ONE, mat)
	_sphere(parent, points[-1], Vector3.ONE * 0.15, mat)


static func _rounded_box(parent: Node3D, point: Vector3, dimensions: Vector3, mat: Material, bevel: float = 0.20) -> MeshInstance3D:
	var key: String = "rounded_box_%.3f" % bevel
	if not _meshes.has(key):
		var base: BoxMesh = BoxMesh.new()
		base.subdivide_width = 8
		base.subdivide_height = 8
		base.subdivide_depth = 8
		var arrays: Array = base.get_mesh_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var inset: Vector3 = Vector3.ONE * (0.5 - bevel)
		for i: int in range(vertices.size()):
			var p: Vector3 = vertices[i]
			var inner: Vector3 = p.clamp(-inset, inset)
			var normal: Vector3 = (p - inner).normalized()
			vertices[i] = inner + normal * bevel
			normals[i] = normal
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_meshes[key] = mesh
	return _instance(parent, _meshes[key], point, dimensions, mat)


static func _box(parent: Node3D, point: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	if not _meshes.has("box"):
		_meshes["box"] = BoxMesh.new()
	return _instance(parent, _meshes["box"], point, dimensions, mat)


static func _cylinder(parent: Node3D, point: Vector3, radius: float, length: float, mat: Material) -> MeshInstance3D:
	if not _meshes.has("cylinder"):
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = 1.0
		mesh.bottom_radius = 1.0
		mesh.height = 1.0
		mesh.radial_segments = 20
		_meshes["cylinder"] = mesh
	return _instance(parent, _meshes["cylinder"], point, Vector3(radius, length, radius), mat)


static func _cylinder_between(parent: Node3D, start: Vector3, end: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var delta: Vector3 = end - start
	var result: MeshInstance3D = _cylinder(parent, (start + end) * 0.5, radius, delta.length(), mat)
	if absf(delta.normalized().dot(Vector3.UP)) < 0.999:
		result.quaternion = Quaternion(Vector3.UP, delta.normalized())
	return result


static func _limb(parent: Node3D, start: Vector3, end: Vector3, radius: float, mat: Material) -> void:
	_cylinder_between(parent, start, end, radius, mat)
	_sphere(parent, start, Vector3.ONE * radius * 2.0, mat)
	_sphere(parent, end, Vector3.ONE * radius * 2.0, mat)


static func _polyline(parent: Node3D, points: Array[Vector3], radius: float, mat: Material) -> void:
	for i: int in range(points.size() - 1):
		_limb(parent, points[i], points[i + 1], radius, mat)


static func _torus(parent: Node3D, point: Vector3, inner: float, outer: float, mat: Material) -> MeshInstance3D:
	var key: String = "torus_%.3f_%.3f" % [inner, outer]
	if not _meshes.has(key):
		var mesh: TorusMesh = TorusMesh.new()
		mesh.inner_radius = inner
		mesh.outer_radius = outer
		mesh.rings = 24
		mesh.ring_segments = 10
		_meshes[key] = mesh
	return _instance(parent, _meshes[key], point, Vector3.ONE, mat)


static func _ear(parent: Node3D, point: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	if not _meshes.has("rounded_ear"):
		var outline: Array[Vector2] = [Vector2(-0.55, -0.21), Vector2(-0.49, 0.10), Vector2(-0.35, 0.53), Vector2(-0.16, 0.91), Vector2(-0.095, 0.98), Vector2(-0.015, 0.97), Vector2(0.12, 0.76), Vector2(0.38, 0.24), Vector2(0.52, -0.19), Vector2(0.27, -0.31), Vector2(-0.20, -0.32)]
		var scales: Array[float] = [1.0, 0.87, 0.52, 0.0]
		var depths: Array[float] = [0.0, -0.19, -0.32, -0.36]
		var center: Vector2 = Vector2(-0.03, 0.22)
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side: int in [-1, 1]:
			for ring: int in range(scales.size() - 1):
				for i: int in range(outline.size()):
					var following: int = (i + 1) % outline.size()
					var a2: Vector2 = center + (outline[i] - center) * scales[ring]
					var b2: Vector2 = center + (outline[following] - center) * scales[ring]
					var c2: Vector2 = center + (outline[i] - center) * scales[ring + 1]
					var d2: Vector2 = center + (outline[following] - center) * scales[ring + 1]
					var depth_scale: float = 1.0 if side == -1 else -0.80
					var a: Vector3 = Vector3(a2.x, a2.y, depths[ring] * depth_scale)
					var b: Vector3 = Vector3(b2.x, b2.y, depths[ring] * depth_scale)
					var c: Vector3 = Vector3(c2.x, c2.y, depths[ring + 1] * depth_scale)
					var d: Vector3 = Vector3(d2.x, d2.y, depths[ring + 1] * depth_scale)
					var triangle: Array[Vector3] = []
					triangle.assign([c, b, a] if side == -1 else [c, a, b])
					if ring < scales.size() - 2:
						triangle.append_array([c, d, b] if side == -1 else [c, b, d])
					for vertex: Vector3 in triangle:
						surface.set_uv(Vector2(vertex.x + 0.5, vertex.y))
						surface.add_vertex(vertex)
		surface.index()
		surface.generate_normals()
		_meshes["rounded_ear"] = surface.commit()
	return _instance(parent, _meshes["rounded_ear"], point, dimensions, mat)


static func _merge_static(parent: Node3D) -> void:
	var groups: Dictionary = {}
	var originals: Array[MeshInstance3D] = []
	for child: Node in parent.get_children():
		if child is MeshInstance3D and child.mesh != null:
			var mesh_instance: MeshInstance3D = child
			var material: Material = mesh_instance.material_override
			if not groups.has(material):
				groups[material] = []
			groups[material].append(mesh_instance)
			originals.append(mesh_instance)
	for material: Material in groups:
		var builder: SurfaceTool = SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: MeshInstance3D in groups[material]:
			for surface_index: int in range(part.mesh.get_surface_count()):
				builder.append_from(part.mesh, surface_index, part.transform)
		var combined: ArrayMesh = builder.commit()
		var visible_mesh: MeshInstance3D = MeshInstance3D.new()
		visible_mesh.mesh = combined
		visible_mesh.material_override = material
		visible_mesh.extra_cull_margin = 0.15
		parent.add_child(visible_mesh)
	for old: MeshInstance3D in originals:
		parent.remove_child(old)
		old.queue_free()
