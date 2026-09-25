extends RefCounted
## Fixed-step arcade handling on a continuous 3D road surface. Rendering has no say in race results.
const Data = preload("res://scripts/rally_data.gd")
const LAPS := 3
const ITEMS := ["fish", "yarn", "turbo", "bubble", "purrquake", "feather_fan", "treat_trail", "paw_parry"]
# Includes the enlarged kitten's measured animated lean envelope (1.673 m half-width).
const KART_HALF_WIDTH := 1.70
const KART_HALF_LENGTH := 2.02
const CONTACT_SKIN := 0.06
const CONTACT_ITERATIONS := 20

var racers: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var events: Array[Dictionary] = []
var race_time := 0.0
var finished := false
var track_length := 1000.0
var road_half := 9.0
## Levels 2/3/4 are Easy/Medium/Hard. Level 2 deliberately preserves the
## previous Fast cats pace and its saved best-lap key.
var difficulty := 2
var mode := "cats"
var world: Node3D
var _rng := RandomNumberGenerator.new()
var _hazard_serial := 0

func setup(track: Node3D, character: int, level: int = 0, racer_mode: String = "cats") -> void:
	world = track
	track_length = float(world.length)
	road_half = float(world.road_width) * 0.5
	difficulty = clampi(level, 2, 4)
	mode = racer_mode
	race_time = 0
	finished = false
	racers.clear()
	pickups.clear()
	hazards.clear()
	_hazard_serial = 0
	events.clear()
	# Keep Easy's established item sequence, and compare the higher levels on
	# the same item layout so their extra race pressure is predictable.
	_rng.seed = 9419 + character * 117 + 2
	var roster: Array[int] = [character]
	for id in range(8):
		if id != character: roster.append(id)
	for i in range(8):
		var grid_slot: int = [6, 0, 1, 2, 3, 4, 5, 7][i]
		var d := -8.0 - float(grid_slot / 2) * 7.0
		racers.append({"character": roster[i], "distance": d, "lane": -3.2 if grid_slot % 2 == 0 else 3.2,
			"speed": 0.0, "angle": 0.0, "steer": 0.0, "boost": 100.0, "turbo": 0.0,
			"drift": 0.0, "drift_direction": 0.0, "drifting": false, "hop": 0.0,
			"hop_timer": 0.0, "stun": 0.0, "shield": 0.0, "parry": 0.0, "item": "", "finish_time": -1.0,
			"lap": 1, "last_lap_at": 0.0, "lap_time": 0.0, "best_lap": -1.0,
			"ai_item_time": 3.0 + i * 1.7, "pad_cooldown": 0.0, "bump_cooldown": 0.0,
			"position": Vector3.ZERO, "yaw": 0.0, "coins": 0})
	for spot in world.item_spots:
		pickups.append({"distance": float(spot.distance), "lane": float(spot.lane), "cooldown": 0.0})
	_update_transforms()
	snap_interpolation()

