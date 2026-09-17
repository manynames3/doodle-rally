extends Node3D
## Shared, self-contained 3D kart model. Coordinates: -Z forward, Y up.
## Every visible part is geometry; all eight drivers can be viewed from any angle.

const PALETTE: Array[Color] = [Color("e52f37"), Color("168ff0"), Color("f159b0"), Color("ff921d"), Color("9446e8"), Color("48b73d"), Color("ffd044"), Color("efbf3c")]
const COATS: Array[Color] = [Color("1b1d22"), Color("9296a4"), Color("ddd7d0"), Color("e99136"), Color("e6d2b3"), Color("c97931"), Color("29211e"), Color("85818b")]
const IRIS: Array[Color] = [Color("bdc45f"), Color("9edd83"), Color("63c9ed"), Color("b8d75f"), Color("67bff9"), Color("92db76"), Color("9d9e60"), Color("9edb76")]
const VOXEL_DRIVER = preload("res://scripts/kart_voxel_driver.gd")
const FUR_SHADER = preload("res://scripts/kart_fur.gdshader")
const GROOM_SHADER = preload("res://scripts/kart_groom.gdshader")
const CAT_SCULPT = preload("res://scripts/kart_cat_sculpt.gd")
const IRIS_SHADER = preload("res://scripts/kart_iris.gdshader")
static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}

var character_index: int = 0
var mode: String = "cats"
var _body: Node3D
var _driver: Node3D
var _head: Node3D
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
	if mode == "cats":
		_merge_static(_head)
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
	_rounded_box(_body, Vector3(0, 1.015, -1.235), Vector3(1.90, 0.84, 1.155), paint_light, 0.31)
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
	if mode == "cats":
		_instance(wheel,CAT_SCULPT.tire(),Vector3.ZERO,Vector3.ONE,rubber)
	else:
		var tire: MeshInstance3D = _cylinder(wheel,Vector3.ZERO,0.47,0.43,rubber)
		tire.rotation.z = PI/2.0
		for x: float in [-0.175,0.175]:
			var shoulder: MeshInstance3D = _torus(wheel,Vector3(x,0,0),0.32,0.505,rubber)
			shoulder.rotation.z = PI/2.0
	var rim: MeshInstance3D = _cylinder(wheel, Vector3(side * 0.239, 0, 0), 0.303, 0.025, chrome)
	rim.rotation.z = PI / 2.0
	var inset: MeshInstance3D = _cylinder(wheel, Vector3(side * 0.26, 0, 0), 0.248, 0.024, graphite)
	inset.rotation.z = PI / 2.0
	var ring: MeshInstance3D = _torus(wheel, Vector3(side * 0.274, 0, 0), 0.255, 0.286, paint)
	ring.rotation.z = PI / 2.0
	for i: int in range(5):
		var angle: float = i * TAU / 5.0
		_cylinder_between(wheel, Vector3(side * (0.275 if mode == "cats" else 0.282), cos(angle) * 0.07, sin(angle) * 0.07), Vector3(side * (0.275 if mode == "cats" else 0.282), cos(angle + 0.17) * 0.22, sin(angle + 0.17) * 0.22), 0.047 if mode == "cats" else 0.029, chrome)
		_sphere(wheel, Vector3(side * 0.316, cos(angle) * 0.095, sin(angle) * 0.095), Vector3(0.018, 0.026, 0.026), chrome)
	var hub: MeshInstance3D = _cylinder(wheel, Vector3(side * 0.289, 0, 0), 0.08, 0.049, paint)
	hub.rotation.z = PI / 2.0
	var tread_material: StandardMaterial3D = _material(Color("303542"), 0.94)
	for i: int in range(18):
		var angle: float = i * TAU / 18.0
		var tread: MeshInstance3D = _box(wheel, Vector3(0, cos(angle) * (0.498 if mode == "cats" else 0.479), sin(angle) * (0.498 if mode == "cats" else 0.479)), Vector3(0.34 if mode == "cats" else 0.31, 0.012 if mode == "cats" else 0.025, 0.035 if mode == "cats" else 0.058), tread_material)
		tread.rotation.x = angle


