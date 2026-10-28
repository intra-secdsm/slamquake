class_name Wrestler
extends CharacterBody3D
## A wrestler in a match: movement, strikes, blocking, hit reactions, knockdowns and
## rope rebounds, driven by a WrestlerController (human or CPU).

signal health_changed(w: Wrestler)
signal struck(attacker: Wrestler, victim: Wrestler, move: Dictionary, blocked: bool)
signal knocked_down(w: Wrestler)
signal landed_on_canvas(w: Wrestler)

enum State { IDLE, RUN, STRIKE, BLOCK, HITSTUN, KNOCKDOWN, DOWN, GETUP, REBOUND, TAUNT }

const WALK_SPEED := 2.5
const RUN_SPEED := 6.4
const RUN_STEER := 2.2           # rad/s
const GRAVITY := 22.0
const MAX_HEALTH := 100.0
const ROPE_MARGIN := 0.42        # how close to the rope line a body centre can get
const DOWN_BASE := 1.4           # seconds on the mat before getting up (plus damage)
const INPUT_BUFFER := 0.22
const LOCK_ON_RANGE := 3.0

@export var look: WrestlerLook
@export var display_name := "Wrestler"

var controller: WrestlerController
var opponents: Array[Wrestler] = []
var ring: Ring
var model: WrestlerModel
var state: State = State.IDLE
var state_time := 0.0
var health := MAX_HEALTH
var invulnerable := false
var infinite_health := false

var _move: Dictionary = {}
var _hit_done := false
var _buffered := ""
var _buffer_time := 0.0
var _freeze := 0.0
var _push := Vector3.ZERO        # decaying knockback / lunge velocity
var _down_left := 0.0
var _run_dir := Vector3.FORWARD
var _auto_run := 0.0
var _combo_hits := 0
var _combo_timer := 0.0
var _rope_normal := Vector3.ZERO
var _rope_point := Vector3.ZERO
var _rebounded := false
var _anim := ""


func _ready() -> void:
	collision_layer = 2
	collision_mask = 3
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.85
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.925
	add_child(cs)
	model = WrestlerModel.new()
	model.look = look if look else WrestlerLook.new()
	add_child(model)
	_enter(State.IDLE)


# ---------------------------------------------------------------- queries

func facing() -> Vector3:
	return global_basis.z


func is_standing() -> bool:
	return state not in [State.KNOCKDOWN, State.DOWN, State.GETUP]


func can_be_hit() -> bool:
	return not invulnerable and state not in [State.KNOCKDOWN, State.DOWN, State.GETUP]


func nearest_opponent() -> Wrestler:
	var best: Wrestler = null
	var best_d := INF
	for o in opponents:
		var d := global_position.distance_squared_to(o.global_position)
		if d < best_d:
			best_d = d
			best = o
	return best


func flat_dir_to(o: Node3D) -> Vector3:
	var d := o.global_position - global_position
	d.y = 0
	return d.normalized() if d.length_squared() > 1e-6 else facing()


# ---------------------------------------------------------------- main loop