func tick(dt: float, controls: Dictionary) -> void:
	if finished or dt <= 0: return
	dt = minf(dt, 0.05)
	race_time += dt
	for pickup in pickups: pickup.cooldown = maxf(0, float(pickup.cooldown) - dt)
	for hazard in hazards:
		hazard.life = float(hazard.life) - dt
		if hazard.has("slide"):
			hazard.lane = clampf(float(hazard.lane) + float(hazard.slide) * dt, -road_half + 1.1, road_half - 1.1)
	hazards = hazards.filter(func(h: Dictionary) -> bool: return float(h.life) > 0)
	var start_distances: Array[float] = []
	for r in racers:
		start_distances.append(float(r.distance))
		_store_previous(r)
	for i in range(racers.size()):
		var r := racers[i]
		if float(r.finish_time) >= 0: continue
		r.turbo = maxf(0, float(r.turbo) - dt)
		r.stun = maxf(0, float(r.stun) - dt)
		r.shield = maxf(0, float(r.shield) - dt)
		r.parry = maxf(0, float(r.parry) - dt)
		r.pad_cooldown = maxf(0, float(r.pad_cooldown) - dt)
		r.bump_cooldown = maxf(0, float(r.bump_cooldown) - dt)
		r.boost = minf(100, float(r.boost) + dt * 5.5)
		r.hop_timer = maxf(0, float(r.hop_timer) - dt)
		r.hop = sin((1.0 - float(r.hop_timer) / 0.55) * PI) * 1.3 if float(r.hop_timer) > 0 else 0.0
		if i == 0: _player_step(r, controls, dt)
		else: _ai_step(r, i, dt)
		var safe_lane := road_half - lateral_extent(float(r.angle))
		if absf(float(r.lane)) > safe_lane:
			r.lane = clampf(float(r.lane), -safe_lane, safe_lane)
			r.angle = -signf(float(r.lane)) * 0.10
			if float(r.bump_cooldown) <= 0:
				r.speed = float(r.speed) * 0.72
				r.bump_cooldown = 0.7
				if i == 0: events.append({"kind": "wall", "text": "Easy on the fence!"})
	# Contact is solid every tick, including the audiovisual cooldown interval.
	_bump_cars()
	for i in range(racers.size()):
		var r := racers[i]
		if float(r.finish_time) >= 0: continue
		var old_d := start_distances[i]
		_check_pickups(r, i, old_d)
		_check_hazards(r, i)
		var new_lap := clampi(int(maxf(0, float(r.distance)) / track_length) + 1, 1, LAPS + 1)
		if new_lap > int(r.lap):
			r.lap_time = race_time - float(r.last_lap_at)
			r.last_lap_at = race_time
			if float(r.best_lap) < 0 or float(r.lap_time) < float(r.best_lap): r.best_lap = r.lap_time
			r.lap = new_lap
			if i == 0 and new_lap <= LAPS:
				events.append({"kind": "lap", "text": "FINAL LAP!" if new_lap == LAPS else "LAP %d / %d" % [new_lap, LAPS]})
		if float(r.distance) >= track_length * LAPS:
			var forward_distance := float(r.distance) - old_d
			var fraction := clampf((track_length * LAPS - old_d) / maxf(forward_distance, .00001), 0, 1)
			r.finish_time = race_time - dt + dt * fraction
			r.distance = track_length * LAPS
	_update_transforms()
	if bool(controls.get("reset", false)):
		_store_previous(racers[0])
	if float(racers[0].finish_time) >= 0:
		finished = true
		events.append({"kind": "finish", "text": "FINISH!"})

