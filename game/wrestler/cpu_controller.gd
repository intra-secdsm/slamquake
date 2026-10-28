class_name CpuController
extends WrestlerController
## Utility-style CPU opponent. Difficulty 0 = practice dummy (never acts).

const PROFILES := [
	# reaction (s), aggression, block chance, heavy chance, run chance, grapple share, mash rate (/s),
	# reversal / parry chance, taunt chance (when there's an opening)
	{"reaction": 9.9, "aggression": 0.0, "block": 0.0, "heavy": 0.0, "run": 0.0, "grapple": 0.0, "mash": 0.0,
		"reverse": 0.0, "parry": 0.0, "taunt": 0.0},
	{"reaction": 0.55, "aggression": 0.4, "block": 0.15, "heavy": 0.2, "run": 0.05, "grapple": 0.35, "mash": 3.5,
		"reverse": 0.06, "parry": 0.03, "taunt": 0.05},
	{"reaction": 0.35, "aggression": 0.6, "block": 0.35, "heavy": 0.3, "run": 0.08, "grapple": 0.45, "mash": 6.0,
		"reverse": 0.15, "parry": 0.08, "taunt": 0.08},
	{"reaction": 0.22, "aggression": 0.78, "block": 0.6, "heavy": 0.35, "run": 0.1, "grapple": 0.5, "mash": 9.0,
		"reverse": 0.28, "parry": 0.15, "taunt": 0.1},
	{"reaction": 0.15, "aggression": 0.88, "block": 0.7, "heavy": 0.4, "run": 0.12, "grapple": 0.55, "mash": 11.0,
		"reverse": 0.4, "parry": 0.25, "taunt": 0.12},
]

var difficulty: int
var profile: Dictionary
var _think := 0.0
var _plan_time := 0.0
var _outside_time := 0.0
var _linger := 2.0               # how long to brawl outside before heading back in
var _follow_outside := false
var _target_was_outside := false
var _climb_corner := -1
var _climb_think := 0.0
var _chair_chase := 0.0
var _chair_cooldown := 0.0
var _last_pos := Vector3.ZERO
var _still_time := 0.0
var _sidestep := 0.0
var _sidestep_dir := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _rev_rolled := false
var _rev_ok := false
var _rev_at := 0.0
var _parry_cool := 0.0
var _block_time := 0.0


func _init(level: int, seed_value: int = 0) -> void:
	difficulty = clampi(level, 0, PROFILES.size() - 1)
	profile = PROFILES[difficulty]
	_rng.seed = seed_value if seed_value != 0 else randi()


