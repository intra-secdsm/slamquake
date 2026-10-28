class_name Wrestler
extends CharacterBody3D
## A wrestler in a match, driven by a WrestlerController (human or CPU).
## Movement, strikes, blocking, knockdowns, rope rebounds, grapples (tie-ups and paired
## moves), Irish whips into the ropes and corners, ground offence and pinfalls.

signal health_changed(w: Wrestler)
signal struck(attacker: Wrestler, victim: Wrestler, move: Dictionary, blocked: bool)
signal knocked_down(w: Wrestler)
signal landed_on_canvas(w: Wrestler)
signal pin_started(attacker: Wrestler, defender: Wrestler)
signal kicked_out(defender: Wrestler)
signal move_performed(attacker: Wrestler, id: String)

enum State {
	IDLE, RUN, STRIKE, BLOCK, HITSTUN, KNOCKDOWN, DOWN, GETUP, REBOUND, TAUNT,
	GRAB_WHIFF, TIEUP, HELD, PAIRED, WHIPPED, CORNER_HIT, CORNERED, CORNER_EXIT,
	STOMP, DOWN_HIT, PINNING, PINNED, KICKOUT, COVER_RELEASE, STUN, CELEBRATE,
}

const WALK_SPEED := 2.5
const RUN_SPEED := 6.4
const WHIP_SPEED := 6.0
const RUN_STEER := 2.2           # rad/s
const GRAVITY := 22.0
const MAX_HEALTH := 100.0
const DAMAGE_SCALE := 0.55       # global tuning knob for match length
const ROPE_MARGIN := 0.42        # how close to the rope line a body centre can get
const DOWN_BASE := 1.4           # seconds on the mat before getting up (plus damage)
const INPUT_BUFFER := 0.22
const LOCK_ON_RANGE := 3.0
const GRAB_RANGE := 1.15
const GROUND_RANGE := 1.1        # reach to a downed opponent's body line
const TIEUP_TIMEOUT := 1.8
const CORNER_TIME := 2.4
const STUN_TIME := 1.1

const DOWNED := [State.KNOCKDOWN, State.DOWN, State.GETUP, State.DOWN_HIT, State.PINNED, State.KICKOUT]
const BUSY := [State.TIEUP, State.HELD, State.PAIRED, State.PINNING, State.PINNED, State.CELEBRATE]

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
var match_over := false

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

# grappling
var partner: Wrestler            # opponent we're locked up / paired with
var _pair: Dictionary = {}
var _anchor := Transform3D.IDENTITY
var _role := ""                  # "a" attacker / "d" defender in a paired move
var _impact_done := false
var _anchor_base := Transform3D.IDENTITY
var _anchor_shift := Vector3.ZERO     # slide applied over the start of a move to keep it inside the ropes
var _released := false
var _whip_dir := Vector3.FORWARD
var _whipped := false
var _rebounds := 0
var _corner := -1
var _kickout_need := 0
var _kickout_have := 0


func _ready() -> void:
	_set_solid(true)
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


func model_scale() -> float:
	return model.look.height if model and model.look else 1.0


func is_standing() -> bool:
	return state not in DOWNED


func is_down() -> bool:
	return state in [State.DOWN, State.DOWN_HIT, State.KNOCKDOWN]


func is_running() -> bool:
	return state in [State.RUN, State.WHIPPED]


func can_be_hit() -> bool:
	return not invulnerable and state not in DOWNED and state not in BUSY


func can_be_grappled() -> bool:
	return state in [State.IDLE, State.BLOCK, State.HITSTUN, State.STUN, State.TAUNT, State.CORNERED,
		State.STRIKE, State.GRAB_WHIFF, State.CORNER_EXIT]


## Where a downed wrestler's head is (DOWN poses lie with the head behind the root).
func head_position() -> Vector3:
	return global_position - facing() * 0.8 * model_scale()


