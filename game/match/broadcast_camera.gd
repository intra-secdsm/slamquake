class_name BroadcastCamera
extends Camera3D
## Hard-cam style camera: looks across the ring from the +Z side, keeps every
## tracked wrestler framed, eases smoothly, and can shake on big impacts. For
## finishers it cuts to a low, slowly orbiting close-up of the pair.

@export var height := 1.45
@export var base_distance := 4.4
@export var spread_zoom := 0.75
@export var follow_speed := 3.5

var targets: Array[Node3D] = []
var _focus := Vector3(0, 2.0, 0)
var _distance := 8.0
var _shake := 0.0
var _rng := RandomNumberGenerator.new()
var _cine: Array = []
var _cine_left := 0.0
var _cine_angle := 0.0
var _cine_blend := 0.0
var _follow: Node3D
var _follow_wide := false


func _ready() -> void:
	fov = 42.0
	_snap()


## Close-up on `subjects` for `seconds`, viewed side-on to `facing` (from the hard-cam side).
func cinematic(subjects: Array, facing: Vector3, seconds: float) -> void:
	_cine = subjects.filter(func(n: Variant) -> bool: return n is Node3D)
	if _cine.is_empty():
		return
	var side := facing.cross(Vector3.UP)
	if side.z < 0.0:
		side = -side
	_cine_angle = atan2(side.x, side.z) + 0.35
	_cine_left = seconds
	_cine_blend = 0.0


## Entrance camera: walk backwards in front of `target` (null returns to the hard cam).
## `wide` pulls right back to show the stage, the titantron and the pyro behind them.
func follow(target: Node3D, wide := false) -> void:
	var was := _follow
	_follow = target
	_follow_wide = wide
	if target and was == null:
		global_transform = _follow_xform(target)
	elif target == null and was != null:
		_snap()


func _follow_xform(target: Node3D) -> Transform3D:
	var chest := target.global_position + Vector3.UP * 1.35
	var to_ring := Vector3(-chest.x, 0, -chest.z)
	to_ring = to_ring.normalized() if to_ring.length() > 0.5 else Vector3.BACK
	var side := to_ring.cross(Vector3.UP)
	var pos := chest + to_ring * 5.2 + side * 1.5 + Vector3.UP * 0.5
	var aim := chest
	if _follow_wide:
		pos = chest + to_ring * 10.0 + side * 2.2 + Vector3.UP * 0.6
		aim = chest + Vector3.UP * 1.1 - side * 0.6
	var x := Transform3D.IDENTITY.looking_at(aim - pos, Vector3.UP)
	x.origin = pos
	return x


func in_cinematic() -> bool:
	return _cine_left > 0.0


func end_cinematic() -> void:
	_cine_left = 0.0


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _snap() -> void:
	_update(1.0)


func _process(delta: float) -> void:
	if _follow:
		if not is_instance_valid(_follow):
			_follow = null
		else:
			global_transform = global_transform.interpolate_with(_follow_xform(_follow), clampf(delta * 3.0, 0.0, 1.0))
			fov = 50.0
			return
	_update(clampf(delta * follow_speed, 0.0, 1.0))
	if _cine_left > 0.0:
		_cine_left -= delta
		_cine_blend = minf(1.0, _cine_blend + delta * 6.0)
		_cine_angle += delta * 0.35
	else:
		_cine_blend = maxf(0.0, _cine_blend - delta * 2.5)
	if _cine_blend > 0.0:
		_apply_cinematic()
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
	fov = 42.0


func _apply_cinematic() -> void:
	var c := Vector3.ZERO
	var n := 0
	for s in _cine:
		if is_instance_valid(s):
			c += (s as Node3D).global_position
			n += 1
	if n == 0:
		_cine_left = 0.0
		return
	c = c / n + Vector3.UP * 1.35
	var dir := Vector3(sin(_cine_angle), 0.0, cos(_cine_angle))
	var dist := 3.8
	# stay inside the ropes when the action is in the ring, so they don't block the shot
	var lim := float(Ring.spec()["post_half"]) - 0.3
	if absf(c.x) < lim and absf(c.z) < lim:
		for axis: int in [0, 2]:
			if absf(dir[axis]) > 0.001:
				dist = minf(dist, (signf(dir[axis]) * lim - c[axis]) / dir[axis])
	dist = maxf(dist, 1.6)
	var close := c + dir * dist + Vector3.UP * (-0.3 + (3.8 - dist) * 0.25)
	var k := _cine_blend * _cine_blend * (3.0 - 2.0 * _cine_blend)
	var from := global_transform
	var to := Transform3D.IDENTITY.looking_at(c - close, Vector3.UP)
	to.origin = close
	global_transform = from.interpolate_with(to, k)
	fov = lerpf(42.0, 50.0 + (3.8 - dist) * 9.0, k)