func update(w: Wrestler, delta: float) -> void:
	clear_one_shots()
	_think -= delta
	_plan_time += delta
	_parry_cool -= delta
	# never turtle for long: covering up is a reaction, not a plan
	_block_time = _block_time + delta if block_held else 0.0
	if _block_time > 1.2:
		block_held = false
	if w.state != Wrestler.State.PAIRED:
		_rev_rolled = false
	var target := w.nearest_opponent()
	if target == null or difficulty == 0:
		move = Vector3.ZERO
		run_held = false
		block_held = false
		return

	match w.state:
		Wrestler.State.DOWN, Wrestler.State.PINNED, Wrestler.State.CORNERED, Wrestler.State.CORNER_HIT:
			mash = _rng.randf() < profile["mash"] * delta
			return
		Wrestler.State.PERCH:
			move = Vector3.ZERO
			if w.state_time > profile["reaction"] + 0.3:
				if _rng.randf() < 0.5:
					punch = true
				else:
					kick = true
			return
		Wrestler.State.TIEUP:
			_tieup(w, target)
			return
		Wrestler.State.PAIRED:
			_defend_grapple(w)
			return
		Wrestler.State.RUN:
			_running(w, target)
			return
		Wrestler.State.IDLE, Wrestler.State.BLOCK:
			pass
		_:
			run_held = false
			return

	var to := target.global_position - w.global_position
	to.y = 0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)

	if _unstick(w, delta):
		return
	if _environment(w, target, dist, dir, delta):
		return

	# a banked SPECIAL: hit the finisher on a dazed opponent, or tie up and hit it from there
	if w.has_special() and w._finisher_ready_on(target):
		taunt = true
		return
	# react to incoming strikes: a well-timed parry, or just cover up
	if target.state == Wrestler.State.STRIKE and dist < 1.8 and _parry_cool <= 0.0:
		var until_hit := float(target._move.get("hit_time", 0.2)) - target.state_time
		if until_hit < 0.15 and until_hit > 0.02:
			_parry_cool = 0.6
			if _rng.randf() < profile["parry"]:
				block_pressed = true
				return
	if target.state == Wrestler.State.STRIKE and dist < 1.8 and _think <= 0.0:
		block_held = _rng.randf() < profile["block"]
		_think = profile["reaction"]
	elif block_held and target.state != Wrestler.State.STRIKE:
		block_held = false
	if block_held:
		move = Vector3.ZERO
		return

	run_held = false
	if target.is_down():
		_ground_game(w, target)
	elif target.is_running() and target.facing().dot(-dir) > 0.6:
		# opponent coming off the ropes at us
		move = Vector3.ZERO
		if dist < 1.7 and _think <= 0.0:
			_think = profile["reaction"]
			if _rng.randf() < 0.45:
				grapple = true
			else:
				punch = true
	elif not target.is_standing() or target.state in Wrestler.BUSY:
		move = dir.rotated(Vector3.UP, PI / 2) * 0.5 if dist < 2.0 else dir * 0.6
		if _think <= 0.0:
			taunt = _rng.randf() < 0.1
			_think = 1.0
	elif dist > 1.05:
		move = dir
		if dist > 3.5 and _think <= 0.0:
			if _rng.randf() < profile["run"] * 4.0:
				run_held = true
				_plan_time = 0.0
			_think = profile["reaction"]
	else:
		move = Vector3.ZERO
		if _think <= 0.0:
			_think = profile["reaction"] * _rng.randf_range(0.8, 1.6)
			_w_special = w.has_special()
			_choose_neutral_attack(dir)


## Ring-exit, chair and turnbuckle decisions. Returns true if it set this frame's intent.
func _environment(w: Wrestler, target: Wrestler, dist: float, dir: Vector3, delta: float) -> bool:
	run_held = false
	if target.outside != w.outside:
		block_held = false
	# opponent just left the ring: decide whether to follow or wait for the count
	if target.outside and not _target_was_outside:
		_follow_outside = _rng.randf() < (0.35 if GameState.rules != "normal" else 0.55)
	_target_was_outside = target.outside
	if w.outside:
		_outside_time += delta
	else:
		_outside_time = 0.0
		_linger = _rng.randf_range(1.5, 5.0)

	if w.held_item:
		if target.is_down() or (target.state == Wrestler.State.KNOCKDOWN):
			# can't swing at someone lying down: ditch it and get on with the ground game
			grapple = _think <= 0.0
			_think = profile["reaction"]
			return true
		if target.outside != w.outside:
			move = _toward_ring(w) if w.outside else _toward_floor(w, target)
		else:
			move = dir if dist > 1.2 else Vector3.ZERO
			punch = dist <= 1.3 and target.can_be_hit() and _think <= 0.0
			if punch:
				_think = profile["reaction"]
		return true

	if w.outside:
		_chair_cooldown -= delta
		var chair := _free_chair(w, 4.0) if _chair_cooldown <= 0.0 else null
		var want_chair := chair != null and _rng.randf() < (0.5 if GameState.rules != "normal" else 0.04) * delta * 4.0
		if chair and (want_chair or _chair_chase > 0.0):
			_chair_chase += delta
			var to_chair := chair.global_position - w.global_position
			to_chair.y = 0
			move = to_chair.normalized()
			grapple = to_chair.length() < 0.8
			if grapple or _chair_chase > 3.0:
				if not grapple:
					_chair_cooldown = 10.0     # couldn't get to it; forget it for a while
				_chair_chase = 0.0
			return true
		_chair_chase = 0.0
		var m := w.get_parent() as Match
		var count := m.outside_count() if m else 0
		if not target.outside or _outside_time > _linger + 2.0 or count >= 12 - difficulty * 2:
			move = _toward_ring(w)
			return true
		return false            # brawl on the floor

	if target.outside and not target.is_down():
		var mm := w.get_parent() as Match
		if _follow_outside and (mm == null or mm.outside_count() < 8):
			move = _toward_floor(w, target)
		else:
			move = dir * 0.0
			taunt = _rng.randf() < 0.2 * delta
		return true

	if target.state == Wrestler.State.PERCH:
		move = dir if dist > 1.0 else Vector3.ZERO
		punch = dist <= 1.2 and _think <= 0.0
		if punch:
			_think = profile["reaction"]
		return true

	# go up top on a downed opponent near a corner
	if target.is_down() and not target.outside:
		_climb_think -= delta
		if _climb_corner < 0 and _climb_think <= 0.0:
			_climb_think = 1.0
			if _rng.randf() < 0.12 * (1.0 + difficulty * 0.3):
				_climb_corner = _corner_near(target.body_center(), 3.6)
		if _climb_corner >= 0:
			var spot := w._corner_spot(_climb_corner)
			var to_spot := spot - w.global_position
			to_spot.y = 0
			move = to_spot.normalized()
			if to_spot.length() < 0.9:
				grapple = true
				_climb_corner = -1
			return true
	else:
		_climb_corner = -1
	return false


