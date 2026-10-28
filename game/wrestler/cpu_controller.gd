class_name CpuController
extends WrestlerController
## Utility-style CPU opponent. Difficulty 0 = practice dummy (never acts).

const PROFILES := [
	# reaction (s), aggression, block chance, heavy chance, run chance, grapple share, mash rate (/s)
	{"reaction": 9.9, "aggression": 0.0, "block": 0.0, "heavy": 0.0, "run": 0.0, "grapple": 0.0, "mash": 0.0},
	{"reaction": 0.55, "aggression": 0.4, "block": 0.15, "heavy": 0.2, "run": 0.05, "grapple": 0.35, "mash": 3.5},
	{"reaction": 0.35, "aggression": 0.6, "block": 0.35, "heavy": 0.3, "run": 0.08, "grapple": 0.45, "mash": 6.0},
	{"reaction": 0.22, "aggression": 0.78, "block": 0.6, "heavy": 0.35, "run": 0.1, "grapple": 0.5, "mash": 9.0},
]

var difficulty: int
var profile: Dictionary
var _think := 0.0
var _plan_time := 0.0
var _rng := RandomNumberGenerator.new()


func _init(level: int, seed_value: int = 0) -> void:
	difficulty = clampi(level, 0, PROFILES.size() - 1)
	profile = PROFILES[difficulty]
	_rng.seed = seed_value if seed_value != 0 else randi()


func update(w: Wrestler, delta: float) -> void:
	clear_one_shots()
	_think -= delta
	_plan_time += delta
	var target := w.nearest_opponent()
	if target == null or difficulty == 0:
		move = Vector3.ZERO
		run_held = false
		block_held = false
		return

	match w.state:
		Wrestler.State.DOWN, Wrestler.State.PINNED:
			mash = _rng.randf() < profile["mash"] * delta
			return
		Wrestler.State.TIEUP:
			_tieup(w, target)
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

	# react to incoming strikes
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
			_choose_neutral_attack(dir)


func _choose_neutral_attack(dir: Vector3) -> void:
	if _rng.randf() < profile["run"]:
		# bounce off the ropes behind us and come back with a clothesline
		move = -dir
		run_held = true
		_plan_time = 0.0
	elif _rng.randf() < profile["aggression"]:
		if _rng.randf() < profile["grapple"]:
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
	var r := _rng.randf()
	var hurt := target.health < 60.0
	if r < 0.28:
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
	var pin_chance := 0.6 if target.health < 35.0 else (0.2 if target.health < 60.0 else 0.03)
	var r := _rng.randf()
	if r < pin_chance:
		block_pressed = true
	elif r < pin_chance + (1.0 - pin_chance) * 0.4:
		kick = true
	elif r < pin_chance + (1.0 - pin_chance) * 0.65:
		punch = true
	else:
		grapple = true
