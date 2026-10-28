class_name CawEditor
extends Control
## Create-a-wrestler: a hub listing created wrestlers (new, copy a roster wrestler, edit),
## then a tabbed editor (profile, body, head, attire, moves, stats) with the wrestler
## previewed live in the ring. Rows work like the rest of the front end: ↑↓ to pick a row,
## ←→ to change it, A to press it, LB/RB (PgUp/PgDn, Q/E) to change tab, B to back out.

signal closed

const TABS := ["PROFILE", "BODY", "HEAD", "ATTIRE", "MOVES", "STATS"]
const NEON := ["ff2bd6", "00e5ff", "ffd400", "3dff6e", "4d7cff", "ff8a1f", "b44dff", "ff3b4e", "f4f4f4", "16161c",
	"c0c8d8", "d4a017", "1fb5ff", "0d5e2c", "2a4fd6", "7a1020", "2a0f4a", "ff9ec8", "8a5a2b", "5a5f6a"]
const SKIN := ["f2d0b8", "e6b896", "d9a07a", "c68a62", "b0764f", "966040", "7a4a30", "5c3622", "45281a"]
const HAIR := ["16100c", "3a2414", "6b4423", "8c3b1c", "c8a050", "eedc9a", "8a8a8a", "e8e8e8", "ff2bd6", "00e5ff",
	"3dff6e", "4d7cff", "ff3b4e", "b44dff"]
const EYES := ["3a2414", "6b4c2a", "4a7a9a", "4f7a4a", "6a7078", "2a3a6a"]
# word lists for random names (original combinations; nothing borrowed)
const FIRST := ["Rex", "Duke", "Jet", "Blaze", "Ace", "Tank", "Vic", "Dash", "Colt", "Rusty", "Brick", "Nitro",
	"Sly", "Moose", "Vance", "Roxy", "Jinx", "Tex", "Mira", "Kit", "Lola", "Zane", "Gus", "Ivy"]
const LAST := ["Hammerfist", "Ironside", "Voltaire", "Blackwood", "Cannonball", "Starling", "Graves", "Raptor",
	"Dynamo", "Thornbury", "Calloway", "Rumbleton", "Sparks", "Maddox", "Vortex", "Halloran", "Crush", "Delgado"]
const ADJ := ["UNSTOPPABLE", "ELECTRIC", "ATOMIC", "ROCK-HARD", "RED-HOT", "GOLDEN", "SAVAGE", "COSMIC", "RAGING"]
const NOUN := ["HURRICANE", "WRECKING BALL", "SUPERSTAR", "JUGGERNAUT", "SHOWSTOPPER", "STORM", "LEGEND", "MACHINE"]

var stage: MenuStage
var _page := "hub"
var _tab := 0
var _entry: Dictionary = {}
var _look: WrestlerLook
var _saved := false               # this wrestler exists in the store
var _dirty := false
var _confirm := ""                # action waiting for a second press
var _copy_pick := 0
var _defs: Array[Dictionary] = []
var _rows: Array[Button] = []
var _list: VBoxContainer
var _scroll: ScrollContainer
var _title: Label
var _tabs: Label
var _info: Label
var _hint: Label
var _names: NameEntry


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.0, 0.06, 0.8)
	shade.position = Vector2(40, 40)
	shade.size = Vector2(760, 1000)
	add_child(shade)
	var box := VBoxContainer.new()
	box.position = Vector2(80, 60)
	box.custom_minimum_size = Vector2(680, 0)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = _label(64, Color("ff2bd6"), Color("00e5ff"), 10)
	box.add_child(_title)
	_tabs = _label(24, Color("ffd400"), Color.BLACK, 6)
	box.add_child(_tabs)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(680, 690)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)
	_info = _label(20, Color.WHITE, Color.BLACK, 6)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(680, 56)
	box.add_child(_info)
	_hint = _label(18, Color(1, 1, 1, 0.7), Color.BLACK, 4)
	box.add_child(_hint)
	_names = NameEntry.new()
	add_child(_names)
	_names.done.connect(_on_name_done)
	_names.cancelled.connect(_focus_row.bind(-1))
	visible = false


