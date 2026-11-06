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


func test_invalid_heights_keep_the_last_valid_correction() -> void:
	var m := _model(1.12)
	for bad in [0.0, -1.0, INF, NAN]:
		m.look.height = bad
		m.apply_look()
		assert_eq(m._absolute_root_height, 1.12, "height %s is ignored" % bad)
		for c in m._absolute_root:
			var a: Animation = c["anim"]
			for k in a.track_get_key_count(c["track"]):
				assert_true(a.track_get_key_value(c["track"], k).is_finite(), "height %s: finite keys" % bad)
	m.look.height = 1.12   # a no-op for the clips: they must still hold the 1.12 correction
	m.apply_look()
	_assert_root(m, "exit_ring", true)


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


# ------------------------------------------- blends and replay (adapted from PR #11)

## A bare instance of the imported scene: plays the untouched clips at scale 1, in real time.
func _reference() -> Node3D:
	var r: Node3D = WrestlerModel.MODEL_SCENE.instantiate()
	add_child_autofree(r)
	return r


func _ref_ap(r: Node3D) -> AnimationPlayer:
	return r.find_child("AnimationPlayer", true, false)


func _ref_root(r: Node3D) -> Vector3:
	var sk: Skeleton3D = r.find_child("Skeleton3D", true, false)
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone("root")).origin


func _root_y(m: WrestlerModel) -> float:
	return (m.skeleton.global_transform * m.skeleton.get_bone_global_pose(m.skeleton.find_bone("root")).origin).y


## Blend weight is driven by the mixer clock, not by seeks, so blends are observed in real time.
func _wait_until_pos(ap: AnimationPlayer, target: float) -> float:
	for i in 120:
		if ap.current_animation_position >= target:
			break
		await wait_physics_frames(1)
	return ap.current_animation_position


func test_blending_from_idle_into_a_level_clip_stays_absolute() -> void:
	var m := _model(1.12)
	var blend := 0.4
	m.anim_player.play("idle", 0.0)
	await wait_physics_frames(2)
	m.anim_player.play("enter_ring", blend)
	for target in [0.1, 0.2, 0.3, 0.6]:
		var t := await _wait_until_pos(m.anim_player, target)
		var y := _root_y(m)
		var w := minf(1.0, t / blend)   # idle's root is at rest, so only the clip contributes
		assert_almost_eq(y, w * _source_root("enter_ring", t).y, 0.03, "t=%.3f mid-blend" % t)


func test_blending_from_a_finisher_keeps_its_part_scaled() -> void:
	var h := 1.12
	var m := _model(h)
	# park on the highest point of supernova_d's root
	var src := _source("supernova_d")
	var track := src.find_track(ROOT_TRACK, Animation.TYPE_POSITION_3D)
	var best_t := 0.0
	var best_y := 0.0
	for k in src.track_get_key_count(track):
		var y: float = src.track_get_key_value(track, k).y
		if absf(y) > absf(best_y):
			best_y = y
			best_t = src.track_get_key_time(track, k)
	assert_gt(absf(best_y), 0.3, "supernova_d lifts the root")
	m.anim_player.play("supernova_d", 0.0)
	await wait_physics_frames(2)
	m.anim_player.seek(best_t, true)
	var blend := 0.4
	m.anim_player.play("exit_ring", blend)
	var t := await _wait_until_pos(m.anim_player, blend * 0.5)
	var w := minf(1.0, t / blend)
	var want := (1.0 - w) * h * _source_root("supernova_d", best_t + t).y + w * _source_root("exit_ring", t).y
	assert_almost_eq(_root_y(m), want, 0.04, "finisher part scaled, level clip absolute")


func test_replay_style_seeking_lands_on_the_absolute_curve() -> void:
	# replay.gd freezes the player (speed_scale 0) and seeks back and forth
	var h := 1.12
	for anim_name in ["exit_ring", "rope_toss_d"]:
		var m := _model(h)
		m.anim_player.play(anim_name, 0.0)
		await wait_physics_frames(1)
		m.anim_player.speed_scale = 0.0
		for t in [0.2, 0.8, 0.5, 1.0, 0.3, 0.9]:
			m.anim_player.seek(t, true)
			var src := _source_root(anim_name, t)
			var got := m.global_transform.affine_inverse() * (m.skeleton.global_transform * m.skeleton.get_bone_global_pose(m.skeleton.find_bone("root")).origin)
			assert_lt((got - Vector3(src.x * h, src.y, src.z * h)).length(), TOL, "%s seek %.1f" % [anim_name, t])
		# back to live playback, run past the end: holds the absolute end pose
		m.anim_player.speed_scale = 1.0
		m.anim_player.play(anim_name, 0.0)
		m.anim_player.seek(0.8, true)
		await wait_physics_frames(60)
		var length := _source(anim_name).length
		assert_almost_eq(_root_y(m), _source_root(anim_name, length).y, 0.01, "%s holds its end pose" % anim_name)


func test_back_to_back_level_clips_match_the_untouched_clips() -> void:
	# a corrected model and a bare reference, driven through the same blends on the same frames
	var m := _model(1.12)
	var r := _reference()
	var rap := _ref_ap(r)
	m.anim_player.play("idle", 0.0)
	rap.play("idle", 0.0)
	await wait_physics_frames(2)
	for anim_name in ["exit_ring", "enter_ring", "exit_ring"]:
		m.anim_player.play(anim_name, 0.15)
		rap.play(anim_name, 0.15)
		var length := _source(anim_name).length
		var frame := 0
		while m.anim_player.current_animation_position < length - 1.0 / 60.0:
			await wait_physics_frames(1)
			frame += 1
			if frame in [3, 5, 7, 9, 20]:   # through the blend-in and mid-clip
				assert_almost_eq(_root_y(m), _ref_root(r).y, 0.02, "%s frame %d" % [anim_name, frame])
		await wait_physics_frames(4)
		assert_almost_eq(_root_y(m), _ref_root(r).y, 0.01, "%s end pose" % anim_name)
