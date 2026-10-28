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
