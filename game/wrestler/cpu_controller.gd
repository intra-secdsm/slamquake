class_name CpuController
extends WrestlerController
## Simple utility-style CPU opponent. Difficulty 0 = practice dummy (never acts).

const PROFILES := [
	# reaction (s), aggression, block chance, heavy chance, run chance, mash rate (/s)
	{"reaction": 9.9, "aggression": 0.0, "block": 0.0, "heavy": 0.0, "run": 0.0, "mash": 0.0},
	{"reaction": 0.55, "aggression": 0.35, "block": 0.15, "heavy": 0.2, "run": 0.05, "mash": 3.0},
	{"reaction": 0.35, "aggression": 0.55, "block": 0.35, "heavy": 0.3, "run": 0.08, "mash": 6.0},
	{"reaction": 0.2, "aggression": 0.75, "block": 0.6, "heavy": 0.35, "run": 0.1, "mash": 10.0},
]

var difficulty: int
var profile: Dictionary
var _think := 0.0
var _plan := "approach"
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

	if w.state == Wrestler.State.DOWN:
		mash = _rng.randf() < profile["mash"] * delta
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

	if w.state == Wrestler.State.RUN:
		# keep running straight until we've bounced back toward the target
		var coming_back := w.facing().dot(dir) > 0.5
		move = dir if coming_back else Vector3.ZERO
		punch = coming_back and dist < 1.7 and target.is_standing()
		if _plan_time > 3.0:
			run_held = false
		return
	if w.state in [Wrestler.State.REBOUND]:
		return

	if not target.is_standing():
		# opponent is down: circle and maybe taunt
		move = dir.rotated(Vector3.UP, PI / 2) * 0.5 if dist < 2.0 else dir * 0.6
		run_held = false
		if _think <= 0.0:
			taunt = _rng.randf() < 0.15
			_think = 1.0
		return

	run_held = false
	if dist > 1.15:
		move = dir
		if dist > 3.5 and _think <= 0.0:
			if _rng.randf() < profile["run"] * 4.0:
				run_held = true
				_plan_time = 0.0
			_think = profile["reaction"]
	else:
		move = Vector3.ZERO
		if _think <= 0.0 and not block_held:
			_think = profile["reaction"] * _rng.randf_range(0.8, 1.6)
			if _rng.randf() < profile["run"]:
				# bounce off the ropes behind us and come back with a clothesline
				move = -dir
				run_held = true
				_plan_time = 0.0
			elif _rng.randf() < profile["aggression"]:
				if _rng.randf() < profile["heavy"]:
					kick = true
				else:
					punch = true
			elif _rng.randf() < 0.3:
				move = -dir * 0.6
