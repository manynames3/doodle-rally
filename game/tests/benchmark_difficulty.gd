extends SceneTree
## Deterministic pace probe: run with --headless --path game --script res://tests/benchmark_difficulty.gd.
const Sim = preload("res://scripts/race_sim.gd")
const World = preload("res://scripts/track_world.gd")
const STEP := 1.0 / 60.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var failures := 0
	for course in range(3):
		var world: Node3D = World.new()
		root.add_child(world)
		world.build(course, "cats")
		var places: Array[int] = []
		var pressures: Array[float] = []
		for level in [2, 3, 4]:
			var sim: RefCounted = Sim.new()
			sim.setup(world, 0, level, "cats")
			for step in range(15000):
				var player: Dictionary = sim.racers[0]
				var steer: float = clampf(-float(player.lane) * 0.3 - float(player.angle) * 2.0, -1.0, 1.0)
				sim.tick(STEP, {"throttle": 1.0, "steer": steer, "boost": step % 240 == 0, "item": player.item != ""})
				if sim.finished: break
			var pressure: float = -INF
			var complete := 0
			for i in range(1, 8):
				var rival: Dictionary = sim.racers[i]
				if float(rival.finish_time) >= 0:
					complete += 1
					pressure = maxf(pressure, (sim.race_time - float(rival.finish_time)) * 40.0)
				else:
					pressure = maxf(pressure, float(rival.distance) - float(sim.racers[0].distance))
			places.append(sim.player_place())
			pressures.append(pressure)
			print("PACE course=%d level=%d player=%.2f place=%d rival_pressure_m=%.1f rivals_finished=%d" % [course, level, sim.race_time, sim.player_place(), pressure, complete])
		if not (places[0] <= places[1] and places[1] <= places[2] and pressures[0] < pressures[1] and pressures[1] < pressures[2]):
			failures += 1
			push_error("Difficulty progression is not competitive and ordered on course %d" % course)
		world.free()
	print("DIFFICULTY_BENCHMARK %d courses; %d failures" % [3,failures])
	quit(1 if failures else 0)
