extends GutTest
## Tag team rules: tags, illegal partners, saves, double teams, team wins.

const S := Wrestler.State

class Scripted:
	extends WrestlerController
	var hold_move := Vector3.ZERO
	var press := ""

	func update(_w: Wrestler, _d: float) -> void:
		clear_one_shots()
		move = hold_move
		match press:
			"punch": punch = true
			"kick": kick = true
			"grapple": grapple = true
			"block": block_pressed = true
		press = ""

var m: Match
var a1: Wrestler    # team 0, legal
var b1: Wrestler    # team 1, legal
var a2: Wrestler    # team 0, apron
var b2: Wrestler    # team 1, apron


func before_each() -> void:
	GameState.rules = "nodq"
	GameState.match_entrants = [
		{"roster": 0, "control": "cpu", "slot": 0, "difficulty": 0, "team": 0},
		{"roster": 2, "control": "cpu", "slot": 1, "difficulty": 0, "team": 1},
		{"roster": 1, "control": "cpu", "slot": 2, "difficulty": 0, "team": 0},
		{"roster": 0, "control": "cpu", "slot": 3, "difficulty": 0, "team": 1},
	]
	m = load("res://match/match.tscn").instantiate()
	add_child_autofree(m)
	await wait_physics_frames(2)
	a1 = m.wrestlers[0]
	b1 = m.wrestlers[1]
	a2 = m.wrestlers[2]
	b2 = m.wrestlers[3]
	for w in m.wrestlers:
		w.controller = Scripted.new()
		w.infinite_health = false


func _wait_until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await wait_physics_frames(1)
	return cond.call()


func _put(w: Wrestler, at: Vector3, face: Vector3) -> void:
	w.global_position = Vector3(at.x, Ring.canvas_height(), at.z)
	w._face(face, 0.0, true)


func test_setup_has_legal_men_in_and_partners_on_the_apron() -> void:
	assert_true(m.tag_mode)
	assert_true(a1.legal and b1.legal)
	assert_false(a2.legal or b2.legal)
	assert_eq(a2.state, S.APRON)
	assert_eq(b2.state, S.APRON)
	assert_eq(a1.teammate, a2)
	assert_false(a1.opponents.has(a2))
	assert_ne(b1.nearest_opponent(), a2, "partners on the apron can't be targeted")


func test_tag_swaps_the_legal_man() -> void:
	_put(a1, a1.entry_spot() + Vector3(0, 0, 0.5), Vector3.BACK)
	_put(b1, Vector3(1.5, 0, 1.5), Vector3.FORWARD)
	a1.health = 30.0
	await wait_physics_frames(1)
	watch_signals(a1)
	(a1.controller as Scripted).press = "grapple"
	await wait_physics_frames(2)
	assert_signal_emitted(a1, "tagged")
	assert_false(a1.legal)
	assert_true(a2.legal)
	assert_eq(a1.state, S.APRON_EXIT)
	assert_eq(a2.state, S.APRON_ENTER)
	assert_gt(a2.momentum, 20.0, "hot tag")
	assert_true(await _wait_until(func() -> bool: return a1.state == S.APRON and a2.state == S.IDLE, 120))
	assert_almost_eq(a1.global_position.x, a1.apron_spot.x, 0.01)


func test_illegal_partner_is_sent_back_after_the_count() -> void:
	(a2.controller as Scripted).hold_move = Vector3.BACK      # toward the ring (+z from the far apron)
	assert_true(await _wait_until(func() -> bool: return a2.state == S.IDLE, 90), "climbed in")
	assert_false(a2.legal)
	(a2.controller as Scripted).hold_move = Vector3.ZERO
	_put(a2, Vector3(0.5, 0, 0.5), Vector3.FORWARD)
	a2.illegal_time = Wrestler.ILLEGAL_TIME - 0.1
	await wait_physics_frames(10)
	assert_true(a2.forced_return)
	assert_true(await _wait_until(func() -> bool: return a2.state == S.APRON, 240), "walked back out to the apron")


func test_partner_breaks_up_a_pin() -> void:
	_put(a1, Vector3(0, 0, 0), Vector3.RIGHT)
	_put(b1, Vector3(1.2, 0, 0), Vector3.LEFT)
	b1._go_down(10.0)
	await wait_physics_frames(2)
	(a1.controller as Scripted).press = "block"
	assert_true(await _wait_until(func() -> bool: return a1.state == S.PINNING, 60), "pinning")
	_put(b2, a1.global_position + Vector3(0, 0, -0.9), Vector3.BACK)
	b2._enter(S.IDLE)
	await wait_physics_frames(1)
	watch_signals(a1)
	(b2.controller as Scripted).press = "punch"
	assert_true(await _wait_until(func() -> bool: return a1.state == S.KNOCKDOWN, 40), "pinner knocked off")
	assert_signal_emitted(a1, "pin_saved")
	assert_ne(b1.state, S.PINNED)
	assert_null(m.winner)


func test_illegal_man_cannot_pin() -> void:
	_put(a2, Vector3(0, 0, 0), Vector3.RIGHT)
	a2._enter(S.IDLE)
	_put(b1, Vector3(1.2, 0, 0), Vector3.LEFT)
	b1._go_down(10.0)
	await wait_physics_frames(2)
	(a2.controller as Scripted).press = "block"
	await wait_physics_frames(10)
	assert_ne(a2.state, S.PINNING)


func test_double_team_suplex() -> void:
	_put(a1, Vector3(0, 0, 0), Vector3.RIGHT)
	_put(b1, Vector3(0.6, 0, 0), Vector3.LEFT)
	await wait_physics_frames(2)
	(a1.controller as Scripted).press = "grapple"
	assert_true(await _wait_until(func() -> bool: return a1.state == S.TIEUP, 30), "tied up")
	_put(a2, Vector3(0.1, 0, 1.0), Vector3.FORWARD)
	a2._enter(S.IDLE)
	await wait_physics_frames(1)
	var hp := b1.health
	watch_signals(a2)
	(a2.controller as Scripted).press = "grapple"
	await wait_physics_frames(2)
	assert_signal_emitted(a2, "double_team")
	assert_eq(a2.state, S.PAIRED)
	assert_eq(a1.state, S.PAIRED)
	assert_true(await _wait_until(func() -> bool: return b1.state == S.DOWN, 200), "suplexed")
	assert_lt(b1.health, hp - 10.0)
	assert_true(a2.state in [S.GETUP, S.IDLE], "helper finished too")


func test_pinning_the_legal_man_wins_for_the_team() -> void:
	_put(a1, Vector3(0, 0, 0), Vector3.RIGHT)
	_put(b1, Vector3(1.2, 0, 0), Vector3.LEFT)
	b1.health = 0.0
	b1._go_down(10.0)
	await wait_physics_frames(2)
	(a1.controller as Scripted).press = "block"
	assert_true(await _wait_until(func() -> bool: return m.winner != null, 60 * 8), "three count")
	assert_eq(m.winner.team, 0)
	assert_eq(a2.state, S.APRON, "the partner celebrates where they are")
	assert_true(a2.match_over)
