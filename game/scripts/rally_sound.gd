extends Node
## Original course music and event-specific race sound design.
var master_volume := 0.7
var music_volume := 0.55
var effects_volume := 0.8
var silent := false
var music: AudioStreamPlayer
var music_next: AudioStreamPlayer
var engine: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var clips: Dictionary = {}
var _music_players: Array[AudioStreamPlayer] = []
var _music_gain := [0.0, 0.0]
var _music_target := [0.0, 0.0]
var _music_active := -1
var _music_fade_seconds := 0.95
var _duck_gain := 1.0
var _duck_timer := 0.0
var _engine_speed := 0.0
var _engine_active := false
var _voice := 0
var _theme := -1
var _variation := 0

func _ready() -> void:
	silent = DisplayServer.get_name() == "headless" or "--qa" in OS.get_cmdline_user_args()
	music = AudioStreamPlayer.new()
	music.name = "CourseMusic_A"
	music_next = AudioStreamPlayer.new()
	music_next.name = "CourseMusic_B"
	engine = AudioStreamPlayer.new()
	engine.name = "KartEngine"
	add_child(music)
	add_child(music_next)
	add_child(engine)
	_music_players = [music, music_next]
	engine.stream = load("res://assets/sfx/engine_loop.wav") as AudioStreamWAV
	if engine.stream:
		engine.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		engine.stream.loop_begin = 0
		engine.stream.loop_end = maxi(1, int(round(engine.stream.get_length() * engine.stream.mix_rate)))
	for i in range(8):
		var voice := AudioStreamPlayer.new()
		voice.name = "RaceVoice_%d" % i
		add_child(voice)
		voices.append(voice)
	var paths := {
		"pickup": "pickup", "boost": "boost", "drift": "drift", "item": "item",
		"hit": "hit", "wall": "wall", "bump": "bump", "lap": "lap", "finish": "finish",
		"countdown": "countdown", "go": "go", "click": "click", "shield": "shield",
		"purr_wave": "purr_wave", "feather_fan": "feather_fan", "treat_toss": "treat",
		"paw_parry": "paw_parry", "yarn_toss": "yarn", "projectile": "fish", "reset": "reset",
	}
	for kind in paths:
		clips[kind] = load("res://assets/sfx/%s.wav" % paths[kind]) as AudioStreamWAV
	set_mix(master_volume, music_volume, effects_volume)

func set_mix(master: float, soundtrack: float, effects: float = 0.8) -> void:
	master_volume = clampf(master, 0.0, 1.0)
	music_volume = clampf(soundtrack, 0.0, 1.0)
	effects_volume = clampf(effects, 0.0, 1.0)
	_apply_music_levels()
	_apply_engine_level()

func play_theme(course: int) -> void:
	if course == _theme: return
	_theme = course
	var name_text: String = ["desk", "castle", "sky"][clampi(course, 0, 2)]
	var stream := load("res://assets/music/%s.wav" % name_text) as AudioStreamWAV
	if stream == null: return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	# Godot can import WAVs as compressed samples, so decoded duration is authoritative.
	stream.loop_begin = 0
	stream.loop_end = maxi(1, int(round(stream.get_length() * stream.mix_rate)))
	var next_index := 0 if _music_active != 0 else 1
	var incoming := _music_players[next_index]
	incoming.stop()
	incoming.stream = stream
	incoming.volume_db = -70.0
	_music_gain[next_index] = 0.0
	_music_target = [0.0, 0.0]
	_music_target[next_index] = 1.0
	_music_active = next_index
	if not silent: incoming.play()
	_apply_music_levels()

func update_engine(speed: float, active: bool, paused: bool = false) -> void:
	_engine_active = active
	_engine_speed = maxf(speed, 0.0)
	engine.stream_paused = paused
	if active and not silent and not engine.playing: engine.play()
	if not active: engine.stop()
	_apply_engine_level()

func event(kind: String) -> void:
	if silent or not clips.has(kind): return
	var stream := clips[kind] as AudioStreamWAV
	if stream == null: return
	var player := voices[_voice]
	_voice = (_voice + 1) % voices.size()
	player.stream = stream
	player.volume_db = linear_to_db(maxf(0.0001, master_volume * effects_volume * _effect_gain(kind)))
	player.pitch_scale = _next_pitch(kind)
	player.play()
	if kind in ["boost", "drift", "item", "hit", "wall", "shield", "purr_wave", "feather_fan", "treat_toss", "paw_parry", "projectile", "yarn_toss", "lap", "finish", "go"]:
		_duck_timer = maxf(_duck_timer, 0.22 if kind not in ["lap", "finish", "go"] else 0.42)

func _process(delta: float) -> void:
	if _duck_timer > 0.0:
		_duck_timer = maxf(0.0, _duck_timer - delta)
		_duck_gain = move_toward(_duck_gain, 0.72, delta / 0.055)
	else:
		_duck_gain = move_toward(_duck_gain, 1.0, delta / 0.55)
	var fade_step := delta / _music_fade_seconds
	for index in range(_music_players.size()):
		_music_gain[index] = move_toward(_music_gain[index], _music_target[index], fade_step)
		if _music_gain[index] <= 0.0005 and _music_target[index] <= 0.0 and _music_players[index].playing:
			_music_players[index].stop()
	_apply_music_levels()

func _effect_gain(kind: String) -> float:
	match kind:
		"click": return 0.27
		"countdown": return 0.34
		"bump": return 0.36
		"pickup", "item", "reset": return 0.52
		"finish", "go": return 0.72
		"hit", "purr_wave", "paw_parry": return 0.67
		_: return 0.58

func _next_pitch(kind: String) -> float:
	var pitches := [0.985, 1.0, 1.018, 0.994, 1.012]
	var pitch := float(pitches[_variation % pitches.size()])
	_variation += 1
	if kind in ["finish", "lap", "go", "countdown"]: return 1.0
	return pitch

func _apply_music_levels() -> void:
	if _music_players.is_empty(): return
	var base := master_volume * music_volume * 0.90 * _duck_gain
	for index in range(_music_players.size()):
		# Equal-power fades keep perceived loudness steady as two different tracks overlap.
		var gain := base * sqrt(float(_music_gain[index]))
		_music_players[index].volume_db = linear_to_db(maxf(0.0001, gain))

func _apply_engine_level() -> void:
	if engine == null or not _engine_active: return
	var speed_ratio := clampf(_engine_speed / 38.0, 0.0, 1.0)
	engine.pitch_scale = 0.76 + speed_ratio * 0.94
	var gain := master_volume * effects_volume * (0.14 + speed_ratio * 0.15)
	engine.volume_db = linear_to_db(maxf(0.0001, gain))
