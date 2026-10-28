extends GutTest
## Momentum, specials and finishers, parries and grapple reversals.

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
			"taunt": taunt = true
		press = ""

var ring: Ring
var a: Wrestler
var b: Wrestler
var ca: Scripted
var cb: Scripted


func before_each() -> void:
	ring = Ring.new()
	add_child_autofree(ring)
	a = _spawn(Vector3(-0.4, 0, 0), PI / 2)
	b = _spawn(Vector3(0.4, 0, 0), -PI / 2)
	ca = a.controller
	cb = b.controller
	a.opponents.append(b)
	b.opponents.append(a)
	await wait_physics_frames(3)


func after_each() -> void:
	Engine.time_scale = 1.0


func _spawn(at: Vector3, yaw: float) -> Wrestler:
	var w := Wrestler.new()
	w.ring = ring
	w.controller = Scripted.new()
	add_child_autofree(w)
	w.global_position = at + Vector3.UP * Ring.canvas_height()
	w.rotation.y = yaw
	return w


func _wait_until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await wait_physics_frames(1)
	return cond.call()


func test_landing_offence_builds_momentum_into_a_special() -> void:
	ca.press = "punch"
	assert_true(await _wait_until(func() -> bool: return b.state == S.HITSTUN, 30), "jab landed")
	assert_gt(a.momentum, 0.0)
	assert_gt(a.momentum, b.momentum, "attacker gains more than the victim")
	watch_signals(a)
	a.gain_momentum(Wrestler.MOMENTUM_MAX)
	assert_true(a.has_special())
	assert_signal_emitted(a, "special_ready")
	a.special_left = 0.01
	await wait_physics_frames(2)
	assert_false(a.has_special(), "a special that isn't used runs out")
	assert_almost_eq(a.momentum, Wrestler.MOMENTUM_MAX * 0.5, 0.01)


func test_finisher_from_tieup_needs_special_and_consumes_it() -> void:
	ca.press = "grapple"
	assert_true(await _wait_until(func() -> bool: return a.state == S.TIEUP, 20), "tied up")
	ca.press = "taunt"
	await wait_physics_frames(3)
	assert_eq(a.state, S.TIEUP, "no finisher without a special")
	a.gain_momentum(Wrestler.MOMENTUM_MAX)
	var hp := b.health
	ca.press = "taunt"
	await wait_physics_frames(2)
	assert_eq(a.state, S.PAIRED)
	assert_eq(a._pair["id"], "thunder_bomb")
	assert_false(a.has_special())
	assert_eq(a.momentum, 0.0)
	assert_true(await _wait_until(func() -> bool: return b.state == S.DOWN, 240), "finisher put them down")
	assert_lt(b.health, hp - 15.0)
	assert_gt(b._finisher_hit, 0.0, "kick-outs are harder right after a finisher")


func test_finisher_straight_onto_dazed_opponent() -> void:
	a.gain_momentum(Wrestler.MOMENTUM_MAX)
	b._enter(S.STUN)
	await wait_physics_frames(1)
	ca.press = "taunt"
	await wait_physics_frames(2)
	assert_eq(a.state, S.PAIRED)
	assert_eq(a._pair.get("id", ""), "thunder_bomb")


func test_timed_block_parries_a_strike() -> void:
	b.global_position.x = 0.5
	ca.press = "punch"
	await wait_physics_frames(1)
	var hit := float(a._move["hit_time"])
	while a.state_time < hit - 0.1:
		await wait_physics_frames(1)
	cb.press = "block"
	assert_true(await _wait_until(func() -> bool: return b.state == S.PARRY, 20), "parried")
	assert_eq(a.state, S.STUN, "the striker is left open")
	assert_eq(b.health, Wrestler.MAX_HEALTH)


func test_mashing_block_does_not_parry() -> void:
	b.global_position.x = 0.5
	ca.press = "punch"
	await wait_physics_frames(1)
	var hit := float(a._move["hit_time"])
	while a.state_time < hit - 0.15:
		await wait_physics_frames(1)
	cb.press = "block"
	await wait_physics_frames(3)
	cb.press = "block"
	await _wait_until(func() -> bool: return a._hit_done, 20)
	await wait_physics_frames(1)
	assert_ne(b.state, S.PARRY)


func test_reversing_a_suplex_into_a_hip_toss() -> void:
	ca.press = "grapple"
	assert_true(await _wait_until(func() -> bool: return a.state == S.TIEUP, 20))
	await wait_physics_frames(6)
	ca.press = "kick"
	assert_true(await _wait_until(func() -> bool: return a.state == S.PAIRED, 10), "suplex started")
	await wait_physics_frames(4)
	watch_signals(b)
	cb.press = "block"
	await wait_physics_frames(2)
	assert_signal_emitted(b, "reversed")
	assert_eq(b.state, S.PAIRED)
	assert_eq(b._pair.get("id", ""), "hip_toss")
	assert_eq(a._role, "d")
	assert_true(await _wait_until(func() -> bool: return a.state == S.DOWN, 120), "the attacker got thrown")


func test_late_block_does_not_reverse() -> void:
	ca.press = "grapple"
	assert_true(await _wait_until(func() -> bool: return a.state == S.TIEUP, 20))
	await wait_physics_frames(6)
	ca.press = "kick"
	assert_true(await _wait_until(func() -> bool: return a.state == S.PAIRED, 10))
	await wait_seconds(0.5)
	cb.press = "block"
	await wait_physics_frames(2)
	assert_eq(a._pair.get("id", ""), "suplex", "too late: the suplex carries on")