## Open on the hub (the list of created wrestlers).
func open() -> void:
	visible = true
	_show_hub()


func _label(font_size: int, color: Color, outline: Color, outline_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", outline_size)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _names.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _page == "edit":
			_exit_editor()
		else:
			_close()
	elif _page == "edit" and (event.is_action_pressed("ui_page_up") or event.is_action_pressed("ui_page_down")
			or event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_Q, KEY_E]):
		var back: bool = event.is_action_pressed("ui_page_up") or event is InputEventKey and event.keycode == KEY_Q
		_set_tab(wrapi(_tab + (-1 if back else 1), 0, TABS.size()))
	else:
		return
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- hub

func _show_hub() -> void:
	_page = "hub"
	_confirm = ""
	_title.text = "CREATE-A-WRESTLER"
	var made := CawStore.entries()
	_tabs.text = "%d / %d created" % [made.size(), CawStore.MAX_WRESTLERS]
	_info.text = "Make your own wrestler, or start from one of the roster."
	_hint.text = "↑↓ select   ←→ change   A: choose   B: back"
	stage.end_preview()
	AudioDirector.play_music("theme_menu", 0.6)
	var defs: Array[Dictionary] = []
	if made.size() < CawStore.MAX_WRESTLERS:
		defs.append({"text": func() -> String: return "★  NEW WRESTLER  ★", "press": func() -> void:
			_edit(CawStore.blank(), false)})
		defs.append({"text": func() -> String:
				return "◀  Copy: %s  ▶" % Roster.builtin()[_copy_pick]["name"],
			"change": func(step: int) -> void: _copy_pick = wrapi(_copy_pick + step, 0, Roster.builtin().size()),
			"press": _copy_roster})
	for e in made:
		defs.append({"text": func() -> String: return "Edit: %s" % e["name"], "press": func() -> void:
			_edit(e, true)})
	defs.append({"text": func() -> String: return "Back", "press": _close})
	_build(defs)
	_focus_row(0)


func _copy_roster() -> void:
	var src: Dictionary = Roster.builtin()[_copy_pick]
	var e := CawStore.blank()
	for key in ["tagline", "color", "theme", "pyro", "motif"]:
		e[key] = src[key]
	e["name"] = String(src["name"]).left(CawStore.NAME_MAX - 3) + " II"
	e["moves"] = (src["moves"] as Dictionary).duplicate()
	e["stats"] = (src["stats"] as Dictionary).duplicate()
	e["look"] = (src["look"] as WrestlerLook).duplicate()
	_edit(e, false)


func _close() -> void:
	visible = false
	AudioDirector.play_music("theme_menu", 0.6)
	closed.emit()


# ---------------------------------------------------------------- editor

func _edit(entry: Dictionary, saved: bool) -> void:
	_entry = entry.duplicate()
	_entry["moves"] = Movesets.resolve(entry.get("moves", {}))
	_entry["stats"] = Stats.sanitize(entry.get("stats", {}))
	_look = (entry["look"] as WrestlerLook).duplicate()
	_entry["look"] = _look
	_saved = saved
	_dirty = not saved
	_page = "edit"
	_set_tab(0)


func _set_tab(t: int) -> void:
	_tab = t
	_confirm = ""
	_title.text = String(_entry["name"]).to_upper()
	var parts: Array[String] = []
	for i in TABS.size():
		parts.append("[%s]" % TABS[i] if i == _tab else TABS[i])
	_tabs.text = "LB ◀  " + "  ".join(parts) + "  ▶ RB"
	_hint.text = "↑↓ select   ←→ change   A: press   LB/RB (Q/E): tab   B: exit"
	_info.text = ""
	stage.preview(_look, "head" if TABS[_tab] == "HEAD" else "full")
	stage.preview_move("")
	if TABS[_tab] == "PROFILE":
		AudioDirector.play_music(_entry["theme"], 0.5)
	var defs: Array[Dictionary] = []
	match TABS[_tab]:
		"PROFILE": defs = _profile_rows()
		"BODY": defs = _body_rows()
		"HEAD": defs = _head_rows()
		"ATTIRE": defs = _attire_rows()
		"MOVES": defs = _move_rows()
		"STATS": defs = _stat_rows()
	defs.append({"text": func() -> String: return "★  SAVE  ★" if _dirty else "Saved", "press": _save})
	defs.append({"text": func() -> String:
			return "Exit without saving? Press again" if _confirm == "exit" else "Exit", "press": _exit_editor})
	if _saved and TABS[_tab] == "PROFILE":
		defs.append({"text": func() -> String:
				return "Really delete? Press again" if _confirm == "delete" else "Delete this wrestler",
			"press": _delete})
	_build(defs)
	_focus_row(0)


