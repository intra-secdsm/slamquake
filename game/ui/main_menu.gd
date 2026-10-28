extends Node
## Title screen + quick match setup over a live 3D ring backdrop.
## Fully usable with keyboard or gamepad (up/down to move, left/right to change).

const MODES := ["1P vs CPU", "2P Versus", "Practice (vs Dummy)", "CPU vs CPU", "Tag Team (2v2)"]
const TAG := 4
const ROWS := 8

var _mode := 0
var _p1 := 0
var _p2 := 2
var _difficulty := 2
var _rules := 0
# tag team: team A slots 0-1, team B slots 2-3
var _picks := [0, 1, 2, 0]
var _humans := [true, false, false, false]
var _rows: Array[Button] = []


func _ready() -> void:
	var backdrop: Node = load("res://match/showcase.tscn").instantiate()
	add_child(backdrop)

	var layer := CanvasLayer.new()
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.0, 0.05, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(620, 0)
	box.position = Vector2(-310, -360)
	box.add_theme_constant_override("separation", 12)
	layer.add_child(box)

	var title := Label.new()
	title.text = "WRESTLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 120)
	title.add_theme_color_override("font_color", Color("ff2bd6"))
	title.add_theme_color_override("font_outline_color", Color("00e5ff"))
	title.add_theme_constant_override("outline_size", 14)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "working title · early playtest build"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color("ffd400"))
	box.add_child(sub)
	box.add_child(Control.new())

	for i in ROWS:
		var b := Button.new()
		b.add_theme_font_size_override("font_size", 30)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.gui_input.connect(_on_row_input.bind(i))
		b.pressed.connect(_on_row_pressed.bind(i))
		box.add_child(b)
		_rows.append(b)
	var start := Button.new()
	start.text = "★  START MATCH  ★"
	start.add_theme_font_size_override("font_size", 38)
	start.add_theme_color_override("font_color", Color("ffd400"))
	start.pressed.connect(_start)
	box.add_child(start)
	var quit := Button.new()
	quit.text = "Quit"
	quit.add_theme_font_size_override("font_size", 24)
	quit.pressed.connect(get_tree().quit)
	box.add_child(quit)

	var hint := Label.new()
	hint.text = "↑↓ select   ←→ change   Enter / A: start"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	box.add_child(hint)

	_mode = clampi(int(DevTools.get_arg("menu_mode", "0")), 0, MODES.size() - 1)   # dev: screenshot a mode
	_refresh()
	start.grab_focus()


func _refresh() -> void:
	for r in _rows:
		r.visible = true
		r.disabled = false
		r.focus_mode = Control.FOCUS_ALL
		r.remove_theme_font_size_override("font_size")
		r.add_theme_font_size_override("font_size", 30)
	_rows[0].text = "◀  Mode: %s  ▶" % MODES[_mode]
	if _mode == TAG:
		_refresh_tag()
		return
	_rows[6].visible = false
	_rows[7].visible = false
	var names := Roster.all().map(func(e: Dictionary) -> String: return e["name"])
	var p2_label := "P2" if _mode == 1 else "CPU"
	_rows[1].text = "◀  P1: %s  ▶" % names[_p1] if _mode != 3 else "◀  CPU 1: %s  ▶" % names[_p1]
	_rows[2].text = "◀  %s: %s  ▶" % [p2_label, names[_p2]]
	_rows[3].text = "◀  CPU Difficulty: %s  ▶" % GameState.DIFFICULTIES[_difficulty]
	_rows[3].disabled = _mode == 1 or _mode == 2
	_rows[4].text = "◀  Rules: %s  ▶" % GameState.RULES.values()[_rules]
	_rows[5].text = "Controls: gamepads 1–4, or keyboard (P1 WASD+JIKL, P2 arrows+numpad)"
	_rows[5].add_theme_font_size_override("font_size", 18)
	_rows[5].focus_mode = Control.FOCUS_NONE


func _refresh_tag() -> void:
	var names := Roster.all().map(func(e: Dictionary) -> String: return e["name"])
	var player := 0
	for i in 4:
		var who := "CPU"
		if _humans[i]:
			player += 1
			who = "P%d" % player
		_rows[1 + i].text = "◀  Team %s · %s: %s  ▶" % ["A" if i < 2 else "B", who, names[_picks[i]]]
		_rows[1 + i].add_theme_font_size_override("font_size", 26)
	_rows[5].text = "◀  CPU Difficulty: %s  ▶" % GameState.DIFFICULTIES[_difficulty]
	_rows[5].disabled = not _humans.has(false)
	_rows[6].text = "◀  Rules: %s  ▶" % GameState.RULES.values()[_rules]
	_rows[7].text = "←→ wrestler · Enter / A on a slot: Human ⇄ CPU · players get pads/keys in order"
	_rows[7].add_theme_font_size_override("font_size", 18)
	_rows[7].focus_mode = Control.FOCUS_NONE


func _on_row_input(event: InputEvent, row: int) -> void:
	var step := 0
	if event.is_action_pressed("ui_left"):
		step = -1
	elif event.is_action_pressed("ui_right"):
		step = 1
	if step == 0:
		return
	_change(row, step)
	get_viewport().set_input_as_handled()


func _on_row_pressed(row: int) -> void:
	if _mode == TAG and row >= 1 and row <= 4:
		_humans[row - 1] = not _humans[row - 1]
		_refresh()
		return
	_change(row, 1)


func _change(row: int, step: int) -> void:
	var n := Roster.all().size()
	if _mode == TAG and row > 0:
		match row:
			1, 2, 3, 4: _picks[row - 1] = wrapi(_picks[row - 1] + step, 0, n)
			5: _difficulty = wrapi(_difficulty + step, 1, GameState.DIFFICULTIES.size())
			6: _rules = wrapi(_rules + step, 0, GameState.RULES.size())
		_refresh()
		return
	match row:
		0: _mode = wrapi(_mode + step, 0, MODES.size())
		1: _p1 = wrapi(_p1 + step, 0, n)
		2: _p2 = wrapi(_p2 + step, 0, n)
		3: _difficulty = wrapi(_difficulty + step, 1, GameState.DIFFICULTIES.size())
		4: _rules = wrapi(_rules + step, 0, GameState.RULES.size())
	_refresh()


func _start() -> void:
	GameState.rules = GameState.RULES.keys()[_rules]
	if _mode == TAG:
		# HUD order: A1, B1, A2, B2 (left/right bars per team); humans take input slots in menu order
		var slots := {}
		var next := 0
		for i in 4:
			if _humans[i]:
				slots[i] = next
				next += 1
		GameState.match_entrants.clear()
		for i in [0, 2, 1, 3]:
			GameState.match_entrants.append({"roster": _picks[i], "control": "human" if _humans[i] else "cpu",
				"slot": slots.get(i, 0), "difficulty": _difficulty, "team": 0 if i < 2 else 1})
		get_tree().change_scene_to_file("res://match/match.tscn")
		return
	var human := "human"
	var cpu := "cpu"
	var p1 := {"roster": _p1, "control": human, "slot": 0, "difficulty": _difficulty}
	var p2 := {"roster": _p2, "control": cpu, "slot": 1, "difficulty": _difficulty}
	match _mode:
		1: p2["control"] = human
		2: p2["difficulty"] = 0
		3: p1["control"] = cpu
	GameState.match_entrants = [p1, p2]
	GameState.rules = GameState.RULES.keys()[_rules]
	get_tree().change_scene_to_file("res://match/match.tscn")
