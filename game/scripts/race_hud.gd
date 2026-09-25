extends Control
const Data = preload("res://scripts/rally_data.gd")
const FONT = preload("res://assets/fonts/Kalam-Bold.ttf")
const RACE_FONT = preload("res://assets/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
const Sim = preload("res://scripts/race_sim.gd")
const Core = preload("res://scripts/cat_core_assets.gd")
signal pause_requested
var sim: RefCounted
var course := 1
var best_time := -1.0
var countdown := 3.0
var announcement := ""
var announcement_time := 0.0
var using_controller := false
var reduced_motion := false
var map_points := PackedVector2Array()
var map_min := Vector2.ZERO
var map_span := Vector2.ONE
var pause_button: Button
var _time := 0.0
var cat_portraits: Array[Texture2D] = []
var block_portraits: Array[Texture2D] = []
var _world: Node3D

func _ready() -> void:
	for i in range(8):
		var path := Core.portrait(i)
		cat_portraits.append(load(path) as Texture2D if ResourceLoader.exists(path) else null)
		path = "res://assets/portraits/block_%d.png" % i
		block_portraits.append(load(path) as Texture2D if ResourceLoader.exists(path) else null)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_button = Button.new()
	pause_button.text = "Ⅱ"
	pause_button.tooltip_text = "Pause · Esc / Start"
	pause_button.add_theme_font_size_override("font_size", 24)
	pause_button.position = Vector2(684, 17)
	pause_button.size = Vector2(50, 40)
	pause_button.pressed.connect(func(): pause_requested.emit())
	add_child(pause_button)
	resized.connect(_layout_pause)
	_layout_pause()

func _layout_pause() -> void:
	if pause_button:
		pause_button.position = Vector2(size.x * 0.5 - 25, 14)

func configure(race: RefCounted, world: Node3D, course_index: int, record: float) -> void:
	sim = race
	_world = world
	course = course_index
	best_time = record
	var samples := PackedVector2Array()
	map_min = Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for i in range(161):
		var point: Vector3 = world.sample(float(i) / 160.0 * float(world.length))
		var p := Vector2(point.x, point.z)
		map_min = map_min.min(p)
		maximum = maximum.max(p)
		samples.append(p)
	map_span = maximum - map_min
	var max_axis := maxf(map_span.x, map_span.y)
	map_min -= (Vector2.ONE * max_axis - map_span) / 2
	map_span = Vector2.ONE * max_axis
	map_points.clear()
	for p in samples: map_points.append(_map(p))

func announce(message: String, duration: float = 2.0) -> void:
	announcement = message
	announcement_time = duration

func _process(delta: float) -> void:
	_time += delta
	announcement_time = maxf(0, announcement_time - delta)
	queue_redraw()

func _draw() -> void:
	if sim == null or sim.racers.is_empty(): return
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(1440, 900))
	var player: Dictionary = sim.racers[0]
	var rank: int = sim.player_place()
	var yellow := Color("ffdc53")
	_race_text(Vector2(34, 111), str(rank), 108, yellow)
	_race_text(Vector2(114, 103), "/8", 52, Color.WHITE)
	_race_text(Vector2(40, 140), "POSITION", 16, Color("fff4d4"), 2)
	var order: Array[int] = sim.standings()
	for j in range(order.size()):
		var id: int = order[j]
		var racer: Dictionary = sim.racers[id]
		var ch := int(racer.character)
		var y := 166.0 + j * 33.0
		var panel_color := Color(0.03, 0.045, 0.07, 0.65)
		if id == 0: panel_color = Color(1.0, 0.76, 0.12, 0.95)
		_panel(Rect2(31, y - 24, 202, 31), panel_color, 7)
		_race_text(Vector2(40, y + 1), str(j + 1), 27, Color.WHITE if id != 0 else Color("202030"), 2 if id != 0 else 0)
		_cat_icon(Vector2(84, y - 9), 11, ch)
		var name_text: String = str(Data.BLOCK_NAMES[ch]) if str(sim.mode) == "minecraft" else str(Data.NAMES[ch])
		_race_text(Vector2(105, y + 1), name_text, 24, Color.WHITE if id != 0 else Color("202030"), 1 if id != 0 else 0)
	_panel(Rect2(1171, 25, 241, 77), Color(0.025, 0.035, 0.06, 0.83), 12)
	_race_text(Vector2(1185, 77), "LAP", 30, Color.WHITE)
	_race_text(Vector2(1255, 88), "%d/3" % mini(int(player.lap), 3), 62, Color.WHITE)
	_panel(Rect2(1202, 109, 210, 39), Color(0.025, 0.035, 0.06, 0.82), 8)
	_race_text(Vector2(1217, 140), Data.time_string(float(sim.race_time)), 32, Color.WHITE, 2)
	_panel(Rect2(1171, 154, 241, 29), Color(0.025, 0.035, 0.06, 0.7), 6)
	_race_text(Vector2(1182, 176), "BEST", 18, yellow, 1)
	_race_text(Vector2(1245, 176), Data.time_string(best_time), 21, Color.WHITE, 1)
	if map_points.size() > 2:
		draw_polyline(map_points, Color(0.035, 0.03, 0.05, 0.85), 12, true)
		draw_polyline(map_points, Color(0.94, 0.93, 0.91, 0.85), 7, true)
		var f := map_points[0]
		for x in range(3):
			for y in range(3): draw_rect(Rect2(f + Vector2(x * 5, y * 5) - Vector2(7, 7), Vector2(5, 5)), Color.WHITE if (x + y) % 2 == 0 else Color("252234"))
		for j in range(order.size() - 1, -1, -1):
			var index: int = order[j]
			var r: Dictionary = sim.racers[index]
			var p3: Vector3 = r.position
			_cat_icon(_map(Vector2(p3.x, p3.z)), 10 if index == 0 else 7, int(r.character), index == 0)
		# Trap pins keep road items legible on the course map when a kart hides
		# their small 3D model in a tight pack. Show nearby threats only.
		for hazard in sim.hazards:
			if float(hazard.get("life", 0.0)) <= 0: continue
			var forward := fposmod(float(hazard.distance) - float(player.distance), float(sim.track_length))
			var behind := fposmod(float(player.distance) - float(hazard.distance), float(sim.track_length))
			if minf(forward, behind) > 150.0: continue
			var hazard_position: Vector3 = _world.sample(float(hazard.distance), float(hazard.lane))
			_draw_hazard_pin(_map(Vector2(hazard_position.x, hazard_position.z)), str(hazard.get("kind", "yarn")))
	# Item wheel, made large enough to read at couch distance.
	var center := Vector2(111, 770)
	draw_circle(center + Vector2(3, 4), 82, Color(0.01, 0.012, 0.018, 0.40))
	draw_circle(center, 76, Color(0.018, 0.024, 0.04, 0.88))
	draw_arc(center, 78, 0, TAU, 96, Color("332b27"), 8, true)
	draw_arc(center, 76, -PI * .85, PI * .45, 72, Color("bcb6a9"), 3, true)
	draw_arc(center, 68, 0, TAU, 96, Color("243740"), 7, true)
	draw_arc(center, 68, -PI * .8, PI * 1.20, 96, Color("60c8e8"), 3, true)
	draw_arc(center, 64, -PI * .85, -PI * .35, 32, Color("dcfaff"), 2, true)
	_draw_item(center, str(player.item))
	_keycap(Vector2(168, 821), "X" if using_controller else "E")
	_text(Vector2(42, 873), "ITEM", 19, Color.WHITE)
	if float(player.shield) > 0:
		_text(Vector2(50, 674), "SHIELD %.0fs" % ceilf(float(player.shield)), 21, Color("91efff"))
	# Speedometer sweep.
	center = Vector2(1306, 798)
	draw_circle(center, 103, Color(0.045, 0.035, 0.029, 0.76))
	draw_arc(center, 108, PI * .88, PI * 2.12, 110, Color("352a25"), 13, true)
	draw_arc(center, 106, PI * .88, PI * 2.12, 110, Color("c9baa7"), 7, true)
	draw_arc(center, 101, PI * .88, PI * 2.12, 110, Color("fff9e7"), 3, true)
	var speed := float(player.speed) * 3.6
	for seg in range(15):
		var start := PI * .89 + float(seg) / 15.0 * PI * 1.21
		var color := Color("5cd6f6") if seg < 9 else Color("ffdc58") if seg < 12 else Color("ff7851")
		if speed / 205.0 < float(seg) / 15: color = color.darkened(.22)
		draw_arc(center, 90, start, start + .215, 8, Color("15191c"), 16, true)
		draw_arc(center, 90, start, start + .20, 8, color, 12, true)
	for tick in range(31):
		var angle := PI * .89 + float(tick) / 30.0 * PI * 1.21
		var ray := Vector2(cos(angle), sin(angle))
		draw_line(center + ray * 77, center + ray * (71 if tick % 5 == 0 else 74), Color(1, .97, .88, .55), 1.5, true)
	_center_race_text(Vector2(1306, 820), str(int(speed)), 65, Color.WHITE, 5)
	_center_race_text(Vector2(1306, 846), "km/h", 21, Color.WHITE)
	# Refillable reserve and drift-charge indication.
	_panel(Rect2(927, 818, 241, 47), Color(0.02, .03, .05, .9), 12, Color("ddd0b5"), 3)
	for segment in range(6):
		var amount := clampf(float(player.boost) / 100 * 6 - segment, 0, 1)
		var rect := Rect2(939 + segment * 31, 829, 25, 23)
		draw_rect(rect, Color("183f59"))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * amount, rect.size.y)), Color("5fddff"))
	_keycap(Vector2(1149, 844), "RB" if using_controller else "⇧", 18)
	_text(Vector2(936, 806), "PAW POWER", 18, Color.WHITE)
	if bool(player.drifting):
		var color := yellow if float(player.drift) >= 1.6 else Color("6ee6ff")
		_panel(Rect2(506, 757, 427, 53), Color(0.02, .03, .05, .65), 18)
		_center_text(Vector2(720, 791), "RELEASE FOR TURBO!" if float(player.drift) >= .75 else "HOLD THE DRIFT…", 26, color)
		var amount := minf(1, float(player.drift) / 1.6)
		draw_line(Vector2(532, 809), Vector2(532 + 376 * amount, 809), color, 4, true)
	if countdown > 0:
		var value := str(int(ceilf(countdown)))
		_center_race_text(Vector2(720, 446), value, 155, yellow, 9)
		_center_text(Vector2(720, 500), "READY, LITTLE RACER?", 30, Color.WHITE)
	elif countdown > -0.75:
		_center_race_text(Vector2(720, 446), "GO!", 143, yellow, 8)
	if announcement_time > 0 and countdown <= -0.75:
		_center_text(Vector2(720, 200), announcement, 41, Color("ffdf68"), 4)
	if float(sim.race_time) < 14:
		_panel(Rect2(380, 837, 501, 41), Color(0.02, .03, .05, .62), 11)
		var prompt := "RT  Gas   •   Stick  Steer   •   LB  Drift" if using_controller else "W / ↑  Gas    A D / ← →  Steer    Space  Drift"
		_center_text(Vector2(630, 865), prompt, 18, Color("fff4d9"), 1)
	_race_text(Vector2(290, 35), "MINECRAFT RACING" if str(sim.mode) == "minecraft" else "CAT RACERS", 22, Color("ffedb2"), 2)
	_text(Vector2(40, 455), str(Data.COURSES[course]).to_upper(), 16, Color("fff0c8"), 2)

