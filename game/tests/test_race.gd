extends SceneTree
## Run with Godot --headless --path game --script res://tests/test_race.gd.
## Pure simulation tests use a curved, kilometre-scale fixture. Preference files
## live in the workspace work/ directory, never the player's user:// save.

const Sim = preload("res://scripts/race_sim.gd")
const Prefs = preload("res://scripts/preferences.gd")
const STEP: float = 1.0 / 60.0

class TestTrack extends Node3D:
	var length: float = 1200.0
	var road_width: float = 18.0
	var curve: Curve3D = Curve3D.new()
	var item_spots: Array[Dictionary] = []
	var boost_spots: Array[Dictionary] = []
	func sample(distance: float, lane: float = 0.0) -> Vector3:
		var radius: float = length / TAU
		var theta: float = distance / radius
		return Vector3(radius * (1.0 - cos(theta)), 0, -radius * sin(theta)) + Vector3(cos(theta), 0, sin(theta)) * lane
	func tangent(distance: float) -> Vector3:
		var theta: float = distance / (length / TAU)
		return Vector3(sin(theta), 0, -cos(theta))
	func frame(distance: float) -> Basis:
		return Basis.looking_at(tangent(distance), Vector3.UP)

var _checks: int = 0
var _failures: Array[String] = []
var _tracks: Array[Node3D] = []
var _temp_path: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var work_directory: String = ProjectSettings.globalize_path("res://").path_join("../test-output").simplify_path()
	DirAccess.make_dir_recursive_absolute(work_directory)
	_temp_path = work_directory.path_join("race_test_preferences_%d.cfg" % OS.get_process_id())
	_test_setup()
	_test_handling()
	_test_boundaries_and_reset()
	_test_drift_and_boost()
	_test_pickups_and_pads()
	_test_items_hits_and_hazards()
	_test_bumps_and_standings()
	_test_solid_contacts()
	_test_finish_crossing()
	_test_full_races()
	_test_difficulty_pace()
	_test_real_courses()
	await _test_pause_and_timestep()
	_test_preferences()
	for track: Node3D in _tracks:
		track.free()
	for path: String in [_temp_path, _temp_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if _failures.is_empty():
		print("RACE_TESTS_PASS: %d checks; deterministic three-lap races, controls, items, pause, and isolated persistence" % _checks)
		quit(0)
	else:
		for failure: String in _failures:
			print("FAIL: " + failure)
		print("RACE_TESTS_FAILED: %d of %d checks" % [_failures.size(), _checks])
		quit(1)


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)


func _near(actual: float, expected: float, tolerance: float, description: String) -> void:
	_expect(absf(actual - expected) <= tolerance, "%s (actual %.6f, expected %.6f ± %.6f)" % [description, actual, expected, tolerance])


func _new_sim(character: int = 0, difficulty: int = 2, mode: String = "cats", course_items: bool = false) -> RefCounted:
	var world: TestTrack = TestTrack.new()
	_tracks.append(world)
	if course_items:
		for distance: float in [160.0, 440.0, 730.0, 995.0]:
			world.item_spots.append({"distance": distance, "lane": 0.0})
		for distance: float in [300.0, 870.0]:
			world.boost_spots.append({"distance": distance, "lane": 0.0})
	var sim: RefCounted = Sim.new()
	sim.setup(world, character, difficulty, mode)
	return sim


func _isolated(character: int = 0) -> RefCounted:
	var sim: RefCounted = _new_sim(character)
	for i: int in range(1, 8):
		sim.racers[i].finish_time = 1.0
	sim.racers[0].distance = 100.0
	sim.racers[0].lane = 0.0
	return sim


func _tick_for(sim: RefCounted, seconds: float, controls: Dictionary) -> void:
	for i: int in range(int(round(seconds / STEP))):
		sim.tick(STEP, controls)


func _has_event(sim: RefCounted, kind: String) -> bool:
	for event: Dictionary in sim.events:
		if event.kind == kind:
			return true
	return false


