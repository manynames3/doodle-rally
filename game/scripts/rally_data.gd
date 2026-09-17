extends RefCounted

const NAMES := ["Zizi", "Luna", "Milo", "Biscuit", "Mochi", "Pumpkin", "Mak-Doong", "Nori"]
const STYLES := ["All-rounder", "Balanced", "Speedster", "Power", "Drifter", "Trickster", "Technical", "Technical"]
const COLORS := [Color("ed4b45"), Color("38b9ef"), Color("f16dab"), Color("ffa52c"), Color("a065ed"), Color("6ddd72"), Color("f8d74e"), Color("efbf3c")]
const COURSES := ["Desktop Dojo", "Block Quarry", "Glitch Core"]
const TAGLINES := ["Draw. Race. Repeat.", "Climb higher. Go further.", "Warp. Drift. Survive."]
const TOP_SPEED := [38.0, 37.2, 40.0, 38.8, 37.6, 38.2, 37.8, 38.4]
const ACCEL := [15.0, 15.5, 17.2, 13.0, 15.0, 17.0, 16.0, 15.4]
const HANDLING := [1.0, 1.08, 0.94, 0.88, 1.22, 1.0, 1.18, 1.15]
const BLOCK_NAMES := ["Steve", "Alex", "Creeper", "Enderman", "Zombie", "Skeleton", "Pig", "Villager"]

static func time_string(seconds: float) -> String:
	if seconds < 0: return "—:—.—"
	var cents := int(seconds * 100.0)
	return "%02d:%02d.%02d" % [cents / 6000, (cents / 100) % 60, cents % 100]

static func ordinal(value: int) -> String:
	return str(value) + (["st", "nd", "rd"][value - 1] if value <= 3 else "th")