func _map(point: Vector2) -> Vector2:
	return Vector2(1200, 215) + (point - map_min) / map_span * 186

func _panel(rect: Rect2, color: Color, radius: int = 10, border: Color = Color.TRANSPARENT, width: int = 0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(width)
	draw_style_box(style, rect)

func _text(pos: Vector2, value: String, font_size: int, color: Color, outline: int = 3) -> void:
	if outline > 0: draw_string_outline(FONT, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, Color("10131d"))
	draw_string(FONT, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _center_text(pos: Vector2, value: String, font_size: int, color: Color, outline: int = 3) -> void:
	_text(pos - Vector2(FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2, 0), value, font_size, color, outline)

func _race_text(pos: Vector2, value: String, font_size: int, color: Color, outline: int = 3) -> void:
	if outline > 0: draw_string_outline(RACE_FONT, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, Color("10131d"))
	draw_string(RACE_FONT, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _center_race_text(pos: Vector2, value: String, font_size: int, color: Color, outline: int = 3) -> void:
	_race_text(pos - Vector2(RACE_FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2, 0), value, font_size, color, outline)

func _keycap(center: Vector2, value: String, font_size: int = 23) -> void:
	draw_circle(center, 23, Color("1b1e23"))
	draw_arc(center, 22, 0, TAU, 32, Color("fff7e4"), 3, true)
	_center_text(center + Vector2(0, 9), value, font_size, Color.WHITE, 0)

func _cat_icon(center: Vector2, radius: float, character: int, selected: bool = false) -> void:
	var portraits := block_portraits if sim != null and str(sim.mode) == "minecraft" else cat_portraits
	if portraits.size() == 8 and portraits[character] != null:
		if selected: draw_circle(center, radius + 4, Color("ffda42"))
		draw_circle(center, radius + 1, Color("171e25"))
		draw_texture_rect(portraits[character], Rect2(center - Vector2.ONE * radius * 1.45, Vector2.ONE * radius * 2.9), false)
		return
	if sim != null and str(sim.mode) == "minecraft":
		var skin: Color = [Color("bc875c"), Color("dba274"), Color("5faf42"), Color("242034"), Color("70a150"), Color("dad3c2"), Color("e9a4a7"), Color("bb906b")][character]
		draw_rect(Rect2(center - Vector2.ONE * (radius + 2), Vector2.ONE * (radius + 2) * 2), Color("ffdc52") if selected else Color("171923"))
		draw_rect(Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2), skin)
		var eye := Color("cc61ff") if character == 3 else Color("28232d")
		draw_rect(Rect2(center + Vector2(-radius * .6, -radius * .25), Vector2(radius * .38, radius * .35)), eye)
		draw_rect(Rect2(center + Vector2(radius * .25, -radius * .25), Vector2(radius * .38, radius * .35)), eye)
		draw_rect(Rect2(center + Vector2(-radius * .25, radius * .35), Vector2(radius * .5, radius * .25)), eye)
		return
	var fur: Color = [Color("26232b"), Color("99989d"), Color("fff2ed"), Color("eb993b"), Color("dec6a4"), Color("f99a36"), Color("82858c"), Color("8f8f98")][character]
	if selected: draw_circle(center, radius + 4, Color("ffda42"))
	draw_circle(center, radius + 1, Color("171e25"))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-radius, 0), center + Vector2(-radius, -radius * 1.35), center + Vector2(-radius * .1, -radius * .55)]), fur)
	draw_colored_polygon(PackedVector2Array([center + Vector2(radius, 0), center + Vector2(radius, -radius * 1.35), center + Vector2(radius * .1, -radius * .55)]), fur)
	draw_circle(center, radius, fur)
	draw_circle(center + Vector2(-radius * .36, radius * .25), radius * .42, Color("fff0d9"))
	draw_circle(center + Vector2(radius * .36, radius * .25), radius * .42, Color("fff0d9"))
	draw_circle(center + Vector2(-radius * .34, -radius * .16), radius * .18, Color("202427"))
	draw_circle(center + Vector2(radius * .34, -radius * .16), radius * .18, Color("202427"))
	draw_circle(center + Vector2(0, radius * .25), radius * .14, Color("d98687"))

