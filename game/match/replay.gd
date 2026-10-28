class_name Replay
extends Node
## Instant replay: records the last few seconds of every wrestler's (and the referee's)
## transform and animation frame, and plays a stretch back in slow motion through a
## VHS filter with an orbiting camera. Props aren't replayed.

signal done

const SECONDS := 8.0
const SPEED := 0.5

var match_node: Match
var recording := true
var _tracked: Array[Node3D] = []
var _buf: Array = []          # per physics frame: [[xform, anim, pos], ...] per tracked node
var _frame := 0               # absolute frame count
var _marks := {}


func setup(m: Match) -> void:
	match_node = m
	for w in m.wrestlers:
		_tracked.append(w)
	_tracked.append(m.referee)


func _physics_process(_delta: float) -> void:
	if not recording:
		return
	var snap := []
	for n in _tracked:
		var ap := _model(n).anim_player
		snap.append([n.global_transform, ap.current_animation, ap.current_animation_position])
	_buf.append(snap)
	if _buf.size() > int(SECONDS * Engine.physics_ticks_per_second):
		_buf.pop_front()
	_frame += 1


## Remember "now" under a name (e.g. "finisher", "pin").
func mark(mark_name: String) -> void:
	_marks[mark_name] = _frame


## Frames ago that a mark was set, or -1 if it's no longer in the buffer.
func frames_since(mark_name: String) -> int:
	if not _marks.has(mark_name):
		return -1
	var ago: int = _frame - int(_marks[mark_name])
	return ago if ago < _buf.size() else -1


## Play back from `start_ago` frames ago for `length` frames.
func play(start_ago: int, length: int, subjects: Array) -> void:
	recording = false
	var m := match_node
	start_ago = clampi(start_ago, 1, _buf.size())
	var first := _buf.size() - start_ago
	var last := mini(_buf.size() - 1, first + length)
	var saved := []
	for n in _tracked:
		var ap := _model(n).anim_player
		saved.append([n.global_transform, ap.current_animation, ap.current_animation_position, ap.speed_scale])
		n.set_physics_process(false)
		ap.speed_scale = 0.0
	var overlay := _overlay()
	m.hud.show_bars(false)
	var facing: Vector3 = (subjects[0] as Node3D).global_basis.z if not subjects.is_empty() else Vector3.FORWARD
	m.camera.cinematic(subjects, facing, (last - first) / Engine.physics_ticks_per_second / SPEED + 0.5)
	var t := float(first)
	while t < last and is_inside_tree():
		_apply(t)
		await get_tree().process_frame
		t += get_process_delta_time() * Engine.physics_ticks_per_second * SPEED
	overlay.queue_free()
	m.camera.end_cinematic()
	for i in _tracked.size():
		var n := _tracked[i]
		var ap := _model(n).anim_player
		n.global_transform = saved[i][0]
		if saved[i][1] != "":
			ap.play(saved[i][1], 0.0)
			ap.seek(saved[i][2], true)
		ap.speed_scale = saved[i][3]
		n.set_physics_process(true)
	m.hud.show_bars(true)
	done.emit()


func _apply(t: float) -> void:
	var i := int(t)
	var k := t - i
	var a: Array = _buf[i]
	var b: Array = _buf[mini(i + 1, _buf.size() - 1)]
	for j in _tracked.size():
		var n := _tracked[j]
		n.global_transform = (a[j][0] as Transform3D).interpolate_with(b[j][0], k)
		var ap := _model(n).anim_player
		var anim: String = a[j][1]
		if anim == "":
			continue
		if ap.current_animation != anim:
			ap.play(anim, 0.0)
		var pos := lerpf(a[j][2], b[j][2], k) if b[j][1] == anim and b[j][2] >= a[j][2] else float(a[j][2])
		ap.seek(pos, true)


func _model(n: Node3D) -> WrestlerModel:
	return n.model if n is Wrestler else (n as Referee).model


func _overlay() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var fx := ColorRect.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://fx/vhs.gdshader")
	fx.material = mat
	layer.add_child(fx)
	var osd := Label.new()
	osd.text = "▶ REPLAY"
	osd.position = Vector2(60, 50)
	osd.add_theme_font_size_override("font_size", 48)
	osd.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	osd.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	osd.add_theme_constant_override("shadow_offset_x", 3)
	osd.add_theme_constant_override("shadow_offset_y", 3)
	layer.add_child(osd)
	var sp := osd.duplicate() as Label
	sp.text = "SP  SLOW"
	sp.position = Vector2(60, 110)
	sp.add_theme_font_size_override("font_size", 30)
	layer.add_child(sp)
	var tw := osd.create_tween().set_loops()
	tw.tween_property(osd, "modulate:a", 0.2, 0.5)
	tw.tween_property(osd, "modulate:a", 1.0, 0.5)
	return layer