func _player_step(r: Dictionary, controls: Dictionary, dt: float) -> void:
	var steer := clampf(float(controls.get("steer", 0)), -1, 1)
	var throttle := clampf(float(controls.get("throttle", 0)), 0, 1)
	var brake := clampf(float(controls.get("brake", 0)), 0, 1)
	var wants_drift := bool(controls.get("drift", false)) and float(r.speed) > 10
	var character := int(r.character)
	if bool(controls.get("boost", false)) and float(r.boost) >= 30 and float(r.stun) <= 0:
		r.boost = float(r.boost) - 30
		r.turbo = maxf(float(r.turbo), 1.65)
		events.append({"kind": "boost", "text": "PAW POWER!"})
	if bool(controls.get("item", false)): _use_item(0)
	if bool(controls.get("reset", false)):
		r.lane = 0.0
		r.angle = 0.0
		r.speed = 8.0
		r.stun = 0.0
		events.append({"kind": "reset", "text": "Back on track"})
	if wants_drift and not bool(r.drifting):
		r.hop_timer = 0.55
		r.drift_direction = signf(steer)
	if wants_drift and absf(steer) > 0.12:
		r.drift = minf(3.0, float(r.drift) + dt * (1.2 if character == 4 else 1.0))
		if float(r.drift_direction) == 0: r.drift_direction = signf(steer)
	elif not wants_drift and bool(r.drifting):
		if float(r.drift) >= 0.75:
			r.turbo = maxf(float(r.turbo), 1.65 if float(r.drift) >= 1.6 else 0.85)
			r.boost = minf(100, float(r.boost) + 10)
			events.append({"kind": "drift", "text": "SUPER MINI-TURBO!" if float(r.drift) >= 1.6 else "MINI-TURBO!"})
		r.drift = 0.0
	r.drifting = wants_drift
	r.steer = lerpf(float(r.steer), steer, minf(1, dt * 9))
	var top := float(Data.TOP_SPEED[character])
	if float(r.turbo) > 0: top *= 1.42
	if float(r.stun) > 0: top *= 0.32
	var target := top * throttle * (1.0 - brake * 0.86)
	var accel := float(Data.ACCEL[character])
	if float(r.turbo) > 0: accel *= 2.6
	var decel := 32.0 if brake > 0 else 7.0
	r.speed = move_toward(float(r.speed), target, (accel if target > float(r.speed) else decel) * dt)
	var speed_fraction := clampf(float(r.speed) / 25, 0, 1)
	var turn_rate := 1.10 * float(Data.HANDLING[character]) * speed_fraction
	if wants_drift: turn_rate *= 1.28
	r.angle = float(r.angle) + steer * turn_rate * dt
	# A gentle steering assist damps overcorrection, while input still controls the actual heading.
	var align := 2.0
	if wants_drift: align *= 0.62
	r.angle = lerpf(float(r.angle), 0, minf(1, dt * align))
	r.angle = clampf(float(r.angle), -0.8, 0.8)
	var before: Vector3 = world.tangent(float(r.distance))
	var advance := float(r.speed) * cos(float(r.angle)) * dt
	r.distance = float(r.distance) + advance
	r.lane = float(r.lane) + float(r.speed) * sin(float(r.angle)) * dt
	var after: Vector3 = world.tangent(float(r.distance))
	var bend := wrapf(atan2(-after.x, -after.z) - atan2(-before.x, -before.z), -PI, PI)
	r.angle = float(r.angle) + bend * 0.62

func _ai_step(r: Dictionary, i: int, dt: float) -> void:
	var ch := int(r.character)
	# Easy preserves the old Fast cats pace. Higher levels increase rival pace,
	# recovery and passing rather than changing the player's handling.
	var tier := difficulty - 2
	var base: float = float(Data.TOP_SPEED[ch]) * float([1.10, 1.12, 1.21][tier])
	var behind := float(racers[0].distance) - float(r.distance)
	base *= 1.0 + clampf(behind / track_length, float([-0.10, -0.09, -0.07][tier]), float([0.07, 0.08, 0.125][tier]))
	base *= 0.98 + sin(race_time * 0.27 + i * 1.4) * 0.035
	if float(r.turbo) > 0: base *= 1.35
	if float(r.stun) > 0: base *= 0.36
	var ai_accel: float = float(Data.ACCEL[ch]) * float([1.12, 1.14, 1.27][tier])
	r.speed = move_toward(float(r.speed), base, ai_accel * dt)
	var target_lane := sin(float(r.distance) * 0.013 + i * 2.3) * (road_half - 3.3)
	# Racers choose a collectable line when a box approaches.
	if str(r.item).is_empty():
		for p in pickups:
			var ahead := fposmod(float(p.distance) - float(r.distance), track_length)
			if ahead < 28 and float(p.cooldown) <= 0:
				target_lane = float(p.lane)
				break
	# A visible Treat Trail is a lure: rivals without a Bubble Shield will
	# briefly leave their ideal line to chase it, giving the player a setup.
	if float(r.shield) <= 0:
		var treat_target: Dictionary = {}
		var nearest_treat := 24.0
		for hazard in hazards:
			if str(hazard.get("kind", "")) != "treat" or int(hazard.owner) == i: continue
			var treat_ahead := fposmod(float(hazard.distance) - float(r.distance), track_length)
			if treat_ahead > 1.5 and treat_ahead < nearest_treat:
				nearest_treat = treat_ahead
				treat_target = hazard
		if not treat_target.is_empty(): target_lane = float(treat_target.lane)
	# Look ahead before a pass; traffic does not deliberately drive through a rival.
	var blocker := -1
	var nearest := 18.0
	for other in range(racers.size()):
		if other == i or float(racers[other].finish_time) >= 0: continue
		var ahead := fposmod(float(racers[other].distance) - float(r.distance), track_length)
		if ahead > .01 and ahead < nearest and absf(float(racers[other].lane) - float(r.lane)) < 3.2:
			blocker = other
			nearest = ahead
	if blocker >= 0:
		var blocked_lane := float(racers[blocker].lane)
		var left := blocked_lane - 3.7
		var right := blocked_lane + 3.7
		var limit := road_half - 1.85
		if left >= -limit and (right > limit or absf(left - float(r.lane)) < absf(right - float(r.lane))): target_lane = left
		elif right <= limit: target_lane = right
		if nearest < 6.0:
			r.speed = minf(float(r.speed), float(racers[blocker].speed) + maxf(0, nearest - 4.1) * 2.0)
	var old_lane := float(r.lane)
	# Steering needs forward motion. Full lateral speed from a standing grid
	# would rotate AI cars sideways and create an immediate launch pileup.
	var lateral_speed := minf(4.7 + tier * 0.30, float(r.speed) * (0.35 + tier * 0.012))
	r.lane = move_toward(old_lane, target_lane, dt * lateral_speed)
	r.angle = atan2((float(r.lane) - old_lane) / dt, maxf(1, float(r.speed)))
	r.steer = float(r.angle) * 2.0
	r.distance = float(r.distance) + float(r.speed) * dt
	r.ai_item_time = float(r.ai_item_time) - dt
	if float(r.ai_item_time) <= 0:
		if str(r.item) != "paw_parry" or _ai_has_parry_opening(i):
			_use_item(i)
			r.ai_item_time = (4.15 - tier * 0.15) + i * 0.34
		else:
			# Save the timing item until a rival or tossed yarn gets close.
			r.ai_item_time = .45

