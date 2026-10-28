extends Node
## Front end over the live arena: a title screen ("PRESS START"), the match setup panel
## with the chosen wrestlers standing in the ring beside it, and an options screen.
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
var _stage: MenuStage
var _title_screen: Control
var _setup: Control
var _options: Control
var _opt_rows: Array[Button] = []
var _start_button: Button
var _caw: CawEditor
var _pick_info: Label


func _ready() -> void:
	_stage = MenuStage.new()
	add_child(_stage)
	add_child(CrtOverlay.new())
	AudioDirector.play_music("theme_menu", 1.0, true, AudioDirector.MENU_DB)
	AudioDirector.crowd_ambience(true)
	AudioDirector.set_crowd(0.35)

	var layer := CanvasLayer.new()
	add_child(layer)
	_title_screen = _build_title()
	layer.add_child(_title_screen)
	_setup = Control.new()
	_setup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_setup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup.visible = false
	layer.add_child(_setup)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.0, 0.06, 0.78)
	shade.position = Vector2(40, 40)
	shade.size = Vector2(760, 1000)
	_setup.add_child(shade)

	var box := VBoxContainer.new()
	box.position = Vector2(80, 60)
	box.custom_minimum_size = Vector2(680, 0)
	box.add_theme_constant_override("separation", 12)
	_setup.add_child(box)

	box.add_child(_logo(100, 36))
	box.add_child(Control.new())

	for i in ROWS:
		var b := Button.new()
		b.add_theme_font_size_override("font_size", 30)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		ArrowClick.track(b)
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
	_start_button = start
	var career := Button.new()
	career.text = "★  CAREER  ★"
	career.add_theme_font_size_override("font_size", 30)
	career.add_theme_color_override("font_color", Color("00e5ff"))
	career.pressed.connect(_show_career)
	box.add_child(career)
	var caw := Button.new()
	caw.text = "Create-a-Wrestler"
	caw.add_theme_font_size_override("font_size", 24)
	caw.pressed.connect(_show_caw)
	box.add_child(caw)
	var opts := Button.new()
	opts.text = "Options"
	opts.add_theme_font_size_override("font_size", 24)
	opts.pressed.connect(_show_options)
	box.add_child(opts)
	var quit := Button.new()
	quit.text = "Quit"
	quit.add_theme_font_size_override("font_size", 24)
	quit.pressed.connect(get_tree().quit)
	box.add_child(quit)

	_pick_info = Label.new()
	_pick_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pick_info.add_theme_font_size_override("font_size", 20)
	_pick_info.add_theme_color_override("font_color", Color("ffd400"))
	_pick_info.custom_minimum_size = Vector2(680, 30)
	box.add_child(_pick_info)
	var hint := Label.new()
	hint.text = "↑↓ select   ←→ change   Enter / A: start"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	box.add_child(hint)

	_options = _build_options()
	layer.add_child(_options)
	_caw = CawEditor.new()
	_caw.stage = _stage
	layer.add_child(_caw)
	_caw.closed.connect(_on_caw_closed)
	for i in ROWS:
		_rows[i].focus_entered.connect(_show_pick_info.bind(i))
	_mode = clampi(int(DevTools.get_arg("menu_mode", "0")), 0, MODES.size() - 1)   # dev: screenshot a mode
	_refresh()
	if DevTools.has_arg("menu_mode"):
		_show_setup()
	elif DevTools.get_arg("menu", "") == "options":
		_show_options()
	elif DevTools.get_arg("menu", "") == "caw":          # dev: --menu=caw [--caw_tab=N --caw_row=N --caw_name]
		_show_caw()
		if DevTools.has_arg("caw_tab"):
			_caw._copy_roster()
			_caw._set_tab(int(DevTools.get_arg("caw_tab")))
			if DevTools.has_arg("caw_row"):               # dev: --caw_row=N  focus row N
				_caw._focus_row(int(DevTools.get_arg("caw_row")))
			if DevTools.has_arg("caw_name"):              # dev: --caw_name  open the name entry
				_caw._on_row_pressed(0)