## Middle of the body for ground attacks and effects.
func body_center() -> Vector3:
	if is_down() or state == State.PINNED:
		return global_position - facing() * 0.35 * model_scale() + Vector3.UP * 0.2
	return global_position + Vector3.UP * 1.2


## Horizontal distance from p to a downed wrestler's body (head-to-feet line).
func distance_to_body(p: Vector3) -> float:
	if not (is_down() or state == State.PINNED):
		return Vector2(p.x - global_position.x, p.z - global_position.z).length()
	var head := head_position()
	var feet := global_position + facing() * 0.9 * model_scale()
	var q := Geometry3D.get_closest_point_to_segment(Vector3(p.x, 0, p.z), Vector3(head.x, 0, head.z), Vector3(feet.x, 0, feet.z))
	return q.distance_to(Vector3(p.x, 0, p.z))


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
	return _flat(o.global_position - global_position, facing())


func pinned_by() -> Wrestler:
	return partner if state == State.PINNED else null


func kickout_progress() -> float:
	return float(_kickout_have) / maxf(1.0, float(_kickout_need))


# ---------------------------------------------------------------- main loop

func _physics_process(delta: float) -> void:
	if controller and not match_over:
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
		State.HITSTUN: _st_timed(float(_move.get("stun", 0.4)))
		State.KNOCKDOWN: _st_knockdown(delta)
		State.DOWN: _st_down(delta)
		State.GETUP: _st_anim_then_idle("getup")
		State.REBOUND: _st_rebound(delta)
		State.TAUNT: _st_anim_then_idle("taunt")
		State.GRAB_WHIFF: _st_anim_then_idle("grab_whiff")
		State.TIEUP: _st_tieup(delta)
		State.HELD: _hold_still()
		State.PAIRED: _st_paired(delta)
		State.WHIPPED: _st_whipped(delta)
		State.CORNER_HIT: _st_corner_hit(delta)
		State.CORNERED: _st_cornered(delta)
		State.CORNER_EXIT: _st_anim_then_idle("corner_exit")
		State.STOMP: _st_stomp(delta)
		State.DOWN_HIT: _st_down_hit(delta)
		State.PINNING: _hold_still()
		State.PINNED: _st_pinned(delta)
		State.KICKOUT: _st_kickout(delta)
		State.COVER_RELEASE: _st_anim_then_idle("cover_release")
		State.STUN: _st_timed(STUN_TIME)
		State.CELEBRATE: _st_celebrate(delta)

	_push = _push.move_toward(Vector3.ZERO, 9.0 * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_confine_to_ring()


func _buffer_inputs(delta: float) -> void:
	_buffer_time -= delta
	for b in ["punch", "kick", "grapple", "block"]:
		var pressed: bool = controller.get(b) if b != "block" else controller.block_pressed
		if pressed:
			_buffered = b
			_buffer_time = INPUT_BUFFER
	if _buffer_time <= 0.0:
		_buffered = ""


func _take_buffered() -> String:
	var b := _buffered
	_buffered = ""
	return b


# ---------------------------------------------------------------- basic states

func _enter(s: State, blend: float = -1.0) -> void:
	state = s
	state_time = 0.0
	invulnerable = s == State.GETUP
	var anims := {
		State.IDLE: ["idle", 0.2], State.RUN: ["run", 0.12], State.BLOCK: ["block", 0.08],
		State.KNOCKDOWN: ["knockdown", 0.05], State.DOWN: ["down", 0.25], State.GETUP: ["getup", 0.15],
		State.TAUNT: ["taunt", 0.15], State.REBOUND: ["rope_rebound", 0.06], State.GRAB_WHIFF: ["grab_whiff", 0.06],
		State.WHIPPED: ["run", 0.1], State.CORNER_HIT: ["corner_hit", 0.05], State.CORNERED: ["corner_slump", 0.2],
		State.CORNER_EXIT: ["corner_exit", 0.15], State.STOMP: ["stomp", 0.08], State.DOWN_HIT: ["down_hit", 0.04],
		State.PINNING: ["cover_hold", 0.0], State.PINNED: ["down", 0.0], State.KICKOUT: ["kickout", 0.05],
		State.COVER_RELEASE: ["cover_release", 0.0], State.STUN: ["groggy", 0.15], State.CELEBRATE: ["taunt", 0.2],
	}
	if anims.has(s):
		_play(anims[s][0], anims[s][1] if blend < 0.0 else blend, true)


func _st_idle(delta: float) -> void:
	var c := controller
	var action := _take_buffered()
	if action != "" and _try_action(action):
		return
	if c and c.block_held and action == "":
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
		_whipped = false
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


## Context-sensitive offence from a buffered button. Returns true if something started.
func _try_action(action: String) -> bool:
	var target := nearest_opponent()
	var downed := target != null and target.is_down() and target.distance_to_body(global_position) < GROUND_RANGE
	match action:
		"punch":
			if downed:
				_start_paired("elbow_drop", target)
			else:
				_start_strike("jab")
			return true
		"kick":
			if downed:
				_face(_flat(target.body_center() - global_position, facing()), 0.0, true)
				partner = target
				_enter(State.STOMP)
			else:
				_start_strike("big_boot")
			return true
		"grapple":
			_try_grapple(target)
			return true
		"block":
			if downed:
				_start_paired("cover", target)
				return true
	return false


func _st_run(delta: float) -> void:
	var c := controller
	if c and c.move.length() > 0.3:
		var desired := c.move.normalized()
		var ang := _run_dir.signed_angle_to(desired, Vector3.UP)
		_run_dir = _run_dir.rotated(Vector3.UP, clampf(ang, -RUN_STEER * delta, RUN_STEER * delta))
	_face(_run_dir, 0.0, true)
	velocity.x = _run_dir.x * RUN_SPEED
	velocity.z = _run_dir.z * RUN_SPEED

	var action := _take_buffered()
	if action == "punch" or action == "kick":
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
	var release := _event("rope_rebound", "release", 0.26)
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
		if _whipped:
			_rebounds += 1
			_enter(State.WHIPPED)
		else:
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
	if _move.has("next") and state_time >= float(_move.get("cancel", 99.0)) \
			and (_buffered == "punch" or _buffered == "kick"):
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

	var was_stunned := state == State.HITSTUN or state == State.STUN
	var running_into := is_running() and facing().dot(from) > 0.3
	_damage(float(mv["damage"]) * (1.3 if running_into else 1.0))
	_combo_hits += 1
	_combo_timer = 1.6
	freeze(stop)
	attacker.freeze(stop)
	AudioDirector.play(mv.get("sfx", "hit_light"), global_position + Vector3.UP * 1.4)
	struck.emit(attacker, self, mv, false)

	if state in [State.CORNERED, State.CORNER_HIT]:
		# pinned against the turnbuckle: soak it up and stay in the corner
		_enter(State.CORNER_HIT, 0.04)
		return
	_face(from, 0.0, true)
	_whipped = false
	var knock: bool = mv.get("knockdown", false) or health <= 0.0 or _combo_hits >= 4 or running_into \
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
	if _buffered == "grapple":
		_enter(State.IDLE)
		return
	if controller == null or not controller.block_held:
		_enter(State.IDLE)


func _st_timed(duration: float) -> void:
	velocity.x = _push.x
	velocity.z = _push.z
	if state_time >= duration:
		_enter(State.IDLE)


func _st_anim_then_idle(anim_name: String) -> void:
	velocity.x = _push.x
	velocity.z = _push.z
	if state_time >= _anim_length(anim_name) - 0.02:
		_enter(State.IDLE)


func _st_knockdown(_delta: float) -> void:
	velocity.x = _push.x
	velocity.z = _push.z
	var impact := _event("knockdown", "impact", 0.5)
	if state_time >= impact and state_time - get_physics_process_delta_time() < impact:
		AudioDirector.play("body_fall", global_position + Vector3.UP * 0.3)
		landed_on_canvas.emit(self)
	if state_time >= _anim_length("knockdown"):
		_go_down()


func _go_down(extra: float = 0.0) -> void:
	_down_left = DOWN_BASE + (1.0 - health / MAX_HEALTH) * 2.5 + extra
	_enter(State.DOWN)


func _st_down(delta: float) -> void:
	velocity.x = _push.x
	velocity.z = _push.z
	if match_over:
		return
	_down_left -= delta
	if controller and controller.mash:
		_down_left -= 0.12
	if _down_left <= 0.0 and (health > 0.0 or infinite_health or state_time > 6.0):
		_enter(State.GETUP)


func _st_celebrate(_delta: float) -> void:
	_hold_still()
	if state_time >= _anim_length("taunt"):
		_enter(State.CELEBRATE)


# ---------------------------------------------------------------- grappling

func _try_grapple(target: Wrestler) -> void:
	if target == null:
		_enter(State.GRAB_WHIFF)
		return
	var to := flat_dir_to(target)
	var d := _flat(target.global_position - global_position, Vector3.ZERO).length()
	if target.is_down() and target.distance_to_body(global_position) < GROUND_RANGE:
		_start_paired("pickup", target)
	elif target.is_running() and target.facing().dot(-to) > 0.6 and d < 1.8:
		_face(to, 0.0, true)
		_start_paired("back_body_drop", target)
	elif target.can_be_grappled() and d < GRAB_RANGE and facing().angle_to(to) < deg_to_rad(75):
		_face(to, 0.0, true)
		if target.facing().dot(to) > 0.3 and target.state != State.CORNERED:
			_start_paired("german", target)
		else:
			_start_tieup(target)
	else:
		_enter(State.GRAB_WHIFF)


func _start_tieup(target: Wrestler) -> void:
	_anchor = _flat_xform()
	target._lock(self, _anchor, State.HELD, "tieup_d")
	_lock(target, _anchor, State.TIEUP, "tieup_a")


## Put this wrestler at the pair anchor in a locked (non-colliding) state.
func _lock(other: Wrestler, anchor: Transform3D, s: State, anim_name: String) -> void:
	partner = other
	_anchor = anchor
	global_transform = anchor
	_set_solid(false)
	_whipped = false
	_push = Vector3.ZERO
	state = s
	state_time = 0.0
	invulnerable = false
	_play(anim_name, 0.1, true)


func _st_tieup(_delta: float) -> void:
	_hold_still()
	if partner == null or partner.state != State.HELD:
		_unlock_to(State.IDLE)
		return
	var c := controller
	var dir := c.move if c else Vector3.ZERO
	var has_dir := dir.length() > 0.3
	var action := _take_buffered()
	if c and c.run_held and state_time > 0.1:
		_whip_dir = dir.normalized() if has_dir else facing()
		_start_paired("whip", partner)
	elif action == "punch":
		_start_paired("body_slam" if has_dir else "headbutt", partner)
	elif action == "kick":
		_start_paired("ddt" if has_dir else "suplex", partner)
	elif action == "grapple" or state_time > TIEUP_TIMEOUT:
		_break_tieup()


func _break_tieup() -> void:
	var p := partner
	p._unlock_to(State.STUN, _anchor * Grapples.root_xform(_root_info("tieup_d", "root_end"), p.model_scale()))
	p._push = facing() * 2.5
	_unlock_to(State.IDLE)


func _unlock_to(s: State, xform: Variant = null) -> void:
	if xform != null:
		global_transform = xform
	_set_solid(true)
	partner = null
	_enter(s, 0.0 if xform != null else -1.0)


func _start_paired(id: String, target: Wrestler) -> void:
	var mv := Grapples.get_move(id)
	var anchor := _flat_xform()
	if mv["align"] == "attacker":
		# keep the defender where they are; move the attacker into position
		var start := Grapples.root_xform(mv["root_start_d"], target.model_scale())
		anchor = target._flat_xform() * start.affine_inverse()
	# never put the pair's anchor off the canvas
	var edge := _rope_limit() + 0.45
	anchor.origin.x = clampf(anchor.origin.x, -edge, edge)
	anchor.origin.z = clampf(anchor.origin.z, -edge, edge)
	target._begin_paired(self, mv, anchor, "d")
	_begin_paired(target, mv, anchor, "a")
	_anchor_base = anchor
	# moves on a downed opponent leave them where they lie (so pins under the ropes still break)
	_anchor_shift = Vector3.ZERO if mv.get("in_place", false) else _inside_shift(anchor, mv, target)
	_impact_done = false
	_released = false
	move_performed.emit(self, id)


## How far to slide a move's anchor so both wrestlers start and end inside the ropes.
func _inside_shift(anchor: Transform3D, mv: Dictionary, target: Wrestler) -> Vector3:
	var lim := _rope_limit() - 0.05
	var pts: Array[Vector3] = []
	for x in [anchor * Grapples.root_xform(mv["root_end_a"], model_scale()),
			anchor * Grapples.root_xform(mv["root_end_d"], target.model_scale()),
			anchor * Grapples.root_xform(mv["root_start_d"], target.model_scale())]:
		pts.append(x.origin)
		pts.append(x.origin - x.basis.z * 0.8)   # head, if lying down
	var shift := Vector3.ZERO
	for axis in [0, 2]:
		var hi := -INF
		var lo := INF
		for q in pts:
			hi = maxf(hi, q[axis])
			lo = minf(lo, q[axis])
		if hi - lo > 2.0 * lim:
			continue
		if hi > lim:
			shift[axis] = lim - hi
		elif lo < -lim:
			shift[axis] = -lim - lo
	return shift


func _begin_paired(other: Wrestler, mv: Dictionary, anchor: Transform3D, role: String) -> void:
	partner = other
	_pair = mv
	_anchor = anchor
	global_transform = anchor
	_set_solid(false)
	_whipped = false
	_push = Vector3.ZERO
	state = State.PAIRED
	state_time = 0.0
	invulnerable = false
	_role = role
	_play(mv["anim_" + role], 0.06, true)


func _st_paired(_delta: float) -> void:
	_hold_still()
	if _role != "a":
		# the attacker drives timing for both; this is only a safety net
		if state_time > float(_pair.get("length", 2.0)) + 0.5:
			_end_paired(_pair, "d", null) if not _pair.is_empty() else _go_down()
		return
	var linked := partner != null and partner.partner == self and partner.state == State.PAIRED
	if _anchor_shift != Vector3.ZERO:
		var k := clampf(state_time / 0.25, 0.0, 1.0)
		_anchor = _anchor_base.translated(_anchor_shift * k)
		global_transform = _anchor
		if linked:
			partner._anchor = _anchor
			partner.global_transform = _anchor
	var events: Dictionary = _pair["events"]
	if linked and not _impact_done and events.has("impact") and state_time >= float(events["impact"]):
		_impact_done = true
		partner._take_move_damage(self, _pair)
	if linked and not _released and events.has("release") and state_time >= float(events["release"]):
		_released = true
		if _pair["id"] == "whip":
			partner._start_whipped(_anchor * Grapples.root_xform(_pair["root_end_d"], partner.model_scale()), _whip_dir)
	if state_time >= float(_pair["length"]) - 0.01:
		_finish_pair()


func _take_move_damage(attacker: Wrestler, mv: Dictionary) -> void:
	_damage(float(mv["damage"]))
	if mv.has("sfx"):
		AudioDirector.play(mv["sfx"], body_center())
	struck.emit(attacker, self, mv, false)
	landed_on_canvas.emit(self)


func _finish_pair() -> void:
	var mv := _pair
	var p := partner
	if p and p.state == State.PAIRED and p.partner == self:
		p._end_paired(mv, "d", self)
	_end_paired(mv, "a", p)


func _end_paired(mv: Dictionary, role: String, other: Wrestler) -> void:
	var end_info: Dictionary = mv["root_end_" + role]
	global_transform = _anchor * Grapples.root_xform(end_info, model_scale())
	_set_solid(true)
	_pair = {}
	var end: String = mv["end_" + role]
	var blend := 0.15 if Grapples.is_identity(end_info) else 0.0
	match end:
		"idle": _enter(State.IDLE, blend)
		"getup": _enter(State.GETUP, 0.0)
		"down": _go_down(0.4)
		"stun": _enter(State.STUN, blend)
		"tieup":
			_lock(other, _anchor * Grapples.root_xform(end_info, model_scale()), State.TIEUP, "tieup_a")
		"held":
			_lock(other, other._anchor if other else global_transform, State.HELD, "tieup_d")
		"pinning":
			partner = other
			_set_solid(false)
			_enter(State.PINNING, 0.0)
		"pinned":
			partner = other
			_set_solid(false)
			_kickout_have = 0
			_kickout_need = int(2 + pow(1.0 - health / MAX_HEALTH, 1.8) * 18.0 + (16.0 if health <= 0.0 else 0.0))
			_enter(State.PINNED, 0.0)
			if other:
				other.pin_started.emit(other, self)
		_: _enter(State.IDLE, blend)


# ---------------------------------------------------------------- whips and corners

func _start_whipped(xform: Transform3D, dir: Vector3) -> void:
	global_transform = xform
	_set_solid(true)
	_pair = {}
	partner = null
	_run_dir = _flat(dir, facing())
	_face(_run_dir, 0.0, true)
	_whipped = true
	_rebounds = 0
	_corner = _corner_in_direction(global_position, _run_dir)
	_enter(State.WHIPPED, 0.0)


static func _corner_in_direction(from: Vector3, dir: Vector3) -> int:
	for i in 4:
		var c := Ring.corner(i) - from
		c.y = 0
		if c.length() > 1.0 and rad_to_deg(dir.angle_to(c)) < 24.0:
			return i
	return -1


func _st_whipped(_delta: float) -> void:
	_face(_run_dir, 0.0, true)
	velocity.x = _run_dir.x * WHIP_SPEED
	velocity.z = _run_dir.z * WHIP_SPEED
	if _corner >= 0:
		# home in on the turnbuckle; ropes don't matter on the way into a corner
		var spot := _corner_spot(_corner)
		var to := spot - global_position
		to.y = 0
		if to.length() < 0.4 or state_time > 3.0:
			global_position = Vector3(spot.x, global_position.y, spot.z)
			_face(-_flat(spot, Vector3.FORWARD), 0.0, true)
			_whipped = false
			_enter(State.CORNER_HIT)
			AudioDirector.play("hit_heavy", global_position + Vector3.UP * 1.2, -3.0)
			landed_on_canvas.emit(self)
		else:
			_run_dir = to.normalized()
		return
	if _rebounds >= 2 or state_time > 4.0:
		_whipped = false
		_push = _run_dir * 3.0
		_enter(State.IDLE)
		return
	if _hits_ropes():
		_enter(State.REBOUND)


func _corner_spot(i: int) -> Vector3:
	var lim := _rope_limit() + 0.18
	var c := Ring.corner(i)
	return Vector3(signf(c.x) * lim, global_position.y, signf(c.z) * lim)


func _st_corner_hit(_delta: float) -> void:
	_hold_still()
	if state_time >= _anim_length("corner_hit"):
		_enter(State.CORNERED)


func _st_cornered(_delta: float) -> void:
	_hold_still()
	if state_time >= CORNER_TIME:
		_push = facing() * 1.5
		_enter(State.CORNER_EXIT)


# ---------------------------------------------------------------- ground offence and pins

func _st_stomp(_delta: float) -> void:
	_hold_still()
	var hit := _event("stomp", "hit", 0.32)
	if state_time >= hit and state_time - get_physics_process_delta_time() < hit:
		if partner and partner.is_down() and partner.distance_to_body(global_position + facing() * 0.5) < 0.9:
			partner.receive_ground_hit(self, 6.0)
		else:
			AudioDirector.play("whoosh", global_position + Vector3.UP * 0.5, -10.0)
	if state_time >= _anim_length("stomp"):
		partner = null
		_enter(State.IDLE)


func receive_ground_hit(attacker: Wrestler, dmg: float) -> void:
	_damage(dmg)
	AudioDirector.play("hit_heavy", body_center(), -2.0)
	struck.emit(attacker, self, {"id": "stomp", "damage": dmg}, false)
	_down_left += 0.35
	_enter(State.DOWN_HIT)


func _st_down_hit(_delta: float) -> void:
	_hold_still()
	if state_time >= _anim_length("down_hit"):
		var left := _down_left
		_enter(State.DOWN, 0.0)
		_down_left = left


func _st_pinned(_delta: float) -> void:
	_hold_still()
	if match_over:
		return
	if controller and controller.mash:
		_kickout_have += 1
	if _kickout_have >= _kickout_need:
		kick_out()


## Break the pin (kick-out, rope break or interruption).
func kick_out() -> void:
	if state != State.PINNED:
		return
	var p := partner
	partner = null
	_set_solid(true)
	_down_left = 0.8
	_enter(State.KICKOUT)
	if p and p.state == State.PINNING:
		p.partner = null
		p._set_solid(true)
		p._enter(State.COVER_RELEASE)
	kicked_out.emit(self)


func _st_kickout(_delta: float) -> void:
	_hold_still()
	if state_time >= _anim_length("kickout"):
		_enter(State.DOWN, 0.0)
		_down_left = 0.6


# ---------------------------------------------------------------- match control

func win() -> void:
	match_over = true
	partner = null
	_set_solid(true)
	_enter(State.CELEBRATE)


func lose() -> void:
	match_over = true
	partner = null
	_set_solid(true)
	if state != State.DOWN:
		_enter(State.DOWN, 0.1)


# ---------------------------------------------------------------- helpers

func freeze(seconds: float) -> void:
	_freeze = maxf(_freeze, seconds)
	model.anim_player.speed_scale = 0.0


func restore_health() -> void:
	health = MAX_HEALTH
	health_changed.emit(self)


func _damage(amount: float) -> void:
	if not infinite_health:
		health = maxf(0.0, health - amount * DAMAGE_SCALE)
	health_changed.emit(self)


func _hold_still() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _set_solid(solid: bool) -> void:
	# locked/paired wrestlers overlap by design, so they stop colliding with each other
	collision_layer = 2 if solid else 0
	collision_mask = 3 if solid else 1


func _flat_xform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rotation.y), Vector3(global_position.x, global_position.y, global_position.z))


static func _flat(v: Vector3, fallback: Vector3) -> Vector3:
	v.y = 0
	return v.normalized() if v.length_squared() > 1e-6 else fallback


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
	if blend <= 0.0:
		model.anim_player.seek(0.0, true)


func _anim_length(anim_name: String) -> float:
	return float(WrestlerModel.manifest()["animations"][anim_name]["length"])


func _event(anim_name: String, ev: String, default: float) -> float:
	return float(WrestlerModel.manifest()["animations"][anim_name]["events"].get(ev, default))


func _root_info(anim_name: String, which: String) -> Dictionary:
	return WrestlerModel.manifest()["animations"][anim_name][which]


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
	var extra := 0.0
	if state == State.REBOUND:
		extra = 0.5
	elif state in [State.CORNER_HIT, State.CORNERED]:
		extra = 0.2
	elif state in [State.PAIRED, State.HELD, State.TIEUP, State.PINNING, State.PINNED]:
		return  # paired bodies sit at the shared anchor; their visible bodies are offset
	var lim := _rope_limit() + extra
	position.x = clampf(position.x, -lim, lim)
	position.z = clampf(position.z, -lim, lim)