func _ai_has_parry_opening(index: int) -> bool:
	var racer: Dictionary = racers[index]
	for other in range(racers.size()):
		if other == index or float(racers[other].finish_time) >= 0: continue
		var gap := absf(wrapf(float(racers[other].distance) - float(racer.distance), -track_length * .5, track_length * .5))
		if gap < 14.0 and absf(float(racers[other].lane) - float(racer.lane)) < 4.3: return true
	for hazard in hazards:
		if str(hazard.get("kind", "")) != "yarn" or int(hazard.owner) == index: continue
		var ahead := fposmod(float(hazard.distance) - float(racer.distance), track_length)
		if ahead < 9.0 and absf(float(hazard.lane) - float(racer.lane)) < 3.0: return true
	return false

func _check_pickups(r: Dictionary, index: int, old_d: float) -> void:
	for p in pickups:
		if float(p.cooldown) > 0 or absf(float(r.lane) - float(p.lane)) > 2.3: continue
		if not _crossed(old_d, float(r.distance), float(p.distance)): continue
		if not str(r.item).is_empty(): continue
		p.cooldown = 5.0
		r.item = ITEMS[_rng.randi_range(0, ITEMS.size() - 1)]
		r.coins = int(r.coins) + 1
		if index == 0: events.append({"kind": "pickup", "text": item_name(str(r.item))})
	if float(r.pad_cooldown) <= 0:
		for pad in world.boost_spots:
			if absf(float(r.lane) - float(pad.lane)) < 3.0 and _crossed(old_d, float(r.distance), float(pad.distance)):
				r.turbo = maxf(float(r.turbo), 1.4)
				r.pad_cooldown = 1.0
				r.hop_timer = 0.55
				if index == 0: events.append({"kind": "boost", "text": "BOOST STRIP!"})

func _crossed(old_d: float, new_d: float, point: float) -> bool:
	var ahead := fposmod(point - old_d, track_length)
	return ahead <= new_d - old_d and new_d > old_d

