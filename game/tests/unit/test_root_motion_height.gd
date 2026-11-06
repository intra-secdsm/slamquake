extends GutTest
## Issue #8: clips whose root motion encodes absolute arena heights (ring entry/exit,
## over-the-top falls, turnbuckle climbs, rope toss) must not have their vertical travel
## scaled by model height. The model owns per-instance copies of exactly those animations
## with corrected root-position Y keys, so every sampling path (playback, immediate and
## paused seeks, replay, dev tools) sees the corrected data. Horizontal travel and body
## proportions keep the usual height scaling; unselected clips are untouched.
##
## The reference below is a bare instantiation of the imported scene at scale 1: its
## AnimationPlayer serves the untouched source animations, and expected values are read
## from it, never from the corrected copies.

const HEIGHTS: Array[float] = [0.88, 1.0, 1.12]
## The six clips with absolute vertical root travel (see issue #8 and the manifest).
const SELECTED := ["exit_ring", "enter_ring", "fall_over_ropes", "climb_corner", "climb_down", "rope_toss_d"]
## Finisher clips with intermediate vertical root offsets that must keep height scaling.
const FINISHERS := ["supernova_a", "supernova_d", "quetzal_rana_a", "quetzal_rana_d", "system_crash_a", "system_crash_d"]
const TOL := 0.001

var ref: Node3D
var ref_ap: AnimationPlayer
var ref_sk: Skeleton3D
var ref_tracks: Dictionary = {}    # anim name -> root position track index in the source
var ref_root_ys: Dictionary = {}   # anim name -> [key Y values] in the untouched source


func before_each() -> void:
	ref = WrestlerModel.MODEL_SCENE.instantiate()
	add_child_autofree(ref)
	ref_ap = ref.find_child("AnimationPlayer", true, false) as AnimationPlayer
	ref_sk = ref.find_child("Skeleton3D", true, false) as Skeleton3D
	await wait_physics_frames(1)
	for name in SELECTED + FINISHERS + ["apron_enter", "apron_exit", "dive_moonsault", "dive_land"]:
		ref_tracks[name] = _root_position_track(ref_ap, ref_sk, ref_ap.get_animation(name))
		assert_gte(ref_tracks[name], 0, "source %s has a resolvable root position track" % name)
		var ys: Array = []
		var a: Animation = ref_ap.get_animation(name)
		var t: int = ref_tracks[name]
		for k in a.track_get_key_count(t):
			var v: Vector3 = a.track_get_key_value(t, k)
			ys.append(v.y)
		ref_root_ys[name] = ys


## A fresh visual model at the given height (the public look path, which re-applies the
## scale and the height correction together).
func _model_at(h: float) -> WrestlerModel:
	var m := WrestlerModel.new()
	add_child_autofree(m)
	var l := m.look.duplicate()
	l.height = h
	m.look = l
	await wait_physics_frames(1)
	return m


## All authored key times plus times between them and the clip end.
func _sample_times(name: String, length: float) -> Array[float]:
	var a: Animation = ref_ap.get_animation(name)
	var t: int = ref_tracks[name]
	var times: Array[float] = [0.0]
	for k in a.track_get_key_count(t) - 1:
		times.append(a.track_get_key_time(t, k))
		times.append(lerpf(a.track_get_key_time(t, k), a.track_get_key_time(t, k + 1), 0.5))
	times.append(a.track_get_key_time(t, a.track_get_key_count(t) - 1))
	times.append(length)
	return times


## Zero-blend playback plus immediate seeks; returns world-space root origins in order.
func _sample_world(ap: AnimationPlayer, sk: Skeleton3D, name: String, times: Array[float]) -> Array[Vector3]:
	ap.play(name, 0.0)
	await wait_physics_frames(1)
	var out: Array[Vector3] = []
	for t in times:
		ap.seek(t, true)
		out.append(_world_root(sk))
	return out


func _world_root(sk: Skeleton3D) -> Vector3:
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone("root")).origin


func _ref_root_y() -> float:
	return _world_root(ref_sk).y


