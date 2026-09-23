extends "res://scripts/ui_racer_stage.gd"
## The Garage is the side-view showcase for the numbered core-pack frames.
const SpriteAnimator = preload("res://scripts/cat_sprite_animator.gd")
var character_index := 0
var active := false
var kart: Node3D
var animator: TextureRect
var effects: Dictionary = {}
var _demo_clock := 0.0

func _ready() -> void:
	characters.assign([character_index])
	selected_character = character_index
	single_preview = true
	super._ready()
	if not karts.is_empty(): kart = karts[0]
	if mode != "cats": return
	if is_instance_valid(kart): kart.visible = false
	for effect in ["dust", "boost_flame", "skid_smoke"]:
		var sprite := TextureRect.new()
		sprite.name = "SharedVFX_" + effect
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.texture = load(Core.vfx(effect))
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The kart faces right. The blue jet's bright tip belongs at its left
		# exhaust; the softer dust and smoke sit behind the rear tire.
		var side: float = 179.0 if effect == "boost_flame" else 218.0
		var center := Vector2(28, 375) if effect == "boost_flame" else Vector2(93, 408)
		sprite.position = center - Vector2.ONE * side * 0.5
		sprite.size = Vector2.ONE * side
		sprite.modulate = Color(1, 1, 1, 0.7)
		sprite.visible = false
		add_child(sprite)
		effects[effect] = sprite
	animator = SpriteAnimator.new()
	animator.name = "CoreSpriteAnimator"
	animator.set("character_index", character_index)
	animator.position = Vector2(-7, -42)
	animator.size = Vector2(595, 595)
	animator.z_index = 1
	add_child(animator)

func _process(delta: float) -> void:
	super._process(delta)
	if not active or mode != "cats" or not is_instance_valid(animator): return
	if reduced_motion:
		animator.call("show_state", "idle")
		animator.set_process(false)
		for effect in effects.values(): (effect as TextureRect).visible = false
		return
	animator.set_process(true)
	_demo_clock = fmod(_demo_clock + delta, 5.2)
	var boosting := _demo_clock >= 3.0 and _demo_clock < 4.0
	var braking := _demo_clock >= 4.0
	var speed := 0.0 if _demo_clock < 1.4 else 38.0 if boosting else 27.0 if not braking else 10.0
	animator.call("set_motion", speed, braking, boosting)
	for effect in effects:
		var sprite: TextureRect = effects[effect]
		sprite.visible = (effect == "dust" and not braking and not boosting and speed > 4.0) or (effect == "boost_flame" and boosting) or (effect == "skid_smoke" and braking)
		if sprite.visible: sprite.modulate.a = 0.55 + sin(_demo_clock * 9.0) * 0.10
