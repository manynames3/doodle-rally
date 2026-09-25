extends Control
## Responsive, fully interactive clubhouse menus. Every label and button is native UI.
signal start_race(character_index: int, course_index: int)
signal quit_requested
signal settings_changed(values: Dictionary)

const Data = preload("res://scripts/rally_data.gd")
const WoodSign = preload("res://scripts/ui_wood_sign.gd")
const Paw = preload("res://scripts/ui_paw.gd")
const MenuIcon = preload("res://scripts/ui_menu_icon.gd")
const KartPreview = preload("res://scripts/ui_kart_preview.gd")
const RacerStage = preload("res://scripts/ui_racer_stage.gd")
const CHALK = preload("res://assets/fonts/Kalam-Bold.ttf")
const ART := "res://assets/art/"
const CREAM := Color("fff6dc")
const GOLD := Color("ffda4b")
const INK := Color("17212b")
# Keep the two player mascots together in the visual center of the lineup.
# These are display positions only; stable character indices remain in rally_data.
const DISPLAY_ORDER := [1, 2, 3, 0, 6, 4, 5, 7]
const DESCRIPTIONS := ["Your tuxedo.\nReady to rally.", "Steady and reliable\non any track.", "Light and quick.\nBorn to zoom.", "Strong and sturdy.\nGo full throttle.", "Smooth and nimble.\nLoves the corners.", "Unexpected moves.\nAlways a surprise.", "Calico. Golden halo.\nFinds the best line.", "Precise and clever.\nFinds the best line."]
const STATS := [[0.70,0.73,0.72],[0.65,0.78,0.82],[0.92,0.94,0.59],[0.80,0.58,0.53],[0.67,0.73,0.99],[0.74,0.90,0.72],[0.69,0.82,0.93],[0.72,0.82,0.91]]
const DIFFICULTY_NAMES := ["Easy", "Medium", "Hard"]
var selected_mode := "cats"
var selected_character := 0
var selected_course := 1
var screen := ""
var preferences := {"master_volume": 0.8, "music_volume": 0.65, "reduced_motion": false, "auto_accelerate": false, "difficulty": 2, "graphics_quality": 0}
var _background: TextureRect
var _wash: TextureRect
var _stage: Control
var _cards: Array[Button] = []
var _difficulty_buttons: Array[Button] = []
var _previews: Array[Control] = []
var _placards: Array[Panel] = []
var _spotlights: Array[Panel] = []
var _lineup: Control
var _selection_label: Label
var _selection_detail: Label
var _elapsed := 0.0
var _navigation_axis := 0
var _markers: Array[Control] = []
var _transition: Tween

func _ready() -> void:
	_configure_ui_input()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_background = TextureRect.new()
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wash = TextureRect.new()
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wash)
	_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage = Control.new()
	_stage.name = "MenuStage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.size = Vector2(1440, 900)
	add_child(_stage)
	resized.connect(_layout)
	_layout()

func _configure_ui_input() -> void:
	# Godot 4.7 platform defaults may contain only keyboard events. Bind all
	# controllers explicitly; leave existing keyboard bindings intact.
	var buttons := {"ui_accept":JOY_BUTTON_A,"ui_cancel":JOY_BUTTON_B,"ui_select":JOY_BUTTON_X,"ui_left":JOY_BUTTON_DPAD_LEFT,"ui_right":JOY_BUTTON_DPAD_RIGHT,"ui_up":JOY_BUTTON_DPAD_UP,"ui_down":JOY_BUTTON_DPAD_DOWN}
	for action: String in buttons:
		if not InputMap.has_action(action):
			InputMap.add_action(action,0.4)
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = buttons[action]
		if not InputMap.action_has_event(action,event):
			InputMap.action_add_event(action,event)
	var axes := {"ui_left":[JOY_AXIS_LEFT_X,-1.0],"ui_right":[JOY_AXIS_LEFT_X,1.0],"ui_up":[JOY_AXIS_LEFT_Y,-1.0],"ui_down":[JOY_AXIS_LEFT_Y,1.0]}
	for action: String in axes:
		var event := InputEventJoypadMotion.new()
		event.device = -1
		event.axis = axes[action][0]
		event.axis_value = axes[action][1]
		if not InputMap.action_has_event(action,event):
			InputMap.action_add_event(action,event)
		InputMap.action_set_deadzone(action,0.4)

func _focus_when_ready(button: Variant) -> void:
	if is_instance_valid(button) and button.is_inside_tree():
		button.grab_focus()

