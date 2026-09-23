extends Control
## A shared native, antialiased workbench keeps the racers together in one scene.
var characters: Array[int] = []
var mode := "cats"
var selected_character := 0
var selected_course := 1
var rear_view := false
var single_preview := false
var reduced_motion := false
var karts: Array[Node3D] = []
var _viewport: SubViewport
var _camera: Camera3D
var _canvas: TextureRect
var _reference_sprites: Array[TextureRect] = []
var _rear_motion: Dictionary = {}
var _head_look: Dictionary = {}
var _turntable_viewport: SubViewport
var _turntable_sprite: TextureRect
var _turntable_kart: Node3D
var _turntable_character := -1
var _spin_elapsed := 0.0
var _elapsed := 0.0
var _resize_clock := 0.0

# Small per-racer offsets keep the lineup feeling like the illustrated
# reference: each kitten has a slightly different head turn and stance while
# the two hero cats remain readable in the centre pair.
const PRESENTATION_YAW := [-0.15, -0.18, 0.16, -0.12, 0.12, -0.16, 0.19, 0.22]
const PRESENTATION_ROLL := [0.022, -0.024, 0.012, -0.016, 0.020, -0.012, 0.020, -0.020]
const TURNTABLE_PERIOD := 6.0
const TURNTABLE_BASE_YAW := 0.22
const REAR_MOTION = preload("res://scripts/track_lineup_motion.gdshader")
const Core = preload("res://scripts/cat_core_assets.gd")
# The clean rear crops share a canvas, but the visible tails sit on different
# sides. Zizi's and Biscuit's tails are mostly hidden by their karts.
const TAIL_CENTERS := [Vector2(-1.0,-1.0),Vector2(0.22,0.46),Vector2(0.20,0.52),Vector2(0.76,0.51),Vector2(0.20,0.56),Vector2(0.21,0.50),Vector2(0.83,0.45),Vector2(0.20,0.47)]
# Individual transparent core-pack files replace the former sheet crops.
# The 3D racers remain as hidden alignment and hit-testing anchors.
const REFERENCE_SPRITES := {
	0: "res://assets/characters/core/zizi/selection/select_sprite.png",
	1: "res://assets/characters/core/luna/selection/select_sprite.png",
	2: "res://assets/characters/core/milo/selection/select_sprite.png",
	3: "res://assets/characters/core/biscuit/selection/select_sprite.png",
	4: "res://assets/characters/core/mochi/selection/select_sprite.png",
	5: "res://assets/characters/core/pumpkin/selection/select_sprite.png",
	6: "res://assets/characters/core/mak-doong/selection/select_sprite.png",
	7: "res://assets/characters/core/nori/selection/select_sprite.png",
}
const REFERENCE_REAR_SPRITES := {
	0: "res://assets/characters/reference/hires/zizi_back_hires.png",
	1: "res://assets/characters/reference/hires/luna_back_hires.png",
	2: "res://assets/characters/reference/hires/milo_back_hires.png",
	3: "res://assets/characters/reference/hires/biscuit_back_hires.png",
	4: "res://assets/characters/reference/hires/mochi_back_hires.png",
	5: "res://assets/characters/reference/hires/pumpkin_back_hires.png",
	6: "res://assets/characters/reference/hires/mak_doong_back_clean.png",
	7: "res://assets/characters/reference/hires/nori_back_hires.png",
}
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas = TextureRect.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_canvas.stretch_mode = TextureRect.STRETCH_SCALE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_canvas.texture = _viewport.get_texture()
	var scene := Node3D.new()
	_viewport.add_child(scene)
	_lighting(scene)
	var source := load("res://scripts/kart_visual.gd") as Script
	for slot in range(characters.size()):
		var kart := Node3D.new()
		kart.set_script(source)
		scene.add_child(kart)
		kart.call("build", characters[slot], mode)
		kart.position.x = -(float(slot) - float(characters.size()-1)*0.5)*3.05
		var presentation_angle: float = 0.0 if rear_view else PRESENTATION_YAW[characters[slot]]
		kart.rotation.y = (PI if rear_view else 0.0) + presentation_angle
		kart.rotation.z = 0.0 if rear_view else PRESENTATION_ROLL[characters[slot]]
		# A supplied sheet sprite is the visible presentation layer for this
		# front-facing menu slot. Keep the native node as an invisible anchor so
		# selection markers and hit regions still use the same measured geometry.
		var reference_map: Dictionary = REFERENCE_REAR_SPRITES if rear_view else REFERENCE_SPRITES
		if mode == "cats" and not single_preview and reference_map.has(characters[slot]):
			kart.visible = false
		karts.append(kart)
		# Photographed sheet sprites already carry their own grounded tire shadow.
		# Do not leave a second shadow-catching plane under the hidden 3D anchor:
		# that dark plane is what produced the halo/ghost edge around wheels during
		# selection and track lineup transitions.
		var has_reference: bool = (REFERENCE_REAR_SPRITES if rear_view else REFERENCE_SPRITES).has(characters[slot])
		if mode != "cats" or not has_reference:
			_contact_shadow(scene,kart.position)
	_bench(scene,float(characters.size())*3.05+0.8)
	# Character Select uses the normalized side-view cutouts and portraits from
	# the core pack. Track Select keeps its rear illustrations, since the pack
	# has no rear-facing frames for that camera angle.
	if mode == "cats" and not single_preview:
		var reference_map: Dictionary = REFERENCE_REAR_SPRITES if rear_view else REFERENCE_SPRITES
		for slot in range(characters.size()):
			var character: int = characters[slot]
			var path: String = str(reference_map.get(character, ""))
			if path.is_empty() or not ResourceLoader.exists(path): continue
			var sprite := TextureRect.new()
			sprite.name = "ReferenceSprite_%s_%d" % ["back" if rear_view else "front", character]
			sprite.texture = load(path)
			sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			# Keep the entire straight-alpha canvas; no cropped wheels or halo.
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if rear_view:
				var slot_width: float = size.x / maxf(1.0, float(characters.size()))
				sprite.position = Vector2(slot * slot_width, 0.0)
				sprite.size = Vector2(slot_width, size.y)
				var motion := ShaderMaterial.new()
				motion.shader = REAR_MOTION
				motion.set_shader_parameter("tail_center",TAIL_CENTERS[character])
				if character == 6:
					motion.set_shader_parameter("head_center",Vector2(0.51,0.30))
					motion.set_shader_parameter("tail_radius",Vector2(0.17,0.22))
				sprite.material = motion
				_rear_motion[slot] = motion
				_head_look[slot] = 0.0
			else:
				sprite.position = Vector2(6.0 + slot * 174.0, 92.0)
				sprite.size = Vector2(166.0, 190.0)
			sprite.z_index = 0
			add_child(sprite)
			_reference_sprites.append(sprite)
	_camera = Camera3D.new()
	scene.add_child(_camera)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 0.1
	_camera.far = 80
	_camera.position = Vector3(0,4.4,-22)
	_camera.look_at(Vector3(0,1.72,0))
	_camera.current = true
	if single_preview:
		_camera.position = Vector3(4.1,3.8,-9.5)
		_camera.look_at(Vector3(0,1.75,0))
	resized.connect(_resize_target)
	visibility_changed.connect(_sync_visibility)
	_resize_target()
	if mode == "cats" and not rear_view and not single_preview:
		_setup_turntable()
		_sync_turntable_selection()
	_sync_visibility()