func _unhandled_input(event: InputEvent) -> void:
	if _title_screen.visible and (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		AudioDirector.play("bell", Vector3.ZERO, -10.0)
		_show_setup()
		get_viewport().set_input_as_handled()
	elif _options.visible and event.is_action_pressed("ui_cancel"):
		_close_options()
		get_viewport().set_input_as_handled()


func _show_caw() -> void:
	_title_screen.visible = false
	_setup.visible = false
	_options.visible = false
	_caw.open()


func _on_caw_closed() -> void:
	# created wrestlers may have come or gone: keep every pick in range
	var n := Roster.all().size()
	_p1 = mini(_p1, n - 1)
	_p2 = mini(_p2, n - 1)
	for i in _picks.size():
		_picks[i] = mini(_picks[i], n - 1)
	_refresh()
	_show_setup()


## Under the rows: who the focused pick is (nickname, finisher), so 8+ wrestlers are easy to tell apart.
func _show_pick_info(row: int) -> void:
	var pick := -1
	if _mode == TAG and row >= 1 and row <= 4:
		pick = _picks[row - 1]
	elif _mode != TAG and (row == 1 or row == 2):
		pick = _p1 if row == 1 else _p2
	if pick < 0:
		_pick_info.text = ""
		return
	var e := Roster.get_entry(pick)
	var fin := Movesets.move_name(Movesets.resolve(e.get("moves", {}))["finisher"])
	_pick_info.text = "%s%s  ·  Finisher: %s" % [e.get("tagline", ""), "  ·  CREATED" if e.get("caw", false) else "",
		fin]


func _show_setup() -> void:
	_title_screen.visible = false
	_options.visible = false
	_caw.visible = false
	_setup.visible = true
	_start_button.grab_focus()


## The game's logo: chrome SLAMQUAKE! over a hot yellow subtitle, as on the box art.
func _logo(size: int, sub_size: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -int(size * 0.12))
	var title := Label.new()
	title.text = "SLAMQUAKE!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", size)
	title.add_theme_color_override("font_color", Color("eef2ff"))
	title.add_theme_color_override("font_outline_color", Color("ff2bd6"))
	title.add_theme_constant_override("outline_size", maxi(8, size / 9))
	title.add_theme_color_override("font_shadow_color", Color("3a0a6e"))
	title.add_theme_constant_override("shadow_offset_x", size / 30)
	title.add_theme_constant_override("shadow_offset_y", size / 14)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "SUPLEX SPECTACULAR!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", sub_size)
	sub.add_theme_color_override("font_color", Color("ffd400"))
	sub.add_theme_color_override("font_outline_color", Color("ff4a00"))
	sub.add_theme_constant_override("outline_size", maxi(6, sub_size / 6))
	sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	sub.add_theme_constant_override("shadow_offset_y", sub_size / 10)
	box.add_child(sub)
	return box


func _build_title() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var logo := _logo(220, 84)
	logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	logo.position = Vector2(-800, 150)
	logo.size = Vector2(1600, 340)
	root.add_child(logo)
	var tag := Label.new()
	tag.text = "BIG MUSCLES.  BIGGER EGOS.  EARTH-SHATTERING SLAMS."
	tag.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tag.position = Vector2(-700, 570)
	tag.size = Vector2(1400, 60)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 40)
	tag.add_theme_color_override("font_color", Color("ffd400"))
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	tag.add_theme_constant_override("outline_size", 8)
	root.add_child(tag)
	var press := Label.new()
	press.text = "PRESS START"
	press.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	press.position = Vector2(-500, -260)
	press.size = Vector2(1000, 80)
	press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	press.add_theme_font_size_override("font_size", 64)
	press.add_theme_color_override("font_color", Color.WHITE)
	press.add_theme_color_override("font_outline_color", Color("ff2bd6"))
	press.add_theme_constant_override("outline_size", 12)
	root.add_child(press)
	var tw := press.create_tween().set_loops()
	tw.tween_property(press, "modulate:a", 0.15, 0.55)
	tw.tween_property(press, "modulate:a", 1.0, 0.55)
	var foot := Label.new()
	foot.text = "playtest build · all wrestlers are fictional"
	foot.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	foot.position = Vector2(-500, -90)
	foot.size = Vector2(1000, 40)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 20)
	foot.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	root.add_child(foot)
	return root


# ---------------------------------------------------------------- options

const OPTIONS := ["music_volume", "sfx_volume", "crowd_volume", "fullscreen", "high_quality", "crt", "entrances", "replays"]
const OPTION_NAMES := {"music_volume": "Music", "sfx_volume": "Sound effects", "crowd_volume": "Crowd",
	"fullscreen": "Fullscreen", "high_quality": "Graphics", "crt": "CRT filter (menus)", "entrances": "Entrances",
	"replays": "Instant replays"}


