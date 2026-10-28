extends GutTest
## Wrestler mechanics driven by a scripted controller in a real ring.

class Scripted:
	extends WrestlerController
	var hold_move := Vector3.ZERO
	var hold_run := false
	var hold_block := false
	var press := ""

	func update(_w: Wrestler, _d: float) -> void:
		clear_one_shots()
		move = hold_move
		run_held = hold_run
		block_held = hold_block
		match press:
			"punch": punch = true
			"kick": kick = true
			"mash": mash = true
		press = ""

var ring: Ring
var a: Wrestler
var b: Wrestler
var ca: Scripted
var cb: Scripted


func before_each() -> void:
	ring = Ring.new()
	add_child_autofree(ring)
	a = _spawn(Vector3(-0.5, 0, 0), PI / 2)
	b = _spawn(Vector3(0.5, 0, 0), -PI / 2)
	ca = a.controller
	cb = b.controller
	a.opponents.append(b)
	b.opponents.append(a)
	await wait_physics_frames(5)


func _spawn(at: Vector3, yaw: float) -> Wrestler:
	var w := Wrestler.new()
	w.ring = ring
	w.controller = Scripted.new()
	add_child_autofree(w)
	w.global_position = at + Vector3.UP * Ring.canvas_height()
	w.rotation.y = yaw
	return w


func test_jab_hits_opponent_in_front() -> void:
	ca.press = "punch"
	await wait_physics_frames(20)
	assert_lt(b.health, Wrestler.MAX_HEALTH, "jab landed")
	assert_eq(b.state, Wrestler.State.HITSTUN)


func test_block_negates_damage() -> void:
	cb.hold_block = true
	await wait_physics_frames(3)
	ca.press = "punch"
	await wait_physics_frames(20)
	assert_eq(b.health, Wrestler.MAX_HEALTH)
	assert_eq(b.state, Wrestler.State.BLOCK)


func test_strike_whiffs_out_of_range() -> void:
	b.global_position.x = 2.5
	ca.press = "kick"
	await wait_physics_frames(30)
	assert_eq(b.health, Wrestler.MAX_HEALTH)


func test_combo_ender_knocks_down_then_gets_up() -> void:
	ca.press = "punch"
	await wait_physics_frames(14)
	ca.press = "kick"
	await wait_physics_frames(30)
	assert_true(b.state in [Wrestler.State.KNOCKDOWN, Wrestler.State.DOWN], "kick after jab knocks down")
	# mash to get up; must stand again within a few seconds
	for i in 300:
		cb.press = "mash" if i % 4 == 0 else ""
		await wait_physics_frames(1)
		if b.state == Wrestler.State.IDLE:
			break
	assert_eq(b.state, Wrestler.State.IDLE, "got back up")


func test_running_into_ropes_rebounds_and_reverses() -> void:
	b.global_position = Vector3(0, Ring.canvas_height(), 2.0)  # out of the way
	ca.hold_move = Vector3.RIGHT
	ca.hold_run = true
	var saw_rebound := false
	for i in 120:
		await wait_physics_frames(1)
		if a.state == Wrestler.State.REBOUND:
			saw_rebound = true
		if saw_rebound and a.state == Wrestler.State.RUN:
			break
	assert_true(saw_rebound, "hit the ropes")
	assert_eq(a.state, Wrestler.State.RUN)
	assert_lt(a.facing().x, -0.5, "now running back the other way")


func test_wrestlers_stay_inside_ropes() -> void:
	ca.hold_move = Vector3.BACK
	await wait_physics_frames(150)
	assert_true(Ring.is_inside(a.global_position))
	assert_almost_eq(a.global_position.y, Ring.canvas_height(), 0.05, "standing on the canvas")
