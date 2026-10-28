extends Node
## Headless CPU-vs-CPU soak test. Runs simulated matches as fast as possible and fails
## if a wrestler gets stuck or the match never produces action.
##   godot --headless --fixed-fps 60 --path game res://dev/soak.tscn -- --seconds=180

const STUCK_LIMIT := {  # max seconds allowed in one state
	Wrestler.State.IDLE: 60.0, Wrestler.State.RUN: 8.0, Wrestler.State.STRIKE: 2.0,
	Wrestler.State.BLOCK: 10.0, Wrestler.State.HITSTUN: 2.0, Wrestler.State.KNOCKDOWN: 2.0,
	Wrestler.State.DOWN: 12.0, Wrestler.State.GETUP: 2.0, Wrestler.State.REBOUND: 2.0,
	Wrestler.State.TAUNT: 3.0,
}

var _match: Match
var _elapsed := 0.0
var _limit := 120.0
var _stats := {"hits": 0, "blocks": 0, "knockdowns": 0, "rebounds": 0, "kos": 0}
var _failures: Array[String] = []
var _was_rebound := {}


func _ready() -> void:
	_limit = float(DevTools.get_arg("seconds", "120"))
	seed(int(DevTools.get_arg("seed", "1")))
	GameState.match_entrants = [
		{"roster": 0, "control": "cpu", "slot": 0, "difficulty": 3},
		{"roster": 2, "control": "cpu", "slot": 1, "difficulty": 2},
	]
	_match = load("res://match/match.tscn").instantiate()
	add_child(_match)
	for w in _match.wrestlers:
		w.struck.connect(func(_a: Wrestler, _v: Wrestler, _m: Dictionary, blocked: bool) -> void:
			_stats["blocks" if blocked else "hits"] += 1)
		w.knocked_down.connect(func(v: Wrestler) -> void:
			_stats["knockdowns"] += 1
			if v.health <= 0.0:
				_stats["kos"] += 1)
		_was_rebound[w] = false


func _physics_process(delta: float) -> void:
	_elapsed += delta
	for w in _match.wrestlers:
		var limit: float = STUCK_LIMIT.get(w.state, 10.0)
		if w.state_time > limit:
			_failures.append("%s stuck in %s for %.1fs at t=%.1f" % [
				w.display_name, Wrestler.State.keys()[w.state], w.state_time, _elapsed])
			w.state_time = 0.0
		var reb := w.state == Wrestler.State.REBOUND
		if reb and not _was_rebound[w]:
			_stats["rebounds"] += 1
		_was_rebound[w] = reb
		# leaning back into the ropes on a rebound puts the body centre just past the posts
		var edge: float = Ring.spec()["post_half"] + 0.1
		if absf(w.global_position.x) > edge or absf(w.global_position.z) > edge:
			_failures.append("%s left the ring at t=%.1f" % [w.display_name, _elapsed])
		if w.global_position.y < Ring.canvas_height() - 0.2:
			_failures.append("%s fell through the canvas at t=%.1f" % [w.display_name, _elapsed])
	if _elapsed >= _limit:
		_finish()


func _finish() -> void:
	set_physics_process(false)
	print("SOAK %.0fs: %s" % [_elapsed, _stats])
	if _stats["hits"] == 0 or _stats["knockdowns"] == 0:
		_failures.append("no action: %s" % _stats)
	for f in _failures.slice(0, 20):
		print("FAIL ", f)
	print("SOAK RESULT: ", "PASS" if _failures.is_empty() else "FAIL (%d)" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)
