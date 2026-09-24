extends SceneTree
## Portable menu integration test: godot --headless --path game --script res://tests/test_menu.gd
## Exercises actual menu routes, native control signals, keyboard/pad events, and layout.
var ui: Control
var launches: Array = []
var settings: Array = []
var quit_count := 0
var checks := 0
var failures := 0

func _initialize() -> void:
	_go.call_deferred()

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Menu check failed: " + description)

func _action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	ui.call("_input",event)

func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _joy(button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _axis(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	ui.call("_input",event)

func _press_title(name: String) -> void:
	ui.get_node("MenuStage/Menu_" + name.replace(" ","_")).pressed.emit()

func _go() -> void:
	root.size = Vector2i(960,600)
	ui = Control.new()
	ui.set_script(load("res://scripts/menu_ui.gd"))
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.start_race.connect(func(character: int,course: int): launches.append([character,course,ui.selected_mode]))
	ui.settings_changed.connect(func(values: Dictionary): settings.append(values))
	ui.quit_requested.connect(func(): quit_count += 1)
	ui.set_preferences({"master_volume":0.25,"music_volume":0.5,"reduced_motion":true,"difficulty":2})
	ui.show_title()
	await process_frame
	await process_frame
	await _key(KEY_ENTER)
	_check(ui.screen == "characters" and ui.selected_mode == "cats", "focused title Start Game accepts keyboard Enter")
	ui.show_title()
	_press_title("Minecraft Racing")
	_check(ui.screen == "characters" and ui.selected_mode == "minecraft", "Minecraft title route selects voxel roster")
	await _key(KEY_RIGHT)
	_check(ui.selected_character == 6, "keyboard selects the next visible character beside the centered Zizi")
	await _joy(JOY_BUTTON_A)
	_check(ui.screen == "tracks", "gamepad confirm opens track selection")
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	_check(ui.selected_course == 2, "gamepad d-pad chooses track")
	await _joy(JOY_BUTTON_B)
	_check(ui.screen == "characters" and ui.selected_mode == "minecraft", "gamepad back preserves roster and selection")
	_axis(0.9)
	var axis_selection: int = ui.selected_character
	_axis(0.95)
	_check(ui.selected_character == axis_selection, "held analog axis does not skip through every character")
	_axis(0.0)
	_axis(0.9)
	_check(ui.selected_character != axis_selection, "analog axis re-arms after neutral")
	_axis(0.0)
	ui.show_tracks()
	ui.call("_choose_course",1)
	_check(ui._difficulty_buttons.size() == 3 and ui._difficulty_buttons[0].text == "Easy" and ui._difficulty_buttons[2].text == "Hard", "track screen exposes Easy, Medium and Hard")
	ui._difficulty_buttons[2].pressed.emit()
	_check(ui.preferences.difficulty == 4 and "Hard" in ui._selection_label.text, "Hard selection applies before launch")
	_action("ui_up")
	_check(ui.preferences.difficulty == 3, "track screen up direction selects Medium")
	ui._difficulty_buttons[0].pressed.emit()
	_check(ui.preferences.difficulty == 2, "Easy restores the established race pace")
	var chosen: int = ui.selected_character
	ui.call("_launch")
	ui.call("_launch")
	_check(launches.size() == 1 and launches[0] == [chosen,1,"minecraft"], "track confirmation emits one race with correct roster")
	ui.show_title()
	var title_routes: Array[String] = []
	for child in ui.get_node("MenuStage").get_children():
		if child is Button and child.name.begins_with("Menu_"):
			title_routes.append(str(child.name))
	_check(title_routes == ["Menu_Start_Game","Menu_Garage","Menu_Minecraft_Racing","Menu_Options"],"title menu contains modes, garage and options without duplicate character/track routes")
	for route in ["Garage","Options"]:
		ui.show_title()
		_press_title(route)
		var expected: String = {"Garage":"garage","Options":"settings"}[route]
		_check(ui.screen == expected,"title route " + route)
	ui.show_settings()
	var stage: Control = ui.get_node("MenuStage")
	var sliders := 0
	var toggles := 0
	var settings_before := settings.size()
	for child in stage.get_children():
		if child is HSlider:
			child.value = 0.7
			sliders += 1
		if child is Button and child.toggle_mode and not child is OptionButton:
			child.button_pressed = not child.button_pressed
			toggles += 1
		if child is OptionButton and child.get_item_text(0) == "Smooth motion":
			child.select(2)
			child.item_selected.emit(2)
		if child is OptionButton and child.get_item_text(0) == "Easy":
			child.select(1)
			child.item_selected.emit(1)
	_check(sliders == 2 and toggles == 2 and settings.size() == settings_before + 6,"native sliders, toggles, graphics and difficulty emit preference changes")
	_check(is_equal_approx(ui.preferences.master_volume,0.7) and ui.preferences.auto_accelerate,"preference payload contains changed values")
	_check(ui.preferences.graphics_quality == 2,"graphics choice reaches saved preferences")
	_check(ui.preferences.difficulty == 3,"Options difficulty matches the track selector")
	_action("ui_cancel")
	_check(ui.screen == "title", "settings cancel returns to title")
	ui.call("_show_garage")
	var previous: int = ui.selected_character
	_action("ui_left")
	_check(ui.screen == "garage" and ui.selected_character == posmod(previous-1,8),"Garage cycles the actual racer")
	_action("ui_accept")
	_check(ui.screen == "tracks","Garage confirm continues to tracks")
	ui.show_title()
	for child in ui.get_node("MenuStage").get_children():
		if child is Button and child.text == "How to play":
			child.pressed.emit()
			break
	_check(ui.screen == "controls", "How to play button opens controls")
	_action("ui_cancel")
	ui.show_title()
	for child in ui.get_node("MenuStage").get_children():
		if child is Button and child.text == "Quit":
			child.pressed.emit()
	_check(quit_count == 1, "Quit requests application shutdown")
	ui.show_title()
	await process_frame
	await process_frame
	await _joy(JOY_BUTTON_DPAD_DOWN)
	await _joy(JOY_BUTTON_DPAD_DOWN)
	await _joy(JOY_BUTTON_A)
	_check(ui.screen == "characters" and ui.selected_mode == "minecraft","title native focus navigates and confirms with gamepad")
	ui.show_title()
	_press_title("Start Game")
	_check(ui.selected_mode == "cats","Start Game returns to cat roster")
	_check(ui.get_node("MenuStage").size.x * ui.get_node("MenuStage").scale.x <= ui.size.x + 1.0,"960x600 layout fits viewport")
	root.content_scale_size = Vector2i(1600,900)
	root.size = Vector2i(1280,720)
	await process_frame
	_check(ui.get_node("MenuStage").size.y * ui.get_node("MenuStage").scale.y <= ui.size.y + 1.0,"16:9 layout fits viewport")
	await process_frame
	print("MENU QA: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