func _build_cat() -> void:
	var base: Color = COATS[character_index]
	# Pumpkin uses a warm russet calico-like blaze so she reads as her own racer;
	# the old orange tabby treatment made her indistinguishable from Biscuit.
	var pattern: int = 6 if character_index == 0 else 4 if character_index == 6 else 2 if character_index == 5 else 1 if character_index in [1, 3, 7] else 3 if character_index == 4 else 8
	var coat: Material = _fur_material(base, pattern)
	var white: Material = _fur_material(Color("d9d3c7"))
	var body_coat: Material = _fur_material(base, 4 if character_index == 6 else 1 if character_index in [1,3,7] else 0)
	var points: Material = _fur_material(Color("594849")) if character_index == 4 else body_coat
	var paws: Material = white if character_index in [0,2,5,6,7] else points
	var nose: Material = _material(Color("16191d") if character_index in [0,7] else Color("ac7a67") if character_index == 6 else Color("c88f92"), 0.43)
	var mouth: Material = _material(Color("1d0c11"), 0.82)
	var tongue: Material = _material(Color("e07b86"), 0.70)
	_driver = _node(_body, "CatDriver")
	# Deep seated haunches and a softly tapering chest are mostly within the
	# cockpit; shoulders and paws retain a natural compact feline posture.
	_fur_sphere(_driver, Vector3(0,1.63,0.28),Vector3(1.14,1.01,1.08),body_coat)
	_fur_sphere(_driver, Vector3(0,1.83,0.13),Vector3(0.88,0.88,0.77),body_coat)
	# The two photographed hero cats have a generous white bib that rises into
	# the jaw; keeping it broad makes the silhouette read from the race camera.
	var bib_width: float = 0.86 if character_index == 0 else 0.98 if character_index == 6 else 0.70
	var bib_height: float = 0.96 if character_index in [0,6] else 0.77
	_fur_sphere(_driver, Vector3(0,1.80,-0.20),Vector3(bib_width,bib_height,0.34),white if character_index in [0,2,5,6] else points)
	if character_index in [0,6]:
		# A second soft lobe makes the white throat read beneath the larger head
		# instead of disappearing behind the dashboard in the lineup camera.
		_fur_sphere(_driver, Vector3(0,2.03,-0.25),Vector3(bib_width * 0.82,0.46,0.30),white)
	for side: float in [-1.0,1.0]:
		_fur_sphere(_driver,Vector3(side*0.36,1.26,0.07),Vector3(0.54,0.51,0.66),body_coat)
		_fur_sphere(_driver,Vector3(side*0.36,1.18,-0.26),Vector3(0.40,0.28,0.54),paws)
		_soft_limb(_driver,Vector3(side*0.38,1.83,-0.075),Vector3(side*0.37,1.53,-0.52),0.175,body_coat)
		_fur_sphere(_driver,Vector3(side*0.365,1.55,-0.616),Vector3(0.39,0.30,0.385),paws)
		for j: int in range(2):
			var x: float = side*0.365-0.047+j*0.094
			_instance(_driver,CAT_SCULPT.curved_line([Vector3(x,1.60,-0.787),Vector3(x,1.54,-0.803),Vector3(x,1.49,-0.785)],0.0024),Vector3.ZERO,Vector3.ONE,_material(Color("8c8582"),0.91))
	_head = _node(_driver,"SculptedFace")
	# A slightly oversized kitten head matches the round, plush proportions of
	# the reference render and keeps the driver's face readable in the lineup.
	_head.scale = Vector3(1.39,1.39,1.25) if character_index == 0 else Vector3(1.22,1.25,1.16) if character_index == 6 else Vector3(1.28,1.28,1.17)
	_head.rotation.z = deg_to_rad(-4.5 if character_index == 0 else 3.0 if character_index == 6 else 0.0)
	_head.position.y = -2.64*0.20
	# One connected surface contains the brow, sockets, nose bridge, cheeks,
	# paired muzzle and tapered jaw; markings follow this continuous sculpture.
	_instance(_head,CAT_SCULPT.head(character_index == 6),Vector3.ZERO,Vector3.ONE,coat)
	var groom: MeshInstance3D = _instance(_head,CAT_SCULPT.groom(character_index == 6),Vector3.ZERO,Vector3.ONE,_fur_material(base,pattern,true))
	groom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Subpixel hair drops out beyond30m; the solid sculpt, eyes, ears and
	# halo remain opaque and visible. Hysteresis avoids boundary flicker.
	groom.visibility_range_end = 30.0
	groom.visibility_range_end_margin = 3.0
	groom.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	for side: float in [-1.0,1.0]:
		var ear_coat: Material = _fur_material(Color("24201e")) if character_index == 6 else points
		var outer_ear: MeshInstance3D = _instance(_head,CAT_SCULPT.ear(side,false),Vector3.ZERO,Vector3.ONE,ear_coat)
		var inner_ear: MeshInstance3D = _instance(_head,CAT_SCULPT.ear(side,true),Vector3.ZERO,Vector3.ONE,_fur_material(Color("6b404b") if character_index == 0 else Color("4a3b3d") if character_index in [6,7] else Color("b58c8e"),9))
		# A small outward cant breaks the mirrored mannequin silhouette while
		# preserving the compact kitten ears from the reference renders.
		outer_ear.rotation.z = side * deg_to_rad(5.0 if character_index in [0,6] else 3.0)
		inner_ear.rotation.z = outer_ear.rotation.z
		_build_eye(side)
		# Whiskers arc, taper and droop; they have no segmented-cylinder joints.
		for j: int in range(6):
			var origin: Vector3 = Vector3(side*(0.23+j*0.013),2.42-j*0.026,-0.797+j*0.012)
			var end: Vector3 = Vector3(side*(0.91+sin(j*2.1)*0.10),2.56-j*0.071,-0.56+sin(j)*0.035)
			_instance(_head,CAT_SCULPT.curved_line([origin,origin+Vector3(side*0.31,0.035-j*0.012,-0.03),end],0.0026),Vector3.ZERO,Vector3.ONE,_material(Color("bdb8ac"),0.88))
			_sphere(_head,origin+Vector3(0,0,-0.006),Vector3(0.009,0.009,0.007),mouth)
	# A tiny triangular velvet nose follows the bridge, with recessed nostrils.
	var nose_mesh: MeshInstance3D = _sphere(_head,Vector3(0,2.489,-0.819),Vector3(0.155,0.075,0.075),nose)
	nose_mesh.rotation.z = 0.0
	_sphere(_head,Vector3(0,2.455,-0.823),Vector3(0.090,0.065,0.064),nose)
	for side: float in [-1.0,1.0]:
		_sphere(_head,Vector3(side*0.042,2.471,-0.851),Vector3(0.024,0.012,0.008),mouth)
	if character_index == 6:
		for point: Vector3 in [Vector3(-0.041,2.50,-0.84),Vector3(0.021,2.512,-0.84)]:
			_sphere(_head,point,Vector3(0.014,0.011,0.006),mouth)
	_instance(_head,CAT_SCULPT.curved_line([Vector3(0,2.445,-0.844),Vector3(0,2.382,-0.827),Vector3(-0.064,2.352,-0.805),Vector3(-0.13,2.372,-0.784)],0.0040),Vector3.ZERO,Vector3.ONE,mouth)
	_instance(_head,CAT_SCULPT.curved_line([Vector3(0,2.382,-0.827),Vector3(0.064,2.352,-0.805),Vector3(0.13,2.372,-0.784)],0.0040),Vector3.ZERO,Vector3.ONE,mouth)
	# Give Zizi and Mak-Doong the open, friendly expression in the reference
	# art. The cavity is shallow so it remains readable without becoming a
	# floating prop when the head turns in the race.
	if character_index in [0,6]:
		# Recessed oval cavity and tongue sit just in front of the sculpted muzzle;
		# the extra depth keeps them visible after the head is enlarged and tilted.
		_sphere(_head,Vector3(0,2.285,-1.005),Vector3(0.40,0.285,0.10),mouth)
		_sphere(_head,Vector3(0,2.225,-1.075),Vector3(0.235,0.125,0.052),tongue)
	# A cloth collar, small tag, and softly curled tail finish the silhouette.
	var scarf: Material = _material(PALETTE[character_index].darkened(0.12),0.88)
	_sphere(_driver,Vector3(0,2.058,0.12),Vector3(0.92,0.105,0.73),scarf)
	var scarf_tail: MeshInstance3D = _sphere(_driver,Vector3(0.29,2.018,0.58),Vector3(0.45,0.08,0.25),scarf)
	scarf_tail.rotation.y = -0.35
	_sphere(_driver,Vector3(0,2.01,-0.305),Vector3(0.12,0.15,0.045),_material(Color("b78c36"),0.32,0.54))
	_tail = _node(_driver,"FluffyTail",Vector3(0.36,1.27,0.64))
	var tail_points: Array[Vector3] = [Vector3.ZERO,Vector3(0.20,0.10,0.15),Vector3(0.36,0.30,0.22),Vector3(0.43,0.52,0.18),Vector3(0.39,0.70,0.08),Vector3(0.27,0.77,0.025)]
	_curved_tail(_tail,tail_points,_fur_material(Color("211d1b"),5) if character_index == 6 else points,1.30 if character_index == 6 else 0.90)
	if character_index == 6:
		# Keep the halo clearly above both ears. A thinner, smoother torus reads as
		# a soft accessory in the chase camera instead of a thick floating arch.
		var halo_mat := _material(Color("f6d56c"),0.20,0.35,0.65)
		var halo: MeshInstance3D = _torus(_driver,Vector3(0,4.46,0.17),0.55,0.63,halo_mat)
		halo.name = "GoldenHalo"
		halo.rotation.x = -deg_to_rad(10.0)
		halo.scale = Vector3(1.0,0.46,1.0)
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var halo_light := OmniLight3D.new()
		halo_light.name = "HaloGlow"
		halo_light.position = Vector3(0,4.40,0.16)
		halo_light.light_color = Color("ffd96e")
		halo_light.light_energy = 0.22
		halo_light.omni_range = 3.8
		halo_light.shadow_enabled = false
		_driver.add_child(halo_light)
	if character_index == 2:
		_build_bow(_driver,Vector3(-0.38,3.22,-0.05),_material(Color("d873a5"),0.74))


