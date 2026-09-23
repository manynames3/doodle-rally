extends TextureRect
## Plays one pack sequence at a time, using the same speed/boost/brake signals
## as the native kart motion. Source frame order is numerical and loops.
const Core = preload("res://scripts/cat_core_assets.gd")
var character_index := 0
var motion_state := "idle"
var frame_index := 0
var _clock := 0.0
var _frames: Dictionary = {}

func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_state("idle")

func set_motion(speed: float, braking: bool, boosting: bool) -> void:
	show_state(Core.motion_state(speed, braking, boosting))

func show_state(next_state: String) -> void:
	if not Core.FRAME_COUNTS.has(next_state): return
	if _frames.is_empty() or motion_state != next_state:
		motion_state = next_state
		frame_index = 0
		_clock = 0.0
		if not _frames.has(next_state):
			var sequence: Array[Texture2D] = []
			for number in range(1, int(Core.FRAME_COUNTS[next_state]) + 1):
				sequence.append(load(Core.frame(character_index, next_state, number)))
			_frames[next_state] = sequence
		texture = _frames[next_state][frame_index]

func _process(delta: float) -> void:
	if not is_visible_in_tree() or _frames.is_empty(): return
	_clock += delta
	var period: float = 1.0 / float(Core.FRAME_RATE[motion_state])
	while _clock >= period:
		_clock -= period
		frame_index = (frame_index + 1) % _frames[motion_state].size()
		texture = _frames[motion_state][frame_index]
