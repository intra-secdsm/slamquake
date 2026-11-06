extends GutTest
## Match rules end to end: referee counts a pin to three and the pinner wins.

var m: Match


func before_each() -> void:
	GameState.match_entrants = [
		{"roster": 0, "control": "cpu", "slot": 0, "difficulty": 0},
		{"roster": 1, "control": "cpu", "slot": 1, "difficulty": 0},
	]
	m = load("res://match/match.tscn").instantiate()
	add_child_autofree(m)
	await wait_physics_frames(3)


func test_three_count_wins_the_match() -> void:
	var a := m.wrestlers[0]
	var b := m.wrestlers[1]
	a.global_position = Vector3(0, Ring.canvas_height(), 0)
	b.global_position = Vector3(0.6, Ring.canvas_height(), 0)
	b.infinite_health = false
	b.health = 0.0
	b._go_down(30.0)
	await wait_physics_frames(2)
	a._start_paired("cover", b)
	var counts: Array[int] = []
	m.referee.counted.connect(func(n: int) -> void: counts.append(n))
	for i in 600:
		await wait_physics_frames(1)
		if m.winner:
			break
	assert_eq(counts, [1, 2, 3] as Array[int])
	assert_eq(m.winner, a)
	assert_eq(a.state, Wrestler.State.CELEBRATE)


func test_pin_near_ropes_is_broken() -> void:
	var a := m.wrestlers[0]
	var b := m.wrestlers[1]
	var edge := float(Ring.spec()["post_half"]) - Wrestler.ROPE_MARGIN
	b.global_position = Vector3(edge, Ring.canvas_height(), 0)
	b.rotation.y = -PI / 2      # head toward the ropes
	b.health = 0.0
	b.infinite_health = false
	b._go_down(30.0)
	a.global_position = Vector3(edge - 1.0, Ring.canvas_height(), 0)
	await wait_physics_frames(2)
	a._start_paired("cover", b)
	for i in 400:
		await wait_physics_frames(1)
		if b.state == Wrestler.State.KICKOUT or m.winner:
			break
	assert_null(m.winner, "no win from a pin under the ropes")
	assert_eq(b.state, Wrestler.State.KICKOUT)


func _wait_until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await wait_physics_frames(1)
	return cond.call()


## Pausing the match mid-entrance must freeze the walk in place (posing, aisle walk and
## ring entry), resume must continue it, and pause menu input must not skip it (issue #18).
func test_entrance_freezes_while_paused() -> void:
	# a real entrance: difficulty 0 CPUs are dummies (no entrance), and headless runs
	# start with entrances switched off
	GameState.match_entrants = [
		{"roster": 0, "control": "cpu", "slot": 0, "difficulty": 1},
		{"roster": 1, "control": "cpu", "slot": 1, "difficulty": 1},
	]
	var saved := Settings.entrances
	Settings.entrances = true
	var mm: Match = load("res://match/match.tscn").instantiate()
	add_child_autofree(mm)
	await wait_physics_frames(1)
	var w: Wrestler = mm.wrestlers[1]      # the challenger's side comes out first
	var p2: Wrestler = mm.wrestlers[0]
	var ent: Entrance = null
	for c in mm.get_children():
		if c is Entrance:
			ent = c
	assert_not_null(ent, "the match starts with an entrance")
	if ent == null:
		Settings.entrances = saved
		return
	# pose: pausing must not burn the pose timer (a 3 s pause is longer than it)
	assert_true(await _wait_until(func() -> bool: return w.global_position.y > 0.5, 240), "on stage")
	mm._toggle_pause()
	assert_true(get_tree().paused)
	await wait_physics_frames(180)
	assert_true(w.global_position.z <= -12.0, "the pose does not advance while paused: z=%.2f" % w.global_position.z)
	assert_false(ent._skipped, "pausing and the pause menu do not skip the entrance")
	mm._toggle_pause()
	# aisle walk: the walk stops exactly where it is and resumes afterwards
	assert_true(await _wait_until(func() -> bool: return w.global_position.z > -11.6, 900), "walking down")
	var p0: Vector3 = w.global_position
	mm._toggle_pause()
	await wait_physics_frames(120)
	assert_eq(w.global_position, p0, "the walk is frozen while paused")
	mm._toggle_pause()
	assert_true(await _wait_until(func() -> bool: return w.global_position != p0, 300), "the walk resumes")
	# ring entry: the roll-in holds and the next side stays backstage while paused
	assert_true(await _wait_until(func() -> bool: return w.state == Wrestler.State.ENTER_RING, 900), "rolling in")
	var q0: Vector3 = w.global_position
	mm._toggle_pause()
	await wait_physics_frames(150)
	assert_eq(w.state, Wrestler.State.ENTER_RING, "the roll-in holds while paused")
	assert_eq(w.global_position, q0, "the roll-in position is frozen while paused")
	assert_lt(p2.global_position.z, -15.0, "the next side is still backstage")
	mm._toggle_pause()
	assert_true(await _wait_until(func() -> bool: return w.state == Wrestler.State.IDLE, 600), "the roll-in finishes")
	assert_true(await _wait_until(func() -> bool: return not mm.intro, 1500), "the whole entrance finishes after the pauses")
	if get_tree().paused:
		mm._toggle_pause()
	Settings.entrances = saved


func test_referee_keeps_a_few_paces_from_the_action_anywhere() -> void:
	# he used to stand by the back rope and stay there when the wrestlers came to him
	var a := m.wrestlers[0]
	var b := m.wrestlers[1]
	var h := Ring.canvas_height()
	for spot in [Vector3(0, h, -2.0), Vector3(2.0, h, -2.0), Vector3(-2.0, h, 0.5), Vector3(0, h, 2.0), Vector3(0, h, 0)]:
		a.global_position = spot + Vector3(-0.5, 0, 0)
		b.global_position = spot + Vector3(0.5, 0, 0)
		await wait_physics_frames(300)
		for w in [a, b]:
			var d := Vector2(m.referee.global_position.x - w.global_position.x, m.referee.global_position.z - w.global_position.z).length()
			assert_gt(d, 1.8, "action at %s: ref %.1f m from %s" % [spot, d, w.display_name])