func _test_setup() -> void:
	var sim: RefCounted = _new_sim(4, 2, "minecraft", true)
	_expect(sim.racers.size() == 8, "setup creates player and seven AI")
	_expect(sim.racers[0].character == 4, "chosen racer occupies the player slot")
	var characters: Dictionary = {}
	for r: Dictionary in sim.racers:
		characters[r.character] = true
		_expect(r.position.is_finite(), "initial racer transform is finite")
	_expect(characters.size() == 8, "roster has no duplicated or omitted characters")
	_expect(sim.difficulty == 2 and sim.mode == "minecraft", "setup retains difficulty and game mode")
	_expect(sim.pickups.size() == 4, "setup copies the course pickup locations")
	_expect(sim.racers[0].distance < 0 and sim.racers[0].lap == 1, "staging grid precedes lap one start")
	_expect(sim.standings().size() == 8 and sim.player_place() in range(1, 9), "initial standings cover all racers")
	sim.setup(sim.world, 2, 2, "cats")
	_expect(sim.racers.size() == 8 and sim.race_time == 0 and not sim.finished, "setup resets an existing simulation")


func _test_handling() -> void:
	var sim: RefCounted = _isolated()
	_tick_for(sim, 1.0, {"throttle": 1.0})
	_near(sim.racers[0].speed, 15.0, 0.02, "throttle accelerates according to character acceleration")
	_expect(sim.racers[0].distance > 107, "accelerating advances along the road")
	_tick_for(sim, 2.0, {"throttle": 1.0})
	_near(sim.racers[0].speed, 38.0, 0.02, "normal acceleration stops at top speed")
	var before_brake: float = sim.racers[0].speed
	_tick_for(sim, 1.0, {"brake": 1.0})
	_expect(sim.racers[0].speed < before_brake * 0.25, "braking quickly slows the kart")
	_tick_for(sim, 1.0, {"brake": 1.0})
	_near(sim.racers[0].speed, 0, 0.00001, "braking reaches rest without reversing")
	for direction: float in [-1.0, 1.0]:
		var turning: RefCounted = _isolated()
		turning.racers[0].speed = 30.0
		_tick_for(turning, 0.35, {"throttle": 0.8, "steer": direction})
		_expect(float(turning.racers[0].lane) * direction > 0.4, "steering %+.0f changes lateral position" % direction)
		_expect(float(turning.racers[0].angle) * direction > 0.07, "steering %+.0f changes heading" % direction)
	var stopped: RefCounted = _isolated()
	_tick_for(stopped, 0.5, {"steer": 1.0})
	_near(stopped.racers[0].lane, 0, 0.000001, "steering at rest does not move the kart sideways")


func _test_boundaries_and_reset() -> void:
	var sim: RefCounted = _isolated()
	var player: Dictionary = sim.racers[0]
	player.speed = 30.0
	player.lane = 100.0
	player.angle = 0.7
	sim.tick(STEP, {"throttle": 1.0})
	_expect(absf(player.lane) + Sim.lateral_extent(player.angle) <= sim.road_half + .001, "fence contains the entire rotated kart hull")
	_expect(player.angle < 0 and player.speed < 25, "fence collision points inward and loses speed")
	_expect(_has_event(sim, "wall"), "fence impact produces feedback")
	var lane_at_fence: float = player.lane
	sim.tick(STEP, {"throttle": 1.0})
	_expect(player.lane < lane_at_fence, "racer naturally recovers inward from the fence")
	player.stun = 2.0
	var distance: float = player.distance
	sim.tick(STEP, {"reset": true})
	_near(player.lane, 0, 0.00001, "reset returns to the centre of the road")
	_expect(absf(player.angle) < 0.01 and player.stun == 0, "reset restores heading and clears stun")
	_expect(player.speed > 7 and player.speed <= 8, "reset grants a modest recovery speed")
	_expect(player.distance >= distance and player.distance - distance < 0.5, "reset preserves race progress")
	_expect(_has_event(sim, "reset"), "reset produces feedback")