func _draw_item(center: Vector2, item: String) -> void:
	match item:
		"fish":
			draw_set_transform(Vector2.ZERO, 0, size / Vector2(1440, 900))
			draw_circle(center + Vector2(14, 0), 27, Color("fff0d9"))
			draw_line(center + Vector2(-39, 0), center + Vector2(3, 0), Color("fff0d9"), 8, true)
			for i in range(3):
				var x := -31.0 + i * 12
				draw_line(center + Vector2(x + 4, 0), center + Vector2(x - 2, -16), Color("fff0d9"), 6, true)
				draw_line(center + Vector2(x + 4, 0), center + Vector2(x - 2, 16), Color("fff0d9"), 6, true)
			draw_circle(center + Vector2(22, -6), 5, Color("182333"))
		"yarn":
			draw_circle(center, 35, Color("f480b5"))
			for i in range(5): draw_arc(center + Vector2(i * 5 - 10, 0), 27, -1.3, 1.3, 24, Color("973e82"), 3, true)
			draw_arc(center + Vector2(26, 30), 23, -.8, 2.2, 22, Color("ffb4d4"), 5, true)
		"turbo":
			draw_colored_polygon(PackedVector2Array([center + Vector2(6, -42), center + Vector2(-29, 7), center + Vector2(-3, 7), center + Vector2(-11, 44), center + Vector2(31, -9), center + Vector2(4, -9)]), Color("ffd545"))
		"bubble":
			draw_circle(center, 35, Color(.3, .85, 1, .4))
			draw_arc(center, 34, 0, TAU, 48, Color("a9f9ff"), 4, true)
			draw_arc(center + Vector2(-2, -2), 24, PI * 1.1, PI * 1.55, 18, Color.WHITE, 6, true)
		"purrquake":
			for radius in [17.0, 28.0, 39.0]:
				draw_arc(center, radius, -.28, TAU + .28, 48, Color("ff82cf"), 4, true)
			draw_circle(center, 10, Color("fff0d9"))
			draw_circle(center + Vector2(-15, -18), 6, Color("fff0d9"))
			draw_circle(center + Vector2(0, -23), 6, Color("fff0d9"))
			draw_circle(center + Vector2(15, -18), 6, Color("fff0d9"))
		"feather_fan":
			for i in range(3):
				var offset := Vector2(float(i - 1) * 22, 0)
				draw_line(center + offset + Vector2(-11, 15), center + offset + Vector2(12, -15), Color("fff0d9"), 4, true)
				draw_arc(center + offset + Vector2(7, -7), 13, -.25, PI * 1.25, 22, [Color("ffd36b"), Color("f69ac4"), Color("b4e8e5")][i], 8, true)
		"treat_trail":
			draw_circle(center, 32, Color("e8a55f"))
			draw_arc(center, 31, 0, TAU, 48, Color("fff0c6"), 4, true)
			for spot in [Vector2(-10, -9), Vector2(0, -15), Vector2(10, -9)]:
				draw_circle(center + spot, 4, Color("fff0c6"))
			draw_circle(center + Vector2(0, 3), 10, Color("fff0c6"))
		"paw_parry":
			draw_circle(center, 35, Color("d79b36"))
			draw_arc(center, 38, 0, TAU, 48, Color("fff0a8"), 5, true)
			draw_circle(center + Vector2(0, 8), 11, Color("fff8df"))
			for toe in [Vector2(-18, -7), Vector2(-7, -20), Vector2(8, -20), Vector2(19, -7)]:
				draw_circle(center + toe, 6, Color("fff8df"))
			draw_arc(center, 47, -.72, .72, 24, Color("fff0a8"), 4, true)
		_:
			_center_text(center + Vector2(0, 19), "?", 63, Color("b4d4dd"), 2)

