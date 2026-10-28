class_name MenuStage
extends Node3D
## Live backdrop for the front end: the arena with its crowd, and the selected wrestlers
## standing in the ring (right of the menu), with a slowly drifting camera.

var _models: Array[WrestlerModel] = []
var _cam: Camera3D
var _t := 0.0
var arena: Arena


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


func _process(delta: float) -> void:
	_t += delta
	var y := Ring.canvas_height()
	var swing := sin(_t * 0.12) * 0.6
	_cam.look_at_from_position(Vector3(-2.6 + swing, y + 1.7, 5.6), Vector3(-1.4 + swing * 0.5, y + 1.15, 0.0))
