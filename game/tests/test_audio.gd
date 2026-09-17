extends SceneTree
## Soundtrack regression test: every course must have a long, loop-ready mix.
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
		check(stream.get_length() >= 90.0, "%s soundtrack is at least 90 seconds (%.1fs)" % [name, stream.get_length()])
	print("AUDIO QA: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