func set_preferences(values: Dictionary) -> void:
	for key in preferences:
		if values.has(key):
			preferences[key] = values[key]

func _layout() -> void:
	if not is_instance_valid(_stage):
		return
	var ui_scale := minf(size.x / 1440.0, size.y / 900.0)
	_stage.scale = Vector2.ONE * ui_scale
	_stage.position = (size - Vector2(1440, 900) * ui_scale) * 0.5

func _reset(next_screen: String, title_art: bool = false) -> void:
	screen = next_screen
	visible = true
	_cards.clear()
	_difficulty_buttons.clear()
	_previews.clear()
	_placards.clear()
	_spotlights.clear()
	_lineup=null
	_markers.clear()
	_selection_label = null
	_selection_detail = null
	for child in _stage.get_children():
		_stage.remove_child(child)
		child.queue_free()
	_background.texture = load(ART + ("title_race_v3.png" if title_art else "clubhouse.png"))
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	gradient.colors = PackedColorArray([Color(0.015,0.055,0.075,0.22), Color(0.02,0.06,0.09,0.04), Color(0.02,0.04,0.08,0.01)]) if title_art else PackedColorArray([Color(0.025,0.02,0.025,0.2), Color(0.025,0.02,0.025,0.09), Color(0.025,0.02,0.025,0.27)])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2.ZERO
	gradient_texture.fill_to = Vector2(1,0) if title_art else Vector2(0,1)
	_wash.texture = gradient_texture
	if is_instance_valid(_transition):
		_transition.kill()
	_stage.modulate.a = 1.0
	if not preferences.reduced_motion:
		_stage.modulate.a = 0.0
		_transition = create_tween()
		_transition.tween_property(_stage, "modulate:a", 1.0, 0.2)

func _style(bg: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.015, 0.012, 0.01, 0.33)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0,5)
	return style

func _panel(parent: Control, rect: Rect2, bg: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 14) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", _style(bg, border, width, radius))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func _label(parent: Control, text: String, rect: Rect2, font_size: int, color: Color = CREAM, centered: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", CHALK)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.35))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Control, text: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_override("font", CHALK)
	button.add_theme_font_size_override("font_size", 31 if primary else 26)
	button.add_theme_color_override("font_color", INK if primary else CREAM)
	button.add_theme_color_override("font_hover_color", INK if primary else GOLD)
	button.add_theme_color_override("font_focus_color", INK if primary else GOLD)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_stylebox_override("normal", _style(GOLD if primary else Color(0.055,0.09,0.10,0.86), Color("ab6a22") if primary else Color(1,0.89,0.68,0.23), 2, 11))
	button.add_theme_stylebox_override("hover", _style(Color("ffe994") if primary else Color("263f43"), GOLD, 3, 11))
	button.add_theme_stylebox_override("pressed", _style(Color("efb943"), CREAM, 3, 11))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, CREAM, 3, 11))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _paw(parent: Control, rect: Rect2, color: Color = CREAM) -> Control:
	var p := Control.new()
	p.set_script(Paw)
	p.position = rect.position
	p.size = rect.size
	p.color = color
	parent.add_child(p)
	return p

func _logo(parent: Control, rect: Rect2, compact: bool = false) -> void:
	var sign := Control.new()
	sign.set_script(WoodSign)
	sign.position = rect.position
	sign.size = rect.size
	sign.rotation = -0.035
	parent.add_child(sign)
	_label(sign, "DOODLE RALLY", Rect2(16, 2, rect.size.x - 76, rect.size.y - 8), 44 if compact else 68, Color("241910"), true)
	_paw(sign, Rect2(rect.size.x-68, rect.size.y*0.23, 50, 50), Color("241910"))
	var subtitle := Control.new()
	subtitle.set_script(WoodSign)
	subtitle.dark = true
	subtitle.position = rect.position + Vector2(rect.size.x*0.19, rect.size.y-5)
	subtitle.size = Vector2(rect.size.x*0.62, 49 if compact else 65)
	subtitle.rotation = -0.035
	parent.add_child(subtitle)
	_label(subtitle, "MINECRAFT RACING" if selected_mode == "minecraft" else "CAT RACERS", Rect2(4,0,subtitle.size.x-8,subtitle.size.y), (20 if compact else 27) if selected_mode == "minecraft" else (25 if compact else 33), CREAM, true)

