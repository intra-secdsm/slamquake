extends GutTest
## Issue #8: a wrestler's height scales the body and horizontal root travel, but a clip that moves
## between arena levels (floor, apron, turnbuckle) travels the same height for everybody.
## Expected values come from the untouched imported clips, never from the model's edited copies.

const S := Wrestler.State
const HEIGHTS := [0.88, 1.0, 1.12]   # the WrestlerLook.height limits and the default
const LEVEL_CLIPS := ["exit_ring", "enter_ring", "fall_over_ropes", "rope_toss_d", "climb_corner", "climb_down"]
# these lift the root mid-move but end where they started: they keep scaling with the body
const BODY_CLIPS := ["quetzal_rana_a", "quetzal_rana_d", "supernova_d", "system_crash_d", "idle"]
const ROOT_TRACK := NodePath("Armature/Skeleton3D:root")
const TOL := 0.001


func _model(height: float) -> WrestlerModel:
	var m := WrestlerModel.new()
	var l := WrestlerLook.new()
	l.height = height
	m.look = l
	add_child_autofree(m)
	return m


## The imported clip every wrestler shares (the scene's own library, not a model's copy).
func _source(anim_name: String) -> Animation:
	var scene: Node = WrestlerModel.MODEL_SCENE.instantiate()
	var ap: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
	var a := ap.get_animation(anim_name)
	scene.free()
	return a


func _source_root(anim_name: String, time: float) -> Vector3:
	var a := _source(anim_name)
	return a.position_track_interpolate(a.find_track(ROOT_TRACK, Animation.TYPE_POSITION_3D), time)


## Where the root bone is drawn, in the WrestlerModel's own space, at `time` into the clip.
func _drawn_root(m: WrestlerModel, anim_name: String, time: float) -> Vector3:
	m.anim_player.play(anim_name, 0.0)
	m.anim_player.seek(time, true)
	var root := m.skeleton.find_bone("root")
	return m.global_transform.affine_inverse() * (m.skeleton.global_transform * m.skeleton.get_bone_global_pose(root).origin)


func _sample_times(anim_name: String) -> Array[float]:
	var length := _source(anim_name).length
	var times: Array[float] = []
	var t := 0.0
	while t < length:
		times.append(t)
		t += 0.05
	times.append(length)
	return times


func _assert_root(m: WrestlerModel, anim_name: String, absolute_y: bool) -> void:
	var h := m.look.height
	var worst := 0.0
	for t in _sample_times(anim_name):
		var src := _source_root(anim_name, t)
		var want := Vector3(src.x * h, src.y if absolute_y else src.y * h, src.z * h)
		worst = maxf(worst, (_drawn_root(m, anim_name, t) - want).length())
	assert_lt(worst, TOL, "%s at height %.2f: worst root error %.4f m" % [anim_name, h, worst])


func test_level_clips_travel_the_authored_height_at_every_body_height() -> void:
	for h in HEIGHTS:
		var m := _model(h)
		for anim_name in LEVEL_CLIPS:
			_assert_root(m, anim_name, true)


func test_lifts_and_carries_still_scale_with_the_body() -> void:
	for h in HEIGHTS:
		var m := _model(h)
		for anim_name in BODY_CLIPS:
			_assert_root(m, anim_name, false)


func test_only_the_level_clips_get_their_own_copies() -> void:
	var m := _model(1.12)
	for anim_name in m.anim_player.get_animation_list():
		var mine := m.anim_player.get_animation(anim_name)
		if mine != _source(anim_name):
			assert_has(LEVEL_CLIPS, String(anim_name), "only level clips are copied: " + anim_name)
	assert_eq(m._absolute_root.size(), LEVEL_CLIPS.size(), "one copy per level clip")


func test_rolling_out_is_half_a_metre_down_at_0_8_s() -> void:
	# exit_ring is keyed at -0.5 m at 0.8 s; endpoints alone wouldn't catch a mid-clip error
	for h in [0.88, 1.12]:
		assert_almost_eq(_drawn_root(_model(h), "exit_ring", 0.8).y, -0.5, TOL, "height %.2f" % h)


func test_wrestlers_do_not_share_corrected_clips() -> void:
	var short := _model(0.88)
	var tall := _model(1.12)
	var src_end := _source_root("exit_ring", _source("exit_ring").length)
	var later := _model(1.0)
	for m in [short, tall, later]:
		_assert_root(m, "exit_ring", true)
	assert_almost_eq(src_end.y, -1.15, TOL, "imported clip untouched")


func test_height_changes_do_not_accumulate() -> void:
	var m := _model(1.0)
	for h in [0.88, 1.12, 1.0, 0.88]:
		m.look.height = h
		m.apply_look()
		_assert_root(m, "climb_corner", true)


# ---------------------------------------------------------------- in a match

func _match_wrestler(height: float) -> Array:
	GameState.rules = "normal"
	GameState.match_entrants = [
		{"roster": 0, "control": "cpu", "slot": 0, "difficulty": 0},
		{"roster": 1, "control": "cpu", "slot": 1, "difficulty": 0},
	]
	var m: Match = load("res://match/match.tscn").instantiate()
	add_child(m)   # freed by the test before the next match, so two rings never overlap
	for x in m.wrestlers:
		x.controller = WrestlerController.new()
	var w: Wrestler = m.wrestlers[0]
	var l: WrestlerLook = w.model.look.duplicate()
	l.height = height
	w.model.look = l
	return [m, w]


func _drawn_root_y(w: Wrestler) -> float:
	var sk := w.model.skeleton
	return (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("root")).origin).y


func test_rolling_out_in_a_match_lands_without_a_height_snap() -> void:
	var lim := float(Ring.spec()["post_half"]) - Wrestler.ROPE_MARGIN
	for h in HEIGHTS:
		var mw := _match_wrestler(h)
		var w: Wrestler = mw[1]
		w.global_position = Vector3(lim, Ring.canvas_height(), 0.3)
		w.rotation.y = PI / 2.0   # facing the +x ropes
		await wait_physics_frames(3)
		var start_y := w.global_position.y
		w._start_root_anim(S.EXIT_RING, "exit_ring")
		# while rolling out, the drawn root follows the authored drop from where the clip started
		var worst := 0.0
		var last_y := start_y
		while w.state == S.EXIT_RING:
			await wait_process_frames(1)
			var ap := w.model.anim_player
			if w.state == S.EXIT_RING and ap.current_animation == "exit_ring":
				var want := start_y + _source_root("exit_ring", ap.current_animation_position).y
				worst = maxf(worst, absf(_drawn_root_y(w) - want))
				last_y = _drawn_root_y(w)
		# ...and the move to the floor afterwards doesn't make the body jump
		var landed_y := _drawn_root_y(w)
		assert_lt(worst, TOL, "height %.2f: worst drawn-root error while rolling out %.4f m" % [h, worst])
		assert_almost_eq(landed_y, last_y, 0.01, "height %.2f: no snap when placed on the floor" % h)
		assert_true(w.outside, "height %.2f landed outside" % h)
		mw[0].free()
		await wait_physics_frames(2)
