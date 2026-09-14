extends Control
var color := Color.WHITE
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var u := minf(size.x, size.y)
	draw_set_transform(Vector2(size.x / 2, size.y / 2), -0.12)
	var pad := PackedVector2Array()
	for j in range(32):
		var a := TAU * float(j) / 32.0
		pad.append(Vector2(cos(a) * 0.27, sin(a) * 0.20 + 0.15) * u)
	draw_colored_polygon(pad, color)
	for v in [Vector2(-0.31, -0.12), Vector2(-0.12, -0.31), Vector2(0.13, -0.31), Vector2(0.33, -0.10)]:
		draw_circle(v * u, u * 0.112, color)
