extends Node
## Original Doodle Rally music, isolated from the fighting game's audio routing.
var master_volume := 0.7
var music_volume := 0.55
var silent := false
var music: AudioStreamPlayer
var engine: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var clips: Dictionary = {}
var _voice := 0
var _theme := -1

func _ready() -> void:
	silent = DisplayServer.get_name() == "headless" or "--qa" in OS.get_cmdline_user_args()
	music = AudioStreamPlayer.new()
	engine = AudioStreamPlayer.new()
	add_child(music)
	add_child(engine)
	engine.stream = _tone(72, 72, 0.3, true)
	for i in range(8):
		var v := AudioStreamPlayer.new()
		add_child(v)
		voices.append(v)
	for kind in ["pickup", "boost", "drift", "item", "hit", "wall", "lap", "finish", "countdown", "go", "click", "shield"]:
		var tones: Array = {"pickup": [780, 1320], "boost": [160, 970], "drift": [550, 1320], "item": [640, 350], "hit": [180, 60], "wall": [130, 65], "lap": [650, 1080], "finish": [523, 1568], "countdown": [420, 420], "go": [840, 1200], "click": [780, 840], "shield": [940, 1540]}[kind]
		clips[kind] = _tone(float(tones[0]), float(tones[1]), 0.65 if kind == "finish" else .28 if kind in ["lap", "go", "boost"] else .13)
	clips["bump"] = _tone(95, 45, .075)
	set_mix(master_volume, music_volume)

func set_mix(master: float, soundtrack: float) -> void:
	master_volume = master
	music_volume = soundtrack
	if music: music.volume_db = linear_to_db(maxf(.0001, master * soundtrack * .6))

func play_theme(course: int) -> void:
	if course == _theme: return
	_theme = course
	var name_text: String = ["desk", "castle", "sky"][clampi(course, 0, 2)]
	var stream: AudioStreamWAV = load("res://assets/music/%s.wav" % name_text)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 4
	music.stream = stream
	if not silent: music.play()

func update_engine(speed: float, active: bool, paused: bool = false) -> void:
	engine.stream_paused = paused
	engine.pitch_scale = 0.62 + speed / 38.0 * 1.9
	engine.volume_db = linear_to_db(maxf(.0001, master_volume * .15 * clampf(speed / 10, .12, 1)))
	if active and not silent and not engine.playing: engine.play()
	if not active: engine.stop()

func event(kind: String) -> void:
	if silent or not clips.has(kind): return
	var player := voices[_voice]
	_voice = (_voice + 1) % voices.size()
	player.stream = clips[kind]
	player.volume_db = linear_to_db(maxf(.0001, master_volume * (.25 if kind == "bump" else .50)))
	player.play()

func _tone(start: float, finish: float, duration: float, loop: bool = false) -> AudioStreamWAV:
	const RATE := 22050
	var frames := int(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / RATE
		var phase := TAU * (start * t + (finish - start) * t * t / (2 * duration))
		var envelope := 0.3 if loop else minf(1, t / .008) * pow(1 - t / duration, 1.5) * .35
		var value := (sin(phase) + sin(phase * 2) * .25 + sin(phase * 4) * .09) * envelope
		var sample := int(value * 32760)
		bytes[i * 2] = sample & 255
		bytes[i * 2 + 1] = (sample >> 8) & 255
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = RATE
	wave.data = bytes
	if loop:
		wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wave.loop_end = frames
	return wave
