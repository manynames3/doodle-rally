extends SceneTree
## Music, effects, and audio-router regression checks.
const Sound = preload("res://scripts/rally_sound.gd")
var failures := 0
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for name in ["desk", "castle", "sky"]:
		var stream := load("res://assets/music/%s.wav" % name) as AudioStreamWAV
		check(is_instance_valid(stream), "%s soundtrack loads" % name)
		if not is_instance_valid(stream):
			continue
		check(stream.data.size() > 0, "%s soundtrack contains PCM data" % name)
		check(stream.get_length() >= 90.0 and stream.get_length() <= 140.0, "%s arrangement is a full race-length loop (%.1fs)" % [name, stream.get_length()])
		check(stream.stereo, "%s arrangement has stereo width" % name)
	var engine := load("res://assets/sfx/engine_loop.wav") as AudioStreamWAV
	check(is_instance_valid(engine), "engine loop loads")
	if is_instance_valid(engine):
		check(engine.get_length() >= 0.95 and engine.get_length() <= 1.05, "engine loop has a compact loopable duration")
		check(engine.data.size() > 0 and engine.stereo, "engine loop has stereo PCM")
	var sound := Sound.new()
	root.add_child(sound)
	await process_frame
	check(sound.clips.size() == 20, "all gameplay, UI, and engine sound assets load")
	for kind in sound.clips:
		var clip := sound.clips[kind] as AudioStreamWAV
		check(is_instance_valid(clip) and clip.data.size() > 0, "%s has a distinct loaded sound cue" % kind)
		if is_instance_valid(clip): check(clip.get_length() >= 0.08 and clip.get_length() <= 2.0, "%s cue has a concise effect length" % kind)
	sound.set_mix(0.5, 0.6, 0.4)
	check(is_equal_approx(sound.master_volume, 0.5) and is_equal_approx(sound.music_volume, 0.6) and is_equal_approx(sound.effects_volume, 0.4), "mix controls keep music and effects independently adjustable")
	sound.play_theme(0)
	check(sound.music.stream != null or sound.music_next.stream != null, "course theme starts through the music crossfade pair")
	var first_track := sound._music_active
	sound._process(sound._music_fade_seconds * 0.5)
	check(sound._music_gain[first_track] > 0.45 and sound._music_gain[first_track] < 0.55, "course fade progresses from elapsed time")
	sound.play_theme(1)
	var second_track := sound._music_active
	sound._process(sound._music_fade_seconds)
	check(sound._music_gain[second_track] >= 0.99 and sound._music_gain[first_track] <= 0.001, "course changes crossfade cleanly to the new arrangement")
	print("AUDIO QA: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