func _save() -> void:
	_entry["name"] = String(_entry["name"]).strip_edges()
	if _entry["name"] == "":
		_entry["name"] = "Wrestler"
	if CawStore.put(_entry):
		_saved = true
		_dirty = false
		_info.text = "Saved. %s is ready to wrestle." % _entry["name"]
		AudioDirector.play("bell", Vector3.ZERO, -10.0)
	else:
		_info.text = "Couldn't save (the list is full, or the save file can't be written)."
	_refresh()


func _exit_editor() -> void:
	if _dirty and _confirm != "exit":
		_confirm = "exit"
		_info.text = "You have unsaved changes."
		_refresh()
		return
	_show_hub()


func _delete() -> void:
	if _confirm != "delete":
		_confirm = "delete"
		_refresh()
		return
	CawStore.remove(_entry["id"])
	_show_hub()


func _changed() -> void:
	_dirty = true
	_confirm = ""
	_title.text = String(_entry["name"]).to_upper()
	# a feminine body always has its chest covered: a top, unless a singlet does it
	if _look.feminine > 0.5 and not _look.singlet:
		_look.top = true
	_update_view()


## Frame the preview for the focused row (row i, or the focused one): the head tab is a
## close-up, the colour / pyro / titantron rows show the entrance stage, the rest the ring.
func _update_view(i: int = -1) -> void:
	if i < 0:
		i = _rows.find(get_viewport().gui_get_focus_owner())
	var view := "full"
	if TABS[_tab] == "HEAD":
		view = "head"
	elif i >= 0 and i < _defs.size() and _defs[i].get("view", "") == "stage":
		view = "stage"
	var was_stage := stage.focus() == "stage"
	stage.preview(_look, view)
	if view == "stage":
		stage.preview_entrance(String(_entry["name"]).to_upper(), _entry["tagline"], _entry["color"],
			_entry["motif"], _entry["pyro"])
		if not was_stage:
			stage.preview_move(_entry["moves"]["taunt"])
	elif was_stage:
		stage.preview_move("")


# ---------------------------------------------------------------- rows

func _profile_rows() -> Array[Dictionary]:
	var themes: Array = Roster.THEMES
	return [
		{"text": func() -> String: return "Name: %s" % _entry["name"],
			"press": func() -> void: _names.open("NAME", _entry["name"], CawStore.NAME_MAX)},
		{"text": func() -> String: return "Nickname: %s" % (_entry["tagline"] if _entry["tagline"] != "" else "—"),
			"press": func() -> void: _names.open("NICKNAME", _entry["tagline"], CawStore.TAGLINE_MAX)},
		{"text": func() -> String: return "Random name & nickname", "press": _random_name},
		_stage_row(_entry_color("Signature colour", "color", NEON),
			"Your colour on the titantron, the pyro and the name cards."),
		{"text": func() -> String: return "◀  Theme: %s  ▶" % Roster.THEME_NAMES.get(_entry["theme"], _entry["theme"]),
			"change": func(step: int) -> void:
				_entry["theme"] = themes[wrapi(themes.find(_entry["theme"]) + step, 0, themes.size())]
				AudioDirector.play_music(_entry["theme"], 0.3)},
		_stage_row(_entry_choice("Pyro", "pyro", Roster.PYRO_STYLES), "The pyro that goes off as you come out."),
		_stage_row(_entry_choice("Titantron", "motif", Roster.MOTIFS), "Your picture on the titantron."),
	]


