extends CanvasLayer
## The supplied studio artwork appears once per launch, before menu input begins.
signal finished

const LOGO = preload("res://assets/benjam_games.png")
const FADE_IN := 0.30
const HOLD := 1.45
const FADE_OUT := 0.30

var elapsed := 0.0
var skipping := false
var _skip_elapsed := 0.0
var _skip_alpha := 1.0
var _complete := false
var artwork: TextureRect

func _ready() -> void:
	layer = 30
	var background := ColorRect.new()
	background.color = Color("13181d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)
	artwork = TextureRect.new()
	artwork.texture = LOGO
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork.anchor_left = .08
	artwork.anchor_right = .92
	artwork.anchor_top = .07
	artwork.anchor_bottom = .93
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork.modulate.a = 0
	add_child(artwork)

func skip() -> void:
	if skipping or _complete: return
	skipping = true
	_skip_alpha = artwork.modulate.a

func _process(dt: float) -> void:
	if _complete: return
	elapsed += dt
	if skipping:
		_skip_elapsed += dt
		artwork.modulate.a = _skip_alpha * (1.0 - clampf(_skip_elapsed / .16, 0, 1))
		if _skip_elapsed >= .16: _finish()
	elif elapsed < FADE_IN:
		artwork.modulate.a = smoothstep(0.0, FADE_IN, elapsed)
	elif elapsed < FADE_IN + HOLD:
		artwork.modulate.a = 1
	else:
		artwork.modulate.a = 1.0 - smoothstep(FADE_IN + HOLD, FADE_IN + HOLD + FADE_OUT, elapsed)
		if elapsed >= FADE_IN + HOLD + FADE_OUT: _finish()

func _finish() -> void:
	_complete = true
	set_process(false)
	finished.emit()
	queue_free()