func _test_drift_and_boost() -> void:
	var sim: RefCounted = _isolated()
	sim.racers[0].speed = 30.0
	_tick_for(sim, 1.0, {"throttle": 1.0, "steer": 0.18, "drift": true})
	_expect(sim.racers[0].drifting and sim.racers[0].drift >= 0.99, "holding drift while turning builds charge")
	sim.tick(STEP, {"throttle": 1.0})
	_expect(sim.racers[0].turbo >= 0.84 and sim.racers[0].drift == 0, "releasing charged drift awards mini-turbo and clears charge")
	_expect(_has_event(sim, "drift"), "mini-turbo produces a drift event")
	var specialist: RefCounted = _isolated(4)
	specialist.racers[0].speed = 30.0
	_tick_for(specialist, 1.5, {"throttle": 1.0, "steer": 0.14, "drift": true})
	_expect(specialist.racers[0].drift >= 1.79, "drifter character charges mini-turbo faster")
	specialist.tick(STEP, {"throttle": 1.0})
	_expect(specialist.racers[0].turbo >= 1.64, "long drift awards the stronger mini-turbo")
	var short_drift: RefCounted = _isolated()
	short_drift.racers[0].speed = 30.0
	_tick_for(short_drift, 0.2, {"throttle": 1.0, "steer": 0.2, "drift": true})
	short_drift.tick(STEP, {"throttle": 1.0})
	_expect(short_drift.racers[0].turbo == 0, "an uncharged drift grants no free turbo")
	var boost: RefCounted = _isolated()
	boost.tick(STEP, {"throttle": 1.0, "boost": true})
	_near(boost.racers[0].boost, 70, 0.01, "boost spends thirty energy")
	_expect(boost.racers[0].turbo >= 1.64, "boost button activates turbo")
	boost.racers[0].boost = 10.0
	boost.racers[0].turbo = 0.0
	boost.tick(STEP, {"boost": true})
	_expect(boost.racers[0].turbo == 0 and boost.racers[0].boost < 11, "insufficient energy prevents boost")
	_tick_for(boost, 2.0, {})
	_expect(boost.racers[0].boost > 20, "boost energy regenerates over time")


func _test_pickups_and_pads() -> void:
	var sim: RefCounted = _isolated()
	sim.pickups.append({"distance": 10.0, "lane": 0.0, "cooldown": 0.0})
	var player: Dictionary = sim.racers[0]
	player.distance = 9.9
	player.speed = 30.0
	sim.tick(STEP, {"throttle": 1.0})
	_expect(player.item in Sim.ITEMS and player.coins == 1, "crossing an item box grants one of four items")
	_expect(sim.pickups[0].cooldown == 5.0 and _has_event(sim, "pickup"), "collected box starts respawn timer and feedback")
	player.item = ""
	player.distance = 9.9
	sim.tick(STEP, {"throttle": 1.0})
	_expect(player.item == "" and player.coins == 1, "box cannot be recollected during cooldown")
	_tick_for(sim, 5.1, {})
	_near(sim.pickups[0].cooldown, 0, 0.000001, "item box respawns after five seconds")
	player.distance = 9.9
	player.speed = 30.0
	player.lane = 0.0
	player.angle = 0.0
	sim.tick(STEP, {"throttle": 1.0})
	_expect(player.coins == 2 and player.item != "", "respawned item box can be collected again")
	var held_item: String = player.item
	sim.pickups[0].cooldown = 0.0
	player.distance = 9.9
	sim.tick(STEP, {"throttle": 1.0})
	_expect(player.item == held_item and sim.pickups[0].cooldown == 0, "holding an item leaves a new box available")
	var wrap: RefCounted = _isolated()
	wrap.pickups.append({"distance": 0.0, "lane": 0.0, "cooldown": 0.0})
	wrap.racers[0].distance = 1199.9
	wrap.racers[0].speed = 30.0
	wrap.tick(STEP, {"throttle": 1.0})
	_expect(wrap.racers[0].item != "", "pickup detection works across the lap boundary")
	var pad: RefCounted = _isolated()
	pad.world.boost_spots.append({"distance": 10.0, "lane": 0.0})
	pad.racers[0].distance = 9.9
	pad.racers[0].speed = 30.0
	pad.tick(STEP, {"throttle": 1.0})
	_expect(pad.racers[0].turbo >= 1.39 and pad.racers[0].hop_timer > 0, "boost strip gives turbo and a jump")
	_tick_for(pad, 0.1, {"throttle": 1.0})
	_expect(pad.racers[0].hop > 0.55, "boost-strip hop lifts the vehicle clear of hazards")


