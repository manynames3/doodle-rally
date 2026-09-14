extends SubViewportContainer
var character_index := 0
var mode := "cats"
var active := false
var reduced_motion := false
var kart: Node3D
var _elapsed := 0.0
var _viewport: SubViewport

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(300, 380)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)
	var root := Node3D.new()
	_viewport.add_child(root)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c4d8ff")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	root.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -30, 0)
	key.light_color = Color("ffe8c3")
	key.light_energy = 1.5
	root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 160, 0)
	fill.light_color = Color("a3d7ff")
	fill.light_energy = 0.55
	root.add_child(fill)
	var camera := Camera3D.new()
	camera.position = Vector3(5.0, 4.0, -9.0)
	camera.fov = 34
	root.add_child(camera)
	camera.look_at(Vector3(0, 1.6, 0))
	camera.current = true
	var source := load("res://scripts/kart_visual.gd") as Script
	if source:
		kart = Node3D.new()
		kart.set_script(source)
		root.add_child(kart)
		kart.call("build", character_index, mode)

func _process(delta: float) -> void:
	if not is_instance_valid(kart):
		return
	_elapsed += delta
	if active and not reduced_motion:
		kart.rotation.y = sin(_elapsed * 0.75) * 0.18
		kart.call("animate", delta, 0.0, 0.0, 0.0, false)
	elif absf(kart.rotation.y) > 0.001:
		kart.rotation.y = lerpf(kart.rotation.y, 0.0, delta * 4.0)