## Waits (real mixer time) until the player's position reaches `target`, then returns the
## position and the world root Y of `sk`. On the pinned engine (4.7.2) the blend weight
## is driven by the mixer clock, not by seek positions, so blend behaviour must be
## observed in real time, never through seeks.
func _wait_until_pos(ap: AnimationPlayer, sk: Skeleton3D, target: float) -> Dictionary:
	var slack := 0.0
	while ap.current_animation_position < target and slack < target + 0.5:
		await wait_physics_frames(1)
		slack += 1.0 / 60.0
	return {"t": ap.current_animation_position, "y": _world_root(sk).y}


func _root_position_track(ap: AnimationPlayer, sk: Skeleton3D, a: Animation) -> int:
	# resolve by track type + the skeleton/bone target in the track path (never by number);
	# glTF-imported track node paths are relative to the player's parent (the model root)
	var rname: StringName = sk.get_bone_name(sk.find_bone("root"))
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		var path: String = a.track_get_path(t)
		var ci := path.rfind(":")
		if ci == -1 or path.substr(ci + 1) != rname:
			continue
		if ap.get_parent().get_node_or_null(path.substr(0, ci)) != sk:
			continue
		return t
	return -1


## The core contract: at every sampled time the visible root follows the authored absolute
## vertical travel (height-independent), while X/Z keep the height scaling.
func test_selected_clips_follow_absolute_vertical_travel() -> void:
	for h in HEIGHTS:
		var m := await _model_at(h)
		for name in SELECTED:
			var src_times := _sample_times(name, (m.anim_player.get_animation(name) as Animation).length)
			var ref_v: Array[Vector3] = await _sample_world(ref_ap, ref_sk, name, src_times)
			var got: Array[Vector3] = await _sample_world(m.anim_player, m.skeleton, name, src_times)
			for i in src_times.size():
				# vertical: absolute, equal to the height-1 source travel
				assert_almost_eq(got[i].y, ref_v[i].y, TOL,
					"h=%.2f %s t=%.3f root Y %.4f != authored %.4f" % [h, name, src_times[i], got[i].y, ref_v[i].y])
				# horizontal: unchanged, still scaled by the model height
				assert_almost_eq(got[i].x, ref_v[i].x * h, TOL, "h=%.2f %s t=%.3f X" % [h, name, src_times[i]])
				assert_almost_eq(got[i].z, ref_v[i].z * h, TOL, "h=%.2f %s t=%.3f Z" % [h, name, src_times[i]])


## The issue's acceptance sample made explicit: exit_ring authors -0.5 m of root Y at
## 0.8 s; every supported height must show exactly that.
func test_exit_ring_authored_sample_at_08s() -> void:
	var src: Animation = ref_ap.get_animation("exit_ring")
	var found := false
	var t: int = ref_tracks["exit_ring"]
	for k in src.track_get_key_count(t):
		if absf(src.track_get_key_time(t, k) - 0.8) < 0.001:
			var v: Vector3 = src.track_get_key_value(t, k)
			assert_almost_eq(v.y, -0.5, 0.001, "source authors -0.5 m at 0.8 s")
			found = true
	assert_true(found, "source has a key at 0.8 s")
	for h in [0.88, 1.12]:
		var m := await _model_at(h)
		m.anim_player.play("exit_ring", 0.0)
		await wait_physics_frames(1)
		m.anim_player.seek(0.8, true)
		assert_almost_eq(_world_root(m.skeleton).y, -0.5, TOL, "h=%.2f sees the authored -0.5 m" % h)


## The control: at height 1.0 the corrected data equals the source exactly, so default-
## height behaviour is bit-identical to the imported clips.
func test_default_height_matches_source_exactly() -> void:
	var m := await _model_at(1.0)
	for name in SELECTED:
		var times := _sample_times(name, (m.anim_player.get_animation(name) as Animation).length)
		var ref_v: Array[Vector3] = await _sample_world(ref_ap, ref_sk, name, times)
		var got: Array[Vector3] = await _sample_world(m.anim_player, m.skeleton, name, times)
		for i in times.size():
			for axis in ["x", "y", "z"]:
				assert_almost_eq(got[i][axis], ref_v[i][axis], 1e-4,
					"%s t=%.3f default-height %s differs from source" % [name, times[i], axis])


