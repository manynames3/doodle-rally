extends RefCounted

var values: Dictionary = {"master_volume": 0.7, "music_volume": 0.55, "reduced_motion": false, "auto_accelerate": false, "difficulty": 2, "graphics_quality": 0}
var records: Dictionary = {}
var selected_character := 0
var selected_course := 1
var selected_mode := "cats"
var file_path := "user://rally_3d.cfg"
var enabled := true
var last_error := ""

func load_data() -> void:
	if not enabled: return
	var config := ConfigFile.new()
	if config.load(file_path) != OK: return
	for key in values:
		var value: Variant = config.get_value("settings", key, values[key])
		if key in ["master_volume", "music_volume"]:
			if (value is float or value is int) and is_finite(float(value)): values[key] = clampf(float(value), 0, 1)
		elif key == "difficulty":
			if value is int: values[key] = clampi(value, 0, 2)
		elif key == "graphics_quality":
			if value is int: values[key] = clampi(value, 0, 2)
		elif value is bool: values[key] = value
	selected_character = clampi(int(config.get_value("racer", "character", 0)), 0, 7)
	selected_course = clampi(int(config.get_value("racer", "course", 1)), 0, 2)
	selected_mode = "minecraft" if str(config.get_value("racer", "mode", "cats")) == "minecraft" else "cats"
	for course in range(3):
		for difficulty in range(3):
			for mode in ["cats", "minecraft"]:
				var key := "%s_%d_%d" % [mode, course, difficulty]
				var value: Variant = config.get_value("records", key, -1.0)
				if (value is float or value is int) and is_finite(float(value)) and float(value) > 0:
					records[key] = float(value)

func save_data() -> bool:
	if not enabled: return true
	var config := ConfigFile.new()
	for key in values: config.set_value("settings", key, values[key])
	for key in records: config.set_value("records", key, records[key])
	config.set_value("racer", "character", selected_character)
	config.set_value("racer", "course", selected_course)
	config.set_value("racer", "mode", selected_mode)
	var temporary := file_path + ".tmp"
	var result := config.save(temporary)
	if result == OK: result = DirAccess.rename_absolute(temporary, file_path)
	last_error = "" if result == OK else "Could not save preferences on this Mac."
	return result == OK

func best(course: int, difficulty: int, mode: String = "cats") -> float:
	return float(records.get("%s_%d_%d" % [mode, course, difficulty], -1.0))

func record(course: int, difficulty: int, seconds: float, mode: String = "cats") -> bool:
	if course < 0 or course > 2 or difficulty < 0 or difficulty > 2 or mode not in ["cats", "minecraft"] or not is_finite(seconds) or seconds <= 0:
		return false
	var key := "%s_%d_%d" % [mode, course, difficulty]
	var previous := float(records.get(key, INF))
	if seconds >= previous: return false
	records[key] = seconds
	save_data()
	return true