func _use_item(index: int) -> void:
	var r := racers[index]
	var item := str(r.item)
	if item.is_empty(): return
	r.item = ""
	match item:
		"turbo":
			r.turbo = maxf(float(r.turbo), 2.8)
		"bubble":
			r.shield = 8.0
		"paw_parry":
			r.parry = 1.05
		"yarn":
			# Toss the yarn just off the racing line, where the chase camera can
			# frame the throw and the next racer can still clip it.
			var yarn_side := signf(float(r.drift_direction))
			if yarn_side == 0: yarn_side = 1.0 if index % 2 == 0 else -1.0
			hazards.append({"id": _next_hazard_id(), "kind": "yarn", "distance": fposmod(float(r.distance) - 1.1, track_length),
				"lane": clampf(float(r.lane) + yarn_side * 2.0, -road_half + 1.1, road_half - 1.1), "owner": index, "life": 16.0})
			events.append({"kind": "yarn_toss", "from": index})
		"fish":
			var target := -1
			var closest := 125.0
			for i in range(racers.size()):
				if i == index or float(racers[i].finish_time) >= 0: continue
				var ahead := float(racers[i].distance) - float(r.distance)
				if ahead > 0 and ahead < closest:
					closest = ahead
					target = i
			if target >= 0:
				_hit(target, 1.55, "Bonked by a flying fish!", .4, index)
				events.append({"kind": "projectile", "from": index, "to": target})
			elif index == 0:
				events.append({"kind": "info", "text": "No rival in fish range"})
		"purrquake":
			var targets := 0
			for target in range(racers.size()):
				if target == index or float(racers[target].finish_time) >= 0: continue
				if absf(float(racers[target].distance) - float(r.distance)) > 26.0: continue
				targets += 1
				_hit(target, .9, "Caught in a Purrquake!", .62)
			events.append({"kind": "purr_wave", "from": index})
			if targets == 0 and index == 0:
				events.append({"kind": "info", "text": "No rivals close enough for Purrquake"})
		"feather_fan":
			var direction := signf(float(r.drift_direction))
			if direction == 0: direction = 1.0 if index % 2 == 0 else -1.0
			var lane_limit := road_half - 1.2
			for feather in range(3):
				var offset := float(feather - 1) * 5.2
				# A forward fan puts the three-hop puzzle in view immediately, then
				# leaves a moving spread for the pack to navigate around.
				hazards.append({"id": _next_hazard_id(), "kind": "feather", "distance": fposmod(float(r.distance) + 24.0 + float(feather) * 2.4, track_length),
					"lane": clampf(float(r.lane) + offset, -lane_limit, lane_limit), "slide": float(feather - 1) * direction * .38,
					"owner": index, "life": 11.0})
			events.append({"kind": "feather_fan", "from": index})
		"treat_trail":
			# Toss a glowing lure into the visible approach line, just beyond the
			# closest rival ahead when one is near enough to bait.
			var treat_side := signf(float(r.drift_direction))
			if treat_side == 0: treat_side = -1.0 if index % 2 == 0 else 1.0
			var treat_distance := float(r.distance) + 14.0
			var treat_lane := float(r.lane)
			var nearest_target := 18.0
			for target in range(racers.size()):
				if target == index or float(racers[target].finish_time) >= 0: continue
				var target_ahead := fposmod(float(racers[target].distance) - float(r.distance), track_length)
				if target_ahead > 0.1 and target_ahead < nearest_target:
					nearest_target = target_ahead
					treat_distance = float(racers[target].distance) + 14.0
					treat_lane = float(racers[target].lane)
			# Keep the lure inside a safe driving lane, even when the user drops it
			# near a rail or while turning sharply.
			var treat_limit := maxf(0.5, road_half - 4.0)
			hazards.append({"id": _next_hazard_id(), "kind": "treat", "distance": fposmod(treat_distance, track_length),
				"lane": clampf(treat_lane + treat_side * 2.35, -treat_limit, treat_limit), "owner": index, "life": 12.0})
			events.append({"kind": "treat_toss", "from": index})
	if index == 0: events.append({"kind": "item", "text": item_name(item) + "!"})

func _check_hazards(r: Dictionary, index: int) -> void:
	if float(r.hop) > 0.55: return
	for hazard in hazards:
		if int(hazard.owner) == index or float(hazard.life) <= 0: continue
		var delta := absf(wrapf(float(r.distance) - float(hazard.distance), -track_length / 2, track_length / 2))
		if delta < 2.3 and absf(float(r.lane) - float(hazard.lane)) < 2.1:
			hazard.life = 0.0
			if str(hazard.get("kind", "yarn")) == "treat":
				_hit(index, .65, "Stopped to sniff a treat!", .70)
			elif str(hazard.get("kind", "yarn")) == "feather":
				_hit(index, .85, "Feathered!", .68)
			else:
				_hit(index, 1.3, "You've been yarn-balled!", .4, int(hazard.owner))