func _header(title: String, subtitle: String) -> void:
	_logo(_stage, Rect2(34,33,396,84), true)
	_label(_stage, title, Rect2(462,55,700,76), 54, CREAM, true)
	_label(_stage, subtitle, Rect2(440,130,744,45), 24, Color("f2dfbb"), true)
	_paw(_stage, Rect2(1192,81,58,58), Color(1,0.98,0.91,0.6))

func _footer(back_callback: Callable, continue_callback: Callable = Callable(), continue_text: String = "LET'S RACE!") -> void:
	_button(_stage, "B / Esc   Back", Rect2(37,810,218,56), back_callback)
	_label(_stage, "←  →  Choose     •     A / Enter  Select", Rect2(280,816,720,47), 22, CREAM, true)
	if continue_callback.is_valid():
		_button(_stage, continue_text + "   →", Rect2(1085,797,317,73), continue_callback, true)

func _name_for(character: int) -> String:
	return Data.BLOCK_NAMES[character] if selected_mode == "minecraft" else Data.NAMES[character]

func _wood_button(text: String, rect: Rect2, callback: Callable, icon_name: String, primary: bool = false) -> Button:
	var button := _button(_stage,"",rect,callback,primary)
	button.name = "Menu_" + text.replace(" ","_")
	button.tooltip_text = text
	var sign := Control.new()
	sign.set_script(WoodSign)
	sign.position = Vector2(4,4)
	sign.size = rect.size - Vector2(8,8)
	sign.tint = Color("f4c763") if primary else Color("825532")
	button.add_child(sign)
	var icon := Control.new()
	icon.set_script(MenuIcon)
	icon.kind = icon_name
	icon.color = INK if primary else CREAM
	icon.position = Vector2(18,10)
	icon.size = Vector2(44,44)
	sign.add_child(icon)
	var text_label := _label(sign,text,Rect2(80,0,rect.size.x-94,rect.size.y-10),32,INK if primary else CREAM)
	var illuminate := func():
		sign.tint = Color("f9d268")
		icon.color = INK
		icon.queue_redraw()
		text_label.add_theme_color_override("font_color",INK)
		sign.queue_redraw()
	var relax := func():
		if button.has_focus() or button.is_hovered():
			return
		sign.tint = Color("f4c763") if primary else Color("825532")
		icon.color = INK if primary else CREAM
		icon.queue_redraw()
		text_label.add_theme_color_override("font_color",INK if primary else CREAM)
		sign.queue_redraw()
	button.mouse_entered.connect(illuminate)
	button.focus_entered.connect(illuminate)
	button.mouse_exited.connect(relax)
	button.focus_exited.connect(relax)
	return button

func _start_cats() -> void:
	selected_mode = "cats"
	show_characters()

func _start_blocks() -> void:
	selected_mode = "minecraft"
	show_characters()

func show_title() -> void:
	if not is_instance_valid(_stage):
		return
	_reset("title", true)
	var sign := Control.new()
	sign.set_script(WoodSign)
	sign.position = Vector2(34,62)
	sign.size = Vector2(621,151)
	sign.rotation = -0.045
	_stage.add_child(sign)
	var title_cat := _label(sign,"CAT",Rect2(20,9,190,126),94,CREAM)
	var title_racers := _label(sign,"RACERS",Rect2(215,9,335,126),80,Color("ffcd59"))
	for title in [title_cat,title_racers]:
		title.add_theme_constant_override("outline_size",12)
		title.add_theme_color_override("font_outline_color",Color("291b14"))
	_paw(sign,Rect2(550,44,60,65),Color("291b14"))
	_label(_stage,"DOODLE RALLY",Rect2(50,25,570,35),21,CREAM,true)
	var subtitle := Control.new()
	subtitle.set_script(WoodSign)
	subtitle.dark = true
	subtitle.position = Vector2(174,201)
	subtitle.size = Vector2(359,89)
	subtitle.rotation = -0.045
	_stage.add_child(subtitle)
	_label(subtitle,"SMALL CATS\nBIG ADVENTURES",Rect2(8,4,343,78),27,CREAM,true)
	# Character and track choice happen inside each racing mode, so keep the
	# title menu focused on starting a mode and the shared garage/settings.
	var start := _wood_button("Cat Racers",Rect2(48,337,422,73),_start_cats,"flag",true)
	_wood_button("Minecraft Racing",Rect2(48,426,422,66),_start_blocks,"cube")
	_wood_button("Garage",Rect2(48,515,352,66),_show_garage,"wrench")
	_wood_button("Options",Rect2(48,604,352,66),show_settings,"gear")
	_label(_stage,"Ready, Set, Meow!",Rect2(59,778,433,55),32,CREAM)
	_paw(_stage,Rect2(368,787,40,40),CREAM)
	_button(_stage,"How to play",Rect2(47,843,202,42),_show_controls)
	_button(_stage,"Quit",Rect2(268,843,110,42),func(): quit_requested.emit())
	_label(_stage,"A / Enter   Select",Rect2(489,841,420,46),28,CREAM,true)
	_panel(_stage,Rect2(1113,783,278,91),Color("f3dba7"),Color("c59c61"),2,4)
	_label(_stage,"Small cats.\nBig adventures. Together.",Rect2(1126,788,252,78),20,Color("40362b"),true)
	_focus_when_ready.call_deferred(start)

