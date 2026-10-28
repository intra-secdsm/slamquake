extends GutTest
## Leaving/entering the ring, over-the-top falls, turnbuckles, chairs, tables, count-outs.

const S := Wrestler.State

class Scripted:
	extends WrestlerController
	var hold_move := Vector3.ZERO
	var hold_run := false
	var press := ""

	func update(_w: Wrestler, _d: float) -> void:
		clear_one_shots()
		move = hold_move
		run_held = hold_run
		match press:
			"punch": punch = true
			"kick": kick = true
			"grapple": grapple = true
			"block": block_pressed = true
		press = ""

var m: Match
var a: Wrestler
var b: Wrestler
var ca: Scripted
var cb: Scripted
var lim: float


func before_each() -> void:
	GameState.rules = "normal"
	GameState.match_entrants = [
		{"roster": 0, "control": "cpu", "slot": 0, "difficulty": 0},
		{"roster": 1, "control": "cpu", "slot": 1, "difficulty": 0},
	]
	m = load("res://match/match.tscn").instantiate()
	add_child_autofree(m)
	a = m.wrestlers[0]
	b = m.wrestlers[1]
	ca = Scripted.new()
	cb = Scripted.new()
	a.controller = ca
	b.controller = cb
	a.infinite_health = false
	b.infinite_health = false
	lim = float(Ring.spec()["post_half"]) - Wrestler.ROPE_MARGIN
	await wait_physics_frames(3)


func _place(w: Wrestler, at: Vector3, face: Vector3) -> void:
	w.global_position = at
	w.rotation.y = atan2(face.x, face.z)


func _wait_until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await wait_physics_frames(1)
	return cond.call()


func test_push_into_ropes_rolls_out_then_back_in() -> void:
	_place(b, Vector3(-2, Ring.canvas_height(), -2), Vector3.FORWARD)
	_place(a, Vector3(lim - 0.2, Ring.canvas_height(), 0.3), Vector3.RIGHT)
	ca.hold_move = Vector3.RIGHT
	assert_true(await _wait_until(func() -> bool: return a.state == S.EXIT_RING, 90), "started rolling out")
	assert_true(await _wait_until(func() -> bool: return a.state == S.IDLE, 120), "landed")
	assert_true(a.outside, "on the floor")
	assert_lt(a.global_position.y, 0.3)
	ca.hold_move = Vector3.LEFT
	assert_true(await _wait_until(func() -> bool: return a.state == S.ENTER_RING, 90), "started climbing in")
	assert_true(await _wait_until(func() -> bool: return a.state == S.IDLE, 120))
	assert_false(a.outside, "back in the ring")
	assert_almost_eq(a.global_position.y, Ring.canvas_height(), 0.1)


func test_big_hit_near_ropes_sends_victim_over_the_top() -> void:
	_place(b, Vector3(lim - 0.1, Ring.canvas_height(), 0.0), Vector3.LEFT)
	_place(a, Vector3(lim - 1.0, Ring.canvas_height(), 0.0), Vector3.RIGHT)
	b.receive_strike(a, Strikes.get_move("clothesline"))
	await wait_physics_frames(1)
	assert_eq(b.state, S.FALL_OUT)
	assert_true(await _wait_until(func() -> bool: return b.state == S.DOWN, 120), "down on the floor")
	assert_true(b.outside)
	assert_lt(b.global_position.y, 0.3)


func test_rope_toss_through_the_table() -> void:
	# the table sits on the +x floor at z = 0
	_place(a, Vector3(lim - 1.2, Ring.canvas_height(), 0.0), Vector3.RIGHT)
	_place(b, Vector3(lim - 0.3, Ring.canvas_height(), 0.0), Vector3.LEFT)
	await wait_physics_frames(2)
	ca.press = "grapple"
	assert_true(await _wait_until(func() -> bool: return a.state == S.TIEUP, 20))
	ca.hold_move = Vector3.RIGHT
	ca.hold_run = true
	assert_true(await _wait_until(func() -> bool: return a.state == S.PAIRED, 30), "toss started")
	ca.hold_run = false
	ca.hold_move = Vector3.ZERO
	assert_eq(a._pair.get("id", ""), "rope_toss")
	assert_true(await _wait_until(func() -> bool: return b.state == S.DOWN, 120), "landed")
	assert_true(b.outside)
	assert_false(m.tables[0].intact, "table smashed")


func test_climb_and_elbow_drop_from_the_top() -> void:
	var corner := Ring.corner(0)
	_place(a, Vector3(corner.x - 0.6, Ring.canvas_height(), corner.z - 0.6), Vector3(1, 0, 1).normalized())
	_place(b, Vector3(corner.x - 2.2, Ring.canvas_height(), corner.z - 2.2), Vector3.FORWARD)
	b._go_down(20.0)
	await wait_physics_frames(2)
	ca.press = "grapple"
	assert_true(await _wait_until(func() -> bool: return a.state == S.PERCH, 120), "perched on the turnbuckle")
	assert_gt(a.global_position.y, Ring.canvas_height() + 1.0)
	var hp := b.health
	ca.press = "punch"
	assert_true(await _wait_until(func() -> bool: return a.state == S.DIVE_LAND, 90), "dived")
	assert_lt(b.health, hp, "elbow landed")
	assert_true(await _wait_until(func() -> bool: return a.is_on_floor(), 60))
	assert_almost_eq(a.global_position.y, Ring.canvas_height(), 0.1)