## Finisher clips carry intermediate vertical root offsets with a final root Y of zero.
## They are not selected: their motion must remain exactly height-scaled (body, root X/Z
## and root Y alike), so correcting by clip end-points would be wrong by design.
func test_unselected_finishers_keep_height_scaling() -> void:
	for h in [0.88, 1.12]:
		var m := await _model_at(h)
		for name in FINISHERS:
			var a: Animation = ref_ap.get_animation(name)
			var t: int = ref_tracks[name]
			# only times with real vertical root motion carry the contract
			var times: Array[float] = []
			for k in a.track_get_key_count(t):
				var v: Vector3 = a.track_get_key_value(t, k)
				if absf(v.y) > 0.05:
					times.append(a.track_get_key_time(t, k))
			if times.is_empty():
				continue
			var ref_v: Array[Vector3] = await _sample_world(ref_ap, ref_sk, name, times)
			var got: Array[Vector3] = await _sample_world(m.anim_player, m.skeleton, name, times)
			for i in times.size():
				for axis in ["x", "y", "z"]:
					var want: float = ref_v[i][axis] * h
					assert_almost_eq(got[i][axis], want, TOL,
						"h=%.2f %s t=%.3f %s must stay height-scaled (%.4f != %.4f)"
							% [h, name, times[i], axis, got[i][axis], want])
			# body proportions keep scaling too (a non-root bone, same time on both)
			ref_ap.seek(times[0], true)
			var chest_r: Vector3 = ref_sk.global_transform * ref_sk.get_bone_global_pose(ref_sk.find_bone("chest")).origin
			m.anim_player.seek(times[0], true)
			var chest_g: Vector3 = m.skeleton.global_transform * m.skeleton.get_bone_global_pose(m.skeleton.find_bone("chest")).origin
			assert_almost_eq(chest_g.y, chest_r.y * h, TOL, "h=%.2f %s chest keeps body scaling" % [h, name])


## Resource ownership: unselected animations stay shared read-only, the six selected ones
## are private per instance, meshes are never deep-copied, and the imported source is
## never mutated.
func test_animation_resources_are_instance_owned() -> void:
	var m1 := await _model_at(1.12)
	var m2 := await _model_at(0.88)
	for name in SELECTED:
		assert_ne(m1.anim_player.get_animation(name), m2.anim_player.get_animation(name),
			"%s: each instance owns a private copy" % name)
		assert_ne(m1.anim_player.get_animation(name), ref_ap.get_animation(name),
			"%s: the instance copy is not the shared source" % name)
	for name in ["idle", "walk", "run", "supernova_a"]:
		if ref_ap.has_animation(name):
			assert_eq(m1.anim_player.get_animation(name), ref_ap.get_animation(name),
				"%s: unselected animations remain shared" % name)
	assert_eq(m1.body.mesh, m2.body.mesh, "meshes are shared, not deep-copied")
	# the untouched source keeps its authored root values
	var t: int = ref_tracks["exit_ring"]
	var a: Animation = ref_ap.get_animation("exit_ring")
	for k in a.track_get_key_count(t):
		assert_almost_eq((a.track_get_key_value(t, k) as Vector3).y, ref_root_ys["exit_ring"][k], 1e-6,
			"source exit_ring key %d untouched" % k)


## Repeated height changes must recompute from the immutable source, never from the
## already-corrected values (no accumulated division).
func test_height_changes_recompute_without_accumulation() -> void:
	var m := await _model_at(0.88)
	m.anim_player.play("exit_ring", 0.0)
	await wait_physics_frames(1)
	for h in [1.12, 1.0, 0.88]:
		var l := m.look.duplicate()
		l.height = h
		m.look = l
		m.anim_player.seek(0.8, true)
		assert_almost_eq(_world_root(m.skeleton).y, -0.5, TOL,
			"h=%.2f still shows the authored -0.5 m after re-height" % h)
		# horizontal values come straight from the source, scaled once
		var src_z := float((ref_ap.get_animation("exit_ring").track_get_key_value(ref_tracks["exit_ring"], 23) as Vector3).z)
		assert_almost_eq(_world_root(m.skeleton).z, src_z * h, TOL, "h=%.2f X/Z scaled exactly once" % h)
	# and the key data itself never drifts from source / height
	var a: Animation = m.anim_player.get_animation("exit_ring")
	var t := _root_position_track(m.anim_player, m.skeleton, a)
	assert_gte(t, 0)
	var k: Vector3 = a.track_get_key_value(t, 23)
	assert_almost_eq(k.y, -0.5 / 0.88, 1e-4, "final key = source / height (no accumulation)")


