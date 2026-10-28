extends Node
## Dev tool: stage environment situations for screenshots.
##   tools/screenshot.sh res://dev/env_shots.tscn out.png 90 --setup=chair|perch|table|outside|dive|finisher|reversal [--move=iron_drop]
##   tools/screenshot.sh res://dev/env_shots.tscn out.png 900 --setup=move --move=<id> [--at=SECONDS] [--cam=side|front|match]
##     performs any moveset move, finisher or taunt (see Movesets); --at pauses that long after the
##     move starts and takes the screenshot there. tools/move_sheet.sh makes a contact sheet of these.

class Hold:
	extends WrestlerController
	var hold_move := Vector3.ZERO
	var hold_run := false
	var press := ""

	func update(_w: Wrestler, _d: float) -> void:
		clear_one_shots()
		move = hold_move
		run_held = hold_run
		match press:
			"punch": punch = true
			"kick": kick = true
			"grapple": grapple = true
			"taunt": taunt = true
			"block": block_pressed = true
		press = ""

var m: Match
var _cam: Camera3D
var _cam_subjects: Array[Wrestler] = []
var _cam_side := 1.0


func _ready() -> void:
	GameState.rules = "nodq"
	Settings.entrances = DevTools.get_arg("setup", "") == "entrance"
	GameState.match_entrants = [
		{"roster": 0, "control": "cpu", "slot": 0, "difficulty": 0},
		{"roster": 2, "control": "cpu", "slot": 1, "difficulty": 0},
	]
	if Settings.entrances:
		for e in GameState.match_entrants:
			e["difficulty"] = 2
	var tag := DevTools.get_arg("setup", "chair").begins_with("tag") or DevTools.has_arg("tag")
	if tag:
		GameState.match_entrants.append({"roster": 1, "control": "cpu", "slot": 2, "difficulty": 0})
		GameState.match_entrants.append({"roster": 0, "control": "cpu", "slot": 3, "difficulty": 0})
	m = load("res://match/match.tscn").instantiate()
	add_child(m)
	await get_tree().physics_frame
	var a := m.wrestlers[0]
	var b := m.wrestlers[1]
	var ca := Hold.new()
	a.controller = ca
	b.controller = Hold.new()
	var y := Ring.canvas_height()
	var lim := float(Ring.spec()["post_half"]) - Wrestler.ROPE_MARGIN
	if DevTools.has_arg("chair_rot"):
		var r := DevTools.get_arg("chair_rot").split_floats(",")
		var t := DevTools.get_arg("chair_pos", "0,0,0").split_floats(",")
		Chair.hold_offset = Transform3D(Basis.from_euler(Vector3(deg_to_rad(r[0]), deg_to_rad(r[1]), deg_to_rad(r[2]))),
			Vector3(t[0], t[1], t[2]))
	match DevTools.get_arg("setup", "chair"):
		"chairhold":
			var chair := m.chairs[0]
			chair.global_position = Vector3(0.6, y + 0.05, 0.8)
			a.global_position = Vector3(0, y, 0.8)
			a.rotation.y = PI / 2
			b.global_position = Vector3(-2.0, y, -1.5)
			m.camera.targets = [a]
			await get_tree().create_timer(0.4).timeout
			ca.press = "grapple"
			await get_tree().create_timer(1.0).timeout
			a.rotation.y = 0.0
		"chair":
			var chair := m.chairs[0]
			a.global_position = chair.global_position + Vector3(0.5, 0, 0)
			b.global_position = chair.global_position + Vector3(1.8, 0, -0.4)
			a.outside = true
			b.outside = true
			a.rotation.y = -PI / 2
			b.rotation.y = PI / 2
			await get_tree().create_timer(0.3).timeout
			ca.press = "grapple"
			await get_tree().create_timer(1.0).timeout
			a.rotation.y = atan2(b.global_position.x - a.global_position.x, b.global_position.z - a.global_position.z)
			ca.press = "punch"
		"perch", "dive":
			var c := Ring.corner(3)
			a.global_position = Vector3(c.x - 0.6, y, c.z + 0.6)
			a.rotation.y = atan2(1, -1)
			b.global_position = Vector3(c.x - 2.2, y, c.z + 2.0)
			b._go_down(30.0)
			await get_tree().physics_frame
			ca.press = "grapple"
			if DevTools.get_arg("setup") == "dive":
				await get_tree().create_timer(1.6).timeout
				ca.press = "kick"
		"table":
			a.global_position = Vector3(lim - 1.2, y, 0)
			b.global_position = Vector3(lim - 0.3, y, 0)
			a.rotation.y = PI / 2
			b.rotation.y = -PI / 2
			await get_tree().physics_frame
			ca.press = "grapple"
			await get_tree().create_timer(0.2).timeout
			ca.hold_move = Vector3.RIGHT
			ca.hold_run = true
		"replay":
			Settings.replays = true
			a.global_position = Vector3(-0.4, y, 0.3)
			b.global_position = Vector3(0.4, y, 0.3)
			a.rotation.y = PI / 2
			b.rotation.y = -PI / 2
			b.health = 1.0
			b.infinite_health = false
			a.gain_momentum(Wrestler.MOMENTUM_MAX)
			await get_tree().physics_frame
			ca.press = "grapple"
			await get_tree().create_timer(0.3).timeout
			ca.press = "taunt"
			await get_tree().create_timer(2.6).timeout
			ca.press = "block"
		"finisher", "reversal":
			a.global_position = Vector3(-0.4, y, 0.3)
			b.global_position = Vector3(0.4, y, 0.3)
			a.rotation.y = PI / 2
			b.rotation.y = -PI / 2
			a.finisher = DevTools.get_arg("move", "thunder_bomb")
			a.gain_momentum(Wrestler.MOMENTUM_MAX)
			await get_tree().physics_frame
			ca.press = "grapple"
			await get_tree().create_timer(0.3).timeout
			ca.press = "taunt"
			if DevTools.get_arg("setup") == "reversal":
				await get_tree().create_timer(0.08).timeout
				(b.controller as Hold).press = "block"
		"tag":
			a.global_position = Vector3(-1.0, y, -1.2)
			b.global_position = Vector3(0.4, y, -0.6)
		"tagin":
			a.global_position = a.entry_spot() + Vector3(0.2, 0, 0.5)
			a.rotation.y = PI
			b.global_position = Vector3(0.8, y, 0.6)
			a.health = 35.0
			await get_tree().create_timer(0.3).timeout
			ca.press = "grapple"
		"tagdouble":
			var a2 := m.wrestlers[2]
			a2.controller = Hold.new()
			a.global_position = Vector3(-0.6, y, -0.5)
			b.global_position = Vector3(0.2, y, -0.5)
			a.rotation.y = PI / 2
			b.rotation.y = -PI / 2
			await get_tree().physics_frame
			ca.press = "grapple"
			await get_tree().create_timer(0.2).timeout
			a2._enter(Wrestler.State.IDLE)
			a2.global_position = Vector3(-0.2, y, 0.4)
			a2.rotation.y = PI
			await get_tree().physics_frame
			(a2.controller as Hold).press = "grapple"
		"entrance":
			pass
		"move":
			await _stage_move(a, b, ca, DevTools.get_arg("move", "body_slam"))
		"outside":
			a.global_position = Vector3(-1.0, y, lim - 0.2)
			a.rotation.y = 0
			b.global_position = Vector3(0.5, 0.05, Ring.canvas_half() + 1.2)
			b.outside = true
			ca.hold_move = Vector3.BACK


