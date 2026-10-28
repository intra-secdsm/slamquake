class_name MenuStage
extends Node3D
## Live backdrop for the front end: the arena with its crowd, and the selected wrestlers
## standing in the ring (right of the menu), with a slowly drifting camera.
## Create-a-wrestler uses preview(): one wrestler on a slow turntable, framed close.

var _models: Array[WrestlerModel] = []
var _cam: Camera3D
var _t := 0.0
var arena: Arena
# create-a-wrestler preview
var _pivot: Node3D
var _hero: WrestlerModel
var _stooge: WrestlerModel       # stand-in opponent for paired moves
var _focus := ""                 # "" = lineup, "full" or "head"
var _spin := 0.0
var _move := ["", ""]
var _move_wait := 0.0


func _ready() -> void:
	add_child(ArenaLighting.new())
	arena = Arena.new()
	add_child(arena)
	arena.heat = 0.45
	add_child(Ring.new())
	_cam = Camera3D.new()
	_cam.fov = 45
	add_child(_cam)
	_cam.current = true


## Put these looks in the ring, facing the camera (up to four).
func show_lineup(looks: Array) -> void:
	end_preview()
	var y := Ring.canvas_height()
	while _models.size() < looks.size():
		var m := WrestlerModel.new()
		add_child(m)
		m.play("idle", 0.0)
		m.anim_player.seek(randf() * 2.0, true)
		_models.append(m)
	for i in _models.size():
		var m := _models[i]
		m.visible = i < looks.size()
		if not m.visible:
			continue
		m.look = looks[i]
		m.apply_look()
		var n := looks.size()
		m.position = Vector3(0.2 + (i - (n - 1) * 0.5) * 1.15, y, 0.6 - absf(i - (n - 1) * 0.5) * 0.35)
		m.rotation.y = 0.25 - i * 0.12


## One wrestler alone in the ring for editing; focus "full" or "head" frames the camera.
func preview(look: WrestlerLook, focus: String = "full") -> void:
	for m in _models:
		m.visible = false
	if _pivot == null:
		_pivot = Node3D.new()
		add_child(_pivot)
		_pivot.position = Vector3(0.1, Ring.canvas_height(), 0.5)
		_hero = WrestlerModel.new()
		_pivot.add_child(_hero)
		_hero.play("idle", 0.0)
		_stooge = WrestlerModel.new()
		var plain := WrestlerLook.new()
		plain.trunks_color = Color(0.35, 0.35, 0.4)
		plain.trim_color = Color(0.5, 0.5, 0.55)
		plain.pads_color = Color(0.35, 0.35, 0.4)
		plain.hair_style = "bald"
		_stooge.look = plain
		_pivot.add_child(_stooge)
		_stooge.visible = false
	_pivot.visible = true
	_hero.look = look
	_hero.apply_look()
	_focus = focus


## Show a move on the preview wrestler (paired moves get the stand-in opponent); "" = idle.
func preview_move(anim_a: String, anim_d: String = "") -> void:
	if _hero == null:
		return
	_move = [anim_a, anim_d]
	_move_wait = 0.0
	_start_move()


func end_preview() -> void:
	_focus = ""
	if _pivot:
		_pivot.visible = false
	for m in _models:
		m.visible = true


func _start_move() -> void:
	var a: String = _move[0]
	if a == "" or not _hero.has_animation(a):
		_stooge.visible = false
		_hero.play("idle", 0.2)
		return
	_hero.play(a, 0.1)
	_hero.anim_player.seek(0.0, true)
	var d: String = _move[1]
	_stooge.visible = d != "" and _stooge.has_animation(d)
	if _stooge.visible:
		_stooge.play(d, 0.0)
		_stooge.anim_player.seek(0.0, true)


func _process(delta: float) -> void:
	_t += delta
	var y := Ring.canvas_height()
	if _focus == "":
		var swing := sin(_t * 0.12) * 0.6
		_cam.look_at_from_position(Vector3(-2.6 + swing, y + 1.7, 5.6), Vector3(-1.4 + swing * 0.5, y + 1.15, 0.0))
		return
	# moves play facing the camera at a three-quarter angle; otherwise the wrestler turns slowly
	if _move[0] != "":
		_pivot.rotation.y = lerp_angle(_pivot.rotation.y, -0.7, delta * 4.0)
		if not _hero.anim_player.is_playing() or _hero.anim_player.current_animation != _move[0]:
			_move_wait += delta
			if _move_wait > 0.8:       # a beat on the final pose, then again
				_move_wait = 0.0
				_start_move()
	else:
		_spin += delta * 0.45
		_pivot.rotation.y = sin(_spin) * 0.9
	var p := _pivot.position
	var eye := Vector3(p.x - 1.75, y + 1.45, p.z + 3.9)
	var at := Vector3(p.x - 0.95, y + 0.95, p.z)
	if _focus == "head":
		eye = Vector3(p.x - 0.42, y + 1.78, p.z + 1.25)
		at = Vector3(p.x - 0.22, y + 1.66, p.z)
	var want := Transform3D(Basis.IDENTITY, eye).looking_at(at)
	_cam.global_transform = _cam.global_transform.interpolate_with(want, minf(1.0, delta * 5.0))