func _test_items_hits_and_hazards() -> void:
	var sim: RefCounted = _isolated()
	var player: Dictionary = sim.racers[0]
	player.item = "turbo"
	sim.tick(STEP, {"item": true})
	_expect(player.item == "" and player.turbo >= 2.79, "turbo item is consumed and grants a long boost")
	player.item = "bubble"
	sim.tick(STEP, {"item": true})
	_expect(player.item == "" and player.shield >= 7.99, "bubble item activates an eight-second shield")
	player.speed = 30.0
	sim._hit(0, 1.3)
	_expect(player.shield == 0 and player.stun == 0 and player.speed == 30, "shield absorbs one attack without losing speed")
	_expect(_has_event(sim, "shield"), "shield absorption produces feedback")
	sim._hit(0, 1.3)
	_near(player.speed, 12, 0.000001, "unshielded hit reduces speed")
	_expect(player.stun == 1.3 and _has_event(sim, "hit"), "unshielded hit stuns the player and produces feedback")
	_tick_for(sim, 1.5, {})
	_expect(player.stun == 0, "stun recovers over time")
	player.distance = 100.0
	player.lane = 0.0
	player.speed = 0.0
	player.item = "yarn"
	sim.tick(STEP, {"item": true})
	_expect(player.item == "" and sim.hazards.size() == 1, "yarn item drops a persistent hazard")
	_near(sim.hazards[0].distance, 93, 0.01, "yarn hazard is placed behind its owner")
	player.distance = 93.0
	sim._check_hazards(player, 0)
	_expect(player.stun == 0 and sim.hazards[0].life > 0, "owner cannot hit their own yarn hazard")
	var rival: Dictionary = sim.racers[1]
	rival.distance = 93.0
	rival.lane = 0.0
	rival.speed = 25.0
	rival.hop = 0.9
	sim._check_hazards(rival, 1)
	_expect(rival.stun == 0 and sim.hazards[0].life > 0, "airborne racer clears a yarn hazard")
	rival.hop = 0.0
	sim._check_hazards(rival, 1)
	_expect(rival.stun > 1 and sim.hazards[0].life == 0, "grounded rival triggers and consumes a yarn hazard")
	sim.tick(STEP, {})
	_expect(sim.hazards.is_empty(), "consumed hazard is removed on the next tick")
	sim.hazards.append({"distance": 500.0, "lane": 0.0, "owner": 0, "life": 0.02})
	sim.tick(0.05, {})
	_expect(sim.hazards.is_empty(), "untouched hazard expires at the end of its lifetime")
	# Fish selects the nearest unfinished opponent ahead, even in another lane.
	player.distance = 100.0
	player.item = "fish"
	for i: int in [1, 2, 3]:
		sim.racers[i].finish_time = -1.0
		sim.racers[i].lane = 5.0
		sim.racers[i].distance = 100.0 + i * 30.0
		sim.racers[i].stun = 0.0
	sim._use_item(0)
	_expect(player.item == "" and sim.racers[1].stun > 1.5 and sim.racers[2].stun == 0, "fish hits only the nearest opponent ahead")
	_expect(_has_event(sim, "projectile"), "fish emits the projectile effect event")
	player.item = "fish"
	sim.racers[1].stun = 0.0
	sim.racers[1].shield = 8.0
	sim._use_item(0)
	_expect(sim.racers[1].shield == 0 and sim.racers[1].stun == 0, "bubble shield also blocks a flying fish")
	for i: int in [1, 2, 3]:
		sim.racers[i].distance = 400.0 + i
	player.item = "fish"
	sim._use_item(0)
	_expect(player.item == "" and _has_event(sim, "info"), "fish with no opponent in range is consumed with explanatory feedback")


func _test_bumps_and_standings() -> void:
	var sim: RefCounted = _new_sim()
	for i: int in range(8):
		sim.racers[i].distance = 200.0 + i * 20
		sim.racers[i].lane = 0.0
		sim.racers[i].speed = 30.0
	sim.racers[1].distance = 201.0
	sim._bump_cars()
	_expect(sim.contact_between(sim.racers[0], sim.racers[1]).is_empty() and sim.racers[0].distance < sim.racers[1].distance, "rear contact separates solid karts without reversing their order")
	_expect(sim.racers[0].speed <= 30 and sim.racers[0].bump_cooldown > 0, "kart contact cannot add speed and starts feedback cooldown")
	var after_bump: float = sim.racers[0].speed
	sim._bump_cars()
	_near(sim.racers[0].speed, after_bump, 0.00001, "bump cooldown prevents repeated collision penalties")
	sim.racers[3].finish_time = 120.0
	sim.racers[4].finish_time = 110.0
	var order: Array[int] = sim.standings()
	_expect(order[0] == 4 and order[1] == 3, "finished racers sort by finish time ahead of unfinished rivals")
	_expect(order[2] == 7, "unfinished racers sort by race progress")