func show_characters() -> void:
	_reset("characters")
	_header("Character Select", "Minecraft Racing • Blocky friends. Big adventures." if selected_mode == "minecraft" else "Different cats. Different styles. Same fun!")
	_character_workbench()
	for slot in range(8):
		var character: int = DISPLAY_ORDER[slot]
		var card := Button.new()
		card.name = "Character_" + _name_for(character)
		card.position = Vector2(28 + slot*174,242)
		card.size = Vector2(166,484)
		card.focus_mode = Control.FOCUS_NONE
		card.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		card.add_theme_stylebox_override("hover",StyleBoxEmpty.new())
		card.add_theme_stylebox_override("pressed",StyleBoxEmpty.new())
		card.pressed.connect(_choose_character.bind(character))
		_stage.add_child(card)
		_cards.append(card)
		# The reference roster uses a dark presentation panel behind each racer;
		# it keeps the bright fur and paint readable against the clubhouse plate.
		_panel(card,Rect2(0,0,166,284),Color(0.025,0.036,0.047,0.86),Color("5d5146"),1,10)
		var spotlight := _panel(card,Rect2(-3,-4,172,283),Color(1,.73,.12,.08),GOLD,3,12)
		_spotlights.append(spotlight)
		var marker := _panel(card,Rect2(56,-12,55,34),Color("b54420"),GOLD,2,6)
		_label(marker,"P1",Rect2(0,0,55,32),23,CREAM,true)
		marker.z_index=2
		_markers.append(marker)
		var placard := _panel(card,Rect2(0,284,166,201),Color(.055,.038,.031,.93),Color("765643"),1,8)
		placard.z_index=2
		_placards.append(placard)
		_label(placard,_name_for(character),Rect2(5,3,156,36),26 if _name_for(character).length()>8 else 29,CREAM,true)
		_label(placard,Data.STYLES[character],Rect2(3,39,160,28),20,Data.COLORS[character],true)
		_label(placard,"Block-built racer.\nReady to roll." if selected_mode=="minecraft" else DESCRIPTIONS[character],Rect2(5,71,156,45),16,Color("e5ddd0"),true)
		for stat in range(3):
			_label(placard,["Speed","Accel.","Handling"][stat],Rect2(10,123+stat*23,66,21),14,CREAM)
			_panel(placard,Rect2(79,132+stat*23,76,8),Color("403b3c"),Color.TRANSPARENT,0,4)
			_panel(placard,Rect2(79,132+stat*23,76*STATS[character][stat],8),Data.COLORS[character],Color.TRANSPARENT,0,4)
	_lineup=_racer_stage(Rect2(22,224,1396,314),DISPLAY_ORDER,false)
	_selection_label = _label(_stage,"",Rect2(294,739,854,39),24,GOLD,true)
	_choose_character(selected_character)
	_footer(show_title,show_tracks,"CHOOSE TRACK")

func _character_workbench() -> void:
	# Bring the existing photographed worktop forward to meet the tire line.
	# Racers and their contact shadows remain live native geometry above it.
	var surface:=TextureRect.new()
	var atlas:=AtlasTexture.new()
	atlas.atlas=load(ART+"clubhouse.png")
	var source_size:=atlas.atlas.get_size()
	atlas.region=Rect2(0,source_size.y*.688,source_size.x,source_size.y*.312)
	surface.texture=atlas
	surface.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	surface.stretch_mode=TextureRect.STRETCH_SCALE
	surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	surface.position=Vector2(0,453)
	surface.size=Vector2(1440,447)
	_stage.add_child(surface)