func _stage_move(a: Wrestler, b: Wrestler, ca: Hold, id: String) -> void:
	var y := Ring.canvas_height()
	var slot := Movesets.slot_of(id)
	if slot != "":
		a.moves[slot] = id
	if not Movesets.is_available(id):
		push_warning("env_shots: %s has no animation in this build" % id)
	a.global_position = Vector3(-0.45, y, -0.6)
	b.global_position = Vector3(0.45, y, -0.6)
	a.rotation.y = PI / 2
	b.rotation.y = -PI / 2
	_watch([a, b], DevTools.get_arg("cam", "side"))
	if DevTools.get_arg("cam", "side") != "match":
		m.hud.visible = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	match slot:
		"kick":
			a._start_strike(id)
		"running":
			a.global_position.x = -2.4
			b.global_position.x = 0.9
			a.rotation.y = PI / 2
			ca.hold_move = Vector3.RIGHT
			ca.hold_run = true
			for i in 240:
				await get_tree().physics_frame
				if a.global_position.x > b.global_position.x - 1.7:
					break
			ca.press = "punch"
			ca.hold_run = false
			ca.hold_move = Vector3.ZERO
			await get_tree().physics_frame
		"back_grapple":
			b.rotation.y = PI / 2       # facing away
			await get_tree().physics_frame
			a._start_paired(id, b)
		"ground_punch":
			b._go_down(30.0)
			await get_tree().create_timer(0.8).timeout
			a._start_paired(id, b)
		"dive_punch", "dive_kick":
			var c := Ring.corner(3)
			a.global_position = Vector3(c.x - 0.6, y, c.z + 0.6)
			a.rotation.y = atan2(1, -1)
			b.global_position = Vector3(c.x - 2.2, y, c.z + 2.0)
			b._go_down(30.0)
			await get_tree().physics_frame
			ca.press = "grapple"
			for i in 240:
				await get_tree().physics_frame
				if a.state == Wrestler.State.PERCH and a.state_time > 0.2:
					break
			ca.press = "punch"
			for i in 30:
				await get_tree().physics_frame
				if a.state == Wrestler.State.DIVE:
					break
		"taunt":
			a._enter(Wrestler.State.TAUNT)
		_:
			# tie-up moves and finishers (anything paired)
			a._start_tieup(b)
			await get_tree().create_timer(0.35).timeout
			a._start_paired(id, b)
	if DevTools.has_arg("at"):
		await get_tree().create_timer(float(DevTools.get_arg("at"))).timeout
		get_tree().paused = true
		DevTools.capture_soon()