## If we've been trying to walk somewhere without moving, sidestep for a moment.
func _unstick(w: Wrestler, delta: float) -> bool:
	if _sidestep > 0.0:
		_sidestep -= delta
		move = _sidestep_dir
		return true
	var moved := w.global_position.distance_to(_last_pos)
	if move.length() > 0.5 and moved < 0.4 * delta:
		_still_time += delta
	else:
		_still_time = 0.0
	_last_pos = w.global_position
	if _still_time > 1.5:
		_still_time = 0.0
		_sidestep = 0.8
		_sidestep_dir = move.rotated(Vector3.UP, PI / 2 * (1.0 if _rng.randf() < 0.5 else -1.0)) * 0.5 - move * 0.5
		_sidestep_dir = _sidestep_dir.normalized()
		return true
	return false


func _free_chair(w: Wrestler, radius: float) -> Chair:
	for node in w.get_tree().get_nodes_in_group("chairs"):
		var c := node as Chair
		if c.is_free() and c.global_position.distance_to(w.global_position) < radius \
				and absf(c.global_position.y - w.global_position.y) < 0.5:
			return c
	return null


func _corner_near(p: Vector3, radius: float) -> int:
	for i in 4:
		var c := Ring.corner(i) - p
		c.y = 0
		if c.length() < radius:
			return i
	return -1


## Walk toward the nearest side of the ring (away from the corners) to climb back in.
func _toward_ring(w: Wrestler) -> Vector3:
	var p := w.global_position
	var axis := 0 if absf(p.x) > absf(p.z) else 2
	var other := 2 - axis
	var v := Vector3.ZERO
	v[axis] = -signf(p[axis])
	# aim for the middle of a side: the steel steps sit near the corners
	if absf(p[other]) > 1.2:
		v[other] = -signf(p[other]) * 1.0
		if absf(p[axis]) < Ring.canvas_half() + 1.5:
			v[axis] = signf(p[axis]) * 0.4      # step back out around the steps
		else:
			v[axis] *= 0.2
	return v.normalized()


## Head out to the floor on the side nearest the opponent.
func _toward_floor(w: Wrestler, target: Wrestler) -> Vector3:
	var p := target.global_position
	var axis := 0 if absf(p.x) > absf(p.z) else 2
	var v := Vector3.ZERO
	v[axis] = signf(p[axis])
	var other := 2 - axis
	var side_lim := float(Ring.spec()["post_half"]) - 1.0
	var q := w.global_position
	if absf(q[other]) > side_lim:
		v[other] = -signf(q[other]) * 0.8
	return v.normalized()


