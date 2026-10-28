class_name MatchHud
extends CanvasLayer
## 90s arcade style HUD: slanted neon health bars with momentum meters and names,
## a banner for big moments, popups, a screen flash, and a controls overlay (F1).

const BAR_W := 520.0
const BAR_H := 30.0
const COLORS := [Color("ff2bd6"), Color("00e5ff"), Color("ffd400"), Color("7dff3a")]

var _bars: Dictionary = {}       # Wrestler -> {fill: ColorRect, lag: ColorRect}
var _banner: Label
var _banner_time := 0.0
var _help: Label
var _root: Control
var _kick_box: Control
var _kick_fill: ColorRect
var _kick_label: Label
var _count_label: Label
var _popups: Array[Dictionary] = []
var _flash: ColorRect
var _time := 0.0
var _card: Control
var _help_wanted := true


func setup(wrestlers: Array[Wrestler], help_text: String) -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	for i in wrestlers.size():
		_add_bar(wrestlers[i], i)
		wrestlers[i].health_changed.connect(_on_health)
		wrestlers[i].momentum_changed.connect(_on_momentum)

	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-400, 150)
	_banner.size = Vector2(800, 120)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 96)
	_banner.add_theme_color_override("font_color", Color("ffd400"))
	_banner.add_theme_color_override("font_outline_color", Color("ff2bd6"))
	_banner.add_theme_constant_override("outline_size", 18)
	_banner.modulate.a = 0.0
	_root.add_child(_banner)

	_build_kickout_meter()
	_count_label = Label.new()
	_count_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_count_label.position = Vector2(-200, 30)
	_count_label.size = Vector2(400, 60)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_size_override("font_size", 40)
	_count_label.add_theme_color_override("font_color", Color("ffd400"))
	_count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_count_label.add_theme_constant_override("outline_size", 10)
	_root.add_child(_count_label)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)

	_help = Label.new()
	_help.text = help_text + "\n\nF1: hide controls    Esc / Start: pause"
	_help.position = Vector2(24, 0)
	_help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help.offset_top = -170
	_help.offset_left = 24
	_help.add_theme_font_size_override("font_size", 20)
	_help.add_theme_color_override("font_outline_color", Color.BLACK)
	_help.add_theme_constant_override("outline_size", 6)
	_root.add_child(_help)


func _build_kickout_meter() -> void:
	_kick_box = Control.new()
	_kick_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_kick_box.position = Vector2(-260, -210)
	_kick_box.visible = false
	_root.add_child(_kick_box)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.size = Vector2(520, 26)
	_kick_box.add_child(bg)
	_kick_fill = ColorRect.new()
	_kick_fill.color = Color("ffd400")
	_kick_fill.position = Vector2(4, 4)
	_kick_fill.size = Vector2(0, 18)
	_kick_box.add_child(_kick_fill)
	_kick_label = Label.new()
	_kick_label.position = Vector2(0, -44)
	_kick_label.size = Vector2(520, 40)
	_kick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kick_label.add_theme_font_size_override("font_size", 30)
	_kick_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_kick_label.add_theme_constant_override("outline_size", 8)
	_kick_box.add_child(_kick_label)


## Ring-out count (0 hides it).
func show_count(n: int) -> void:
	_count_label.text = "OUTSIDE: %d" % n if n > 0 else ""


## Show the pinned wrestler's kick-out progress (null hides the meter).
func show_kickout(w: Wrestler, progress: float) -> void:
	_kick_box.visible = w != null
	if w == null:
		return
	_kick_label.text = "%s: MASH TO KICK OUT!" % w.display_name.to_upper()
	_kick_fill.size.x = 512.0 * clampf(progress, 0.0, 1.0)


func banner(text: String, seconds: float = 1.6) -> void:
	_banner.text = text
	_banner_time = seconds
	_banner.modulate.a = 1.0
	_banner.scale = Vector2(1.3, 1.3)
	_banner.pivot_offset = _banner.size / 2