## Nonfinite or nonpositive heights must not divide the keys: the last valid correction
## stays intact.
func test_invalid_height_keeps_last_valid_correction() -> void:
	var m := await _model_at(1.12)
	m.anim_player.play("exit_ring", 0.0)
	await wait_physics_frames(1)
	for bad in [0.0, -1.0, INF, NAN]:
		var l := m.look.duplicate()
		l.height = bad
		m.look = l
		m.anim_player.seek(0.8, true)
		if is_finite(bad):
			var y := _world_root(m.skeleton).y
			assert_true(is_finite(y), "h=%s left no NaN/Inf in the pose" % str(bad))
	# nonfinite heights are degenerate for the model scale itself; the contract here is
	# only that the correction never divides them into the animation data (the guard
	# reports the bad value with push_warning)
	var a: Animation = m.anim_player.get_animation("exit_ring")
	var t := _root_position_track(m.anim_player, m.skeleton, a)
	for k in a.track_get_key_count(t):
		var v: Vector3 = a.track_get_key_value(t, k)
		assert_true(is_finite(v.y), "key %d stays finite" % k)
		assert_almost_eq(v.y, ref_root_ys["exit_ring"][k] / 1.12, 1e-4,
			"key %d keeps the last valid (1.12) correction" % k)


## Immediate and paused seeks after a height change read the refreshed data and preserve
## the player's paused state.
func test_paused_and_immediate_seeks_after_height_change() -> void:
	var m := await _model_at(1.12)
	m.anim_player.play("exit_ring", 0.0)
	await wait_physics_frames(1)
	m.anim_player.seek(0.4, true)
	m.anim_player.pause()
	var l := m.look.duplicate()
	l.height = 0.88
	m.look = l
	m.anim_player.seek(0.6, true)
	assert_almost_eq(_world_root(m.skeleton).y, -0.028, 0.01, "paused seek sees corrected data")
	var frozen := m.anim_player.current_animation_position
	await wait_physics_frames(3)
	assert_almost_eq(m.anim_player.current_animation_position, frozen, 0.001, "pause state preserved")
	m.anim_player.seek(0.8, true)
	assert_almost_eq(_world_root(m.skeleton).y, -0.5, TOL, "further paused seek still exact")
	m.anim_player.play("exit_ring", 0.0)
	m.anim_player.seek(0.8, true)
	assert_almost_eq(_world_root(m.skeleton).y, -0.5, TOL, "replayed clip unaffected")


## While blending from idle into a selected clip, only the clip's contribution exists
## (idle's root is at rest), so the visible root Y is the blend weight times the authored
## absolute travel - never the height-scaled value.
func test_blend_from_idle_into_selected_clip() -> void:
	var m := await _model_at(1.12)
	var blend := 0.4
	m.anim_player.play("idle", 0.0)
	await wait_physics_frames(2)
	ref_ap.play("enter_ring", 0.0)
	await wait_physics_frames(1)
	m.anim_player.play("enter_ring", blend)
	for target in [0.1, 0.2, 0.3, 0.6]:
		var s := await _wait_until_pos(m.anim_player, m.skeleton, target)
		var t: float = s["t"]
		ref_ap.seek(t, true)
		var d := _ref_root_y()
		var w: float = minf(1.0, t / blend)
		var expected: float = w * d   # idle root rest is 0
		assert_almost_eq(float(s["y"]), expected, 0.03,
			"t=%.3f blend: root Y follows the authored absolute travel" % t)
	m.anim_player.stop()