## A profile row previewed on the entrance stage, with a line of help.
func _stage_row(def: Dictionary, help: String) -> Dictionary:
	def["view"] = "stage"
	return _with_help(def, help)


func _with_help(def: Dictionary, help: String) -> Dictionary:
	def["focus"] = func() -> void: _info.text = help
	return def


func _body_rows() -> Array[Dictionary]:
	return [
		{"text": func() -> String: return "◀  Body type: %s  ▶" % ("Feminine" if _look.feminine > 0.5 else "Masculine"),
			"change": func(_step: int) -> void: _look.feminine = 0.0 if _look.feminine > 0.5 else 1.0,
			"focus": func() -> void: _info.text = "A feminine body always wears a top or a singlet."},
		{"text": func() -> String: return "◀  Height: %d cm  ▶" % roundi(_look.height * 185.0),
			"change": func(step: int) -> void: _look.height = clampf(snappedf(_look.height + step * 0.02, 0.01), 0.88, 1.12)},
		_look_float("Build", "mass", -1.0, 1.0, 0.1),
		_look_float("Muscle", "muscle", 0.0, 1.0, 0.1),
		_look_float("Gut", "gut", 0.0, 1.0, 0.1),
		_look_color("Skin tone", "skin_color", SKIN),
	]


func _head_rows() -> Array[Dictionary]:
	return [
		_look_enum("Hair", "hair_style"),
		_look_color("Hair colour", "hair_color", HAIR),
		_look_enum("Facial hair", "facial_hair"),
		_look_color("Eyes", "eye_color", EYES),
		_look_enum("Face paint", "face_paint"),
		_look_color("Paint colour", "paint_color", NEON, _wear.bind("face_paint")),
		_look_color("Paint accent", "paint_color2", NEON, _wear.bind("face_paint")),
		_look_enum("Mask", "mask"),
		_look_color("Mask colour", "mask_color", NEON, _wear.bind("mask")),
		_look_color("Mask trim", "mask_trim", NEON, _wear.bind("mask")),
	]


func _attire_rows() -> Array[Dictionary]:
	return [
		_look_color("Trunks", "trunks_color", NEON),
		_look_color("Trim", "trim_color", NEON),
		_look_float("Trunks length", "trunks_bottom", 0.7, 0.95, 0.05, true),
		_look_bool("Long tights", "tights"),
		_look_color("Tights", "tights_color", NEON, _wear.bind("tights")),
		_look_bool("Singlet", "singlet"),
		_with_help(_look_bool("Top", "top"), "A sports top. A feminine body always wears a top or a singlet."),
		_look_color("Top colour", "top_color", NEON, _wear.bind("top")),
		_look_enum("Pattern", "pattern"),
		_look_color("Pattern colour", "pattern_color", NEON, _wear.bind("pattern")),
		_look_bool("Boots", "boots"),
		_look_color("Boots colour", "boots_color", NEON, _wear.bind("boots")),
		_look_float("Boot height", "boot_top", 0.25, 0.5, 0.05),
		_look_bool("Kneepads", "kneepads"),
		_look_bool("Elbow pads", "elbowpads"),
		_look_bool("Wristbands", "wristbands"),
		_look_color("Pads colour", "pads_color", NEON, func() -> void:
			if not (_look.kneepads or _look.elbowpads or _look.wristbands):
				_look.kneepads = true),
		_look_enum("Tattoo", "tattoo"),
		_look_color("Tattoo ink", "tattoo_color", NEON, _wear.bind("tattoo")),
	]


func _move_rows() -> Array[Dictionary]:
	var defs: Array[Dictionary] = []
	for s in Movesets.SLOTS:
		var slot_id: String = s["id"]
		defs.append({"text": func() -> String:
				return "◀  %s: %s  ▶" % [s["label"], Movesets.move_name(_entry["moves"][slot_id])],
			"change": func(step: int) -> void:
				var opts := Movesets.options(slot_id)
				_entry["moves"][slot_id] = opts[wrapi(opts.find(_entry["moves"][slot_id]) + step, 0, opts.size())]
				_preview_move(_entry["moves"][slot_id]),
			"focus": func() -> void:
				_info.text = "%s  —  %s" % [s["input"], Movesets.move_name(_entry["moves"][slot_id])]
				_preview_move(_entry["moves"][slot_id])})
	return defs