func _racer_stage(rect: Rect2, roster: Array, rear: bool) -> Control:
	var stage := Control.new()
	stage.set_script(RacerStage)
	stage.z_index=1
	stage.position=rect.position
	stage.size=rect.size
	stage.characters.assign(roster)
	stage.mode=selected_mode
	stage.selected_character=selected_character
	stage.reduced_motion=preferences.reduced_motion
	stage.rear_view=rear
	_stage.add_child(stage)
	return stage

func _kart_preview(parent: Control, rect: Rect2, character: int) -> Control:
	var preview := Control.new()
	preview.set_script(KartPreview)
	preview.position = rect.position
	preview.size = rect.size
	preview.character_index = character
	preview.mode = selected_mode
	preview.reduced_motion = preferences.reduced_motion
	parent.add_child(preview)
	return preview

func _choose_character(character: int) -> void:
	selected_character=character
	for slot in range(_cards.size()):
		var selected: bool=DISPLAY_ORDER[slot]==character
		if slot<_placards.size():
			var style:=_style(Color(.085,.056,.027,.96) if selected else Color(.045,.032,.028,.94),GOLD if selected else Color("79543c"),3 if selected else 1,8)
			style.shadow_color=Color(1,.62,.04,.55) if selected else Color(0,0,0,.35)
			style.shadow_size=12 if selected else 6
			style.shadow_offset=Vector2.ZERO if selected else Vector2(0,4)
			_placards[slot].add_theme_stylebox_override("panel",style)
		if slot<_spotlights.size():
			_spotlights[slot].visible=selected
			var halo:=_style(Color(1,.73,.12,.05),GOLD,3,12)
			halo.shadow_color=Color(1,.71,.05,.62)
			halo.shadow_size=18
			halo.shadow_offset=Vector2.ZERO
			_spotlights[slot].add_theme_stylebox_override("panel",halo)
		if slot<_markers.size():
			_markers[slot].visible=selected
			if selected and is_instance_valid(_lineup):
				if selected_mode == "cats":
					_markers[slot].position.y=-12
				else:
					var visual_bounds:Rect2=_lineup.racer_screen_rect(slot)
					var top_in_card:Vector2=_cards[slot].get_global_transform_with_canvas().affine_inverse()*visual_bounds.position
					_markers[slot].position.y=top_in_card.y-43
	if is_instance_valid(_lineup): _lineup.selected_character=character
	if is_instance_valid(_selection_label):
		_selection_label.text="P1   "+_name_for(character)+"  •  "+Data.STYLES[character]+"   /   Ready for adventure!"

func show_tracks() -> void:
	_reset("tracks")
	_header("Choose your track", "Minecraft Racing • Same tracks. Blocky racers." if selected_mode == "minecraft" else "Same cats. New adventures.")
	var filenames := ["course_dojo.png", "course_quarry.png", "course_glitch.png"]
	var colors := [Color("54d5ff"), Color("ffdc5f"), Color("e476ff")]
	for course in range(3):
		var card := Button.new()
		card.name = "Track_" + str(course)
		card.position = Vector2(65 + course*443,198)
		card.size = Vector2(424, 414)
		card.focus_mode = Control.FOCUS_NONE
		card.clip_contents = false
		card.add_theme_stylebox_override("normal", _style(Color("161e29"), Color("718080"), 3, 13))
		card.add_theme_stylebox_override("hover", _style(Color("263242"), colors[course], 4, 13))
		card.add_theme_stylebox_override("pressed", _style(Color("263242"), colors[course], 5, 13))
		card.pressed.connect(_choose_course.bind(course))
		_stage.add_child(card)
		_cards.append(card)
		var art := TextureRect.new()
		art.position = Vector2(8,8)
		art.size = Vector2(408,295)
		art.texture = load(ART + filenames[course])
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(art)
		_panel(card,Rect2(22,22,98,32),Color(0.025,0.055,0.07,0.8),Color(1,1,1,0.4),1,16)
		_label(card, "3 LAPS", Rect2(25,21,91,33), 19, CREAM, true)
		_label(card,Data.COURSES[course].to_upper(),Rect2(10,304,404,44),31,CREAM,true)
		_label(card,Data.TAGLINES[course],Rect2(10,347,404,31),22,colors[course],true)
		_label(card,["CREATIVE CIRCUIT", "ALPINE ADVENTURE", "NEON NIGHT RIDE"][course],Rect2(10,384,404,22),14,Color("b7bfbe"),true)
	var display_roster: Array[int]=[3,1,0,4,2,5]
	var previous_slot:=display_roster.find(selected_character)
	if previous_slot>=0: display_roster[previous_slot]=display_roster[2]
	display_roster[2]=selected_character
	_lineup=_racer_stage(Rect2(130,573,1180,224),display_roster,true)
	_selection_label = _label(_stage,"",Rect2(324,774,792,32),21,GOLD,true)
	_choose_course(selected_course)
	_button(_stage, "B / Esc   Back", Rect2(37,810,218,56), show_characters)
	_label(_stage,"LEVEL",Rect2(285,819,118,43),20,CREAM,true)
	for index in range(3):
		var level := index + 2
		var button := _button(_stage,DIFFICULTY_NAMES[index],Rect2(408 + index*185,810,170,56),_choose_difficulty.bind(level))
		button.name = "Difficulty_" + DIFFICULTY_NAMES[index]
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size",22)
		_difficulty_buttons.append(button)
	_choose_difficulty(int(preferences.difficulty),false)
	_button(_stage,"LET'S RACE!   →",Rect2(1085,797,317,73),_launch,true)

