extends GutTest
## Arena, crowd, music, entrances and the instant replay.

var m: Match


func before_each() -> void:
	GameState.rules = "nodq"
	GameState.match_entrants = [
		{"roster": 0, "control": "cpu", "slot": 0, "difficulty": 2},
		{"roster": 2, "control": "cpu", "slot": 1, "difficulty": 2},
	]


func _start_match() -> void:
	m = load("res://match/match.tscn").instantiate()
	add_child_autofree(m)
	await wait_physics_frames(2)


func test_crowd_fills_the_stands() -> void:
	await _start_match()
	assert_gt(m.arena.crowd.fan_count, 1500)
	m.excite(0.5)
	assert_gt(m.arena.heat, 0.7)
	m.arena.heat = 2.0
	assert_eq(m.arena.heat, 1.0, "heat is clamped")


func test_low_graphics_drops_haze_and_ssao() -> void:
	await _start_match()
	var env: Environment = (m.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment).environment
	assert_true(env.volumetric_fog_enabled and env.ssao_enabled)
	Settings.high_quality = false
	Settings.apply()
	assert_false(env.volumetric_fog_enabled or env.ssao_enabled, "low quality turns them off at once")
	Settings.high_quality = true
	Settings.apply()
	assert_true(env.volumetric_fog_enabled and env.ssao_enabled)


func test_hit_effects_share_their_meshes() -> void:
	await _start_match()
	var a := HitFx.spawn(m, Vector3.ZERO, true)
	var b := HitFx.spawn(m, Vector3.ZERO, false)
	var mesh := func(fx: HitFx) -> Mesh: return (fx.get_child(0) as CPUParticles3D).mesh
	assert_same(mesh.call(a), mesh.call(b), "one spray mesh for every hit (new ones stalled the renderer)")
	assert_same(mesh.call(HitFx.dust(m, Vector3.ZERO)), mesh.call(HitFx.dust(m, Vector3.ZERO)))


func test_every_roster_theme_exists() -> void:
	for e in Roster.all():
		assert_true(ResourceLoader.exists("res://assets/audio/music/%s.wav" % e["theme"]), e["theme"])
	assert_true(ResourceLoader.exists("res://assets/audio/music/theme_menu.wav"))
	assert_true(ResourceLoader.exists("res://assets/audio/music/victory.wav"))


func test_entrances_end_with_everyone_in_place() -> void:
	GameState.match_entrants.append({"roster": 1, "control": "cpu", "slot": 2, "difficulty": 2, "team": 0})
	GameState.match_entrants.append({"roster": 0, "control": "cpu", "slot": 3, "difficulty": 2, "team": 1})
	Settings.entrances = true
	await _start_match()
	Settings.entrances = false
	assert_true(m.intro, "entrances are playing")
	assert_eq(m.wrestlers[0].state, Wrestler.State.ENTRANCE)
	var ent: Entrance = m.find_children("*", "Entrance", false, false)[0]
	watch_signals(ent)
	await wait_seconds(0.5)
	ent._skipped = true                   # same as a player pressing a button
	await wait_seconds(0.3)
	assert_signal_emitted(ent, "finished")
	assert_false(m.intro, "the match has started")
	for w in m.wrestlers:
		if w.legal:
			assert_eq(w.state, Wrestler.State.IDLE)
			assert_false(Ring.is_outside(w.global_position), "%s in the ring" % w.display_name)
		else:
			assert_eq(w.state, Wrestler.State.APRON)


func test_replay_records_and_restores() -> void:
	await _start_match()
	var w := m.wrestlers[0]
	# nobody moves on their own, so the opponent can't nudge w once the present is restored
	for x in m.wrestlers:
		x.controller = null
	await wait_physics_frames(30)
	m.replay.mark("test")
	var before := w.global_position
	await wait_physics_frames(30)
	w.global_position += Vector3(1.0, 0, 0)
	await wait_physics_frames(5)
	assert_between(m.replay.frames_since("test"), 34, 37)
	var end_pos := w.global_position
	m.replay.play(m.replay.frames_since("test") + 5, 20, [w, m.wrestlers[1]])
	await wait_physics_frames(3)
	assert_almost_eq(w.global_position.x, before.x, 0.3, "showing the past")
	await wait_for_signal(m.replay.done, 5.0)
	assert_almost_eq(w.global_position.x, end_pos.x, 0.01, "back to the present")
	assert_true(w.is_physics_processing())