func _no_penetration(sim: RefCounted) -> bool:
	for i in range(8):
		for j in range(i + 1, 8):
			if not sim.contact_between(sim.racers[i], sim.racers[j]).is_empty(): return false
	return true


func _test_solid_contacts() -> void:
	var sim: RefCounted = _new_sim()
	_expect(_no_penetration(sim), "starting grid gives all eight kart hulls free space")
	sim.tick(STEP, {"throttle": 1.0})
	var grid_heading := true
	for i in range(1, 8): grid_heading = grid_heading and absf(sim.racers[i].angle) < .4
	_expect(grid_heading and _no_penetration(sim), "AI launch points forward instead of sliding sideways into the starting grid")
	for i in range(8):
		sim.racers[i].distance = 100.0 + i * 30
		sim.racers[i].lane = 0.0
		sim.racers[i].angle = 0.0
		sim.racers[i].speed = 30.0
		sim.racers[i].bump_cooldown = 0.6
	sim.racers[1].distance = 101.0
	sim._bump_cars()
	_expect(_no_penetration(sim), "active feedback cooldown never disables physical contact separation")
	# A catching car shares its closing velocity, with no old unconditional speed penalty.
	sim.racers[0].distance = 100.0
	sim.racers[1].distance = 103.8
	sim.racers[0].lane = 0.0
	sim.racers[1].lane = 0.0
	sim.racers[0].speed = 50.0
	sim.racers[1].speed = 20.0
	var old_energy := 50.0 * 50.0 + 20.0 * 20.0
	sim._bump_cars()
	_expect(sim.racers[0].speed < 50 and sim.racers[1].speed > 20, "rear collision transfers closing velocity to the leading kart")
	_expect(pow(sim.racers[0].speed, 2) + pow(sim.racers[1].speed, 2) <= old_energy, "collision response does not create kinetic energy")
	_expect(_no_penetration(sim), "rear collision leaves no hull penetration")
	# Contacts across the lap seam are physically adjacent despite different progress.
	sim.racers[0].distance = sim.track_length - 1.0
	sim.racers[1].distance = 1.0
	sim.racers[0].lane = 0.0
	sim.racers[1].lane = 0.0
	sim._bump_cars()
	_expect(_no_penetration(sim), "solid collision works across the lap seam")
	# Adversarial pack: eight cars cannot fit abreast, so resolve into multiple rows.
	for i in range(8):
		sim.racers[i].distance = 500.0 + (i % 2) * .15
		sim.racers[i].lane = 6.5 - float(i) * .28
		sim.racers[i].angle = .12 if i % 2 else -.12
		sim.racers[i].speed = 32.0
		sim.racers[i].bump_cooldown = .5
	sim._bump_cars()
	_expect(_no_penetration(sim), "eight-kart barrier pileup resolves every hull overlap")
	var inside := true
	for r: Dictionary in sim.racers:
		inside = inside and absf(r.lane) + Sim.lateral_extent(r.angle) <= sim.road_half + .001
	_expect(inside, "pileup resolution keeps rotated hulls inside both barriers")
	sim.snap_interpolation()
	var old_distance: float = sim.racers[0].distance
	sim.tick(STEP, {"throttle": 1.0})
	_near(sim.racers[0].previous_distance, old_distance, .000001, "render interpolation retains the previous physics position")
	_expect(_no_penetration(sim), "contacts remain solid on the following physics tick")


