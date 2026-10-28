class_name Referee
extends Node3D
## The referee: stays a few paces from the action wherever it is (preferring the far side
## from the hard camera), runs in to count pinfalls, and signals the finish.

signal counted(n: int)

enum Mode { FOLLOW, TO_PIN, COUNT, SIGNAL, WATCH_OUTSIDE }

const WALK := 2.2
const RUN := 5.0
const KEEP_AWAY := 2.6
const COUNT_PERIOD := 0.9

var wrestlers: Array[Wrestler] = []
var model: WrestlerModel
var mode := Mode.FOLLOW
var count := 0
var _pinned: Wrestler
var _t := 0.0
var _anim := ""
var _want := Vector3.INF      # where he's walking to while following the action
var _rethink := 0.0


func _ready() -> void:
	model = WrestlerModel.new()
	model.look = Roster.referee_look()
	add_child(model)
	_play("idle", 0.0)


## Stand at the ropes nearest a wrestler on the floor (count-outs).
func watch_outside(w: Wrestler) -> void:
	if mode in [Mode.FOLLOW, Mode.WATCH_OUTSIDE]:
		mode = Mode.WATCH_OUTSIDE
		_pinned = w


func stop_watching() -> void:
	if mode == Mode.WATCH_OUTSIDE:
		mode = Mode.FOLLOW
		_pinned = null


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
		Mode.WATCH_OUTSIDE:
			if _pinned:
				_move_toward(_clamp_inside(_pinned.global_position), WALK, delta, _pinned.global_position)
		Mode.SIGNAL:
			_t += delta
			if _t > 1.6:
				_play("idle", 0.2)


func _follow(delta: float) -> void:
	var active := wrestlers.filter(func(w: Wrestler) -> bool: return not w.outside and not w.on_apron())
	if active.is_empty():
		active = wrestlers
	if active.is_empty():
		return
	var centre := Vector3.ZERO
	for w in active:
		centre += w.global_position
	centre /= active.size()
	_rethink -= delta
	if _want == Vector3.INF or _rethink <= 0.0:
		_rethink = 0.3
		_want = _best_spot(centre, active)
	_move_toward(_want, WALK, delta, centre)


## A spot a few paces from everyone, inside the ropes: away from the wrestlers first,
## then behind the action as the hard camera sees it, then not too far from where he is.
func _best_spot(centre: Vector3, active: Array) -> Vector3:
	var best := global_position
	var best_score := _spot_score(global_position, centre, active) + 0.5    # stay put unless it's clearly better
	for i in 16:
		var dir := Vector3(sin(TAU * i / 16.0), 0, cos(TAU * i / 16.0))
		for r in [2.4, 3.2]:
			var p := _clamp_inside(centre + dir * r)
			var score := _spot_score(p, centre, active)
			if score > best_score:
				best_score = score
				best = p
	return best


func _spot_score(p: Vector3, centre: Vector3, active: Array) -> float:
	var clear := INF
	for w: Wrestler in active:
		clear = minf(clear, Vector2(p.x - w.global_position.x, p.z - w.global_position.z).length())
	var to_centre := Vector2(p.x - centre.x, p.z - centre.z).length()
	return minf(clear, KEEP_AWAY) * 3.0 \
		- maxf(0.0, p.z - centre.z) * 0.5 \
		- absf(to_centre - KEEP_AWAY - 0.4) * 0.4 \
		- Vector2(p.x - global_position.x, p.z - global_position.z).length() * 0.15


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
	var lim := float(Ring.spec()["post_half"]) - 0.45
	return Vector3(clampf(p.x, -lim, lim), Ring.canvas_height(), clampf(p.z, -lim, lim))


func _play(anim_name: String, blend: float) -> void:
	if _anim == anim_name:
		return
	_anim = anim_name
	model.anim_player.speed_scale = 1.0
	model.play(anim_name, blend)