func _setup_turntable() -> void:
	# Only the active racer switches from the supplied 2D cutout to the
	# original 3D model. An isolated transparent viewport lets it turn in place
	# without changing the scale or alignment of the other seven card images.
	_turntable_viewport = SubViewport.new()
	_turntable_viewport.name = "SelectedRacerTurntable"
	_turntable_viewport.size = Vector2i(498, 570)
	_turntable_viewport.transparent_bg = true
	_turntable_viewport.own_world_3d = true
	_turntable_viewport.msaa_3d = Viewport.MSAA_4X
	_turntable_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_turntable_viewport)
	var scene := Node3D.new()
	_turntable_viewport.add_child(scene)
	_lighting(scene)
	var source := load("res://scripts/kart_visual.gd") as Script
	_turntable_kart = Node3D.new()
	_turntable_kart.name = "SelectedRacer3D"
	_turntable_kart.set_script(source)
	scene.add_child(_turntable_kart)
	_turntable_character = selected_character
	_turntable_kart.call("build", selected_character, "cats")
	var turn_camera := Camera3D.new()
	scene.add_child(turn_camera)
	turn_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	turn_camera.near = 0.1
	turn_camera.far = 80.0
	turn_camera.size = 4.9
	turn_camera.position = Vector3(0.0, 3.0, -9.0)
	turn_camera.look_at(Vector3(0.0, 2.0, 0.0))
	turn_camera.current = true
	_turntable_sprite = TextureRect.new()
	_turntable_sprite.name = "SelectedRacerTurntableTexture"
	_turntable_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_turntable_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	_turntable_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_turntable_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turntable_sprite.texture = _turntable_viewport.get_texture()
	_turntable_sprite.size = Vector2(166.0, 190.0)
	_turntable_sprite.z_index = 2
	add_child(_turntable_sprite)