func _test_finish_crossing() -> void:
	# A finish-line hazard must not move the timestamp into an earlier tick:
	# interpolation should use distance advanced, not speed after being hit.
	var sim: RefCounted = _isolated()
	sim.race_time = 80.0
	sim.racers[0].distance = sim.track_length * 3.0 - 0.1
	sim.racers[0].speed = 38.0
	sim.racers[0].lap = 3
	sim.hazards.append({"distance": 0.0, "lane": 0.0, "owner": 1, "life": 10.0})
	sim.tick(0.05, {"throttle": 1.0})
	_expect(sim.finished and sim.racers[0].stun > 0, "racer can finish during a finish-line hazard impact")
	_expect(sim.racers[0].finish_time >= 80.0 and sim.racers[0].finish_time <= 80.05, "finish-line hit cannot timestamp completion before the crossing tick")


func _drive_race(difficulty: int, mode: String, throttle: float = 1.0, use_items: bool = true) -> Dictionary:
	var sim: RefCounted = _new_sim(0, difficulty, mode, true)
	var counts: Dictionary = {}
	var finite_positions: bool = true
	for step: int in range(14000):
		var player: Dictionary = sim.racers[0]
		var steer: float = clampf(-float(player.lane) * 0.3 - float(player.angle) * 2.0, -1.0, 1.0)
		sim.tick(STEP, {"throttle": throttle, "steer": steer, "boost": use_items and step % 240 == 0, "item": use_items and player.item != ""})
		for event: Dictionary in sim.drain_events():
			counts[event.kind] = int(counts.get(event.kind, 0)) + 1
		for racer: Dictionary in sim.racers:
			finite_positions = finite_positions and racer.position.is_finite()
		if sim.finished:
			break
	_expect(sim.finished, "full %s race on difficulty %d reaches the finish" % [mode, difficulty])
	_expect(finite_positions, "full race keeps all world transforms finite")
	_expect(sim.racers[0].lap == 4 and sim.racers[0].finish_time > 0, "player completes exactly three laps")
	_near(sim.racers[0].distance, 3600.0, 0.00001, "finish clamps player to the three-lap distance")
	_expect(counts.get("lap", 0) == 2 and counts.get("finish", 0) == 1, "full race emits two lap changes and one finish event")
	_expect(sim.racers[0].best_lap > 0 and sim.racers[0].best_lap < sim.racers[0].finish_time, "full race produces a valid best lap")
	var order: Array[int] = sim.standings()
	_expect(order.size() == 8 and sim.player_place() == order.find(0) + 1, "full-race standings consistently rank all eight racers")
	for i: int in range(1, order.size()):
		var a: Dictionary = sim.racers[order[i - 1]]
		var b: Dictionary = sim.racers[order[i]]
		_expect((a.finish_time >= 0 and (b.finish_time < 0 or a.finish_time <= b.finish_time)) or (a.finish_time < 0 and b.finish_time < 0 and a.distance >= b.distance), "full-race standings remain correctly ordered at rank %d" % i)
	var snapshot: Array[Dictionary] = sim.racers.duplicate(true)
	var final_time: float = sim.race_time
	sim.tick(STEP, {"throttle": 1.0})
	_expect(sim.racers == snapshot and sim.race_time == final_time, "finished simulation stops changing when ticked")
	return {"sim": sim, "snapshot": snapshot, "time": final_time, "order": order, "events": counts}


func _test_full_races() -> void:
	var first: Dictionary = _drive_race(2, "cats")
	var second: Dictionary = _drive_race(2, "cats")
	_expect(first.snapshot == second.snapshot and first.time == second.time and first.order == second.order and first.events == second.events, "identical seeds and controls produce identical full race outcomes")
	_expect(first.events.get("pickup", 0) > 0 and first.events.get("item", 0) > 0, "full race exercises real pickups and item use")
	var block_race: Dictionary = _drive_race(2, "minecraft", 0.68, false)
	var finished_count: int = 0
	for racer: Dictionary in block_race.sim.racers:
		if racer.finish_time >= 0:
			finished_count += 1
	_expect(finished_count == 8, "seven AI complete all three laps before a deliberately slower player")
	_expect(block_race.sim.player_place() == 8, "a slower player receives eighth place behind seven completed AI")
	print("Full races: normal %.2fs, repeated %.2fs, Minecraft expert %.2fs" % [first.time, second.time, block_race.time])

