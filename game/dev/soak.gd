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
	S.EXIT_RING: 2.0, S.ENTER_RING: 2.0, S.FALL_OUT: 2.0, S.CLIMB: 2.0, S.PERCH: 7.0, S.CLIMB_DOWN: 1.5,
	S.DIVE: 1.5, S.DIVE_LAND: 1.5, S.ITEM_PICKUP: 1.5, S.CHAIR_SWING: 1.5, S.PARRY: 1.0,
	S.APRON: 600.0, S.APRON_ENTER: 1.5, S.APRON_EXIT: 1.8,
}

var _match: Match
var _elapsed := 0.0
var _match_time := 0.0
var _limit := 120.0
var _stats := {"matches": 0, "hits": 0, "blocks": 0, "knockdowns": 0, "rebounds": 0, "pins": 0, "kickouts": 0,
	"exits": 0, "tables": 0, "parries": 0, "reversals": 0, "specials": 0, "tags": 0, "saves": 0,
	"double_teams": 0, "forced_back": 0}
var _endings := {}
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
		{"roster": randi_range(0, Roster.builtin().size() - 1), "control": "cpu", "slot": 0, "difficulty": 3, "team": 0},
		{"roster": randi_range(0, Roster.builtin().size() - 1), "control": "cpu", "slot": 1, "difficulty": randi_range(1, 4), "team": 1},
	]
	var tag := DevTools.get_arg("mode", "mixed") == "tag" or (DevTools.get_arg("mode", "mixed") == "mixed" and randf() < 0.4)
	if tag:
		GameState.match_entrants.append({"roster": randi_range(0, Roster.builtin().size() - 1), "control": "cpu", "slot": 2, "difficulty": 3, "team": 0})
		GameState.match_entrants.append({"roster": randi_range(0, Roster.builtin().size() - 1), "control": "cpu", "slot": 3,
			"difficulty": randi_range(1, 4), "team": 1})
	GameState.rules = "nodq" if randf() < 0.4 else "normal"
	_match = load("res://match/match.tscn").instantiate()
	add_child(_match)
	_match_time = 0.0
	_over = false
	_over_time = 0.0
	_match.match_ended.connect(func(_w: Wrestler) -> void:
		_over = true
		_stats["matches"] += 1
		var key := "%s%s/%s" % ["tag-" if _match.tag_mode else "", GameState.rules, _match.finish_reason]
		_endings[key] = _endings.get(key, 0) + 1
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
		w.reversed.connect(func(_b: Wrestler, _v: Wrestler, kind: String) -> void:
			_stats["parries" if kind == "parry" else "reversals"] += 1)
		w.special_ready.connect(func(_w: Wrestler) -> void: _stats["specials"] += 1)
		w.tagged.connect(func(_o: Wrestler, _i: Wrestler, _h: bool) -> void: _stats["tags"] += 1)
		w.pin_saved.connect(func(_b: Wrestler, _p: Wrestler) -> void: _stats["saves"] += 1)
		w.double_team.connect(func(_a: Wrestler, _b: Wrestler, _v: Wrestler) -> void: _stats["double_teams"] += 1)
		_was_rebound[w] = false
		w.landed_outside.connect(func(_v: Wrestler, _at: Vector3) -> void: _stats["exits"] += 1)
	for t in _match.tables:
		t.broken.connect(func(_t: FoldingTable) -> void: _stats["tables"] += 1)


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
		if _match_time > (300.0 if GameState.rules == "normal" else 420.0) * (1.5 if _match.tag_mode else 1.0):
			_failures.append("match did not finish in time (%s rules)" % GameState.rules)
			_new_match()
	if _elapsed >= _limit:
		_finish()


func _check() -> void:
	for w in _match.wrestlers:
		if w.forced_return and w.illegal_time < Wrestler.ILLEGAL_TIME + 0.02:
			_stats["forced_back"] += 1
		if w.forced_return and w.illegal_time > Wrestler.ILLEGAL_TIME + 15.0:
			_failures.append("%s never made it back to the apron (at %s, %s)" % [w.display_name,
				w.global_position.snapped(Vector3.ONE * 0.01), S.keys()[w.state]])
			w.illegal_time = 0.0
		var limit: float = STUCK_LIMIT.get(w.state, 10.0)
		if w.state_time > limit:
			_failures.append("%s stuck in %s for %.1fs at t=%.1f at %s outside=%s (opponent %s at %s)" % [
				w.display_name, S.keys()[w.state], w.state_time, _elapsed, w.global_position.snapped(Vector3.ONE * 0.01),
				w.outside, S.keys()[w.opponents[0].state], w.opponents[0].global_position.snapped(Vector3.ONE * 0.01)])
			w.state_time = 0.0
		var reb := w.state == S.REBOUND
		if reb and not _was_rebound[w]:
			_stats["rebounds"] += 1
		_was_rebound[w] = reb
		# leaning into the ropes / slumping in a corner put the body centre just past the posts
		var edge: float = Ring.spec()["post_half"] + 0.1
		if w.outside:
			edge = Ring.spec()["barricade_half"]
		if w.state not in Wrestler.SCRIPTED \
				and (absf(w.global_position.x) > edge or absf(w.global_position.z) > edge):
			_failures.append("%s out of bounds at t=%.1f (%s, outside=%s, at %s, last move %s)" % [w.display_name, _elapsed,
				S.keys()[w.state], w.outside, w.global_position.snapped(Vector3.ONE * 0.01), _last_move])
		var floor_y := 0.0 if w.outside else Ring.canvas_height()
		if w.state not in Wrestler.SCRIPTED and w.global_position.y < floor_y - 0.2:
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
	print("ENDINGS ", _endings, " longest %.0fs" % (_durations.max() if not _durations.is_empty() else 0.0))
	if _stats["hits"] == 0 or _stats["matches"] == 0:
		_failures.append("no complete matches: %s" % _stats)
	for f in _failures.slice(0, 20):
		print("FAIL ", f)
	print("SOAK RESULT: ", "PASS" if _failures.is_empty() else "FAIL (%d)" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)
