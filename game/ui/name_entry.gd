class_name NameEntry
extends Control
## Arcade-style text entry that works on a gamepad and a keyboard alike:
## up/down changes the letter under the cursor, left/right moves the cursor,
## A (Enter) accepts and B (Esc) cancels. Typing, Backspace and Delete work too.

signal done(text: String)
signal cancelled

const LETTERS := " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-'&!"

var max_length := 18
var _text := ""
var _cursor := 0
var _picked := false             # edited with up/down: tidy the capitals on accept
var _title: Label
var _field: RichTextLabel
var _help: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.0, 0.06, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(1280, 0)
	box.add_theme_constant_override("separation", 28)
	center.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_color_override("font_color", Color("ff2bd6"))
	box.add_child(_title)
	_field = RichTextLabel.new()
	_field.bbcode_enabled = true
	_field.fit_content = true
	_field.scroll_active = false
	_field.add_theme_font_size_override("normal_font_size", 64)
	box.add_child(_field)
	_help = Label.new()
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help.add_theme_font_size_override("font_size", 22)
	_help.text = "↑↓ letter   ←→ move   A / Enter: done   B / Esc: cancel   (or just type)"
	box.add_child(_help)
	visible = false


func open(title: String, text: String, length: int) -> void:
	_title.text = title
	max_length = length
	_text = text.left(length)
	_cursor = mini(_text.length(), length - 1)
	_picked = false
	visible = true
	_redraw()


func _gui_input(_event: InputEvent) -> void:
	accept_event()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var handled := true
	if event is InputEventKey and event.pressed and not event.echo and event.unicode >= 32 \
			and event.keycode not in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		_type(char(event.unicode))
	elif event is InputEventKey and event.pressed and event.keycode == KEY_BACKSPACE:
		if _cursor > 0:
			_text = _text.erase(_cursor - 1, 1)
			_cursor -= 1
	elif event is InputEventKey and event.pressed and event.keycode == KEY_DELETE:
		_text = _text.erase(_cursor, 1)
	elif event.is_action_pressed("ui_accept"):
		_finish()
	elif event.is_action_pressed("ui_cancel"):
		visible = false
		cancelled.emit()
	elif event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true):
		_cycle(-1 if event.is_action_pressed("ui_up", true) else 1)
	elif event.is_action_pressed("ui_left", true):
		_cursor = maxi(0, _cursor - 1)
	elif event.is_action_pressed("ui_right", true):
		_cursor = mini(mini(_text.length(), max_length - 1), _cursor + 1)
	else:
		handled = false
	if handled:
		_redraw()
		get_viewport().set_input_as_handled()


func _type(c: String) -> void:
	if _text.length() >= max_length and _cursor >= _text.length():
		return
	if _cursor < _text.length():
		_text = _text.erase(_cursor, 1)
	_text = _text.insert(_cursor, c)
	_cursor = mini(_cursor + 1, max_length - 1)


func _cycle(step: int) -> void:
	_picked = true
	var cur := _text[_cursor] if _cursor < _text.length() else " "
	var i := LETTERS.find(cur.to_upper())
	var c := LETTERS[wrapi(i + step, 0, LETTERS.length())]
	if _cursor < _text.length():
		_text = _text.erase(_cursor, 1).insert(_cursor, c)
	else:
		_text += c


func _finish() -> void:
	var t := _text.strip_edges()
	if _picked and t == t.to_upper():
		# letters picked on a pad come out in capitals: make names read "Thunder Mack"
		var words := PackedStringArray()
		for w in t.split(" ", false):
			words.append(w.left(1) + w.substr(1).to_lower())
		t = " ".join(words)
	visible = false
	done.emit(t)


func _redraw() -> void:
	var shown := _text + " ".repeat(maxi(0, _cursor + 1 - _text.length()))
	var out := "[center]"
	for i in shown.length():
		var c := shown[i] if shown[i] != " " else "_" if i == _cursor else " "
		c = "[lb]" if c == "[" else c
		out += "[color=#ffd400][u]%s[/u][/color]" % c if i == _cursor else c
	_field.text = out + "[/center]"