func _test_difficulty_pace() -> void:
	var speeds: Array[float] = []
	for level in [2,3,4]:
		var sim: RefCounted = _new_sim(0,level)
		sim.racers[0].distance = 300.0
		for i in range(2,8): sim.racers[i].finish_time = 1.0
		var rival: Dictionary = sim.racers[1]
		rival.distance = 200.0
		rival.lane = 0.0
		rival.ai_item_time = 999.0
		for tick in range(120):
			sim.race_time += STEP
			sim._ai_step(rival,1,STEP)
		speeds.append(float(rival.speed))
	_expect(speeds[0] < speeds[1] and speeds[1] < speeds[2],"Easy, Medium and Hard progressively increase actual rival pace")


func _test_real_courses() -> void:
	var world_script: GDScript = load("res://scripts/track_world.gd")
	for course: int in range(3):
		var track: Node3D = world_script.new()
		root.add_child(track)
		track.build(course, "cats")
		var sim: RefCounted = Sim.new()
		sim.setup(track, 0, 2, "cats")
		var wall_count: int = 0
		var maximum_lane: float = 0
		var finite_transforms: bool = true
		for step: int in range(16000):
			var player: Dictionary = sim.racers[0]
			var steer: float = clampf(-float(player.lane) * 0.3 - float(player.angle) * 2.0, -1.0, 1.0)
			sim.tick(STEP, {"throttle": 1.0, "steer": steer, "item": player.item != ""})
			maximum_lane = maxf(maximum_lane, absf(float(player.lane)))
			finite_transforms = finite_transforms and player.position.is_finite()
			for event: Dictionary in sim.drain_events():
				if event.kind == "wall":
					wall_count += 1
			if sim.finished:
				break
		_expect(sim.finished and sim.racers[0].lap == 4, "real course %d completes three laps with steering feedback" % course)
		_expect(finite_transforms, "real course %d has finite driving transforms" % course)
		_expect(maximum_lane <= sim.road_half - 1.4 + 0.001, "real course %d keeps the driver within the road" % course)
		_expect(wall_count <= 10, "real course %d steering feedback remains stable (fence impacts: %d)" % [course, wall_count])
		print("Real course %d: length %.1fm; three laps %.2fs; fence impacts %d; max lane %.2fm" % [course, track.length, sim.race_time, wall_count, maximum_lane])
		track.free()


func _test_pause_and_timestep() -> void:
	var sim: RefCounted = _new_sim()
	_tick_for(sim, 0.5, {"throttle": 1.0})
	var snapshot: Array[Dictionary] = sim.racers.duplicate(true)
	var pause_time: float = sim.race_time
	# Main pauses by withholding tick(), so wall-clock/frame passage must not
	# alter the RefCounted simulation or expire item/boost timers.
	await process_frame
	await process_frame
	_expect(sim.racers == snapshot and sim.race_time == pause_time, "withholding simulation ticks freezes a paused race")
	sim.tick(0, {"throttle": 1.0})
	sim.tick(-1, {"throttle": 1.0})
	_expect(sim.racers == snapshot and sim.race_time == pause_time, "zero and negative deltas cannot advance a race")
	sim.tick(STEP, {"throttle": 1.0})
	_expect(sim.race_time > pause_time and sim.racers[0].distance > snapshot[0].distance, "resuming tick resumes race progress")
	var long_frame: RefCounted = _new_sim()
	var capped_frame: RefCounted = _new_sim()
	long_frame.tick(2.0, {"throttle": 1.0})
	capped_frame.tick(0.05, {"throttle": 1.0})
	_expect(long_frame.racers == capped_frame.racers and long_frame.race_time == 0.05, "large frame delays are capped to a safe simulation step")


