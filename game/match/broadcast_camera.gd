class_name BroadcastCamera
extends Camera3D
## Hard-cam style camera: looks across the ring from the +Z side, keeps every
## tracked wrestler framed, eases smoothly, and can shake on big impacts.

@export var height := 1.45
@export var base_distance := 4.4
@export var spread_zoom := 0.75
@export var follow_speed := 3.5

var targets: Array[Node3D] = []
var _focus := Vector3(0, 2.0, 0)
var _distance := 8.0
var _shake := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	fov = 42.0
	_snap()


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _snap() -> void:
	_update(1.0)


func _process(delta: float) -> void:
	_update(clampf(delta * follow_speed, 0.0, 1.0))
	if _shake > 0.0:
		h_offset = _rng.randf_range(-1, 1) * _shake * 0.08
		v_offset = _rng.randf_range(-1, 1) * _shake * 0.08
		_shake = move_toward(_shake, 0.0, delta * 4.0)
	else:
		h_offset = 0.0
		v_offset = 0.0


func _update(t: float) -> void:
	if targets.is_empty():
		return
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for n in targets:
		lo = lo.min(n.global_position)
		hi = hi.max(n.global_position)
	var centre := (lo + hi) * 0.5
	var spread := maxf(hi.x - lo.x, (hi.z - lo.z) * 0.6)
	var want_focus := Vector3(centre.x * 0.85, centre.y + 0.85, centre.z * 0.6)
	var want_distance := base_distance + spread * spread_zoom
	_focus = _focus.lerp(want_focus, t)
	_distance = lerpf(_distance, want_distance, t)
	var pos := _focus + Vector3(0, height + _distance * 0.1, _distance)
	look_at_from_position(pos, _focus)
