class_name Entrance
extends Node
## Ring entrances before the bell: each side in turn appears on the stage to their theme
## with pyro and their name on the titantron, walks down the ramp and the aisle, and
## rolls into the ring (a tag partner climbs up to wait on the apron). Any button skips.

signal finished

const WALK := 2.3
const POSE_TIME := 1.8

var match_node: Match
var _skipped := false
var _age := 0.0
var _centre: Node3D        # keeps the hard cam framing the ring, not just one wrestler


func run() -> void:
	var m := match_node
	var sides: Array = []
	for team in [1, 0]:          # the challenger's side comes out first
		var members := m.wrestlers.filter(func(w: Wrestler) -> bool: return w.team == team)
		sides.append(members)
	for w in m.wrestlers:
		w._enter(Wrestler.State.ENTRANCE)
		w.global_position = Vector3(0, -20, -20)         # backstage until it's their turn
	m.hud.show_bars(false)
	m.referee.wrestlers = []
	m.referee.global_position = Vector3(2.3, Ring.canvas_height(), -2.3)
	m.referee.rotation.y = PI * 0.75
	_centre = Node3D.new()
	add_child(_centre)
	_centre.position = Vector3(0, Ring.canvas_height(), 0.5)
	for members in sides:
		if _skipped:
			break
		await _side(members)
	_place_everyone()
	m.hud.show_bars(true)
	m.hud.name_card("", "")
	m.camera.follow(null)
	m.camera.targets.assign(m.wrestlers)
	m.referee.wrestlers = m.wrestlers
	finished.emit()


func _process(delta: float) -> void:
	_age += delta
	# ignore the first moment so the button that started the match doesn't also skip this
	if not _skipped and _age > 0.6 and _any_button():
		_skipped = true
		AudioDirector.play_music("", 0.4)


func _any_button() -> bool:
	for slot in InputRouter.SLOTS:
		if InputRouter.any_pressed(slot):
			return true
	return false


func _side(members: Array) -> void:
	var m := match_node
	var lead: Wrestler = members[0]
	var entry := Roster.get_entry(_roster_index(lead))
	var names := " & ".join(members.map(func(w: Wrestler) -> String: return w.display_name.to_upper()))
	var color: Color = entry.get("color", Color("ff2bd6"))
	m.arena.titantron.show_text(names, "", color, color.lerp(Color.WHITE, 0.4))
	m.hud.name_card(names, entry.get("tagline", "") if members.size() == 1 else "TAG TEAM")
	AudioDirector.play_music(entry.get("theme", "theme_thunder"), 0.3)
	var stage := Arena.stage_point()
	for i in members.size():
		var w: Wrestler = members[i]
		w.global_position = stage + Vector3((i - (members.size() - 1) * 0.5) * 1.2, 0, 0)
		w._face(Vector3.BACK, 0.0, true)
		w.entrance_pose(w.move_for("taunt"))
	m.camera.follow(lead)
	Pyro.fire(m, stage + Vector3(0, 0, 1.0), color)
	m.excite(0.5, 0.8)
	if await _wait(POSE_TIME):
		return
	# walk the path together, side by side
	var targets: Array[Array] = []
	for i in members.size():
		var w: Wrestler = members[i]
		var off := (i - (members.size() - 1) * 0.5) * 1.0
		var front := float(Ring.spec()["arena"]["stage_front"])
		var gap := float(Ring.spec()["barricade_half"])
		targets.append([
			Vector3(off, Arena.path_height(-front), -front + 0.2),
			Vector3(off * 0.8, 0, Arena.ramp_bottom().z),
			Vector3(off * 0.6, 0, -gap - 0.3),
			_floor_spot(w),
		])
	var leg := [0, 0]
	leg.resize(members.size())
	leg.fill(0)
	while true:
		var done := true
		for i in members.size():
			var w: Wrestler = members[i]
			if leg[i] >= targets[i].size():
				continue
			done = false
			var to: Vector3 = targets[i][leg[i]]
			if w.entrance_walk(to, WALK, get_process_delta_time()):
				leg[i] += 1
				if i == 0 and leg[i] == 3:
					# through the barricade: cut to the hard cam framing just this side
					m.camera.targets.assign(members + [_centre])
					m.camera.follow(null)
		if done:
			break
		if await _wait(0.0):
			return
	# into the ring (or onto the apron)
	for w: Wrestler in members:
		if w.legal or w.teammate == null:
			w._face(Vector3(0, 0, 1) if w.global_position.z < 0 else Vector3(0, 0, -1), 0.0, true)
			w.roll_in()
		else:
			w.climb_to_apron()
	if await _wait(1.4):
		return
	for w: Wrestler in members:
		if w.state == Wrestler.State.IDLE:
			w._enter(Wrestler.State.ENTRANCE)
			while not w.entrance_walk(_start_spot(w), WALK, get_process_delta_time()):
				if await _wait(0.0):
					return
			w._face(Vector3(-signf(w.global_position.x), 0, 0), 0.0, true)
			w.entrance_pose("idle")
	m.camera.follow(null)
	if await _wait(0.6):
		return


## Wait (seconds; 0 = one frame). Returns true if the entrances were skipped.
func _wait(seconds: float) -> bool:
	if seconds <= 0.0:
		await get_tree().process_frame
	else:
		var t := 0.0
		while t < seconds and not _skipped:
			await get_tree().process_frame
			t += get_process_delta_time()
	return _skipped


func _floor_spot(w: Wrestler) -> Vector3:
	var ph := float(Ring.spec()["post_half"])
	if w.teammate and not w.legal:
		return Vector3(w.apron_spot.x, 0, w.apron_spot.z - w._root_dist("enter_ring"))
	var x := -1.5 if w.team == 0 else 1.5
	return Vector3(x, 0, -(ph - Wrestler.ROPE_MARGIN + w._root_dist("enter_ring")))


func _start_spot(w: Wrestler) -> Vector3:
	var spot: Vector3 = Match.START_SPOTS[w.team % 2]
	return spot + Vector3.UP * Ring.canvas_height()


func _roster_index(w: Wrestler) -> int:
	return int(w.get_meta("roster", 0))


## Skipped (or done): everyone straight to their places.
func _place_everyone() -> void:
	for w in match_node.wrestlers:
		if w.teammate and not w.legal:
			w.global_position = w.apron_spot
			w._enter(Wrestler.State.APRON)
		else:
			w.global_position = _start_spot(w)
			w.rotation.y = atan2(-w.global_position.x, -w.global_position.z)
			w._set_solid(true)
			w._enter(Wrestler.State.IDLE)
		w.outside = false
