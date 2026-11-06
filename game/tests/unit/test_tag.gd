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


## A tie-up under the ring (floor level, inside the canvas footprint) must not make the
## double suplex play there: the anchor aligns to the region instead of the grab position
## (issue #13).
func test_double_team_under_the_ring_plays_in_the_region() -> void:
	# place, flag and lock within one frame: non-scripted states would confine the pair
	# back to the canvas (inside) or past the apron (outside)
	a1.global_position = Vector3(2.7, 0.02, 0.0)
	b1.global_position = Vector3(3.3, 0.02, 0.0)
	a1._face(Vector3.RIGHT, 0.0, true)
	b1._face(Vector3.LEFT, 0.0, true)
	a1.outside = true
	b1.outside = true
	var anchor := a1._flat_xform()
	b1._lock(a1, anchor, S.HELD, "tieup_d")
	a1._lock(b1, anchor, S.TIEUP, "tieup_a")
	a2.global_position = Vector3(4.0, 0.02, 0.6)
	a2.outside = true
	a2._enter(S.IDLE)
	await wait_physics_frames(2)
	var hp := b1.health
	watch_signals(a2)
	(a2.controller as Scripted).press = "grapple"
	await wait_physics_frames(2)
	assert_signal_emitted(a2, "double_team")
	# while the suplex plays, nobody may stand on the floor under the canvas
	var under_canvas := false
	for i in 240:
		for w in [a1, a2, b1]:
			var p: Vector3 = w.global_position
			if absf(p.x) < Ring.canvas_half() - 0.1 and absf(p.z) < Ring.canvas_half() - 0.1 \
					and p.y < Ring.canvas_height() - 0.05:
				under_canvas = true
		if b1.state == S.DOWN:
			break
		await wait_physics_frames(1)
	assert_false(under_canvas, "the double team must not play under the ring canvas")
	assert_lt(b1.health, hp - 10.0)


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


func _tag_out_for_countout(w: Wrestler) -> void:
	_put(w, w.entry_spot(), Vector3.BACK)
	assert_true(w._try_tag(), "tag succeeds before the count-out")
	assert_true(await _wait_until(func() -> bool:
		return w.state == S.APRON and w.teammate.state == S.IDLE, 120), "tag finishes")


func _count_out_wrestlers(outside: Array[Wrestler]) -> void:
	GameState.rules = "normal"
	m.count_period = 0.03
	for i in outside.size():
		outside[i].global_position = Vector3(4.2, 0.1, 1.5 + i)
		outside[i].outside = true
	assert_true(await _wait_until(func() -> bool: return m.winner != null, 180), "count-out finishes")
	m._show_end_menu()


func test_count_out_after_team_zero_tags_records_a_win() -> void:
	await _tag_out_for_countout(a1)
	await _count_out_wrestlers([b1])
	assert_same(m.winner, a2, "the legal opponent wins, not the partner on the apron")
	assert_eq(a2.state, S.CELEBRATE)
	assert_eq(a1.state, S.APRON)
	assert_eq(m.finish_reason, "COUNT-OUT")
	assert_eq(m.career_result(), "win")
	var title: Label = m._end_menu.get_child(0).get_child(0)
	assert_eq(title.text, "ZIP VOLTA & THUNDER MACK WIN")


func test_count_out_after_team_one_tags_records_a_loss() -> void:
	await _tag_out_for_countout(b1)
	await _count_out_wrestlers([a1])
	assert_same(m.winner, b2, "the legal opponent wins, not the partner on the apron")
	assert_eq(b2.state, S.CELEBRATE)
	assert_eq(b1.state, S.APRON)
	assert_eq(m.finish_reason, "COUNT-OUT")
	assert_eq(m.career_result(), "loss")
	var title: Label = m._end_menu.get_child(0).get_child(0)
	assert_eq(title.text, "THUNDER MACK & BRUNO KESSLER WIN")


func test_double_count_out_after_tags_remains_a_draw() -> void:
	await _tag_out_for_countout(a1)
	await _tag_out_for_countout(b1)
	await _count_out_wrestlers([a2, b2])
	assert_eq(m.finish_reason, "DOUBLE COUNT-OUT")
	assert_eq(m.career_result(), "draw")
	assert_eq(a2.state, S.DOWN)
	assert_eq(b2.state, S.DOWN)
	var title: Label = m._end_menu.get_child(0).get_child(0)
	assert_eq(title.text, "DRAW")


func test_count_out_during_team_zero_tag_records_a_win() -> void:
	_put(a1, a1.entry_spot(), Vector3.BACK)
	assert_true(a1._try_tag())
	assert_eq(a2.state, S.APRON_ENTER)
	GameState.rules = "normal"
	b1.global_position = Vector3(4.2, 0.1, 1.5)
	b1.outside = true
	m._count = Match.COUNT_OUT - 1
	m._count_out(m.count_period)
	assert_same(m.winner, a2)
	assert_eq(m.career_result(), "win", "the result does not depend on the tag animation")
	m._show_end_menu()
	var title: Label = m._end_menu.get_child(0).get_child(0)
	assert_eq(title.text, "ZIP VOLTA & THUNDER MACK WIN")


func test_count_out_during_team_one_tag_records_a_loss() -> void:
	_put(b1, b1.entry_spot(), Vector3.BACK)
	assert_true(b1._try_tag())
	assert_eq(b2.state, S.APRON_ENTER)
	GameState.rules = "normal"
	a1.global_position = Vector3(4.2, 0.1, 1.5)
	a1.outside = true
	m._count = Match.COUNT_OUT - 1
	m._count_out(m.count_period)
	assert_same(m.winner, b2)
	assert_eq(m.career_result(), "loss", "the result does not depend on the tag animation")
	m._show_end_menu()
	var title: Label = m._end_menu.get_child(0).get_child(0)
	assert_eq(title.text, "THUNDER MACK & BRUNO KESSLER WIN")
