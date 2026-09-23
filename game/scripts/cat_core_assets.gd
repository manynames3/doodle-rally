extends RefCounted
## The supplied side-view pack is presentation art; gameplay karts stay 3D.

const ROOT := "res://assets/characters/core/"
const TURNTABLE_ROOT := "res://assets/characters/turntable/"
const FOLDERS := ["zizi", "luna", "milo", "biscuit", "mochi", "pumpkin", "mak-doong", "nori"]
const FRAME_COUNTS := {"idle": 4, "drive": 6, "boost": 3, "brake": 3}
const FRAME_RATE := {"idle": 5.0, "drive": 9.0, "boost": 12.0, "brake": 7.0}
const TURNTABLE_FRAME_COUNT := 16
const TURNTABLE_FRAME_SECONDS := 0.375

static func folder(character: int) -> String:
	return ROOT + FOLDERS[clampi(character, 0, 7)] + "/"

static func selection(character: int) -> String:
	return folder(character) + "selection/select_sprite.png"

static func portrait(character: int) -> String:
	return folder(character) + "selection/portrait.png"

static func turntable_frame(character: int, frame_index: int) -> String:
	assert(frame_index >= 0 and frame_index < TURNTABLE_FRAME_COUNT)
	return TURNTABLE_ROOT + FOLDERS[clampi(character, 0, 7)] + "/view_%02d.png" % frame_index

static func frame(character: int, state: String, number: int) -> String:
	assert(FRAME_COUNTS.has(state))
	assert(number >= 1 and number <= FRAME_COUNTS[state])
	return folder(character) + "animation/%s/%s_%02d.png" % [state, state, number]

static func motion_state(speed: float, braking: bool, boosting: bool) -> String:
	if boosting: return "boost"
	if braking: return "brake"
	return "drive" if absf(speed) > 4.0 else "idle"

static func vfx(effect: String) -> String:
	assert(effect in ["dust", "boost_flame", "skid_smoke"])
	return ROOT + "Shared_VFX/" + effect + ".png"