func _hit(index: int, duration: float, message: String = "You've been yarn-balled!", speed_factor: float = .4, source_index: int = -1, allow_reflect: bool = true) -> void:
	var r := racers[index]
	if float(r.shield) > 0:
		r.shield = 0.0
		if index == 0: events.append({"kind": "shield", "text": "Bubble saved you!"})
		return
	if allow_reflect and source_index >= 0 and source_index < racers.size() and source_index != index and float(r.parry) > 0:
		r.parry = 0.0
		_hit(source_index, .92, "Pawfect Parry! Your hit bounced back.", .56, -1, false)
		events.append({"kind": "paw_parry", "from": index, "to": source_index})
		if index == 0: events.append({"kind": "info", "text": "Pawfect Parry!"})
		return
	r.stun = duration
	r.speed = float(r.speed) * speed_factor
	r.drift = 0.0
	if index == 0: events.append({"kind": "hit", "text": message})

func _bump_cars() -> void:
	# Separating-axis hulls match the actual kart width/length, including steering.
	# Repeated passes solve packs and redistribute a push when a fence blocks a car.
	for iteration in range(CONTACT_ITERATIONS):
		var changed := false
		for a in range(racers.size()):
			for b in range(a + 1, racers.size()):
				var ra := racers[a]
				var rb := racers[b]
				if float(ra.finish_time) >= 0 or float(rb.finish_time) >= 0: continue
				var contact := contact_between(ra, rb)
				if contact.is_empty(): continue
				changed = true
				var normal: Vector2 = contact.normal
				if iteration >= 6 and absf(normal.x) > .8:
					# A row wider than the road must form two rows, not squeeze through meshes.
					var gap := wrapf(float(ra.distance) - float(rb.distance), -track_length * .5, track_length * .5)
					var extent_a := KART_HALF_LENGTH * absf(cos(float(ra.angle))) + KART_HALF_WIDTH * absf(sin(float(ra.angle)))
					var extent_b := KART_HALF_LENGTH * absf(cos(float(rb.angle))) + KART_HALF_WIDTH * absf(sin(float(rb.angle)))
					normal = Vector2(0, 1 if gap >= 0 else -1)
					contact.depth = maxf(0, extent_a + extent_b - absf(gap))
				var correction: Vector2 = normal * (float(contact.depth) + CONTACT_SKIN)
				var limit_a := road_half - lateral_extent(float(ra.angle))
				var limit_b := road_half - lateral_extent(float(rb.angle))
				var old_a := float(ra.lane)
				var old_b := float(rb.lane)
				ra.lane = clampf(old_a + correction.x * .5, -limit_a, limit_a)
				rb.lane = clampf(old_b - correction.x * .5, -limit_b, limit_b)
				# Any lateral correction blocked by the rail is given to the other kart.
				var unused_a := correction.x * .5 - (float(ra.lane) - old_a)
				var unused_b := -correction.x * .5 - (float(rb.lane) - old_b)
				rb.lane = clampf(float(rb.lane) - unused_a, -limit_b, limit_b)
				ra.lane = clampf(float(ra.lane) - unused_b, -limit_a, limit_a)
				ra.distance = float(ra.distance) + correction.y * .5
				rb.distance = float(rb.distance) - correction.y * .5
				if iteration == 0:
					_contact_velocity(ra, rb, normal)
					if float(ra.bump_cooldown) <= 0 and float(rb.bump_cooldown) <= 0:
						ra.bump_cooldown = .3
						rb.bump_cooldown = .3
						if a == 0 or b == 0: events.append({"kind": "bump"})
		if not changed: break
	for r in racers:
		var limit := road_half - lateral_extent(float(r.angle))
		r.lane = clampf(float(r.lane), -limit, limit)

