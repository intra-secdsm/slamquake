extends Node
## Headless CPU-vs-CPU soak test. Plays complete matches back to back as fast as
## possible and fails if a wrestler gets stuck, leaves the ring, or nothing happens.
##   godot --headless --fixed-fps 60 --path game res://dev/soak.tscn -- --seconds=300

const S := Wrestler.State
const STUCK_LIMIT := {  # max seconds allowed in one state
	S.IDLE: 60.0, S.RUN: 8.0, S.STRIKE: 2.0, S.BLOCK: 10.0, S.HITSTUN: 2.0, S.KNOCKDOWN: 2.0,
	S.DOWN: 12.0, S.GETUP: 2.0, S.REBOUND: 2.0, S.TAUNT: 3.0, S.GRAB_WHIFF: 1.5, S.TIEUP: 3.0,
	S.HELD: 3.5, S.PAIRED: 3.0, S.WHIPPED: 6.0, S.CORNER_HIT: 1.5, S.CORNERED: 4.0,
	S.CORNER_EXIT: 1.5, S.STOMP: 1.5, S.DOWN_HIT: 1.5, S.PINNING: 6.0, S.PINNED: 6.0,
	S.KICKOUT: 1.5, S.COVER_RELEASE: 1.5, S.STUN: 2.0,
}

var _match: Match
var _elapsed := 0.0
var _match_time := 0.0
var _limit := 120.0
var _stats := {"matches": 0, "hits": 0, "blocks": 0, "knockdowns": 0, "rebounds": 0, "pins": 0, "kickouts": 0}
var _moves := {}
var _durations: Array[float] = []
var _failures: Array[String] = []
var _was_rebound := {}
var _over := false
var _over_time := 0.0
var _last_move := ""


func _ready() -> void:
	_limit = float(DevTools.get_arg("seconds", "120"))
	seed(int(DevTools.get_arg("seed", "1")))
	_new_match()


func _new_match() -> void:
	if _match:
		_match.queue_free()
	GameState.match_entrants = [
		{"roster": randi_range(0, 2), "control": "cpu", "slot": 0, "difficulty": 3},
		{"roster": randi_range(0, 2), "control": "cpu", "slot": 1, "difficulty": randi_range(1, 3)},
	]
	_match = load("res://match/match.tscn").instantiate()
	add_child(_match)
	_match_time = 0.0
	_over = false
	_over_time = 0.0
	_match.match_ended.connect(func(_w: Wrestler) -> void:
		_over = true
		_stats["matches"] += 1
		_durations.append(_match_time))
	for w in _match.wrestlers:
		w.struck.connect(func(_a: Wrestler, _v: Wrestler, _m: Dictionary, blocked: bool) -> void:
			_stats["blocks" if blocked else "hits"] += 1)
		w.knocked_down.connect(func(_v: Wrestler) -> void: _stats["knockdowns"] += 1)
		w.pin_started.connect(func(_a: Wrestler, _d: Wrestler) -> void: _stats["pins"] += 1)
		w.kicked_out.connect(func(_d: Wrestler) -> void: _stats["kickouts"] += 1)
		w.move_performed.connect(func(_a: Wrestler, id: String) -> void:
			_moves[id] = _moves.get(id, 0) + 1
			_last_move = id)
		_was_rebound[w] = false


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_match_time += delta
	if _over:
		# give the finish a moment to play out, then start the next match
		_over_time += delta
		if _over_time > 2.0:
			_new_match()
	else:
		_check()
		if _match_time > 240.0:
			_failures.append("match did not finish within 240s")
			_new_match()
	if _elapsed >= _limit:
		_finish()


func _check() -> void:
	for w in _match.wrestlers:
		var limit: float = STUCK_LIMIT.get(w.state, 10.0)
		if w.state_time > limit:
			_failures.append("%s stuck in %s for %.1fs at t=%.1f" % [
				w.display_name, S.keys()[w.state], w.state_time, _elapsed])
			w.state_time = 0.0
		var reb := w.state == S.REBOUND
		if reb and not _was_rebound[w]:
			_stats["rebounds"] += 1
		_was_rebound[w] = reb
		# leaning into the ropes / slumping in a corner put the body centre just past the posts
		var edge: float = Ring.spec()["post_half"] + 0.1
		if w.state not in [S.PAIRED, S.HELD, S.TIEUP, S.PINNING, S.PINNED] \
				and (absf(w.global_position.x) > edge or absf(w.global_position.z) > edge):
			_failures.append("%s left the ring at t=%.1f (%s)" % [w.display_name, _elapsed, S.keys()[w.state]])
		if w.global_position.y < Ring.canvas_height() - 0.2:
			_failures.append("%s fell through the canvas at t=%.1f (%s at %s, last move %s, partner state %s)" % [
				w.display_name, _elapsed, S.keys()[w.state], w.global_position, _last_move,
				S.keys()[w.partner.state] if w.partner else "-"])


func _finish() -> void:
	set_physics_process(false)
	var avg := 0.0
	for d in _durations:
		avg += d / maxf(1, _durations.size())
	print("SOAK %.0fs: %s avg match %.0fs" % [_elapsed, _stats, avg])
	print("MOVES ", _moves)
	if _stats["hits"] == 0 or _stats["matches"] == 0:
		_failures.append("no complete matches: %s" % _stats)
	for f in _failures.slice(0, 20):
		print("FAIL ", f)
	print("SOAK RESULT: ", "PASS" if _failures.is_empty() else "FAIL (%d)" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)