func _build_options() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.0, 0.06, 0.82)
	shade.position = Vector2(40, 40)
	shade.size = Vector2(760, 1000)
	root.add_child(shade)
	var box := VBoxContainer.new()
	box.position = Vector2(80, 80)
	box.custom_minimum_size = Vector2(680, 0)
	box.add_theme_constant_override("separation", 14)
	root.add_child(box)
	var title := Label.new()
	title.text = "OPTIONS"
	title.add_theme_font_size_override("font_size", 80)
	title.add_theme_color_override("font_color", Color("ff2bd6"))
	title.add_theme_color_override("font_outline_color", Color("00e5ff"))
	title.add_theme_constant_override("outline_size", 10)
	box.add_child(title)
	for i in OPTIONS.size():
		var b := Button.new()
		b.add_theme_font_size_override("font_size", 30)
		ArrowClick.track(b)
		b.gui_input.connect(_on_option_input.bind(i))
		b.pressed.connect(func() -> void: _change_option(i, ArrowClick.step()))
		box.add_child(b)
		_opt_rows.append(b)
	var back := Button.new()
	back.text = "Back"
	back.add_theme_font_size_override("font_size", 30)
	back.pressed.connect(_close_options)
	box.add_child(back)
	var hint := Label.new()
	hint.text = "←→ change   Esc / B: back (settings are saved)"
	hint.add_theme_font_size_override("font_size", 18)
	box.add_child(hint)
	_refresh_options()
	return root


func _refresh_options() -> void:
	for i in OPTIONS.size():
		var key: String = OPTIONS[i]
		var v: Variant = Settings.get(key)
		var shown := "%d" % roundi(float(v) * 10.0) if v is float else ("On" if v else "Off")
		if key == "high_quality":
			shown = "High" if v else "Low (faster)"
		_opt_rows[i].text = "◀  %s: %s  ▶" % [OPTION_NAMES[key], shown]


func _on_option_input(event: InputEvent, i: int) -> void:
	if event.is_action_pressed("ui_left"):
		_change_option(i, -1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_change_option(i, 1)
		get_viewport().set_input_as_handled()


func _change_option(i: int, step: int) -> void:
	var key: String = OPTIONS[i]
	var v: Variant = Settings.get(key)
	if v is float:
		Settings.set(key, clampf(snappedf(float(v) + step * 0.1, 0.1), 0.0, 1.0))
	else:
		Settings.set(key, not v)
	Settings.apply()
	for c in get_children():
		if c is CrtOverlay:
			c.visible = Settings.crt
	AudioDirector.play("hit_light", Vector3.ZERO, -12.0)
	_refresh_options()


func _show_options() -> void:
	_title_screen.visible = false
	_setup.visible = false
	_options.visible = true
	_opt_rows[0].grab_focus()


func _close_options() -> void:
	Settings.save()
	_show_setup()


func _refresh() -> void:
	_update_lineup()
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


## Show the picked wrestlers standing in the ring.
func _update_lineup() -> void:
	if _stage == null:
		return
	var picks: Array = _picks if _mode == TAG else [_p1, _p2]
	var looks := []
	var used := {}
	for p in picks:
		var look: WrestlerLook = Roster.get_entry(p)["look"]
		looks.append(Roster.alt_look(look) if used.has(p) else look)
		used[p] = true
	_stage.show_lineup(looks)


func _on_row_input(event: InputEvent, row: int) -> void:
	var step := 0
	if event.is_action_pressed("ui_left"):
		step = -1
	elif event.is_action_pressed("ui_right"):
		step = 1
	if step == 0:
		return
	_change(row, step)
	_show_pick_info(row)
	get_viewport().set_input_as_handled()


func _on_row_pressed(row: int) -> void:
	if _mode == TAG and row >= 1 and row <= 4:
		_humans[row - 1] = not _humans[row - 1]
		_refresh()
		return
	_change(row, ArrowClick.step())
	_show_pick_info(row)


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
		_go()
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
	_go()


func _show_career() -> void:
	GameState.career = null
	get_tree().change_scene_to_file("res://ui/career.tscn")


func _go() -> void:
	GameState.career = null            # exhibition match
	GameState.end_career_match()
	AudioDirector.play_music("", 0.6)
	AudioDirector.crowd_ambience(false)
	get_tree().change_scene_to_file("res://match/match.tscn")