## Short callout next to a wrestler's health bar ("PARRY!", "SPECIAL!").
func popup(text: String, w: Wrestler) -> void:
	if not _bars.has(w):
		return
	var bar: Dictionary = _bars[w]
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", bar["color"])
	l.add_theme_constant_override("outline_size", 12)
	var holder: Control = bar["holder"]
	l.position = Vector2(BAR_W - 260 if bar["right"] else 10, BAR_H + 62)
	l.size = Vector2(250, 50)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if bar["right"] else HORIZONTAL_ALIGNMENT_LEFT
	holder.add_child(l)
	_popups.append({"label": l, "t": 1.1})


## Small line under a wrestler's name ("on the apron", "ILLEGAL 3"); "" hides it.
func set_status(w: Wrestler, text: String) -> void:
	if not _bars.has(w):
		return
	var bar: Dictionary = _bars[w]
	var l: Label = bar["status"]
	if l.text != text:
		l.text = text
	var dim := w.on_apron() and not w.legal
	(bar["holder"] as Control).modulate.a = 0.55 if dim else 1.0


## Show or hide the health bars and controls (hidden during entrances and replays).
func show_bars(on: bool) -> void:
	for w in _bars:
		(_bars[w]["holder"] as Control).visible = on
	_help.visible = on and _help_wanted


## Lower-third caption for entrances ("" hides it).
func name_card(title: String, subtitle: String) -> void:
	if _card == null:
		_card = Control.new()
		_card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_card.position = Vector2(60, -230)
		_root.add_child(_card)
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 0.6)
		bar.size = Vector2(900, 120)
		_card.add_child(bar)
		var stripe := ColorRect.new()
		stripe.color = Color("ff2bd6")
		stripe.size = Vector2(10, 120)
		_card.add_child(stripe)
		for i in 2:
			var l := Label.new()
			l.position = Vector2(30, 6 if i == 0 else 78)
			l.add_theme_font_size_override("font_size", 60 if i == 0 else 26)
			l.add_theme_color_override("font_color", Color.WHITE if i == 0 else Color("ffd400"))
			l.add_theme_color_override("font_outline_color", Color("ff2bd6") if i == 0 else Color.BLACK)
			l.add_theme_constant_override("outline_size", 10 if i == 0 else 6)
			_card.add_child(l)
	_card.visible = title != ""
	(_card.get_child(2) as Label).text = title
	(_card.get_child(3) as Label).text = subtitle
	_card.modulate.a = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.3)


func flash() -> void:
	_flash.color.a = 0.85


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F1:
		_help_wanted = not _help_wanted
		_help.visible = _help_wanted


func _process(delta: float) -> void:
	_time += delta
	_flash.color.a = move_toward(_flash.color.a, 0.0, delta * 2.5)
	for p in _popups.duplicate():
		p["t"] -= delta
		var l: Label = p["label"]
		l.position.y += delta * 24.0
		l.modulate.a = clampf(p["t"] / 0.3, 0.0, 1.0)
		if p["t"] <= 0.0:
			l.queue_free()
			_popups.erase(p)
	for w: Wrestler in _bars:
		var bar: Dictionary = _bars[w]
		var tag: Label = bar["special"]
		tag.visible = w.has_special()
		if tag.visible:
			tag.modulate.a = 0.6 + 0.4 * sin(_time * 12.0)
			var mfill: ColorRect = bar["mfill"]
			mfill.color = Color.WHITE.lerp(bar["color"], 0.5 + 0.5 * sin(_time * 12.0))
			mfill.size.x = float(bar["mfull"]) * w.special_left / Wrestler.SPECIAL_TIME
			mfill.position.x = float(bar["mx"]) + (float(bar["mfull"]) - mfill.size.x if bar["right"] else 0.0)
	if _banner_time > 0.0:
		_banner_time -= delta
		_banner.scale = _banner.scale.lerp(Vector2.ONE, delta * 12.0)
		if _banner_time < 0.3:
			_banner.modulate.a = maxf(0.0, _banner_time / 0.3)
	for w in _bars:
		var bar: Dictionary = _bars[w]
		var lag: ColorRect = bar["lag"]
		var fill: ColorRect = bar["fill"]
		lag.size.x = move_toward(lag.size.x, fill.size.x, delta * 160.0)
		if bar["right"]:
			lag.position.x = 6 + float(bar["full"]) - lag.size.x