func _test_preferences() -> void:
	var prefs: RefCounted = Prefs.new()
	prefs.file_path = _temp_path
	_expect(prefs.best(1, 2, "cats") < 0, "new preference file starts with no best record")
	_expect(prefs.record(1, 2, 102.5, "cats"), "first valid Easy race establishes a best record")
	_expect(not prefs.record(1, 2, 103.0, "cats"), "slower race does not replace an existing best")
	_expect(not prefs.record(1, 2, 102.5, "cats"), "equal race does not claim a new best")
	_expect(prefs.record(1, 2, 100.0, "cats"), "faster race improves the best record")
	_expect(prefs.record(1, 3, 115.0, "cats"), "Medium has its own best record")
	_expect(prefs.record(1, 2, 94.0, "minecraft"), "game mode has its own best record")
	_expect(prefs.record(2, 2, 88.0, "cats"), "course has its own best record")
	_near(prefs.best(1, 2, "cats"), 100.0, 0.0001, "Easy cat record retains the old Fast cats key")
	_near(prefs.best(1, 3, "cats"), 115.0, 0.0001, "Medium record is isolated")
	_near(prefs.best(1, 2, "minecraft"), 94.0, 0.0001, "Minecraft record is isolated")
	_expect(prefs.best(1, 4, "cats") < 0 and prefs.best(1, 3, "minecraft") < 0, "unused difficulty and mode combinations stay empty")
	for invalid: float in [0.0, -1.0, INF, -INF, NAN]:
		_expect(not prefs.record(0, 2, invalid, "cats"), "reject invalid race time %s" % invalid)
	_expect(not prefs.record(-1, 2, 50, "cats") and not prefs.record(3, 2, 50, "cats"), "reject out-of-range course records")
	_expect(not prefs.record(0, 1, 50, "cats") and not prefs.record(0, 5, 50, "cats"), "reject out-of-range difficulty records")
	_expect(not prefs.record(0, 2, 50, "unknown"), "reject unknown game-mode records")
	prefs.selected_character = 5
	prefs.selected_course = 2
	prefs.selected_mode = "minecraft"
	prefs.values.master_volume = 0.23
	prefs.values.music_volume = 0.41
	prefs.values.reduced_motion = true
	prefs.values.auto_accelerate = true
	prefs.values.difficulty = 2
	prefs.values.graphics_quality = 1
	_expect(prefs.save_data(), "preferences save successfully to the temporary workspace file")
	_expect(FileAccess.file_exists(_temp_path) and not FileAccess.file_exists(_temp_path + ".tmp"), "atomic save leaves only the completed configuration file")
	var restored: RefCounted = Prefs.new()
	restored.file_path = _temp_path
	restored.load_data()
	_expect(restored.records == prefs.records, "all course/difficulty/mode best records survive reload")
	_expect(restored.values == prefs.values, "settings survive reload")
	_expect(restored.selected_character == 5 and restored.selected_course == 2 and restored.selected_mode == "minecraft", "racer, course and mode selection survive reload")
	var legacy := ConfigFile.new()
	legacy.set_value("settings", "difficulty", 1)
	legacy.set_value("records", "cats_1_2", 100.0)
	_expect(legacy.save(_temp_path) == OK, "legacy difficulty fixture saves")
	var migrated: RefCounted = Prefs.new()
	migrated.file_path = _temp_path
	migrated.load_data()
	_expect(migrated.values.difficulty == 2 and migrated.best(1, 2, "cats") == 100.0, "old settings become Easy while previous Fast cats best is retained")
	var config: ConfigFile = ConfigFile.new()
	config.set_value("settings", "master_volume", 50.0)
	config.set_value("settings", "music_volume", -2.0)
	config.set_value("settings", "difficulty", 99)
	config.set_value("settings", "graphics_quality", 99)
	config.set_value("settings", "reduced_motion", "wrong_type")
	config.set_value("records", "cats_0_2", -45.0)
	config.set_value("records", "minecraft_0_2", "bad_record")
	config.set_value("racer", "character", 100)
	config.set_value("racer", "course", -2)
	config.set_value("racer", "mode", "not_a_mode")
	_expect(config.save(_temp_path) == OK, "malformed-data fixture is written only to the workspace temp file")
	var sanitized: RefCounted = Prefs.new()
	sanitized.file_path = _temp_path
	sanitized.load_data()
	_expect(sanitized.values.master_volume == 1 and sanitized.values.music_volume == 0 and sanitized.values.difficulty == 4 and sanitized.values.graphics_quality == 2, "loading clamps numeric settings to safe ranges")
	_expect(sanitized.values.reduced_motion == false, "loading ignores a wrong-typed boolean setting")
	_expect(sanitized.selected_character == 7 and sanitized.selected_course == 0 and sanitized.selected_mode == "cats", "loading sanitizes racer and course selections")
	_expect(sanitized.records.is_empty(), "loading ignores corrupt or nonpositive record values")
