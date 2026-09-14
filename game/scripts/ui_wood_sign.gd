extends Control
## Reusable transparent wood texture with native, separately rendered labels.
var tint := Color("c98746")
var dark := false
var _texture: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture = load("res://assets/art/wood_sign.png")
	resized.connect(queue_redraw)

func _draw() -> void:
	if not _texture:
		return
	var modulation := Color.WHITE
	if dark:
		modulation = Color(0.52,0.55,0.56)
	elif tint.r < 0.6:
		modulation = Color(0.60,0.65,0.65)
	elif tint.r > 0.9:
		modulation = Color(1.24,1.36,1.2)
	draw_texture_rect(_texture,Rect2(Vector2(4,9),size),false,Color(0,0,0,0.45))
	draw_texture_rect(_texture,Rect2(Vector2.ZERO,size),false,modulation)