func _sync_turntable_selection() -> void:
	if not is_instance_valid(_turntable_kart) or not is_instance_valid(_turntable_sprite): return
	var selected_slot := characters.find(selected_character)
	var showing := selected_slot >= 0 and is_visible_in_tree()
	_turntable_kart.visible = showing
	_turntable_sprite.visible = showing
	for slot in range(_reference_sprites.size()):
		_reference_sprites[slot].visible = not showing or slot != selected_slot
	if not showing: return
	_turntable_sprite.position = Vector2(6.0 + selected_slot * 174.0, 92.0)
	if _turntable_character != selected_character:
		_turntable_character = selected_character
		_turntable_kart.call("build", selected_character, "cats")
	_turntable_kart.rotation.y = _turntable_yaw(_spin_elapsed)

func _turntable_yaw(seconds: float) -> float:
	return TURNTABLE_BASE_YAW + TAU * fposmod(seconds, TURNTABLE_PERIOD) / TURNTABLE_PERIOD

func _sync_visibility() -> void:
	if not is_instance_valid(_viewport): return
	var showing := is_visible_in_tree()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if showing else SubViewport.UPDATE_DISABLED
	if is_instance_valid(_turntable_viewport):
		_turntable_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if showing and is_instance_valid(_turntable_kart) and _turntable_kart.visible else SubViewport.UPDATE_DISABLED
	set_process(showing)

func _resize_target() -> void:
	if not is_instance_valid(_viewport) or size.x<1 or size.y<1: return
	# Supersample the actual display target. One roster pass is cheaper and more
	# coherent than eight independently stretched, low-resolution thumbnails.
	var scale_factor := maxf(1.5,get_global_transform_with_canvas().get_scale().x*1.5)
	if characters.size()>1: scale_factor=maxf(scale_factor,float(characters.size()*400)/maxf(1,size.x))
	var target := Vector2i(ceilf(size.x*scale_factor),ceilf(size.y*scale_factor))
	if target.x>3200: target=Vector2i(Vector2(target)*(3200.0/float(target.x)))
	if target.y>1200: target=Vector2i(Vector2(target)*(1200.0/float(target.y)))
	_viewport.size = Vector2i(maxi(64,target.x),maxi(64,target.y))
	if is_instance_valid(_camera):
		var aspect := size.x/maxf(1,size.y)
		_camera.size = maxf(4.85,(float(characters.size())*3.05+0.10)/aspect)
		if single_preview: _camera.size = 5.6

func _lighting(scene: Node3D) -> void:
	var holder := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0,0,0,0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c2c7c9")
	environment.ambient_light_energy = 0.28
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = .95
	environment.ssao_enabled = true
	environment.ssao_radius = .8
	environment.ssao_intensity = 1.35
	environment.ssao_light_affect = .30
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("516071")
	sky_material.sky_horizon_color = Color("eee9df")
	sky_material.ground_horizon_color = Color("b3a18c")
	sky_material.ground_bottom_color = Color("493c31")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	holder.environment = environment
	scene.add_child(holder)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-36,-145,0)
	key.light_color = Color("ffe4b3")
	key.light_energy = .9
	key.light_angular_distance = 1.2
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 45
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.shadow_bias = .02
	key.shadow_normal_bias = .12
	scene.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18,140,0)
	fill.light_color = Color("e7eff9")
	fill.light_energy = .16
	scene.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-28,15,-12)
	rim.light_color = Color("ffc67b")
	rim.light_energy = .5
	scene.add_child(rim)
	# A soft camera-side source lifts the black coat and keeps the eyes and white
	# bib legible against the warm clubhouse plate, like the reference key light.
	var face_fill := OmniLight3D.new()
	face_fill.position = Vector3(0, 3.35, -5.2)
	face_fill.light_color = Color("ffe8d2")
	face_fill.light_energy = 1.15
	face_fill.omni_range = 18.0
	face_fill.shadow_enabled = false
	scene.add_child(face_fill)

func _bench(scene: Node3D,width: float) -> void:
	# A real shadow-catching floor integrates the native racers with the wooden
	# worktop in the clubhouse art without adding a flat, floating brown slab.
	var floor:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2(width+6,9)
	floor.mesh=plane
	floor.position=Vector3(0,-.025,.5)
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color("725031")
	material.roughness=.87
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shadow_to_opacity=true
	floor.material_override=material
	scene.add_child(floor)