func contact_between(a: Dictionary, b: Dictionary) -> Dictionary:
	var delta := Vector2(float(a.lane) - float(b.lane), wrapf(float(a.distance) - float(b.distance), -track_length * .5, track_length * .5))
	if absf(delta.x) > 6.0 or absf(delta.y) > 6.0: return {}
	var aa := float(a.angle)
	var ab := float(b.angle)
	var right_a := Vector2(cos(aa), -sin(aa))
	var forward_a := Vector2(sin(aa), cos(aa))
	var right_b := Vector2(cos(ab), -sin(ab))
	var forward_b := Vector2(sin(ab), cos(ab))
	var depth := INF
	var normal := Vector2.ZERO
	for axis: Vector2 in [right_a, forward_a, right_b, forward_b]:
		var radius_a := absf(axis.dot(right_a)) * KART_HALF_WIDTH + absf(axis.dot(forward_a)) * KART_HALF_LENGTH
		var radius_b := absf(axis.dot(right_b)) * KART_HALF_WIDTH + absf(axis.dot(forward_b)) * KART_HALF_LENGTH
		var separation := delta.dot(axis)
		var overlap := radius_a + radius_b - absf(separation)
		if overlap <= .0001: return {}
		if overlap < depth:
			depth = overlap
			normal = axis * (1.0 if separation >= 0 else -1.0)
	return {"normal": normal, "depth": depth}

func _contact_velocity(a: Dictionary, b: Dictionary, normal: Vector2) -> void:
	var va := Vector2(sin(float(a.angle)), cos(float(a.angle))) * float(a.speed)
	var vb := Vector2(sin(float(b.angle)), cos(float(b.angle))) * float(b.speed)
	var closing := (va - vb).dot(normal)
	if closing >= 0: return
	var impulse := -closing * .56
	va += normal * impulse
	vb -= normal * impulse
	a.speed = maxf(0, va.length())
	b.speed = maxf(0, vb.length())
	a.angle = clampf(atan2(va.x, maxf(.01, va.y)), -.8, .8)
	b.angle = clampf(atan2(vb.x, maxf(.01, vb.y)), -.8, .8)

static func lateral_extent(angle: float) -> float:
	return KART_HALF_WIDTH * absf(cos(angle)) + KART_HALF_LENGTH * absf(sin(angle)) + CONTACT_SKIN

func _store_previous(r: Dictionary) -> void:
	r.previous_distance = float(r.distance)
	r.previous_lane = float(r.lane)
	r.previous_hop = float(r.hop)
	r.previous_angle = float(r.angle)

func snap_interpolation() -> void:
	for r in racers: _store_previous(r)

func _update_transforms() -> void:
	for r in racers:
		r.position = world.sample(float(r.distance), float(r.lane)) + Vector3.UP * float(r.hop)
		var forward: Vector3 = world.tangent(float(r.distance))
		r.yaw = atan2(-forward.x, -forward.z) - float(r.angle)

func standings() -> Array[int]:
	var result: Array[int] = []
	for i in range(racers.size()): result.append(i)
	result.sort_custom(func(a: int, b: int) -> bool:
		var ra := racers[a]
		var rb := racers[b]
		if float(ra.finish_time) >= 0 and float(rb.finish_time) >= 0: return float(ra.finish_time) < float(rb.finish_time)
		if float(ra.finish_time) >= 0: return true
		if float(rb.finish_time) >= 0: return false
		return float(ra.distance) > float(rb.distance))
	return result

func player_place() -> int:
	return standings().find(0) + 1

func drain_events() -> Array[Dictionary]:
	var pending := events.duplicate()
	events.clear()
	return pending

static func item_name(item: String) -> String:
	return {"fish": "Flying fish", "yarn": "Yarn ball", "turbo": "Catnip turbo", "bubble": "Bubble shield",
		"purrquake": "Purrquake", "feather_fan": "Feather Fan", "treat_trail": "Treat Trail", "paw_parry": "Pawfect Parry"}.get(item, "Find an item box")

func _next_hazard_id() -> int:
	_hazard_serial += 1
	return _hazard_serial