func _choose_course(course: int) -> void:
	selected_course = course
	var colors := [Color("54d5ff"), Color("ffdc5f"), Color("e476ff")]
	for i in range(_cards.size()):
		var selected: bool = i == course
		var style := _style(Color("161e29"), colors[i] if selected else Color("6b7476"), 5 if selected else 2, 13)
		if selected:
			style.shadow_color = Color(colors[i],0.75)
			style.shadow_size = 15
			style.shadow_offset = Vector2.ZERO
		_cards[i].add_theme_stylebox_override("normal",style)
	if is_instance_valid(_selection_label):
		_selection_label.text = _name_for(selected_character) + "   →   " + Data.COURSES[course] + "   •   " + DIFFICULTY_NAMES[clampi(int(preferences.difficulty)-2,0,2)] + " / 3 laps"
	if is_instance_valid(_lineup):
		_lineup.selected_course = course

func _choose_difficulty(level: int, save: bool = true) -> void:
	level = clampi(level,2,4)
	if save: _preference("difficulty",level)
	for index in range(_difficulty_buttons.size()):
		var selected := index + 2 == level
		var button := _difficulty_buttons[index]
		button.add_theme_stylebox_override("normal",_style(Color("ffda4b") if selected else Color(0.055,0.09,0.10,0.86),GOLD if selected else Color(1,0.89,0.68,0.23),3 if selected else 2,11))
		button.add_theme_color_override("font_color",INK if selected else CREAM)
	if is_instance_valid(_selection_label) and screen == "tracks": _choose_course(selected_course)

func _launch() -> void:
	if screen != "tracks":
		return
	screen = "loading"
	start_race.emit(selected_character, selected_course)

func _show_garage() -> void:
	_reset("garage")
	_header("The garage", "A closer look at your next favorite ride.")
	_panel(_stage,Rect2(100,236,1240,499),Color(0.055,0.07,0.075,0.92),Color("bd9557"),3,18)
	var preview := _kart_preview(_stage,Rect2(180,221,581,513),selected_character)
	preview.active = true
	_label(_stage,_name_for(selected_character),Rect2(812,268,425,67),51,GOLD)
	_label(_stage,Data.STYLES[selected_character],Rect2(816,339,417,46),30,Data.COLORS[selected_character])
	var identity := "Minecraft Racing" if selected_mode == "minecraft" else "Cat Racers"
	if selected_mode == "cats":
		if selected_character == 0: identity = "Tuxedo · White bib & paws"
		elif selected_character == 6: identity = "Calico · Golden halo"
		elif selected_character == 7: identity = "Tabby · Precision racer"
	_label(_stage,identity,Rect2(815,393,411,35),23,CREAM)
	for stat in range(3):
		_label(_stage,["Speed", "Acceleration", "Handling"][stat],Rect2(815,455+stat*62,190,34),23)
		_panel(_stage,Rect2(1015,467+stat*62,234,12),Color("444b48"),Color.TRANSPARENT,0,6)
		_panel(_stage,Rect2(1015,467+stat*62,234*STATS[selected_character][stat],12),Data.COLORS[selected_character],Color.TRANSPARENT,0,6)
	_label(_stage,"Choose your racer to change your kart.",Rect2(800,663,480,35),19,Color("b8c8bd"))
	_button(_stage,"←",Rect2(116,461,58,67),func():
		selected_character=posmod(selected_character-1,8)
		_show_garage())
	_button(_stage,"→",Rect2(720,461,58,67),func():
		selected_character=posmod(selected_character+1,8)
		_show_garage())
	_footer(show_title,show_tracks,"CHOOSE TRACK")