## Blending a (height-scaled, unselected) finisher pose into a selected clip: at
## intermediate weights the finisher contribution keeps its original height scaling while
## the selected clip's contribution is absolute.
func test_blend_between_finisher_and_selected_clip() -> void:
	var h := 1.12
	var m := await _model_at(h)
	# park the model at a finisher pose with a sizeable vertical root offset
	var fsrc: Animation = ref_ap.get_animation("supernova_d")
	var ft: int = ref_tracks["supernova_d"]
	var best_t := 0.0
	var best_y := 0.0
	for k in fsrc.track_get_key_count(ft):
		var v: Vector3 = fsrc.track_get_key_value(ft, k)
		if absf(v.y) > absf(best_y):
			best_y = v.y
			best_t = fsrc.track_get_key_time(ft, k)
	assert_gt(absf(best_y), 0.3, "supernova_d has intermediate vertical root motion")
	m.anim_player.play("supernova_d", 0.0)
	await wait_physics_frames(2)
	m.anim_player.seek(best_t, true)
	var blend := 0.4
	m.anim_player.play("exit_ring", blend)
	# mid-blend in real time; capture the model's state before advancing any frames
	var s := await _wait_until_pos(m.anim_player, m.skeleton, blend * 0.5)
	var t: float = s["t"]
	# the old animation advanced by t from best_t during the blend; sample both source curves
	ref_ap.play("supernova_d", 0.0)
	await wait_physics_frames(1)
	ref_ap.seek(best_t + t, true)
	var d_f := _ref_root_y()
	ref_ap.play("exit_ring", 0.0)
	await wait_physics_frames(1)
	ref_ap.seek(t, true)
	var d_e := _ref_root_y()
	var w: float = minf(1.0, t / blend)
	var expected: float = (1.0 - w) * h * d_f + w * d_e
	assert_almost_eq(float(s["y"]), expected, 0.04,
		"finisher keeps height scaling, selected clip stays absolute (tolerance = 1-2 frames of old-anim travel)")


## Replay drives the player with speed_scale 0 plus repeated seeks (see replay.gd): every
## seek must land on the corrected absolute trajectory, forward and backward, with no
## accumulated correction, and normal playback must resume correctly.
func test_replay_style_seeking() -> void:
	for clip in ["exit_ring", "rope_toss_d"]:
		var h := 1.12
		var m := await _model_at(h)
		ref_ap.play(clip, 0.0)
		await wait_physics_frames(1)
		m.anim_player.play(clip, 0.0)
		await wait_physics_frames(1)
		m.anim_player.speed_scale = 0.0
		for t in [0.2, 0.8, 0.5, 1.0, 0.3, 0.9]:
			m.anim_player.seek(t, true)
			ref_ap.seek(t, true)
			var expected: Vector3 = ref_sk.global_transform * ref_sk.get_bone_global_pose(ref_sk.find_bone("root")).origin
			var got := _world_root(m.skeleton)
			assert_almost_eq(got.y, expected.y, TOL, "%s replay seek t=%.2f Y" % [clip, t])
			assert_almost_eq(got.x, expected.x * h, TOL, "%s replay seek t=%.2f X" % [clip, t])
			assert_almost_eq(got.z, expected.z * h, TOL, "%s replay seek t=%.2f Z" % [clip, t])
		# restore live playback (as replay does) and let it run past the end
		m.anim_player.speed_scale = 1.0
		m.anim_player.play(clip, 0.0)
		m.anim_player.seek(0.8, true)
		for i in 60:
			await wait_physics_frames(1)
		ref_ap.play(clip, 0.0)
		await wait_physics_frames(1)
		ref_ap.seek((ref_ap.get_animation(clip) as Animation).length, true)
		var expected_y: float = (ref_sk.global_transform * ref_sk.get_bone_global_pose(ref_sk.find_bone("root"))).origin.y
		assert_almost_eq(_world_root(m.skeleton).y, expected_y, 0.01,
			"%s live playback after restored replay pose holds the end pose" % clip)


## A height change mid-blend must not leave a discontinuity: the visible root Y is
## absolute before, during and after the change, and returning to 1.0 restores the
## original data exactly.
func test_height_change_during_blend() -> void:
	var m := await _model_at(1.12)
	m.anim_player.play("idle", 0.0)
	await wait_physics_frames(2)
	var blend := 0.8
	m.anim_player.play("enter_ring", blend)
	await wait_physics_frames(20)   # mid-blend, where the climb is well under way
	var l := m.look.duplicate()
	l.height = 0.88
	m.look = l
	await wait_physics_frames(2)
	ref_ap.play("enter_ring", 0.0)
	await wait_physics_frames(1)
	var t: float = m.anim_player.current_animation_position
	ref_ap.seek(t, true)
	var d: float = (ref_sk.global_transform * ref_sk.get_bone_global_pose(ref_sk.find_bone("root"))).origin.y
	assert_gt(d, 0.1, "sampled a nontrivial climb height")
	var w: float = minf(1.0, t / blend)
	assert_almost_eq(_world_root(m.skeleton).y, w * d, 0.02, "post-change mid-blend stays absolute")
	for i in 40:
		await wait_physics_frames(1)
	l = m.look.duplicate()
	l.height = 1.0
	m.look = l
	# the pose must refresh immediately from the new data (no extra frame needed)
	var t2: float = m.anim_player.current_animation_position
	ref_ap.seek(t2, true)
	var d2 := _ref_root_y()
	assert_almost_eq(_world_root(m.skeleton).y, d2, 0.01, "back at 1.0 the pose equals the source, immediately")