var _w_special := false


## Being thrown: maybe reverse it, a moment after it starts (like a human reacting).
func _defend_grapple(w: Wrestler) -> void:
	move = Vector3.ZERO
	if w.reversal_window() <= 0.0:
		return
	if not _rev_rolled:
		_rev_rolled = true
		_rev_ok = _rng.randf() < profile["reverse"]
		_rev_at = _rng.randf_range(0.04, 0.14)
	if _rev_ok and w.state_time >= _rev_at:
		block_pressed = true
		_rev_ok = false


func _choose_neutral_attack(dir: Vector3) -> void:
	if _rng.randf() < profile["run"]:
		# bounce off the ropes behind us and come back with a clothesline
		move = -dir
		run_held = true
		_plan_time = 0.0
	elif _rng.randf() < profile["aggression"]:
		if _rng.randf() < profile["grapple"] or (_w_special and _rng.randf() < 0.6):
			grapple = true
		elif _rng.randf() < profile["heavy"]:
			kick = true
		else:
			punch = true
	elif _rng.randf() < 0.3:
		move = -dir * 0.6


func _tieup(w: Wrestler, target: Wrestler) -> void:
	move = Vector3.ZERO
	run_held = false
	if w.state_time < profile["reaction"] * 1.3:
		return
	if w.has_special():
		taunt = true
		return
	var r := _rng.randf()
	var hurt := target.health < 60.0
	var toss := w._rope_toss_normal(target.global_position - w.global_position) if not w.outside else Vector3.ZERO
	for n in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		if toss == Vector3.ZERO:
			toss = w._rope_toss_normal(n)
	if toss != Vector3.ZERO and r < 0.2:
		run_held = true
		move = toss
	elif r < 0.28:
		# Irish whip: often into a corner, otherwise into the ropes
		run_held = true
		if _rng.randf() < 0.45:
			var c := Ring.corner(_rng.randi_range(0, 3)) - w.global_position
			c.y = 0
			move = c.normalized()
		else:
			move = w.facing()
	elif r < 0.5:
		punch = true
		move = Vector3.ZERO if _rng.randf() < 0.4 else w.facing()
	elif r < (0.85 if hurt else 0.7):
		kick = true
		move = Vector3.ZERO if _rng.randf() < 0.5 else w.facing()
	else:
		punch = true


func _running(w: Wrestler, target: Wrestler) -> void:
	var dir := target.global_position - w.global_position
	dir.y = 0
	var dist := dir.length()
	dir = dir.normalized()
	var coming_back := w.facing().dot(dir) > 0.5
	move = dir if coming_back else Vector3.ZERO
	punch = coming_back and dist < 1.7 and target.is_standing()
	if _plan_time > 3.0:
		run_held = false


func _ground_game(w: Wrestler, target: Wrestler) -> void:
	var to := target.body_center() - w.global_position
	to.y = 0
	if target.distance_to_body(w.global_position) > Wrestler.GROUND_RANGE - 0.25:
		move = to.normalized()
		return
	move = Vector3.ZERO
	if _think > 0.0:
		return
	_think = profile["reaction"] * 1.5
	if not w.has_special() and target.health > 30.0 and _rng.randf() < profile["taunt"]:
		taunt = true      # play to the crowd for momentum while they're down
		return
	var pin_chance := 0.6 if target.health < 35.0 else (0.2 if target.health < 60.0 else 0.03)
	if w.outside or target.outside:
		pin_chance = 0.0
	var r := _rng.randf()
	if r < pin_chance:
		block_pressed = true
	elif r < pin_chance + (1.0 - pin_chance) * 0.4:
		kick = true
	elif r < pin_chance + (1.0 - pin_chance) * 0.65:
		punch = true
	else:
		grapple = true