func show_settings() -> void:
	_reset("settings")
	_header("Make it yours", "A little tune-up before the adventure.")
	_panel(_stage,Rect2(223,228,994,540),Color(0.055,0.07,0.075,0.96),Color("bd9557"),3,18)
	_label(_stage,"SOUND & PLAY",Rect2(266,252,386,45),29,GOLD)
	_label(_stage,"Master volume",Rect2(270,316,344,40),25)
	_slider("master_volume",Rect2(710,323,390,30))
	_label(_stage,"Music volume",Rect2(270,382,344,40),25)
	_slider("music_volume",Rect2(710,389,390,30))
	_label(_stage,"Difficulty",Rect2(270,448,344,40),25)
	var difficulty := OptionButton.new()
	difficulty.position = Vector2(710,447)
	difficulty.size = Vector2(390,45)
	for difficulty_name in DIFFICULTY_NAMES:
		difficulty.add_item(difficulty_name)
	difficulty.selected = clampi(int(preferences.difficulty)-2,0,2)
	difficulty.add_theme_font_override("font",CHALK)
	difficulty.add_theme_font_size_override("font_size",24)
	difficulty.add_theme_stylebox_override("normal",_style(Color("314441"),Color("597068"),1,8))
	difficulty.add_theme_stylebox_override("focus",_style(Color.TRANSPARENT,GOLD,3,8))
	difficulty.item_selected.connect(func(value: int): _preference("difficulty",value+2))
	_stage.add_child(difficulty)
	_label(_stage,"Graphics",Rect2(270,510,344,40),25)
	var graphics := OptionButton.new()
	graphics.position = Vector2(710,510)
	graphics.size = Vector2(390,45)
	for quality_name in ["Smooth motion", "Balanced", "Full detail"]:
		graphics.add_item(quality_name)
	graphics.selected = int(preferences.graphics_quality)
	graphics.add_theme_font_override("font",CHALK)
	graphics.add_theme_font_size_override("font_size",24)
	graphics.add_theme_stylebox_override("normal",_style(Color("314441"),Color("597068"),1,8))
	graphics.add_theme_stylebox_override("focus",_style(Color.TRANSPARENT,GOLD,3,8))
	graphics.item_selected.connect(func(value: int): _preference("graphics_quality",value))
	_stage.add_child(graphics)
	_toggle("auto_accelerate", "Auto-accelerate", "Keep moving while you focus on steering.", 574)
	_toggle("reduced_motion", "Reduced motion", "Calmer camera and menu animation.", 656)
	_button(_stage,"DONE   →",Rect2(1085,797,317,73),show_title,true)
	_button(_stage,"B / Esc   Back",Rect2(37,810,218,56),show_title)
	_label(_stage,"Your settings are saved automatically.",Rect2(329,819,710,43),22,CREAM,true)
	_focus_when_ready.call_deferred(difficulty)

func _slider(key: String, rect: Rect2) -> void:
	var slider := HSlider.new()
	slider.position = rect.position
	slider.size = rect.size
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(preferences[key])
	var rail := _style(Color("52615d"),Color.TRANSPARENT,0,5)
	rail.content_margin_top = 5
	rail.content_margin_bottom = 5
	var fill := _style(GOLD,Color.TRANSPARENT,0,5)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	slider.add_theme_stylebox_override("slider",rail)
	slider.add_theme_stylebox_override("grabber_area",fill)
	slider.add_theme_stylebox_override("grabber_area_highlight",fill)
	var knob := load("res://assets/art/ui_slider_knob.svg") as Texture2D
	slider.add_theme_icon_override("grabber",knob)
	slider.add_theme_icon_override("grabber_highlight",knob)
	slider.add_theme_stylebox_override("focus",_style(Color.TRANSPARENT,CREAM,2,8))
	slider.value_changed.connect(func(value: float): _preference(key,value))
	_stage.add_child(slider)