func _contact_shadow(scene: Node3D,point: Vector3) -> void:
	# Transparent SubViewports do not always retain the floor's lighting alpha.
	# This soft grounded footprint guarantees contact under the actual tires.
	var gradient:=Gradient.new()
	gradient.offsets=PackedFloat32Array([0.0,.40,.76,1.0])
	gradient.colors=PackedColorArray([Color(.055,.026,.012,.60),Color(.055,.026,.012,.42),Color(.055,.026,.012,.17),Color(.055,.026,.012,0)])
	var texture:=GradientTexture2D.new()
	texture.width=128
	texture.height=128
	texture.fill=GradientTexture2D.FILL_RADIAL
	texture.fill_from=Vector2(.5,.5)
	texture.fill_to=Vector2(1,.5)
	texture.gradient=gradient
	var plane:=PlaneMesh.new()
	plane.size=Vector2(3.65,4.7)
	var shadow:=MeshInstance3D.new()
	shadow.mesh=plane
	shadow.position=point+Vector3(0,-.009,.04)
	shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture=texture
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	shadow.material_override=material
	scene.add_child(shadow)

func racer_screen_center(slot: int) -> Vector2:
	if slot<0 or slot>=karts.size(): return Vector2.INF
	var pixel:=_camera.unproject_position(karts[slot].global_position+Vector3.UP*1.7)
	return get_global_transform_with_canvas()*(pixel/Vector2(_viewport.size)*size)

func racer_screen_rect(slot: int) -> Rect2:
	if slot<0 or slot>=karts.size(): return Rect2()
	var meshes: Array[Node]=karts[slot].find_children("*","MeshInstance3D",true,false)
	var first:=true
	var result:=Rect2()
	for node in meshes:
		var mesh:=node as MeshInstance3D
		var bounds: AABB=mesh.get_aabb()
		for corner in range(8):
			var world_point: Vector3=mesh.global_transform*bounds.get_endpoint(corner)
			var point: Vector2=get_global_transform_with_canvas()*(_camera.unproject_position(world_point)/Vector2(_viewport.size)*size)
			result=Rect2(point,Vector2.ZERO) if first else result.expand(point)
			first=false
	return result

func _process(delta: float) -> void:
	_elapsed += delta
	_resize_clock += delta
	if _resize_clock>.5:
		_resize_clock=0
		_resize_target()
	for slot in range(karts.size()):
		var kart := karts[slot]
		var selected: bool = characters[slot]==selected_character
		var base_rotation := PI if rear_view else 0.0
		var presentation_angle: float = 0.0 if rear_view else PRESENTATION_YAW[characters[slot]]
		var motion := sin(_elapsed*.65)*.075 if selected and not reduced_motion else 0.0
		kart.rotation.y=base_rotation+presentation_angle+motion
		kart.rotation.z = 0.0 if rear_view else PRESENTATION_ROLL[characters[slot]] + sin(_elapsed*.55 + slot)*.006
		if not reduced_motion and kart.visible: kart.call("animate",delta,0.0,0.0,0.0,false)
	if is_instance_valid(_turntable_kart):
		_sync_turntable_selection()
		if _turntable_kart.visible:
			if reduced_motion:
				_turntable_kart.rotation.y = TURNTABLE_BASE_YAW
			else:
				_spin_elapsed = fposmod(_spin_elapsed + delta, TURNTABLE_PERIOD)
				_turntable_kart.rotation.y = _turntable_yaw(_spin_elapsed)
				_turntable_kart.call("animate", delta, 0.0, 0.0, 0.0, false)
	if rear_view and not _rear_motion.is_empty():
		var course_x := size.x * (0.125 + 0.375 * float(selected_course))
		var slot_width := size.x / maxf(1.0,float(characters.size()))
		for slot in _rear_motion:
			var head_target := clampf((course_x - (float(slot)+0.5)*slot_width) / (size.x / 3.0),-1.0,1.0)
			var prior: float = float(_head_look[slot])
			var current := head_target if reduced_motion else lerpf(prior,head_target,1.0-exp(-delta*3.5))
			_head_look[slot] = current
			var material: ShaderMaterial = _rear_motion[slot]
			material.set_shader_parameter("look",current)
			material.set_shader_parameter("tail_wag",0.0 if reduced_motion else sin(_elapsed*2.2 + float(slot)*1.05)*0.8)
