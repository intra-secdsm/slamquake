extends GutTest
## Grapples, whips, corners and pins with scripted controllers.

const S := Wrestler.State

class Scripted:
	extends WrestlerController
	var hold_move := Vector3.ZERO
	var hold_run := false
	var press := ""
	var mash_every := 0
	var _n := 0

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
		_n += 1
		mash = mash_every > 0 and _n % mash_every == 0

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


func test_grapple_locks_up() -> void:
	ca.press = "grapple"
	await wait_physics_frames(3)
	assert_eq(a.state, S.TIEUP)
	assert_eq(b.state, S.HELD)
	assert_eq(a.partner, b)


func test_tieup_times_out_into_a_shove() -> void:
	ca.press = "grapple"
	await wait_physics_frames(3)
	assert_true(await _wait_until(func() -> bool: return a.state == S.IDLE, 150))
	assert_eq(b.state, S.STUN)


func test_suplex_puts_opponent_down_and_hurts() -> void:
	ca.press = "grapple"
	await wait_physics_frames(3)
	ca.press = "kick"
	await wait_physics_frames(3)
	assert_eq(a.state, S.PAIRED)
	assert_true(await _wait_until(func() -> bool: return b.state == S.DOWN, 150), "defender ends down")
	assert_lt(b.health, Wrestler.MAX_HEALTH)
	assert_true(a.state in [S.GETUP, S.IDLE], "attacker gets back up")
	assert_true(Ring.is_inside(b.global_position), "landed inside the ring")


func test_whip_into_ropes_rebounds() -> void:
	ca.press = "grapple"
	await wait_physics_frames(3)
	ca.hold_move = Vector3.RIGHT
	ca.hold_run = true
	await wait_physics_frames(10)
	ca.hold_run = false
	ca.hold_move = Vector3.ZERO
	assert_true(await _wait_until(func() -> bool: return b.state == S.WHIPPED, 60), "whipped")
	assert_true(await _wait_until(func() -> bool: return b.state == S.REBOUND, 90), "bounced off the ropes")


func test_whip_into_corner_slams_turnbuckle() -> void:
	ca.press = "grapple"
	await wait_physics_frames(3)
	var to_corner := Ring.corner(3) - b.global_position   # (+x, -z) corner
	to_corner.y = 0
	ca.hold_move = to_corner.normalized()
	ca.hold_run = true
	await wait_physics_frames(10)
	ca.hold_run = false
	assert_true(await _wait_until(func() -> bool: return b.state in [S.CORNER_HIT, S.CORNERED], 120), "hit the corner")
	assert_true(await _wait_until(func() -> bool: return b.state == S.CORNERED, 60))


func test_pin_and_kickout() -> void:
	b.health = 80.0
	b._go_down(5.0)
	await wait_physics_frames(2)
	ca.press = "block"
	assert_true(await _wait_until(func() -> bool: return b.state == S.PINNED, 60), "pinned")
	assert_eq(a.state, S.PINNING)
	cb.mash_every = 3
	assert_true(await _wait_until(func() -> bool: return b.state == S.KICKOUT, 120), "kicked out by mashing")
	assert_eq(a.state, S.COVER_RELEASE)


func test_downed_opponent_can_be_stomped_and_picked_up() -> void:
	b._go_down(10.0)
	await wait_physics_frames(2)
	var hp := b.health
	ca.press = "kick"
	assert_true(await _wait_until(func() -> bool: return b.state == S.DOWN_HIT, 40), "stomped")
	assert_lt(b.health, hp)
	await _wait_until(func() -> bool: return a.state == S.IDLE and b.state == S.DOWN, 60)
	ca.press = "grapple"
	assert_true(await _wait_until(func() -> bool: return a.state == S.TIEUP and b.state == S.HELD, 90), "picked up into a tie-up")