func _draw_hazard_pin(center: Vector2, kind: String) -> void:
	var color := Color("f480b5") if kind == "yarn" else Color("79e6ee") if kind == "feather" else Color("ffc45d")
	draw_circle(center + Vector2(1, 2), 10, Color("10131d"))
	draw_circle(center, 9, color)
	draw_arc(center, 8, 0, TAU, 32, Color("fff7e4"), 1.7, true)
	if kind == "treat":
		draw_circle(center + Vector2(0, 1.5), 2.5, Color("4b3421"))
		for toe in [Vector2(-3.5, -2.2), Vector2(-1.1, -4.2), Vector2(1.1, -4.2), Vector2(3.5, -2.2)]:
			draw_circle(center + toe, 1.25, Color("4b3421"))
	elif kind == "feather":
		draw_line(center + Vector2(-4, 4), center + Vector2(4, -4), Color("12333e"), 1.6, true)
		for barb in range(3):
			var along := float(barb) * 2.0 - 1.0
			draw_line(center + Vector2(along, -along) + Vector2(-2.2, 1.4), center + Vector2(along, -along), Color("12333e"), 1.2, true)
	else:
		draw_arc(center, 4, -.7, 2.1, 16, Color("542346"), 1.4, true)
		draw_arc(center + Vector2(-1.5, 0), 3, 1.8, 4.8, 16, Color("542346"), 1.2, true)

func visible_hazard_marker_count() -> int:
	if sim == null or sim.racers.is_empty(): return 0
	var player: Dictionary = sim.racers[0]
	var count := 0
	for hazard in sim.hazards:
		if float(hazard.get("life", 0.0)) <= 0: continue
		var forward := fposmod(float(hazard.distance) - float(player.distance), float(sim.track_length))
		var behind := fposmod(float(player.distance) - float(hazard.distance), float(sim.track_length))
		if minf(forward, behind) <= 150.0: count += 1
	return count