func _build_eye(side: float) -> void:
	var eye: Node3D = _node(_head,"Eye",Vector3(side*0.361,2.734,-0.468))
	# The lens is embedded in the sculpted socket and has a continuous curved
	# glossy iris. No stacked medallion rings, brows or floating highlights.
	eye.rotation.z = -side*0.10
	eye.rotation.y = side*0.11
	# The reference uses soft illustrated eyes; a smaller lens leaves more of the
	# sculpted socket visible and avoids the oversized glass-doll impression.
	eye.scale = Vector3.ONE * 0.88
	_eyes.append(eye)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = IRIS_SHADER
	material.set_shader_parameter("iris_color",IRIS[character_index])
	_instance(eye,CAT_SCULPT.lens(),Vector3.ZERO,Vector3.ONE,material)


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


static func _fur_material(color: Color, pattern: int = 0, groomed: bool = false) -> ShaderMaterial:
	var key: String = "fur_%s_%d_%s" % [color.to_html(), pattern, groomed]
	if _materials.has(key):
		return _materials[key]
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = GROOM_SHADER if groomed else FUR_SHADER
	mat.set_shader_parameter("coat_color", color)
	mat.set_shader_parameter("coat_pattern", pattern)
	mat.set_shader_parameter("groom_geometry", groomed)
	mat.set_shader_parameter("dark_color", Color("59474b") if pattern == 3 else color.darkened(0.58))
	mat.set_shader_parameter("cream_color", Color("d9d3c7"))
	if not groomed and ResourceLoader.exists("res://assets/characters/fur_microdetail.png"):
		mat.set_shader_parameter("fur_texture",load("res://assets/characters/fur_microdetail.png"))
		mat.set_shader_parameter("use_fur_texture",true)
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
	var physical_size: Vector3 = mesh.get_aabb().size * dimensions.abs()
	if physical_size.x * physical_size.y * physical_size.z < 0.08 or mat is ShaderMaterial and mat.shader == IRIS_SHADER:
		result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