func _stat_rows() -> Array[Dictionary]:
	var defs: Array[Dictionary] = [{"text": func() -> String:
		return "Points left: %d" % (Stats.BUDGET - Stats.total(_entry["stats"]))}]
	for n in Stats.NAMES:
		defs.append({"text": func() -> String:
				var v := int(_entry["stats"][n])
				return "◀  %s  %s  ▶" % [String(Stats.LABELS[n]).rpad(10), "■".repeat(v) + "□".repeat(Stats.MAX - v)],
			"change": func(step: int) -> void:
				var v := int(_entry["stats"][n]) + step
				if v >= Stats.MIN and v <= Stats.MAX and (step < 0 or Stats.total(_entry["stats"]) < Stats.BUDGET):
					_entry["stats"][n] = v,
			"focus": func() -> void: _info.text = "%s: %s" % [Stats.LABELS[n], Stats.HELP[n]]})
	return defs


func _look_enum(label: String, prop: String) -> Dictionary:
	return {"text": func() -> String: return "◀  %s: %s  ▶" % [label, String(_look.get(prop)).capitalize()],
		"change": func(step: int) -> void:
			var opts := _look.choices(prop)
			_look.set(prop, opts[wrapi(opts.find(_look.get(prop)) + step, 0, opts.size())])}


func _look_bool(label: String, prop: String) -> Dictionary:
	return {"text": func() -> String: return "◀  %s: %s  ▶" % [label, "On" if _look.get(prop) else "Off"],
		"change": func(_step: int) -> void: _look.set(prop, not _look.get(prop))}


## A slider shown as a bar. flip: the property's low end is the bar's high end (e.g. trunks length).
func _look_float(label: String, prop: String, lo: float, hi: float, step: float, flip: bool = false) -> Dictionary:
	return {"text": func() -> String:
			var k := (float(_look.get(prop)) - lo) / (hi - lo)
			var filled := roundi((1.0 - k if flip else k) * 10.0)
			return "◀  %s  %s  ▶" % [label, "▮".repeat(filled) + "▯".repeat(10 - filled)],
		"change": func(dir: int) -> void:
			var v := float(_look.get(prop)) + (-dir if flip else dir) * step
			_look.set(prop, clampf(snappedf(v, step * 0.5), lo, hi))}


## A colour row; wear (optional) switches on what the colour is for, so the change shows.
func _look_color(label: String, prop: String, palette: Array, wear: Callable = Callable()) -> Dictionary:
	return {"text": func() -> String: return "◀  %s: [color]  ▶" % label,
		"swatch": func() -> Color: return _look.get(prop),
		"change": func(step: int) -> void:
			_look.set(prop, _next_color(_look.get(prop), palette, step))
			if wear.is_valid():
				wear.call()}


## Put on an item that's off: a bool turns on, an enum at "none" takes its first style.
func _wear(prop: String) -> void:
	var v: Variant = _look.get(prop)
	if v is bool:
		_look.set(prop, true)
	elif String(v) == "none":
		_look.set(prop, _look.choices(prop)[1])


func _entry_color(label: String, key: String, palette: Array) -> Dictionary:
	return {"text": func() -> String: return "◀  %s: [color]  ▶" % label,
		"swatch": func() -> Color: return _entry[key],
		"change": func(step: int) -> void: _entry[key] = _next_color(_entry[key], palette, step)}


func _entry_choice(label: String, key: String, options: Array) -> Dictionary:
	return {"text": func() -> String: return "◀  %s: %s  ▶" % [label, String(_entry[key]).capitalize()],
		"change": func(step: int) -> void:
			_entry[key] = options[wrapi(options.find(_entry[key]) + step, 0, options.size())]}


## The next colour in a palette after the one nearest to `c`.
static func _next_color(c: Color, palette: Array, step: int) -> Color:
	var best := 0
	var best_d := INF
	for i in palette.size():
		var p := Color(palette[i])
		var d := Vector3(p.r - c.r, p.g - c.g, p.b - c.b).length()
		if d < best_d:
			best_d = d
			best = i
	return Color(palette[wrapi(best + step, 0, palette.size())])