## Rapid consecutive environmental actions (each blending into the next) must keep the
## absolute contract throughout: a corrected model and the unmodified reference, driven
## through the identical play sequence, show the same world root Y at all times -
## through the blend-in, mid-clip and the held end pose - because the blend structure
## is identical on both sides and only the key data differs (corrected vs source).
func test_rapid_consecutive_environmental_actions() -> void:
	var m := await _model_at(1.12)
	var clips := ["exit_ring", "enter_ring", "exit_ring"]
	var blend := 0.15
	m.anim_player.play("idle", 0.0)
	ref_ap.play("idle", 0.0)
	await wait_physics_frames(2)
	for clip in clips:
		# both players start the same blend on the same frame
		m.anim_player.play(clip, blend)
		ref_ap.play(clip, blend)
		var length: float = (m.anim_player.get_animation(clip) as Animation).length
		var done := false
		var frame := 0
		while not done:
			await wait_physics_frames(1)
			frame += 1
			if frame in [3, 5, 7, 9, 20]:   # across the 0.15s blend-in and mid-clip
				var my: float = _world_root(m.skeleton).y
				var ry: float = _ref_root_y()
				assert_lte(absf(my - ry), 0.02,
					"%s frame %d: corrected model matches the unmodified reference" % [clip, frame])
			done = m.anim_player.current_animation_position >= length - 1.0 / 60.0
		await wait_physics_frames(4)   # both now hold their end pose
		assert_lte(absf(_world_root(m.skeleton).y - _ref_root_y()), 0.01,
			"%s: held end pose matches the reference" % clip)
	m.anim_player.play("idle", 0.0)
	m.anim_player.seek(0.5, true)
	assert_almost_eq(_world_root(m.skeleton).y, 0.0, 0.02, "idle after the flurry holds the rest root")


## Apron and dive clips are node-driven or ground-level: their root motion keeps the
## ordinary height scaling (they are not selected).
func test_apron_and_dive_clips_keep_height_scaling() -> void:
	var h := 1.12
	var m := await _model_at(h)
	for name in ["apron_enter", "apron_exit", "dive_moonsault", "dive_land"]:
		if not m.anim_player.has_animation(name):
			continue
		var times := _sample_times(name, (m.anim_player.get_animation(name) as Animation).length)
		var ref_v: Array[Vector3] = await _sample_world(ref_ap, ref_sk, name, times)
		var got: Array[Vector3] = await _sample_world(m.anim_player, m.skeleton, name, times)
		for i in times.size():
			for axis in ["x", "y", "z"]:
				assert_almost_eq(got[i][axis], ref_v[i][axis] * h, TOL,
					"%s t=%.3f %s keeps height scaling" % [name, times[i], axis])


## States after a selected clip (idle, perch, down) hold the root at rest and the model
## node keeps its baseline position: nothing to clear, no residual offset.
func test_post_clip_states_leave_no_residual() -> void:
	var m := await _model_at(1.12)
	var baseline := m._model.position
	for name in ["idle", "perch", "down"]:
		if m.anim_player.has_animation(name):
			m.anim_player.play(name, 0.0)
			await wait_physics_frames(1)
			m.anim_player.play(name, 0.0)
			m.anim_player.seek((m.anim_player.get_animation(name) as Animation).length * 0.5, true)
			await wait_physics_frames(1)
			assert_almost_eq(_world_root(m.skeleton).y, 0.0, 0.02,
				"%s holds the root at rest" % name)
			assert_eq(m._model.position, baseline, "%s leaves the model node at baseline" % name)
	var l := m.look.duplicate()
	l.height = 0.88
	m.look = l
	m.anim_player.play("idle", 0.0)
	m.anim_player.seek(0.5, true)
	assert_almost_eq(_world_root(m.skeleton).y, 0.0, 0.02, "height change in idle leaves no offset")
	assert_eq(m._model.position, baseline)