## A fixed-height dev camera inside the ropes that keeps these wrestlers in view
## ("side": profile view, "front": from behind the defender, "match": the broadcast camera).
func _watch(subjects: Array[Wrestler], mode: String) -> void:
	if mode == "match":
		return
	_cam_subjects = subjects
	_cam_side = 1.0 if mode == "side" else -1.0
	_cam = Camera3D.new()
	_cam.fov = 62
	add_child(_cam)
	_cam.process_mode = Node.PROCESS_MODE_ALWAYS
	_update_cam(1.0)


func _process(delta: float) -> void:
	if _cam:
		_update_cam(minf(1.0, delta * 4.0))


func _update_cam(weight: float) -> void:
	var mid := Vector3.ZERO
	for w in _cam_subjects:
		mid += w.global_position
	mid /= maxf(1.0, _cam_subjects.size())
	var y := Ring.canvas_height()
	var target := Vector3(mid.x, y + 0.85, mid.z)
	var eye := target + (Vector3(0, 0.4, 3.0) if _cam_side > 0.0 else Vector3(3.0, 0.4, 0.0))
	# stay inside the ropes so they never block the view
	var lim := float(Ring.spec()["post_half"]) - 0.25
	eye.x = clampf(eye.x, -lim, lim)
	eye.z = clampf(eye.z, -lim, lim)
	var want := Transform3D(Basis.IDENTITY, eye).looking_at(target)
	_cam.global_transform = _cam.global_transform.interpolate_with(want, weight) if weight < 1.0 else want
	_cam.current = true