func _random_name() -> void:
	_entry["name"] = "%s %s" % [FIRST.pick_random(), LAST.pick_random()]
	_entry["tagline"] = "THE %s %s" % [ADJ.pick_random(), NOUN.pick_random()]
	_changed()
	_refresh()


func _on_name_done(text: String) -> void:
	if _page != "edit":
		return
	if _names.max_length == CawStore.NAME_MAX:
		if text != "":
			_entry["name"] = text
	else:
		_entry["tagline"] = text.to_upper()
	_changed()
	_refresh()
	_focus_row(-1)


func _preview_move(id: String) -> void:
	if Grapples.ALL.has(id):
		var base := String(Grapples.ALL[id].get("anim", id))
		stage.preview_move(base + "_a", base + "_d")
	elif Strikes.ALL.has(id):
		stage.preview_move(Strikes.ALL[id]["anim"])
	else:
		stage.preview_move(id)


# ---------------------------------------------------------------- row plumbing

func _build(defs: Array[Dictionary]) -> void:
	_defs = defs
	for b in _rows:
		b.queue_free()
	_rows.clear()
	for i in defs.size():
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 28)
		b.gui_input.connect(_on_row_input.bind(i))
		b.pressed.connect(_on_row_pressed.bind(i))
		b.focus_entered.connect(_on_row_focus.bind(i))
		if defs[i].has("swatch"):
			var sw := Panel.new()
			var sb := StyleBoxFlat.new()
			sb.set_border_width_all(2)
			sb.border_color = Color(1, 1, 1, 0.8)
			sw.add_theme_stylebox_override("panel", sb)
			sw.size = Vector2(54, 26)
			sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(sw)
		_list.add_child(b)
		_rows.append(b)
	_refresh()


func _refresh() -> void:
	for i in _rows.size():
		var d := _defs[i]
		var text: String = d["text"].call()
		var b := _rows[i]
		if d.has("swatch"):
			# leave a gap in the text where the colour swatch sits
			var head := text.get_slice("[color]", 0)
			b.text = text.replace("[color]", "          ")
			var sw := b.get_child(0) as Panel
			(sw.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = d["swatch"].call()
			sw.position = Vector2(b.get_theme_font("font").get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x + 18, 9)
		else:
			b.text = text
		b.focus_mode = Control.FOCUS_ALL if d.has("change") or d.has("press") else Control.FOCUS_NONE


func _focus_row(i: int) -> void:
	if _rows.is_empty():
		return
	if i < 0:
		var cur := get_viewport().gui_get_focus_owner()
		i = maxi(0, _rows.find(cur))
	for k in _rows.size():
		var j := (i + k) % _rows.size()
		if _rows[j].focus_mode != Control.FOCUS_NONE:
			_grab_focus.call_deferred(_rows[j].get_instance_id())
			return


## Deferred so a fresh row is in the tree; skipped if the rows were rebuilt meanwhile.
func _grab_focus(id: int) -> void:
	var b := instance_from_id(id) as Control
	if b and b.is_inside_tree() and not b.is_queued_for_deletion():
		b.grab_focus()


func _on_row_input(event: InputEvent, i: int) -> void:
	var step := 0
	if event.is_action_pressed("ui_left", true):
		step = -1
	elif event.is_action_pressed("ui_right", true):
		step = 1
	if step == 0 or not _defs[i].has("change"):
		return
	_defs[i]["change"].call(step)
	AudioDirector.play("hit_light", Vector3.ZERO, -14.0)
	if _page == "edit":
		_changed()
	_refresh()
	get_viewport().set_input_as_handled()


func _on_row_pressed(i: int) -> void:
	var d := _defs[i]
	if d.has("press"):
		d["press"].call()
	elif d.has("change"):
		d["change"].call(1)
		if _page == "edit":
			_changed()
	_refresh()


func _on_row_focus(i: int) -> void:
	if _page == "edit":
		_update_view(i)
		_info.text = ""
	if i < _defs.size() and _defs[i].has("focus"):
		_defs[i]["focus"].call()
