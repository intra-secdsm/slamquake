class_name MatchHud
extends CanvasLayer
## 90s arcade style HUD: slanted neon health bars with names, a banner for big
## moments, and a controls overlay (F1).

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


func setup(wrestlers: Array[Wrestler], help_text: String) -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	for i in wrestlers.size():
		_add_bar(wrestlers[i], i)
		wrestlers[i].health_changed.connect(_on_health)

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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F1:
		_help.visible = not _help.visible


func _process(delta: float) -> void:
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
	holder.position = Vector2(40 if not right else 0, 36 + (i / 2) * 78)
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

	var name_label := Label.new()
	name_label.text = w.display_name.to_upper()
	name_label.position = Vector2(4, BAR_H + 2)
	name_label.size = Vector2(BAR_W, 30)
	if right:
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_outline_color", COLORS[i])
	name_label.add_theme_constant_override("outline_size", 6)
	holder.add_child(name_label)
	_bars[w] = {"fill": fill, "lag": lag, "right": right, "full": BAR_W - 12}


func _on_health(w: Wrestler) -> void:
	var bar: Dictionary = _bars[w]
	var fill: ColorRect = bar["fill"]
	var full: float = bar["full"]
	fill.size.x = full * w.health / Wrestler.MAX_HEALTH
	if bar["right"]:
		fill.position.x = 6 + full - fill.size.x