func _add_bar(w: Wrestler, i: int) -> void:
	var right := i % 2 == 1
	var holder := Control.new()
	holder.position = Vector2(40 if not right else 0, 36 + (i / 2) * 104)
	if right:
		holder.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		holder.position.x = -BAR_W - 40
	_root.add_child(holder)

	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.65)
	sb.border_color = COLORS[i]
	sb.set_border_width_all(3)
	sb.skew = Vector2(-0.35 if not right else 0.35, 0)
	frame.add_theme_stylebox_override("panel", sb)
	frame.size = Vector2(BAR_W, BAR_H)
	holder.add_child(frame)

	var lag := ColorRect.new()
	lag.color = Color(1, 1, 1, 0.85)
	lag.position = Vector2(6, 6)
	lag.size = Vector2(BAR_W - 12, BAR_H - 12)
	holder.add_child(lag)
	var fill := ColorRect.new()
	fill.color = COLORS[i]
	fill.position = lag.position
	fill.size = lag.size
	holder.add_child(fill)

	var mbg := ColorRect.new()
	mbg.color = Color(0, 0, 0, 0.65)
	mbg.position = Vector2(6, BAR_H + 3)
	mbg.size = Vector2(BAR_W * 0.6, 9)
	if right:
		mbg.position.x = BAR_W - 6 - mbg.size.x
	holder.add_child(mbg)
	var mfill := ColorRect.new()
	mfill.color = COLORS[i].lerp(Color.WHITE, 0.35)
	mfill.position = mbg.position + Vector2(1, 1)
	mfill.size = Vector2(0, 7)
	holder.add_child(mfill)
	var special := Label.new()
	special.text = "SPECIAL"
	special.visible = false
	special.add_theme_font_size_override("font_size", 18)
	special.add_theme_color_override("font_color", Color("ffd400"))
	special.add_theme_color_override("font_outline_color", Color.BLACK)
	special.add_theme_constant_override("outline_size", 6)
	special.position = Vector2(mbg.position.x + mbg.size.x + 8 if not right else mbg.position.x - 96, BAR_H - 4)
	holder.add_child(special)

	var name_label := Label.new()
	name_label.text = w.display_name.to_upper()
	name_label.position = Vector2(4, BAR_H + 12)
	name_label.size = Vector2(BAR_W, 30)
	if right:
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_outline_color", COLORS[i])
	name_label.add_theme_constant_override("outline_size", 6)
	holder.add_child(name_label)
	var status := Label.new()
	status.position = Vector2(4, BAR_H + 40)
	status.size = Vector2(BAR_W, 24)
	if right:
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", Color("ffd400"))
	status.add_theme_color_override("font_outline_color", Color.BLACK)
	status.add_theme_constant_override("outline_size", 6)
	holder.add_child(status)
	_bars[w] = {"fill": fill, "lag": lag, "right": right, "full": BAR_W - 12, "holder": holder, "color": COLORS[i],
		"mfill": mfill, "mfull": mbg.size.x - 2, "mx": mbg.position.x + 1, "special": special, "status": status}


func _on_health(w: Wrestler) -> void:
	var bar: Dictionary = _bars[w]
	var fill: ColorRect = bar["fill"]
	var full: float = bar["full"]
	fill.size.x = full * w.health / Wrestler.MAX_HEALTH
	if bar["right"]:
		fill.position.x = 6 + full - fill.size.x


func _on_momentum(w: Wrestler) -> void:
	var bar: Dictionary = _bars[w]
	var mfill: ColorRect = bar["mfill"]
	mfill.color = (bar["color"] as Color).lerp(Color.WHITE, 0.35)
	mfill.size.x = float(bar["mfull"]) * w.momentum / Wrestler.MOMENTUM_MAX
	mfill.position.x = float(bar["mx"]) + (float(bar["mfull"]) - mfill.size.x if bar["right"] else 0.0)