func _toggle(key: String, title: String, description: String, y: float) -> void:
	_label(_stage,title,Rect2(270,y,418,37),25)
	_label(_stage,description,Rect2(270,y+37,660,30),18,Color("b8c7ba"))
	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.position = Vector2(955,y+4)
	toggle.size = Vector2(140,48)
	toggle.text = "ON" if preferences[key] else "OFF"
	toggle.button_pressed = bool(preferences[key])
	toggle.add_theme_font_override("font",CHALK)
	toggle.add_theme_font_size_override("font_size",24)
	toggle.add_theme_stylebox_override("normal",_style(Color("314441"),Color("647870"),2,8))
	toggle.add_theme_stylebox_override("pressed",_style(Color("46582e"),GOLD,2,8))
	toggle.add_theme_stylebox_override("hover",_style(Color("51614c"),CREAM,2,8))
	toggle.add_theme_stylebox_override("hover_pressed",_style(Color("607243"),GOLD,2,8))
	toggle.add_theme_stylebox_override("focus",_style(Color.TRANSPARENT,GOLD,3,8))
	toggle.toggled.connect(func(value: bool):
		toggle.text = "ON" if value else "OFF"
		_preference(key,value))
	_stage.add_child(toggle)

func _preference(key: String, value: Variant) -> void:
	preferences[key] = value
	settings_changed.emit(preferences.duplicate())

func _show_controls() -> void:
	_reset("controls")
	_header("Let's go racing", "A few tricks. A whole lot of fun.")
	_panel(_stage,Rect2(150,227,1140,520),Color(0.055,0.07,0.075,0.96),Color("bd9557"),3,18)
	_label(_stage,"THE BASICS",Rect2(194,253,400,45),30,GOLD)
	var actions := ["Accelerate", "Brake", "Steer", "Drift / hop", "Use item", "Boost", "Recover", "Pause"]
	var keyboard := ["W / ↑", "S / ↓", "A D / ← →", "Space", "E", "Shift", "R", "Esc"]
	var controller := ["Right trigger", "Left trigger", "Left stick", "Left bumper / L1", "X / Square", "Right bumper / R1", "Y / Triangle", "Start / Options"]
	_label(_stage,"KEYBOARD",Rect2(622,259,249,32),21,Color("a4dcef"))
	_label(_stage,"CONTROLLER",Rect2(936,259,278,32),21,Color("a4dcef"))
	for i in range(actions.size()):
		var y := 308+i*42
		_label(_stage,actions[i],Rect2(199,y,368,39),24)
		_label(_stage,keyboard[i],Rect2(626,y,277,39),23,GOLD)
		_label(_stage,controller[i],Rect2(938,y,296,39),22)
	_label(_stage,"Release a charged drift for mini-turbo. Purrquake pulses nearby rivals.\nHop Feather Fan, bait with Treat Trail, or time Pawfect Parry to reflect a thrown attack.",Rect2(179,649,1080,78),19,Color("cadbcf"),true)
	_button(_stage,"LET'S RACE!   →",Rect2(1085,797,317,73),show_characters,true)
	_button(_stage,"B / Esc   Back",Rect2(37,810,218,56),show_title)
	_label(_stage,"Need a gentler start? Try auto-accelerate in Settings.",Rect2(273,817,769,42),21,CREAM,true)

func _input(event: InputEvent) -> void:
	if not visible or screen == "loading":
		return
	if event.is_action_pressed("ui_cancel"):
		if screen == "tracks":
			show_characters()
		elif screen != "title":
			show_title()
		get_viewport().set_input_as_handled()
		return
	if screen != "characters" and screen != "tracks" and screen != "garage":
		return
	if screen == "tracks" and (event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down")):
		_choose_difficulty(clampi(int(preferences.difficulty) + (-1 if event.is_action_pressed("ui_up") else 1),2,4))
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_X:
		if absf(event.axis_value) < 0.4:
			_navigation_axis = 0
			return
		var axis_direction := int(signf(event.axis_value))
		if _navigation_axis == axis_direction:
			return
		_navigation_axis = axis_direction
	var direction := 0
	if event.is_action_pressed("ui_left"):
		direction = -1
	elif event.is_action_pressed("ui_right"):
		direction = 1
	if direction != 0:
		if screen == "garage":
			selected_character = posmod(selected_character + direction, 8)
			_show_garage()
		elif screen == "characters":
			var slot := DISPLAY_ORDER.find(selected_character)
			_choose_character(DISPLAY_ORDER[posmod(slot + direction, 8)])
		else:
			_choose_course(posmod(selected_course + direction, 3))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if screen == "characters" or screen == "garage":
			show_tracks()
		else:
			_launch()
		get_viewport().set_input_as_handled()