static func _fur_outline(parent: Node3D, center: Vector3, dimensions: Vector3, mat: Material, count: int, length_scale: float = 1.0) -> void:
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
		var tuft: MeshInstance3D = _instance(parent, _meshes["fur_fibre"], point, Vector3(0.012, (0.075 + sin(i * 3.7) * 0.019) * length_scale, 0.014), mat)
		tuft.quaternion = Quaternion(Vector3.UP, direction)


static func _soft_limb(parent: Node3D, start: Vector3, end: Vector3, radius: float, mat: Material) -> void:
	var limb: MeshInstance3D = _sphere(parent, (start + end) * 0.5, Vector3(radius * 2, start.distance_to(end) + radius * 1.6, radius * 2), mat)
	limb.quaternion = Quaternion(Vector3.UP, (end - start).normalized())


static func _curved_tail(parent: Node3D, points: Array[Vector3], mat: Material, thickness: float = 1.0) -> void:
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
		var radius: float = lerpf(0.17, 0.075, u) * thickness
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
	_sphere(parent, points[-1], Vector3.ONE * 0.15 * thickness, mat)


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
		mesh.rings = 36
		mesh.ring_segments = 18
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
			var part: MeshInstance3D = child
			# Groom retains its own distance hysteresis. Everything else batches,
			# including small trim with shadow casting disabled.
			if part.visibility_range_end > 0.0 or part.visibility_range_begin > 0.0:
				continue
			var mat: Material = part.material_override
			var key: String = "%s_%s" % [mat.get_instance_id(),part.cast_shadow]
			if not groups.has(key):
				groups[key] = {"material": mat,"shadow": part.cast_shadow,"parts": []}
			groups[key].parts.append(part)
			originals.append(part)
	for key: String in groups:
		var group: Dictionary = groups[key]
		var builder: SurfaceTool = SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: MeshInstance3D in group.parts:
			for surface_index: int in range(part.mesh.get_surface_count()):
				builder.append_from(part.mesh,surface_index,part.transform)
		var combined: ArrayMesh = builder.commit()
		var visible_mesh: MeshInstance3D = MeshInstance3D.new()
		visible_mesh.mesh = combined
		visible_mesh.material_override = group.material
		visible_mesh.cast_shadow = group.shadow
		visible_mesh.extra_cull_margin = 0.15
		parent.add_child(visible_mesh)
	for old: MeshInstance3D in originals:
		parent.remove_child(old)
		old.queue_free()