func test_perched_wrestler_can_be_knocked_off() -> void:
	var corner := Ring.corner(1)
	_place(a, Vector3(corner.x + 0.6, Ring.canvas_height(), corner.z - 0.6), Vector3(-1, 0, 1).normalized())
	_place(b, Vector3(0, Ring.canvas_height(), -2.5), Vector3.FORWARD)
	await wait_physics_frames(2)
	ca.press = "grapple"
	assert_true(await _wait_until(func() -> bool: return a.state == S.PERCH, 120))
	b.global_position = a.global_position - a.facing() * 0.0 + Vector3(0.7, 0, -0.7)
	b.global_position.y = Ring.canvas_height()
	a.receive_strike(b, Strikes.get_move("jab"))
	assert_eq(a.state, S.KNOCKDOWN)
	assert_true(await _wait_until(func() -> bool: return a.state == S.DOWN, 90))
	assert_almost_eq(a.global_position.y, Ring.canvas_height(), 0.1, "fell to the canvas")


func test_chair_shot_is_a_disqualification_in_normal_rules() -> void:
	var chair := m.chairs[0]
	_place(a, chair.global_position + Vector3(0.6, 0, 0), Vector3.LEFT)
	_place(b, chair.global_position + Vector3(1.6, 0, 0), Vector3.LEFT)
	a.outside = true
	b.outside = true
	await wait_physics_frames(10)
	ca.press = "grapple"
	assert_true(await _wait_until(func() -> bool: return a.held_item != null, 60), "picked up the chair")
	await _wait_until(func() -> bool: return a.state == S.IDLE, 60)
	a.global_position += Vector3(0, 0, 0.5)
	await wait_physics_frames(5)
	var hand := a.model.skeleton.global_transform * a.model.skeleton.get_bone_global_pose(a.model.skeleton.find_bone("hand.R")).origin
	assert_lt(chair.global_position.distance_to(hand), 0.6, "chair travels with the hand")
	a.rotation.y = atan2(b.global_position.x - a.global_position.x, b.global_position.z - a.global_position.z)
	b.global_position = a.global_position + a.facing() * 1.0
	ca.press = "punch"
	assert_true(await _wait_until(func() -> bool: return m.winner != null, 90), "match ended")
	assert_eq(b.state, S.CELEBRATE, "victim wins by DQ")


func test_count_out() -> void:
	m.count_period = 0.03
	_place(b, Vector3(Ring.canvas_half() + 0.8, 0.1, 0.0), Vector3.LEFT)
	b.outside = true
	assert_true(await _wait_until(func() -> bool: return m.winner != null, 200), "counted out")
	assert_eq(a.state, S.CELEBRATE)


func test_cpu_route_back_in_goes_round_the_table() -> void:
	# from behind the ringside table, the CPU heads for the gap past its end instead of
	# walking into it (which stalled no-DQ matches: no count-out to end them)
	var cpu := CpuController.new(3, 1)
	for z in [-0.8, -0.3, 0.0, 0.3, 0.8, 1.2]:
		_place(a, Vector3(5.4, 0, z), Vector3.LEFT)
		var v := cpu._toward_ring(a)
		assert_gt(absf(v.z), 0.9, "from z=%.1f it walks along the table, not into it (%s)" % [z, v])
		assert_lt(v.z, 0.0, "towards the end away from the steel steps")
	m.tables[0].smash()
	_place(a, Vector3(5.4, 0, 0.0), Vector3.LEFT)
	assert_almost_eq(cpu._toward_ring(a), Vector3.LEFT, Vector3.ONE * 0.01, "once it's broken, straight in")


func test_letting_go_of_run_stops_a_diagonal_run() -> void:
	# corner to corner, every rope comes before the run wears off: it must still stop
	_place(b, Vector3(-2, Ring.canvas_height(), -2), Vector3.FORWARD)
	_place(a, Vector3(-2, Ring.canvas_height(), 0), Vector3(1, 0, 1).normalized())
	ca.hold_run = true
	ca.hold_move = Vector3(1, 0, 1).normalized()
	assert_true(await _wait_until(func() -> bool: return a.state == S.REBOUND, 120), "ran into the ropes")
	ca.hold_run = false
	ca.hold_move = Vector3.ZERO
	assert_true(await _wait_until(func() -> bool: return a.state == S.IDLE, 300), "stopped running")


func test_two_wrestlers_on_one_corner_spot_stay_on_the_canvas() -> void:
	# both dropped on the same corner spot, as when a whip lands someone in an occupied corner
	var spot := Vector3(lim + 0.18, Ring.canvas_height(), -(lim + 0.18))
	_place(b, spot, Vector3.FORWARD)
	_place(a, spot + Vector3(0, 0.02, 0), Vector3.FORWARD)
	for i in 30:
		await wait_physics_frames(1)
		assert_gt(a.global_position.y, Ring.canvas_height() - 0.1)
		assert_gt(b.global_position.y, Ring.canvas_height() - 0.1)
