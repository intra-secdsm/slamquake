class_name MenuStage
extends Node3D
## Live backdrop for the front end: the arena with its crowd, and the selected wrestlers
## standing in the ring (right of the menu), with a slowly drifting camera.
## Create-a-wrestler uses preview(): one wrestler on a slow turntable, framed close, or
## ("stage") posing on the entrance stage under their titantron with their pyro going off.

var _models: Array[WrestlerModel] = []
var _cam: Camera3D
var _t := 0.0
var arena: Arena
# create-a-wrestler preview
var _pivot: Node3D
var _hero: WrestlerModel
var _stooge: WrestlerModel       # stand-in opponent for paired moves
var _focus := ""                 # "" = lineup, "full", "head" or "stage"
var _spin := 0.0
var _move := ["", ""]
var _move_wait := 0.0
var _pyro := ""                  # stage preview: pyro style on a loop
var _pyro_color := Color.WHITE
var _pyro_wait := 0.0
var _pyro_id := 0                # instance id of the pyro going off now


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


## One wrestler alone for editing; focus "full" or "head" frames the camera in the ring,
## "stage" puts them on the entrance stage (see preview_entrance).
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
	if _focus == "stage" and focus != "stage":
		_leave_stage()
	_focus = focus
	_pivot.position = Arena.stage_point() if focus == "stage" else Vector3(0.1, Ring.canvas_height(), 0.5)


## The titantron and pyro for the wrestler on the stage; the pyro goes off again whenever
## its style or colour changes, and on a loop while the preview lasts.
func preview_entrance(title: String, subtitle: String, color: Color, motif: String, pyro: String) -> void:
	arena.titantron.show_text(title, subtitle, color, color.lerp(Color.WHITE, 0.4), motif)
	if pyro != _pyro or color != _pyro_color:
		_pyro = pyro
		_pyro_color = color
		_fire_pyro()


func focus() -> String:
	return _focus


func _fire_pyro() -> void:
	var old := instance_from_id(_pyro_id) as Node
	if old and not old.is_queued_for_deletion():
		old.queue_free()
	_pyro_wait = 0.0
	_pyro_id = Pyro.fire(self, Arena.stage_point() + Vector3(0, 0, 1.0), _pyro_color, _pyro).get_instance_id()


func _leave_stage() -> void:
	_pyro = ""
	var old := instance_from_id(_pyro_id) as Node
	if old and not old.is_queued_for_deletion():
		old.queue_free()
	arena.titantron.show_text("WRESTLE", "LIVE TONIGHT")


## Show a move on the preview wrestler (paired moves get the stand-in opponent); "" = idle.
func preview_move(anim_a: String, anim_d: String = "") -> void:
	if _hero == null:
		return
	_move = [anim_a, anim_d]
	_move_wait = 0.0
	_start_move()


func end_preview() -> void:
	if _focus == "stage":
		_leave_stage()
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
	if _focus == "stage":
		_stage_view(delta)
		return
	# moves play facing the camera at a three-quarter angle; otherwise the wrestler turns slowly
	if _move[0] != "":
		_pivot.rotation.y = lerp_angle(_pivot.rotation.y, -0.7, delta * 4.0)
		_loop_move(delta)
	else:
		_spin += delta * 0.45
		_pivot.rotation.y = sin(_spin) * 0.9
	var p := _pivot.position
	var eye := Vector3(p.x - 1.75, y + 1.45, p.z + 3.9)
	var at := Vector3(p.x - 0.95, y + 0.95, p.z)
	if _focus == "head":
		eye = Vector3(p.x - 0.42, y + 1.78, p.z + 1.25)
		at = Vector3(p.x - 0.22, y + 1.66, p.z)
	_ease_camera(eye, at, delta)


func _ease_camera(eye: Vector3, at: Vector3, delta: float) -> void:
	var want := Transform3D(Basis.IDENTITY, eye).looking_at(at)
	_cam.global_transform = _cam.global_transform.interpolate_with(want, minf(1.0, delta * 5.0))


## Looking up the aisle at the stage: the wrestler posing, the titantron above, pyro on a loop.
func _stage_view(delta: float) -> void:
	_pivot.rotation.y = lerp_angle(_pivot.rotation.y, 0.25, delta * 4.0)
	_loop_move(delta)
	if _pyro != "":
		_pyro_wait += delta
		if _pyro_wait > Pyro.show_time(_pyro) + 1.6:
			_fire_pyro()
	var s := Arena.stage_point()
	_ease_camera(s + Vector3(1.6, 1.8, 9.5), s + Vector3(-2.4, 2.4, 0.0), delta)


func _loop_move(delta: float) -> void:
	if _move[0] != "" and (not _hero.anim_player.is_playing() or _hero.anim_player.current_animation != _move[0]):
		_move_wait += delta
		if _move_wait > 0.8:       # a beat on the final pose, then again
			_move_wait = 0.0
			_start_move()
