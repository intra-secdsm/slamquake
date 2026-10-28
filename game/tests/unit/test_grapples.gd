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


## Stomping or elbow-dropping a downed opponent can't keep them down forever.
func test_ground_spam_cannot_keep_opponent_down() -> void:
	b.health = 20.0
	b._go_down()
	await wait_physics_frames(2)
	var frames := 0
	while b.state != S.GETUP and frames < 60 * 8:
		if a.state == S.IDLE and b.is_down():
			ca.press = "kick" if frames % 2 == 0 else "punch"
		await wait_physics_frames(1)
		frames += 1
	assert_eq(b.state, S.GETUP, "got up despite the ground attacks")
	assert_lt(frames / 60.0, Wrestler.DOWN_MAX + 2.0)


func test_getting_up_gives_a_moment_of_protection() -> void:
	b._go_down()
	b._down_left = 0.05
	assert_true(await _wait_until(func() -> bool: return b.state == S.IDLE, 120), "back up")
	assert_false(b.can_be_hit(), "can't be jabbed the instant they're up")
	assert_false(b.can_be_grappled())
	await wait_seconds(Wrestler.WAKE_GRACE + 0.05)
	assert_true(b.can_be_hit())


func test_corner_hits_do_not_trap_forever() -> void:
	var lim := b._rope_limit() + 0.18
	b.global_position = Vector3(lim, b.global_position.y, -lim)
	b._corner_clock = 0.0
	b._corner_hits = 0
	b._enter(S.CORNERED)
	a.global_position = b.global_position + Vector3(-0.8, 0, 0.8)
	a.look_at(b.global_position, Vector3.UP, true)
	await wait_physics_frames(2)
	var frames := 0
	while b.state in [S.CORNERED, S.CORNER_HIT] and frames < 60 * 4:
		if a.state == S.IDLE:
			ca.press = "punch"
		await wait_physics_frames(1)
		frames += 1
	assert_true(b.state not in [S.CORNERED, S.CORNER_HIT], "stumbled out of the corner")
	assert_lt(frames / 60.0, Wrestler.CORNER_TIME + 0.3)
