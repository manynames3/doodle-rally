extends Control
var kind := "paw"
var color := Color.WHITE
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,size/Vector2(48,48))
	match kind:
		"flag":
			draw_line(Vector2(7,45),Vector2(13,5),color,3,true)
			for x in range(4):
				for y in range(3):
					if (x+y)%2 == 0:
						draw_rect(Rect2(14+x*7,7+y*7,7,7),color)
		"mountain":
			draw_polyline(PackedVector2Array([Vector2(3,39),Vector2(18,8),Vector2(27,25),Vector2(33,16),Vector2(46,39),Vector2(3,39)]),color,3,true)
			draw_polyline(PackedVector2Array([Vector2(13,18),Vector2(18,22),Vector2(23,18)]),color,2,true)
		"cube":
			var p := PackedVector2Array([Vector2(24,4),Vector2(44,14),Vector2(44,35),Vector2(24,45),Vector2(4,35),Vector2(4,14),Vector2(24,4)])
			draw_polyline(p,color,3,true)
			draw_polyline(PackedVector2Array([Vector2(4,14),Vector2(24,24),Vector2(44,14)]),color,3,true)
			draw_line(Vector2(24,24),Vector2(24,44),color,3,true)
		"gear":
			for j in range(8):
				var a := TAU*j/8.0
				draw_line(Vector2(24,24)+Vector2.from_angle(a)*12,Vector2(24,24)+Vector2.from_angle(a)*22,color,7,true)
			draw_arc(Vector2(24,24),14,0,TAU,40,color,7,true)
		"wrench":
			draw_line(Vector2(11,39),Vector2(33,16),color,10,true)
			draw_arc(Vector2(32,14),11,-0.25,PI+0.65,24,color,6,true)
			draw_circle(Vector2(10,40),5,color)
		"cat":
			draw_polyline(PackedVector2Array([Vector2(7,21),Vector2(8,5),Vector2(18,14),Vector2(29,14),Vector2(40,5),Vector2(41,22)]),color,2,true)
			draw_arc(Vector2(24,25),18,-0.25,PI+0.25,24,color,2,true)
			draw_circle(Vector2(17,25),2,color)
			draw_circle(Vector2(31,25),2,color)
			draw_line(Vector2(21,31),Vector2(27,31),color,2,true)
