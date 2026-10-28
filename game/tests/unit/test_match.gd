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
