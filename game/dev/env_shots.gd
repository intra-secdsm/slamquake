extends Node
## Dev tool: stage environment situations for screenshots.
##   tools/screenshot.sh res://dev/env_shots.tscn out.png 90 --setup=chair|perch|table|outside|dive|finisher|reversal [--move=iron_drop]

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
		"outside":
			a.global_position = Vector3(-1.0, y, lim - 0.2)
			a.rotation.y = 0
			b.global_position = Vector3(0.5, 0.05, Ring.canvas_half() + 1.2)
			b.outside = true
			ca.hold_move = Vector3.BACK
