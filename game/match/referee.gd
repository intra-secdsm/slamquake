class_name Referee
extends Node3D
## The referee: stays near the action without getting in the way (on the far side
## from the hard camera), runs in to count pinfalls, and signals the finish.

signal counted(n: int)

enum Mode { FOLLOW, TO_PIN, COUNT, SIGNAL }

const WALK := 2.2
const RUN := 5.0
const KEEP_AWAY := 1.5
const COUNT_PERIOD := 0.9

var wrestlers: Array[Wrestler] = []
var model: WrestlerModel
var mode := Mode.FOLLOW
var count := 0
var _pinned: Wrestler
var _t := 0.0
var _anim := ""


func _ready() -> void:
	model = WrestlerModel.new()
	model.look = Roster.referee_look()
	add_child(model)
	_play("idle", 0.0)


func start_count(pinned: Wrestler) -> void:
	_pinned = pinned
	count = 0
	mode = Mode.TO_PIN


func stop_count() -> void:
	if mode in [Mode.TO_PIN, Mode.COUNT]:
		mode = Mode.FOLLOW
		_pinned = null


func signal_finish() -> void:
	mode = Mode.SIGNAL
	_t = 0.0
	_play("ref_signal", 0.15)


func is_counting() -> bool:
	return mode == Mode.COUNT


func _physics_process(delta: float) -> void:
	match mode:
		Mode.FOLLOW: _follow(delta)
		Mode.TO_PIN: _to_pin(delta)
		Mode.COUNT: _count(delta)
		Mode.SIGNAL:
			_t += delta
			if _t > 1.6:
				_play("idle", 0.2)


func _follow(delta: float) -> void:
	if wrestlers.is_empty():
		return
	var centre := Vector3.ZERO
	for w in wrestlers:
		centre += w.global_position
	centre /= wrestlers.size()
	# stand behind the action as seen from the hard camera (+Z side)
	var want := centre + Vector3(0, 0, -2.2)
	for w in wrestlers:
		var away := want - w.global_position
		away.y = 0
		if away.length() < KEEP_AWAY:
			want = w.global_position + away.normalized() * KEEP_AWAY if away.length() > 0.01 else want + Vector3.BACK
	want = _clamp_inside(want)
	_move_toward(want, WALK, delta, centre)


func _to_pin(delta: float) -> void:
	if _pinned == null:
		mode = Mode.FOLLOW
		return
	var spot := _count_spot()
	if _move_toward(spot, RUN, delta, _pinned.head_position()):
		mode = Mode.COUNT
		_t = 0.0
		_play("ref_count", 0.2)


func _count(delta: float) -> void:
	if _pinned == null:
		mode = Mode.FOLLOW
		return
	_face(_pinned.head_position())
	_t += delta
	var slap := float(WrestlerModel.manifest()["animations"]["ref_count"]["events"]["slap"])
	if _t >= slap + count * COUNT_PERIOD:
		count += 1
		AudioDirector.play("mat_slap", global_position + Vector3.UP * 0.1)
		counted.emit(count)
		if count >= 3:
			signal_finish()


## Kneel beside the pinned wrestler's head, on the side away from the camera.
func _count_spot() -> Vector3:
	var head := _pinned.head_position()
	var side := _pinned.facing().cross(Vector3.UP).normalized()
	if side.z > 0.0:
		side = -side
	return _clamp_inside(head + side * 0.55 - _pinned.facing() * 0.2)


func _move_toward(target: Vector3, speed: float, delta: float, look_at_point: Vector3) -> bool:
	var to := target - global_position
	to.y = 0
	var d := to.length()
	if d < 0.12:
		_face(look_at_point)
		if mode == Mode.FOLLOW:
			_play("idle", 0.25)
		return true
	var step := minf(d, speed * delta)
	global_position += to / d * step
	if d > 0.6:
		_face(global_position + to)
	else:
		_face(look_at_point)
	_play("run" if speed > WALK else "walk", 0.2)
	model.anim_player.speed_scale = 1.0 if speed > WALK else 0.9
	return false


func _face(point: Vector3) -> void:
	var d := point - global_position
	d.y = 0
	if d.length_squared() > 1e-4:
		rotation.y = atan2(d.x, d.z)


func _clamp_inside(p: Vector3) -> Vector3:
	var lim := float(Ring.spec()["post_half"]) - 0.5
	return Vector3(clampf(p.x, -lim, lim), Ring.canvas_height(), clampf(p.z, -lim, lim))


func _play(anim_name: String, blend: float) -> void:
	if _anim == anim_name:
		return
	_anim = anim_name
	model.anim_player.speed_scale = 1.0
	model.play(anim_name, blend)