func _physics_process(delta: float) -> void:
	if controller:
		controller.update(self, delta)
		_buffer_inputs(delta)
	if _freeze > 0.0:
		_freeze -= delta
		if _freeze <= 0.0:
			model.anim_player.speed_scale = 1.0
		return

	state_time += delta
	_combo_timer -= delta
	if _combo_timer <= 0.0:
		_combo_hits = 0

	match state:
		State.IDLE: _st_idle(delta)
		State.RUN: _st_run(delta)
		State.STRIKE: _st_strike(delta)
		State.BLOCK: _st_block(delta)
		State.HITSTUN: _st_timed(delta, float(_move.get("stun", 0.4)))
		State.KNOCKDOWN: _st_knockdown(delta)
		State.DOWN: _st_down(delta)
		State.GETUP: _st_getup(delta)
		State.REBOUND: _st_rebound(delta)
		State.TAUNT: _st_timed(delta, _anim_length("taunt"))

	_push = _push.move_toward(Vector3.ZERO, 9.0 * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_confine_to_ring()


func _buffer_inputs(delta: float) -> void:
	_buffer_time -= delta
	if controller.punch:
		_buffered = "punch"
		_buffer_time = INPUT_BUFFER
	elif controller.kick:
		_buffered = "kick"
		_buffer_time = INPUT_BUFFER
	if _buffer_time <= 0.0:
		_buffered = ""


func _take_buffered() -> String:
	var b := _buffered
	_buffered = ""
	return b


# ---------------------------------------------------------------- states

func _enter(s: State) -> void:
	state = s
	state_time = 0.0
	invulnerable = s == State.GETUP
	match s:
		State.IDLE: _play("idle", 0.2)
		State.RUN: _play("run", 0.12)
		State.BLOCK: _play("block", 0.08)
		State.KNOCKDOWN: _play("knockdown", 0.05)
		State.DOWN: _play("down", 0.25)
		State.GETUP: _play("getup", 0.15)
		State.TAUNT: _play("taunt", 0.15)
		State.REBOUND: _play("rope_rebound", 0.06)


func _st_idle(delta: float) -> void:
	var c := controller
	var attack := _take_buffered()
	if attack != "":
		_start_strike("big_boot" if attack == "kick" else "jab")
		return
	if c and c.block_held:
		_enter(State.BLOCK)
		return
	if c and c.taunt:
		_enter(State.TAUNT)
		return
	var mv := c.move if c else Vector3.ZERO
	if c and c.run_held:
		_run_dir = mv.normalized() if mv.length() > 0.3 else facing()
		_face(_run_dir, 0.0, true)
		_auto_run = 0.0
		_enter(State.RUN)
		return

	velocity.x = mv.x * WALK_SPEED + _push.x
	velocity.z = mv.z * WALK_SPEED + _push.z
	var target := nearest_opponent()
	if mv.length() > 0.15:
		_face(mv, delta * 10.0)
	elif target and global_position.distance_to(target.global_position) < LOCK_ON_RANGE:
		_face(flat_dir_to(target), delta * 4.0)
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed > 0.3:
		_play("walk", 0.2)
		model.anim_player.speed_scale = clampf(speed / WALK_SPEED, 0.5, 1.3)
	else:
		_play("idle", 0.25)
		model.anim_player.speed_scale = 1.0


func _st_run(delta: float) -> void:
	var c := controller
	if c and c.move.length() > 0.3:
		var desired := c.move.normalized()
		var ang := _run_dir.signed_angle_to(desired, Vector3.UP)
		_run_dir = _run_dir.rotated(Vector3.UP, clampf(ang, -RUN_STEER * delta, RUN_STEER * delta))
	_face(_run_dir, 0.0, true)
	velocity.x = _run_dir.x * RUN_SPEED
	velocity.z = _run_dir.z * RUN_SPEED

	var attack := _take_buffered()
	if attack != "":
		_start_strike("clothesline")
		return
	_auto_run -= delta
	var held := c != null and c.run_held
	if not held and _auto_run <= 0.0 and state_time > 0.25:
		_push = _run_dir * RUN_SPEED * 0.5
		_enter(State.IDLE)
		return
	if _hits_ropes():
		_enter(State.REBOUND)


func _st_rebound(_delta: float) -> void:
	var release := float(_event("rope_rebound", "release", 0.26))
	velocity.x = 0.0
	velocity.z = 0.0
	# lean back into the ropes, deepest midway through the contact
	var lean := sin(clampf(state_time / release, 0.0, 1.0) * PI) * 0.45 if state_time < release else 0.0
	var edge := _rope_limit() + lean
	if _rope_normal.x != 0.0:
		position.x = -_rope_normal.x * edge
	else:
		position.z = -_rope_normal.z * edge
	if state_time < release and ring:
		ring.ropes.press(_rope_point, -_rope_normal * maxf(0.0, lean - 0.17))
	elif not _rebounded:
		_rebounded = true
		if ring:
			ring.ropes.push(_rope_point, _rope_normal * 1.0)
		AudioDirector.play("rope", _rope_point, -4.0)
		_run_dir = _run_dir.bounce(_rope_normal).normalized()
		_run_dir.y = 0
		_face(_run_dir, 0.0, true)
	if state_time >= _anim_length("rope_rebound") - 0.05:
		_auto_run = 0.9
		_enter(State.RUN)


func _start_strike(id: String) -> void:
	_move = Strikes.get_move(id)
	_hit_done = false
	var target := nearest_opponent()
	if target and global_position.distance_to(target.global_position) < LOCK_ON_RANGE:
		var to := flat_dir_to(target)
		if facing().angle_to(to) < deg_to_rad(110):
			_face(to, 0.0, true)
	if id == "clothesline":
		_push = _run_dir * RUN_SPEED * 0.7
	state = State.STRIKE
	state_time = 0.0
	invulnerable = false
	_play(_move["anim"], 0.05, true)


func _st_strike(_delta: float) -> void:
	var lunge_time := float(_move["hit_time"]) + 0.05
	var lunge := float(_move.get("lunge", 0.0)) if state_time < lunge_time else 0.0
	velocity.x = facing().x * lunge + _push.x
	velocity.z = facing().z * lunge + _push.z
	if not _hit_done and state_time >= float(_move["hit_time"]):
		_hit_done = true
		_resolve_hit()
	# combo chain: past the cancel point a punch continues the chain, a kick finishes it
	if _move.has("next") and state_time >= float(_move.get("cancel", 99.0)) and _buffered != "":
		var next: String = _move["next"] if _take_buffered() == "punch" else "big_boot"
		_start_strike(next)
		return
	if state_time >= float(_move["length"]) - 0.04:
		_enter(State.IDLE)


func _resolve_hit() -> void:
	var landed := false
	for o in opponents:
		if not o.can_be_hit():
			continue
		var to := o.global_position - global_position
		to.y = 0
		var d := to.length()
		if d > float(_move["reach"]):
			continue
		if d > 0.05 and rad_to_deg(facing().angle_to(to)) > float(_move["arc"]):
			continue
		o.receive_strike(self, _move)
		landed = true
	if not landed:
		AudioDirector.play("whoosh", global_position + Vector3.UP * 1.4, -8.0)


func receive_strike(attacker: Wrestler, mv: Dictionary) -> void:
	var from := flat_dir_to(attacker)
	var stop := float(mv.get("hitstop", 0.07))
	if state == State.BLOCK and facing().dot(from) > 0.3:
		_push = -from * 2.0
		freeze(0.05)
		attacker.freeze(0.05)
		AudioDirector.play("block", global_position + Vector3.UP * 1.3, -2.0)
		struck.emit(attacker, self, mv, true)
		return

	var was_stunned := state == State.HITSTUN
	if not infinite_health:
		health = maxf(0.0, health - float(mv["damage"]))
	health_changed.emit(self)
	_combo_hits += 1
	_combo_timer = 1.6
	_face(from, 0.0, true)
	freeze(stop)
	attacker.freeze(stop)
	AudioDirector.play(mv.get("sfx", "hit_light"), global_position + Vector3.UP * 1.4)
	struck.emit(attacker, self, mv, false)

	var knock: bool = mv.get("knockdown", false) or health <= 0.0 or _combo_hits >= 4 \
		or (mv.get("knockdown_if_stunned", false) and (was_stunned or _combo_hits >= 2))
	if knock:
		_push = -from * float(mv.get("knockback", 3.0))
		_combo_hits = 0
		_enter(State.KNOCKDOWN)
		knocked_down.emit(self)
	else:
		_push = -from * 1.3
		_move = mv
		state = State.HITSTUN
		state_time = 0.0
		_play("hit_body" if mv.get("region", "head") == "body" else "hit_head", 0.03, true)


func _st_block(_delta: float) -> void:
	velocity.x = _push.x
	velocity.z = _push.z
	var target := nearest_opponent()
	if target:
		_face(flat_dir_to(target), 0.2)
	if controller == null or not controller.block_held:
		_enter(State.IDLE)


func _st_timed(_delta: float, duration: float) -> void:
	velocity.x = _push.x
	velocity.z = _push.z
	if state_time >= duration:
		_enter(State.IDLE)


func _st_knockdown(_delta: float) -> void:
	velocity.x = _push.x
	velocity.z = _push.z
	var impact := float(_event("knockdown", "impact", 0.5))
	if state_time >= impact and state_time - get_physics_process_delta_time() < impact:
		AudioDirector.play("body_fall", global_position + Vector3.UP * 0.3)
		landed_on_canvas.emit(self)
	if state_time >= _anim_length("knockdown"):
		_down_left = DOWN_BASE + (1.0 - health / MAX_HEALTH) * 2.5
		_enter(State.DOWN)


func _st_down(delta: float) -> void:
	velocity.x = _push.x
	velocity.z = _push.z
	_down_left -= delta
	if controller and controller.mash:
		_down_left -= 0.12
	if _down_left <= 0.0 and (health > 0.0 or infinite_health):
		_enter(State.GETUP)


func _st_getup(_delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if state_time >= _anim_length("getup"):
		_enter(State.IDLE)


# ---------------------------------------------------------------- helpers

func freeze(seconds: float) -> void:
	_freeze = maxf(_freeze, seconds)
	model.anim_player.speed_scale = 0.0


func restore_health() -> void:
	health = MAX_HEALTH
	health_changed.emit(self)


func _face(dir: Vector3, weight: float, instant: bool = false) -> void:
	dir.y = 0
	if dir.length_squared() < 1e-6:
		return
	var target_yaw := atan2(dir.x, dir.z)
	rotation.y = target_yaw if instant else lerp_angle(rotation.y, target_yaw, clampf(weight, 0.0, 1.0))


func _play(anim_name: String, blend: float, restart: bool = false) -> void:
	if _anim == anim_name and not restart:
		return
	_anim = anim_name
	model.anim_player.speed_scale = 1.0
	if restart and model.anim_player.current_animation == anim_name:
		model.anim_player.seek(0.0, true)
	model.play(anim_name, blend)


func _anim_length(anim_name: String) -> float:
	return float(WrestlerModel.manifest()["animations"][anim_name]["length"])


func _event(anim_name: String, ev: String, default: float) -> float:
	return float(WrestlerModel.manifest()["animations"][anim_name]["events"].get(ev, default))


func _rope_limit() -> float:
	return float(Ring.spec()["post_half"]) - ROPE_MARGIN


func _hits_ropes() -> bool:
	var lim := _rope_limit() - 0.01  # positions are float32; clamped values sit just under lim
	var p := global_position
	var n := Vector3.ZERO
	if p.x >= lim and _run_dir.x > 0.2:
		n = Vector3(-1, 0, 0)
	elif p.x <= -lim and _run_dir.x < -0.2:
		n = Vector3(1, 0, 0)
	elif p.z >= lim and _run_dir.z > 0.2:
		n = Vector3(0, 0, -1)
	elif p.z <= -lim and _run_dir.z < -0.2:
		n = Vector3(0, 0, 1)
	if n == Vector3.ZERO:
		return false
	_rope_normal = n
	# contact point on the rope line at mid-back height
	var rope_line := float(Ring.spec()["post_half"]) - 0.09
	_rope_point = Vector3(p.x, Ring.canvas_height() + 1.0, p.z)
	if n.x != 0.0:
		_rope_point.x = -n.x * rope_line
	else:
		_rope_point.z = -n.z * rope_line
	_rebounded = false
	return true


func _confine_to_ring() -> void:
	var lim := _rope_limit() + (0.5 if state == State.REBOUND else 0.0)
	position.x = clampf(position.x, -lim, lim)
	position.z = clampf(position.z, -lim, lim)
