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
signal landed_outside(w: Wrestler, at: Vector3)
signal momentum_changed(w: Wrestler)
signal special_ready(w: Wrestler)
signal reversed(by: Wrestler, victim: Wrestler, kind: String)   ## kind: "parry" or "reversal"
signal tagged(out: Wrestler, into: Wrestler, hot: bool)
signal pin_saved(by: Wrestler, pinner: Wrestler)
signal double_team(a: Wrestler, b: Wrestler, victim: Wrestler)

enum State {
	IDLE, RUN, STRIKE, BLOCK, HITSTUN, KNOCKDOWN, DOWN, GETUP, REBOUND, TAUNT,
	GRAB_WHIFF, TIEUP, HELD, PAIRED, WHIPPED, CORNER_HIT, CORNERED, CORNER_EXIT,
	STOMP, DOWN_HIT, PINNING, PINNED, KICKOUT, COVER_RELEASE, STUN, CELEBRATE,
	EXIT_RING, ENTER_RING, FALL_OUT, CLIMB, PERCH, CLIMB_DOWN, DIVE, DIVE_LAND, ITEM_PICKUP, CHAIR_SWING, PARRY,
	APRON, APRON_ENTER, APRON_EXIT, ENTRANCE,
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
const CORNER_TIME := 2.4         # total time stuck in a corner, however often you're hit there
const CORNER_MAX_HITS := 3        # strikes soaked in the corner before stumbling out
const DOWN_MAX := 4.5             # total time on the mat before you're up, whatever they do to you
const WAKE_GRACE := 0.6           # can't be hit or grabbed just after getting back up
const MOMENTUM_MAX := 100.0
const SPECIAL_TIME := 20.0        # how long a full meter stays banked as a SPECIAL
const PARRY_WINDOW := 0.2         # block pressed this close before a strike lands parries it
const MASH_GUARD := 0.45          # a block press this soon after the previous one never counts
const TAG_REACH := 1.25           # how close to your partner's apron spot you must be to tag
const ILLEGAL_TIME := 5.0         # seconds an illegal partner may stay in before being sent back
const APRON_REGEN := 0.2          # health per second recovered while tagged out
const STUN_TIME := 1.1

const DOWNED := [State.KNOCKDOWN, State.DOWN, State.GETUP, State.DOWN_HIT, State.PINNED, State.KICKOUT,
	State.FALL_OUT, State.DIVE_LAND]
const BUSY := [State.TIEUP, State.HELD, State.PAIRED, State.PINNING, State.PINNED, State.CELEBRATE,
	State.EXIT_RING, State.ENTER_RING, State.CLIMB, State.CLIMB_DOWN, State.DIVE,
	State.APRON, State.APRON_ENTER, State.APRON_EXIT, State.ENTRANCE]
## states whose motion is fully scripted (no gravity, collision response or ring clamping)
const SCRIPTED := [State.PAIRED, State.HELD, State.TIEUP, State.PINNING, State.PINNED, State.EXIT_RING,
	State.ENTER_RING, State.FALL_OUT, State.CLIMB, State.PERCH, State.CLIMB_DOWN, State.DIVE,
	State.APRON, State.APRON_ENTER, State.APRON_EXIT, State.ENTRANCE]
## states in which a held chair stays in hand
const ITEM_OK := [State.IDLE, State.CHAIR_SWING, State.ITEM_PICKUP, State.EXIT_RING, State.ENTER_RING]
const EDGE_PUSH_TIME := 0.35
const CHAIR_SHOT := {"id": "chair_shot", "damage": 14.0, "knockdown": true, "knockback": 2.5, "hitstop": 0.13,
	"sfx": "chair_hit", "weapon": true, "region": "head", "reach": 1.5, "arc": 65.0}

@export var look: WrestlerLook
@export var display_name := "Wrestler"

var controller: WrestlerController
var opponents: Array[Wrestler] = []
# tag team (teammate == null in singles)
var teammate: Wrestler
var team := 0
var legal := true                ## the one wrestler per team who may pin and be pinned
var apron_spot := Vector3.ZERO   ## where this team's partner waits (world space)
var illegal_time := 0.0
var forced_return := false       ## the referee is sending this illegal partner back to the apron
var _helper: Wrestler            # teammate joining in on a double-team move
var _to_apron := false           # climbing up from the floor to wait on the apron
var ring: Ring
var model: WrestlerModel
var state: State = State.IDLE
var state_time := 0.0
var health := MAX_HEALTH
var invulnerable := false
var infinite_health := false
var match_over := false
var outside := false             ## on the arena floor rather than in the ring
var held_item: Chair
var momentum := 0.0
var special_left := 0.0          ## seconds left on a banked SPECIAL (finisher available)
## slot -> move id (see Movesets); resolved against the built animations when the match starts
var moves: Dictionary = Movesets.defaults()
var stats: Dictionary = Stats.defaults()   ## power / speed / toughness / charisma, 1-5
var finisher: String:
	get:
		return moves.get("finisher", "thunder_bomb")
	set(value):
		moves["finisher"] = value

var _move: Dictionary = {}
var _hit_done := false
var _buffered := ""
var _buffer_time := 0.0
var _freeze := 0.0
var _push := Vector3.ZERO        # decaying knockback / lunge velocity
var _down_left := 0.0
var _run_dir := Vector3.FORWARD
var _auto_run := 0.0
var _loose_rebounds := 0       # rebounds in a row without run held
var _combo_hits := 0
var _downed_for := 0.0           # time spent down since last standing (survives stomps and elbow drops)
var _down_cap := DOWN_MAX
var _grace := 0.0
var _corner_clock := 0.0
var _corner_hits := 0
var _stun_len := STUN_TIME
var _clock := 0.0
var _press_t := -99.0            # last block press (for parries and reversals)
var _press_prev := -99.0
var _finisher_hit := 0.0         # just took a finisher: kicking out is much harder
var _aura_on := false
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

# environment
var _edge_time := 0.0
var _root_anim := ""
var _root_start := Transform3D.IDENTITY
var _root_impact_done := false
var _item_target: Chair
var _dive_from := Vector3.ZERO
var _dive_to := Vector3.ZERO
var _dive_time := 0.6
var _dive_kind := ""
var _dive_target: Wrestler


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
	moves = Movesets.resolve(moves)
	stats = Stats.sanitize(stats)
	_enter(State.IDLE)


# ---------------------------------------------------------------- queries

func facing() -> Vector3:
	return global_basis.z


## The move this wrestler does in a slot (the slot default if it isn't available).
func move_for(slot_id: String) -> String:
	var id := String(moves.get(slot_id, ""))
	if id == "" or not Movesets.is_available(id):
		id = Movesets.slot(slot_id)["default"]
	return id


func model_scale() -> float:
	return model.look.height if model and model.look else 1.0


func is_standing() -> bool:
	return state not in DOWNED


func is_down() -> bool:
	return state in [State.DOWN, State.DOWN_HIT, State.KNOCKDOWN]


func is_running() -> bool:
	return state in [State.RUN, State.WHIPPED]


func can_be_hit() -> bool:
	return not invulnerable and _grace <= 0.0 and state not in DOWNED and state not in BUSY


func can_be_grappled() -> bool:
	return _grace <= 0.0 and state in [State.IDLE, State.BLOCK, State.HITSTUN, State.STUN, State.TAUNT, State.CORNERED,
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
		if o.on_apron():
			continue
		var d := global_position.distance_squared_to(o.global_position)
		if d < best_d:
			best_d = d
			best = o
	return best


func on_apron() -> bool:
	return state in [State.APRON, State.APRON_ENTER, State.APRON_EXIT]


func can_pin(target: Wrestler) -> bool:
	return teammate == null or (legal and target.legal)


## Just inside the ropes from this team's apron spot.
func entry_spot() -> Vector3:
	var inward := -signf(apron_spot.z)
	return Vector3(apron_spot.x, apron_spot.y, apron_spot.z + inward * _root_dist("apron_enter"))


func flat_dir_to(o: Node3D) -> Vector3:
	return _flat(o.global_position - global_position, facing())


func pinned_by() -> Wrestler:
	return partner if state == State.PINNED else null


func kickout_progress() -> float:
	return float(_kickout_have) / maxf(1.0, float(_kickout_need))


# ---------------------------------------------------------------- main loop

func _physics_process(delta: float) -> void:
	_clock += delta
	_finisher_hit -= delta
	if special_left > 0.0 and state not in BUSY:
		special_left -= delta
		if special_left <= 0.0:
			momentum = MOMENTUM_MAX * 0.5
			momentum_changed.emit(self)
	if teammate and not legal and not match_over:
		if on_apron():
			illegal_time = 0.0
			forced_return = false
		else:
			illegal_time += delta
			forced_return = forced_return or illegal_time > ILLEGAL_TIME
	if special_left > 0.0:
		model.set_aura(0.55 + 0.45 * sin(_clock * 9.0))
		_aura_on = true
	elif _aura_on:
		model.set_aura(0.0)
		_aura_on = false
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
	_grace -= delta
	if state in [State.DOWN, State.DOWN_HIT] or (state in [State.PAIRED, State.HELD] and _downed_for > 0.0):
		_downed_for += delta
	elif state not in DOWNED:
		_downed_for = 0.0
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
		State.GETUP: _st_getup(delta)
		State.REBOUND: _st_rebound(delta)
		State.TAUNT: _st_taunt(delta)
		State.PARRY: _st_parry(delta)
		State.APRON: _st_apron(delta)
		State.APRON_ENTER, State.APRON_EXIT: _st_root_anim(delta)
		State.ENTRANCE: pass        # driven by the match's Entrance director
		State.GRAB_WHIFF: _st_anim_then_idle("grab_whiff")
		State.TIEUP: _st_tieup(delta)
		State.HELD: _hold_still()
		State.PAIRED: _st_paired(delta)
		State.WHIPPED: _st_whipped(delta)
		State.CORNER_HIT: _st_corner_hit(delta)
		State.CORNERED: _st_cornered(delta)
		State.CORNER_EXIT: _st_corner_exit(delta)
		State.STOMP: _st_stomp(delta)
		State.DOWN_HIT: _st_down_hit(delta)
		State.PINNING: _hold_still()
		State.PINNED: _st_pinned(delta)
		State.KICKOUT: _st_kickout(delta)
		State.COVER_RELEASE: _st_anim_then_idle("cover_release")
		State.STUN: _st_timed(_stun_len)
		State.CELEBRATE: _st_celebrate(delta)
		State.EXIT_RING, State.ENTER_RING, State.FALL_OUT, State.CLIMB, State.CLIMB_DOWN: _st_root_anim(delta)
		State.PERCH: _st_perch(delta)
		State.DIVE: _st_dive(delta)
		State.DIVE_LAND: _st_dive_land(delta)
		State.ITEM_PICKUP: _st_item_pickup(delta)
		State.CHAIR_SWING: _st_chair_swing(delta)

	_push = _push.move_toward(Vector3.ZERO, 9.0 * delta)
	if state in SCRIPTED:
		velocity = Vector3.ZERO
		return
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_confine_to_ring()


func _buffer_inputs(delta: float) -> void:
	_buffer_time -= delta
	if controller.block_pressed:
		_press_prev = _press_t
		_press_t = _clock
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
	if held_item and s not in ITEM_OK:
		drop_item(facing() * 1.5 + Vector3.UP * 2.0)
	state = s
	state_time = 0.0
	invulnerable = s == State.GETUP
	_stun_len = STUN_TIME
	var anims := {
		State.IDLE: ["idle", 0.2], State.RUN: ["run", 0.12], State.BLOCK: ["block", 0.08],
		State.KNOCKDOWN: ["knockdown", 0.05], State.DOWN: ["down", 0.25], State.GETUP: ["getup", 0.15],
		State.TAUNT: ["taunt", 0.15], State.REBOUND: ["rope_rebound", 0.06], State.GRAB_WHIFF: ["grab_whiff", 0.06],
		State.WHIPPED: ["run", 0.1], State.CORNER_HIT: ["corner_hit", 0.05], State.CORNERED: ["corner_slump", 0.2],
		State.CORNER_EXIT: ["corner_exit", 0.15], State.STOMP: ["stomp", 0.08], State.DOWN_HIT: ["down_hit", 0.04],
		State.PINNING: ["cover_hold", 0.0], State.PINNED: ["down", 0.0], State.KICKOUT: ["kickout", 0.05],
		State.COVER_RELEASE: ["cover_release", 0.0], State.STUN: ["groggy", 0.15], State.CELEBRATE: ["taunt", 0.2],
		State.PERCH: ["perch", 0.1], State.DIVE_LAND: ["dive_land", 0.05], State.ITEM_PICKUP: ["item_pickup", 0.1],
		State.CHAIR_SWING: ["chair_swing", 0.06], State.PARRY: ["parry", 0.04], State.APRON: ["apron_wait", 0.2],
	}
	if anims.has(s):
		var anim_name: String = move_for("taunt") if s == State.TAUNT or s == State.CELEBRATE else anims[s][0]
		_play(anim_name, anims[s][1] if blend < 0.0 else blend, true)


func _st_idle(delta: float) -> void:
	var c := controller
	var action := _take_buffered()
	if action != "" and _try_action(action):
		return
	var mv := c.move if c else Vector3.ZERO
	if teammate and not legal:
		if forced_return:
			mv = _forced_move()
		if _try_return_to_apron(mv):
			return
	if _edge_push(mv, delta):
		return
	if held_item:
		_idle_with_item(mv, delta)
		return
	if c and c.block_held and action == "":
		_enter(State.BLOCK)
		return
	if c and c.taunt:
		var t := nearest_opponent()
		if has_special() and t and _finisher_ready_on(t):
			_face(flat_dir_to(t), 0.0, true)
			_start_finisher(t)
		else:
			_enter(State.TAUNT)
		return
	if c and c.run_held:
		_run_dir = mv.normalized() if mv.length() > 0.3 else facing()
		_face(_run_dir, 0.0, true)
		_auto_run = 0.0
		_loose_rebounds = 0
		_whipped = false
		_enter(State.RUN)
		return

	velocity.x = mv.x * WALK_SPEED * _speed() + _push.x
	velocity.z = mv.z * WALK_SPEED * _speed() + _push.z
	var target := nearest_opponent()
	if mv.length() > 0.15:
		_face(mv, delta * 10.0)
	elif target and global_position.distance_to(target.global_position) < LOCK_ON_RANGE:
		_face(flat_dir_to(target), delta * 4.0)
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed > 0.3:
		_play("walk", 0.2)
		model.anim_player.speed_scale = clampf(speed / (WALK_SPEED * _speed()), 0.5, 1.3)
	else:
		_play("idle", 0.25)
		model.anim_player.speed_scale = 1.0


## Context-sensitive offence from a buffered button. Returns true if something started.
func _try_action(action: String) -> bool:
	if action != "block":
		_grace = 0.0     # attacking gives up the wake-up protection
	var target := nearest_opponent()
	var downed := target != null and target.is_down() and target.distance_to_body(global_position) < GROUND_RANGE
	if held_item:
		if action == "punch" or action == "kick":
			_enter(State.CHAIR_SWING)
		elif action == "grapple":
			drop_item(facing() * 0.8)
		return true
	match action:
		"punch":
			if downed:
				_start_paired(move_for("ground_punch"), target)
			else:
				_start_strike("jab")
			return true
		"kick":
			if downed:
				_face(_flat(target.body_center() - global_position, facing()), 0.0, true)
				partner = target
				_enter(State.STOMP)
			else:
				_start_strike(move_for("kick"))
			return true
		"grapple":
			_try_grapple(target)
			return true
		"block":
			# pinfalls only count in the ring
			if downed and not outside and not target.outside and can_pin(target):
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
	velocity.x = _run_dir.x * RUN_SPEED * _speed()
	velocity.z = _run_dir.z * RUN_SPEED * _speed()

	var action := _take_buffered()
	if action == "punch" or action == "kick":
		_start_strike(move_for("running"))
		return
	_auto_run -= delta
	var held := c != null and c.run_held
	if not held and _auto_run <= 0.0 and state_time > 0.25:
		_push = _run_dir * RUN_SPEED * _speed() * 0.5
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
			# one bounce carries you back across even with run let go, but no more: on a
			# diagonal the next rope comes before the run wears off, and you'd never stop
			var held := controller != null and controller.run_held
			_loose_rebounds = 0 if held else _loose_rebounds + 1
			_auto_run = 0.9 if _loose_rebounds <= 1 else 0.0
			_enter(State.RUN)


func _start_strike(id: String) -> void:
	_move = Strikes.get_move(id)
	_hit_done = false
	var target := nearest_opponent()
	if target and global_position.distance_to(target.global_position) < LOCK_ON_RANGE:
		var to := flat_dir_to(target)
		if facing().angle_to(to) < deg_to_rad(110):
			_face(to, 0.0, true)
	if _move.get("running", false):
		_push = _run_dir * RUN_SPEED * _speed() * 0.7
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
		var next: String = _move["next"] if _take_buffered() == "punch" else move_for("kick")
		_start_strike(next)
		return
	if state_time >= float(_move["length"]) - 0.04:
		if _move.get("end", "") == "down":
			# dropkicks and crossbodies leave the attacker on the mat for a moment
			_go_down()
			_down_left = 0.35
		else:
			_enter(State.IDLE)


func _resolve_hit() -> void:
	var landed := false
	for o in opponents:
		var saving := o.state == State.PINNING and o.partner != null and o.partner.team == team
		if not o.can_be_hit() and not saving:
			continue
		var to := o.global_position - global_position
		to.y = 0
		var d := to.length()
		if d > float(_move["reach"]) + (0.3 if saving else 0.0):
			continue
		if saving:
			o._broken_up(self)
			landed = true
			continue
		if d > 0.05 and rad_to_deg(facing().angle_to(to)) > float(_move["arc"]):
			continue
		o.receive_strike(self, _move)
		landed = true
	if not landed:
		AudioDirector.play("whoosh", global_position + Vector3.UP * 1.4, -8.0)


# ---------------------------------------------------------------- momentum, specials, parries

func gain_momentum(amount: float) -> void:
	if match_over or (amount > 0.0 and special_left > 0.0):
		return
	if amount > 0.0:
		amount *= Stats.momentum(stats)
	momentum = clampf(momentum + amount, 0.0, MOMENTUM_MAX)
	if momentum >= MOMENTUM_MAX and special_left <= 0.0:
		special_left = SPECIAL_TIME
		AudioDirector.play("special_ready", global_position + Vector3.UP * 1.5, -2.0, 0.0)
		special_ready.emit(self)
	momentum_changed.emit(self)


func has_special() -> bool:
	return special_left > 0.0


## Damage multiplier from power and momentum (up to +15% on a full meter).
func damage_boost() -> float:
	return (1.0 + 0.15 * momentum / MOMENTUM_MAX) * Stats.damage_dealt(stats)


func finisher_name() -> String:
	return Movesets.move_name(move_for("finisher")).to_upper()


## A finisher can be hit straight onto a dazed opponent, or from a tie-up.
func _finisher_ready_on(t: Wrestler) -> bool:
	var d := _flat_len(t.global_position - global_position)
	return t.can_be_grappled() and t.outside == outside and d < GRAB_RANGE + 0.15 \
		and t.state in [State.STUN, State.HITSTUN, State.CORNERED, State.CORNER_EXIT]


func _start_finisher(t: Wrestler) -> void:
	special_left = 0.0
	momentum = 0.0
	momentum_changed.emit(self)
	_start_paired(move_for("finisher"), t)


func _st_taunt(_delta: float) -> void:
	velocity.x = _push.x
	velocity.z = _push.z
	if state_time >= _anim_length(move_for("taunt")) - 0.02:
		gain_momentum(15.0)    # playing to the crowd pays off, if you get away with it
		_enter(State.IDLE)


## A block press within `since` that wasn't part of a mash.
func _timed_block(since: float) -> bool:
	return _press_t >= since and _press_t - _press_prev > MASH_GUARD


func _parry(attacker: Wrestler, from: Vector3) -> void:
	_press_t = -99.0
	_face(from, 0.0, true)
	freeze(0.08)
	attacker.freeze(0.08)
	AudioDirector.play("parry", global_position + Vector3.UP * 1.4)
	_push = Vector3.ZERO
	_enter(State.PARRY)
	attacker._stagger(from)
	gain_momentum(8.0)
	attacker.gain_momentum(-4.0)
	reversed.emit(self, attacker, "parry")


func _stagger(away: Vector3) -> void:
	_push = away * 1.6
	_combo_hits = 0
	_enter(State.STUN)
	_stun_len = 0.8


func _st_parry(_delta: float) -> void:
	velocity.x = _push.x
	velocity.z = _push.z
	if state_time > 0.12:
		var action := _take_buffered()
		if action != "" and _try_action(action):
			return
	if state_time >= _anim_length("parry") - 0.02:
		_enter(State.IDLE)


func receive_strike(attacker: Wrestler, mv: Dictionary) -> void:
	var from := flat_dir_to(attacker)
	var stop := float(mv.get("hitstop", 0.07))
	if state in [State.IDLE, State.BLOCK] and facing().dot(from) > 0.3 and not mv.get("weapon", false) \
			and _timed_block(_clock - PARRY_WINDOW):
		_parry(attacker, from)
		return
	if state == State.BLOCK and facing().dot(from) > 0.3:
		_push = -from * 2.0
		freeze(0.05)
		attacker.freeze(0.05)
		AudioDirector.play("block", global_position + Vector3.UP * 1.3, -2.0)
		gain_momentum(1.5)
		struck.emit(attacker, self, mv, true)
		return

	var was_stunned := state == State.HITSTUN or state == State.STUN
	var running_into := is_running() and facing().dot(from) > 0.3
	var dmg := float(mv["damage"]) * (1.3 if running_into else 1.0) * attacker.damage_boost()
	_damage(dmg)
	attacker.gain_momentum(dmg * 1.5)
	gain_momentum(dmg * 0.35)
	_combo_hits += 1
	_combo_timer = 1.6
	freeze(stop)
	attacker.freeze(stop)
	AudioDirector.play(mv.get("sfx", "hit_light"), global_position + Vector3.UP * 1.4)
	struck.emit(attacker, self, mv, false)
	if match_over:
		return  # e.g. that shot was a disqualification

	if state in [State.CORNERED, State.CORNER_HIT]:
		# pinned against the turnbuckle: soak up a few, then stumble out
		_corner_hits += 1
		if _corner_hits >= CORNER_MAX_HITS or health <= 0.0:
			_leave_corner()
		else:
			_enter(State.CORNER_HIT, 0.04)
		return
	var perched := state == State.PERCH
	_face(from, 0.0, true)
	_whipped = false
	var knock: bool = mv.get("knockdown", false) or health <= 0.0 or _combo_hits >= 4 or running_into or perched \
		or (mv.get("knockdown_if_stunned", false) and (was_stunned or _combo_hits >= 2))
	if knock and not perched and _try_fall_over_ropes(-from, float(mv.get("knockback", 3.0))):
		knocked_down.emit(self)
		return
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
	_down_left = (DOWN_BASE + (1.0 - health / MAX_HEALTH) * 2.5) * Stats.time_down(stats) + extra
	_down_cap = maxf(DOWN_MAX, _down_left)
	_enter(State.DOWN)


func _st_down(delta: float) -> void:
	velocity.x = _push.x
	velocity.z = _push.z
	if match_over:
		return
	_down_left -= delta
	if controller and controller.mash:
		_down_left -= 0.15
		_downed_for += 0.05
	var alive := health > 0.0 or infinite_health
	if (alive and (_down_left <= 0.0 or _downed_for >= _down_cap)) or _downed_for >= maxf(6.0, _down_cap):
		_enter(State.GETUP)


func _st_getup(_delta: float) -> void:
	velocity.x = _push.x
	velocity.z = _push.z
	if state_time >= _anim_length("getup") - 0.02:
		_enter(State.IDLE)
		_grace = WAKE_GRACE


func _st_celebrate(_delta: float) -> void:
	_hold_still()
	if state_time >= _anim_length(move_for("taunt")):
		_enter(State.CELEBRATE)


# ---------------------------------------------------------------- grappling

func _try_grapple(target: Wrestler) -> void:
	if _try_tag():
		return
	if target and _try_double_team(target):
		return
	if target == null:
		if not _try_pick_up_item() and not _try_climb():
			_enter(State.GRAB_WHIFF)
		return
	var to := flat_dir_to(target)
	var d := _flat_len(target.global_position - global_position)
	if target.is_down() and target.distance_to_body(global_position) < GROUND_RANGE:
		_start_paired("pickup", target)
	elif target.is_running() and target.facing().dot(-to) > 0.6 and d < 1.8:
		_face(to, 0.0, true)
		_start_paired("back_body_drop", target)
	elif target.can_be_grappled() and d < GRAB_RANGE and facing().angle_to(to) < deg_to_rad(75) \
			and target.outside == outside:
		_face(to, 0.0, true)
		if target.facing().dot(to) > 0.3 and target.state != State.CORNERED:
			_start_paired(move_for("back_grapple"), target)
		else:
			_start_tieup(target)
	elif not _try_pick_up_item() and not _try_climb():
		_enter(State.GRAB_WHIFF)


func _start_tieup(target: Wrestler) -> void:
	_anchor = _flat_xform()
	target._lock(self, _anchor, State.HELD, "tieup_d")
	_lock(target, _anchor, State.TIEUP, "tieup_a")


## Put this wrestler at the pair anchor in a locked (non-colliding) state.
func _lock(other: Wrestler, anchor: Transform3D, s: State, anim_name: String) -> void:
	if held_item:
		drop_item()
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
		var toss_normal := _rope_toss_normal(_whip_dir)
		if toss_normal != Vector3.ZERO:
			_start_rope_toss(toss_normal)
		else:
			_start_paired("whip", partner)
	elif c and c.taunt and has_special():
		_start_finisher(partner)
	elif action == "punch":
		_start_paired(move_for("tieup_punch_dir" if has_dir else "tieup_punch"), partner)
	elif action == "kick":
		_start_paired(move_for("tieup_kick_dir" if has_dir else "tieup_kick"), partner)
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
	anchor.origin = _clamp_to_region(anchor.origin)
	target._begin_paired(self, mv, anchor, "d")
	_begin_paired(target, mv, anchor, "a")
	_anchor_base = anchor
	# moves on a downed opponent leave them where they lie (so pins under the ropes still break)
	if mv.get("in_place", false):
		_anchor_shift = Vector3.ZERO
	elif outside:
		_anchor_shift = _outside_shift(anchor, mv, target)
	else:
		_anchor_shift = _inside_shift(anchor, mv, target)
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
	for axis: int in [0, 2]:
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


## On the floor, slide a move away from the ring so nobody lands under the apron.
func _outside_shift(anchor: Transform3D, mv: Dictionary, target: Wrestler) -> Vector3:
	var o := anchor.origin
	var pts: Array[Vector3] = []
	for x in [anchor * Grapples.root_xform(mv["root_end_a"], model_scale()),
			anchor * Grapples.root_xform(mv["root_end_d"], target.model_scale())]:
		pts.append(x.origin)
		pts.append(x.origin - x.basis.z * 0.8)
	var shift := Vector3.ZERO
	# stay inside the barricade...
	var bl := float(Ring.spec()["barricade_half"]) - 0.45
	for axis: int in [0, 2]:
		var hi := -INF
		var lo := INF
		for q in pts:
			hi = maxf(hi, q[axis])
			lo = minf(lo, q[axis])
		if hi > bl:
			shift[axis] = bl - hi
		elif lo < -bl:
			shift[axis] = -bl - lo
	# ...and away from the apron on our side of the ring
	var main := 0 if absf(o.x) > absf(o.z) else 2
	var side := signf(o[main])
	var rb := Ring.canvas_half() + 0.35
	var worst := INF
	for q in pts:
		worst = minf(worst, (q[main] + shift[main]) * side)
	if worst < rb:
		shift[main] += (rb - worst) * side
	return shift


## Keep a point on the canvas (in the ring) or between apron and barricade (outside).
func _clamp_to_region(p: Vector3) -> Vector3:
	if outside:
		var lim := float(Ring.spec()["barricade_half"]) - 0.4
		p.x = clampf(p.x, -lim, lim)
		p.z = clampf(p.z, -lim, lim)
		var rb := Ring.canvas_half() + 0.32
		if absf(p.x) < rb and absf(p.z) < rb:
			if absf(p.x) > absf(p.z):
				p.x = signf(p.x) * rb
			else:
				p.z = signf(p.z) * rb
		return p
	var edge := _rope_limit() + 0.45
	return Vector3(clampf(p.x, -edge, edge), p.y, clampf(p.z, -edge, edge))


## Region from position: past the apron, or down at floor height, counts as outside.
func _update_region() -> void:
	outside = Ring.is_outside(global_position) or global_position.y < Ring.canvas_height() - 0.5


func _begin_paired(other: Wrestler, mv: Dictionary, anchor: Transform3D, role: String) -> void:
	if held_item:
		drop_item()
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
	if _role == "a2":
		# helping on a double team: the lead attacker ends the move for us
		if state_time > float(_pair.get("length", 2.0)) + 0.3:
			_end_paired(_pair, "a", partner)
		return
	if _role != "a":
		if reversal_window() > 0.0 and _timed_block(_clock - state_time - 0.1):
			_reverse_grapple()
			return
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


## Seconds left to reverse the move being done to us (0 when it can't be reversed).
func reversal_window() -> float:
	if state != State.PAIRED or _role != "d" or partner == null or partner.state != State.PAIRED:
		return 0.0
	return maxf(0.0, float(_pair.get("reversal", 0.0)) - state_time)


## Turn the tie-up around: back to where we stood, and throw them instead.
func _reverse_grapple() -> void:
	var att := partner
	var id: String = _pair["id"]
	_press_t = -99.0
	var spot := att._anchor * Grapples.root_xform(_root_info("tieup_d", "root_end"), model_scale())
	att._pair = {}
	att.partner = null
	_pair = {}
	partner = null
	global_transform = spot
	if id == "whip":
		_whip_dir = facing()
		_start_paired("whip", att)
	else:
		_start_paired("hip_toss", att)
	AudioDirector.play("parry", body_center(), 2.0)
	gain_momentum(12.0)
	att.gain_momentum(-6.0)
	reversed.emit(self, att, "reversal")


func _take_move_damage(attacker: Wrestler, mv: Dictionary) -> void:
	var dmg := float(mv["damage"]) * attacker.damage_boost()
	_damage(dmg)
	if mv.get("finisher", false):
		_finisher_hit = 10.0
	else:
		attacker.gain_momentum(dmg * 1.6)
	gain_momentum(dmg * 0.35)
	if dmg >= 9.0:
		freeze(0.06)
		attacker.freeze(0.06)
	var land := attacker._anchor * Grapples.root_xform(mv["root_end_d"], model_scale())
	if Ring.is_outside(land.origin):
		landed_outside.emit(self, land.origin - land.basis.z * 0.35 * model_scale())
	if mv.has("sfx"):
		AudioDirector.play(mv["sfx"], body_center())
	struck.emit(attacker, self, mv, false)
	landed_on_canvas.emit(self)


func _finish_pair() -> void:
	var mv := _pair
	var p := partner
	if p and p.state == State.PAIRED and p.partner == self:
		p._end_paired(mv, "d", self)
	if _helper and _helper.state == State.PAIRED and _helper._role == "a2":
		_helper._end_paired(mv, "a", p)
	_helper = null
	_end_paired(mv, "a", p)


func _end_paired(mv: Dictionary, role: String, other: Wrestler) -> void:
	var end_info: Dictionary = mv["root_end_" + role]
	global_transform = _anchor * Grapples.root_xform(end_info, model_scale())
	_update_region()
	_set_solid(true)
	_pair = {}
	var end: String = mv["end_" + role]
	var blend := 0.15 if Grapples.is_identity(end_info) else 0.0
	match end:
		"idle": _enter(State.IDLE, blend)
		"getup": _enter(State.GETUP, 0.0)
		"down": _go_down(0.4 + float(mv.get("down_extra", 0.0)))
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
			_kickout_need = int((2 + pow(1.0 - health / MAX_HEALTH, 1.8) * 18.0 + (16.0 if health <= 0.0 else 0.0))
				* Stats.kickout_ease(stats))
			if _finisher_hit > 0.0:
				_kickout_need = int(_kickout_need * 1.6) + 6
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
			_corner_clock = 0.0
			_corner_hits = 0
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


func _st_corner_hit(delta: float) -> void:
	_hold_still()
	_corner_tick(delta)
	if state == State.CORNER_HIT and state_time >= _anim_length("corner_hit"):
		_enter(State.CORNERED)


func _st_cornered(delta: float) -> void:
	_hold_still()
	_corner_tick(delta)


## The corner timer keeps running through hits; mashing shakes it off sooner.
func _corner_tick(delta: float) -> void:
	_corner_clock += delta
	if controller and controller.mash:
		_corner_clock += 0.12
	if _corner_clock >= CORNER_TIME:
		_leave_corner()


func _leave_corner() -> void:
	_push = facing() * 1.5
	_enter(State.CORNER_EXIT)


func _st_corner_exit(_delta: float) -> void:
	velocity.x = _push.x
	velocity.z = _push.z
	if state_time >= _anim_length("corner_exit") - 0.02:
		_enter(State.IDLE)
		_grace = WAKE_GRACE * 0.6


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
	dmg *= attacker.damage_boost()
	_damage(dmg)
	attacker.gain_momentum(dmg * 1.2)
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
	gain_momentum(6.0)
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
	if on_apron():
		return       # the partner on the apron just stays put
	partner = null
	_set_solid(true)
	_enter(State.CELEBRATE)


func lose() -> void:
	match_over = true
	if on_apron():
		return
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
		health = maxf(0.0, health - amount * DAMAGE_SCALE * Stats.damage_taken(stats))
	health_changed.emit(self)


func _speed() -> float:
	return Stats.speed(stats)


func _hold_still() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _set_solid(solid: bool) -> void:
	# locked/paired wrestlers overlap by design, so they stop colliding with each other
	collision_layer = 2 if solid else 0
	collision_mask = 3 if solid else 1


func _flat_xform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rotation.y), Vector3(global_position.x, global_position.y, global_position.z))


## Horizontal length of a vector.
static func _flat_len(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


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
	if outside:
		return false
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
	if state in SCRIPTED:
		return
	if outside:
		_confine_outside()
		return
	var extra := 0.0
	if state == State.REBOUND:
		extra = 0.5
	elif state in [State.CORNER_HIT, State.CORNERED]:
		extra = 0.2
	var lim := _rope_limit() + extra
	position.x = clampf(position.x, -lim, lim)
	position.z = clampf(position.z, -lim, lim)
	# never sink into the canvas: two bodies put on the same spot (a whip into an occupied
	# corner) can make the physics push one of them down through it
	if position.y < Ring.canvas_height() - 0.05:
		position.y = Ring.canvas_height()
		velocity.y = 0.0


func _confine_outside() -> void:
	var lim := float(Ring.spec()["barricade_half"]) - 0.4
	position.x = clampf(position.x, -lim, lim)
	position.z = clampf(position.z, -lim, lim)
	# keep out of the ring apron
	var rb := Ring.canvas_half() + 0.32
	if absf(position.x) < rb and absf(position.z) < rb:
		if absf(position.x) > absf(position.z):
			position.x = signf(position.x) * rb
		else:
			position.z = signf(position.z) * rb


# ---------------------------------------------------------------- leaving / entering the ring

## Walking into the ropes (or the apron from outside) for a moment rolls out (or in).
func _edge_push(mv: Vector3, delta: float) -> bool:
	var n := _edge_normal(mv)
	if n == Vector3.ZERO:
		_edge_time = 0.0
		return false
	_edge_time += delta
	if _edge_time < EDGE_PUSH_TIME:
		return false
	_edge_time = 0.0
	var axis := 0 if n.x != 0.0 else 2
	if outside:
		# snap to the apron so the roll-in lands just inside the ropes
		position[axis] = -n[axis] * (_rope_limit() + _root_dist("enter_ring"))
		_face(n, 0.0, true)
		_start_root_anim(State.ENTER_RING, "enter_ring")
	else:
		position[axis] = n[axis] * _rope_limit()
		_face(n, 0.0, true)
		_start_root_anim(State.EXIT_RING, "exit_ring")
	return true


## Outward (in the ring) or inward (outside) direction we're pushing against, or zero.
func _edge_normal(mv: Vector3) -> Vector3:
	if mv.length() < 0.5:
		return Vector3.ZERO
	var p := global_position
	var side_lim := float(Ring.spec()["post_half"]) - 0.6
	for axis: int in [0, 2]:
		var other: int = 2 - axis
		if absf(p[other]) > side_lim:
			continue
		var n := Vector3.ZERO
		if outside:
			if absf(p[axis]) < Ring.canvas_half() + 0.9:
				n[axis] = -signf(p[axis])
		elif absf(p[axis]) >= _rope_limit() - 0.03:
			n[axis] = signf(p[axis])
		if n != Vector3.ZERO and mv.normalized().dot(n) > 0.7:
			return n
	return Vector3.ZERO


func _root_dist(anim_name: String) -> float:
	return float(_root_info(anim_name, "root_end")["pos"][2]) * model_scale()


func _start_root_anim(s: State, anim_name: String) -> void:
	_root_start = _flat_xform()
	_root_anim = anim_name
	_root_impact_done = false
	_edge_time = 0.0
	state = s
	state_time = 0.0
	invulnerable = false
	_set_solid(false)
	_play(anim_name, 0.08, true)


func _st_root_anim(_delta: float) -> void:
	var info: Dictionary = WrestlerModel.manifest()["animations"][_root_anim]
	var land := _root_start * Grapples.root_xform(info["root_end"], model_scale())
	if not _root_impact_done and info["events"].has("impact") and state_time >= float(info["events"]["impact"]):
		_root_impact_done = true
		_damage(6.0)
		AudioDirector.play("body_fall", land.origin + Vector3.UP * 0.3)
		landed_on_canvas.emit(self)
		if Ring.is_outside(land.origin):
			landed_outside.emit(self, land.origin - land.basis.z * 0.35)
	if state_time < float(info["length"]) - 0.01:
		return
	global_transform = land
	_update_region()
	_set_solid(true)
	match state:
		State.FALL_OUT: _go_down(0.5)
		State.CLIMB: _enter(State.PERCH, 0.0)
		State.APRON_EXIT: _enter(State.APRON, 0.0)
		_:
			if _to_apron:
				_to_apron = false
				_enter(State.APRON, 0.0)
			else:
				_enter(State.IDLE, 0.0)


## A big hit near the ropes sends the victim over the top to the floor.
func _try_fall_over_ropes(push_dir: Vector3, knockback: float) -> bool:
	if outside or knockback < 3.5:   # only the biggest shots (clotheslines) go over
		return false
	var p := global_position
	var lim := _rope_limit()
	var side_lim := float(Ring.spec()["post_half"]) - 0.5
	for axis: int in [0, 2]:
		var other: int = 2 - axis
		if absf(p[axis]) >= lim - 0.45 and absf(p[other]) < side_lim and push_dir[axis] * signf(p[axis]) > 0.6:
			var n := Vector3.ZERO
			n[axis] = signf(p[axis])
			position[axis] = n[axis] * lim
			_face(-n, 0.0, true)       # back to the ropes
			_combo_hits = 0
			_start_root_anim(State.FALL_OUT, "fall_over_ropes")
			return true
	return false


## In a tie-up next to the ropes, a whip toward them becomes a toss over the top.
func _rope_toss_normal(dir: Vector3) -> Vector3:
	if outside:
		return Vector3.ZERO
	var victim := _anchor * Grapples.root_xform(_root_info("tieup_d", "root_end"), partner.model_scale())
	var lim := _rope_limit()
	var side_lim := float(Ring.spec()["post_half"]) - 0.6
	for axis: int in [0, 2]:
		var other: int = 2 - axis
		var n := Vector3.ZERO
		n[axis] = signf(victim.origin[axis])
		if absf(victim.origin[axis]) > lim - 0.9 and absf(victim.origin[other]) < side_lim and dir.dot(n) > 0.6:
			return n
	return Vector3.ZERO


func _start_rope_toss(n: Vector3) -> void:
	# square up to the ropes so the opponent goes straight over the top
	var axis := 0 if n.x != 0.0 else 2
	_face(n, 0.0, true)
	position[axis] = n[axis] * (_rope_limit() - 0.1 - TIEUP_DIST_M * partner.model_scale())
	_start_paired("rope_toss", partner)


const TIEUP_DIST_M := 0.8


# ---------------------------------------------------------------- turnbuckles

func _try_climb() -> bool:
	if outside:
		return false
	for i in 4:
		var spot := _corner_spot(i)
		var to := spot - global_position
		to.y = 0
		if to.length() < 1.1 and facing().dot(to.normalized()) > 0.2:
			var dir := to.normalized()
			global_position = Vector3(spot.x, global_position.y, spot.z) - dir * 0.6
			_face(dir, 0.0, true)
			_start_root_anim(State.CLIMB, "climb_corner")
			return true
	return false


func _st_perch(_delta: float) -> void:
	if match_over:
		return
	var a := _take_buffered()
	if a == "punch" or a == "kick":
		_start_dive(a)
		return
	var c := controller
	if a == "grapple" or a == "block" or state_time > 6.0 or (c and c.move.length() > 0.5 and c.move.dot(facing()) < -0.6):
		_start_root_anim(State.CLIMB_DOWN, "climb_down")


func _start_dive(button: String) -> void:
	var t := nearest_opponent()
	var y := Ring.canvas_height()
	var lim := _rope_limit()
	_dive_target = t
	_dive_kind = "whiff"
	var to := global_position + facing() * 2.4
	if t and not t.outside:
		var flat_d := Vector2(t.global_position.x - global_position.x, t.global_position.z - global_position.z).length()
		if t.is_down() and flat_d < 5.5:
			to = t.body_center()
			_dive_kind = move_for("dive_punch" if button == "punch" else "dive_kick")
		elif t.is_standing() and t.state not in BUSY and flat_d < 5.5:
			to = t.global_position
			_dive_kind = "crossbody"
	to = Vector3(clampf(to.x, -lim, lim), y + (0.95 if _dive_kind == "crossbody" else 0.22), clampf(to.z, -lim, lim))
	_dive_from = global_position + Vector3.UP * 0.5
	_dive_to = to
	_face(to - global_position, 0.0, true)
	_dive_time = 0.42 + Vector2(to.x - global_position.x, to.z - global_position.z).length() * 0.06
	state = State.DIVE
	state_time = 0.0
	_play(_dive_kind if _dive_kind.begins_with("dive_") else "dive_splash", 0.1, true)
	move_performed.emit(self, _dive_kind if _dive_kind.begins_with("dive_") else "dive_" + _dive_kind)


func _st_dive(_delta: float) -> void:
	var s := clampf(state_time / _dive_time, 0.0, 1.0)
	global_position = _dive_from.lerp(_dive_to, s) + Vector3.UP * 0.8 * 4.0 * s * (1.0 - s)
	if s < 1.0:
		return
	var t := _dive_target
	var hit := false
	match _dive_kind:
		"crossbody":
			if t and t.can_be_hit() and Vector2(t.global_position.x - _dive_to.x, t.global_position.z - _dive_to.z).length() < 1.1:
				t.receive_strike(self, {"id": "crossbody", "damage": 13.0, "knockdown": true, "knockback": 1.5,
					"hitstop": 0.12, "sfx": "hit_heavy", "region": "body"})
				hit = true
		_ when _dive_kind.begins_with("dive_"):
			if t and t.is_down() and t.distance_to_body(_dive_to) < 0.9:
				t.receive_ground_hit(self, float(Movesets.DIVE_DAMAGE.get(_dive_kind, 14.0)))
				hit = true
	if not hit:
		_damage(7.0)
		AudioDirector.play("body_fall", global_position)
	landed_on_canvas.emit(self)
	_set_solid(true)
	_enter(State.DIVE_LAND, 0.05)


func _st_dive_land(_delta: float) -> void:
	_hold_still()
	if state_time >= _anim_length("dive_land"):
		_go_down()
		_down_left = 0.7


# ---------------------------------------------------------------- chairs

func _try_pick_up_item() -> bool:
	for node in get_tree().get_nodes_in_group("chairs"):
		var chair := node as Chair
		if chair.is_free() and Vector2(chair.global_position.x - global_position.x,
				chair.global_position.z - global_position.z).length() < 1.0 \
				and absf(chair.global_position.y - global_position.y) < 0.8:
			_item_target = chair
			_face(chair.global_position - global_position, 0.0, true)
			_enter(State.ITEM_PICKUP)
			return true
	return false


func _st_item_pickup(_delta: float) -> void:
	_hold_still()
	var grab := _event("item_pickup", "grab", 0.3)
	if _item_target and state_time >= grab and held_item == null:
		if _item_target.is_free():
			_item_target.pick_up(self)
			held_item = _item_target
		_item_target = null
	if state_time >= _anim_length("item_pickup"):
		_enter(State.IDLE)


func _idle_with_item(mv: Vector3, delta: float) -> void:
	velocity.x = mv.x * WALK_SPEED * _speed() * 0.85 + _push.x
	velocity.z = mv.z * WALK_SPEED * _speed() * 0.85 + _push.z
	var target := nearest_opponent()
	if mv.length() > 0.15:
		_face(mv, delta * 10.0)
	elif target and global_position.distance_to(target.global_position) < LOCK_ON_RANGE:
		_face(flat_dir_to(target), delta * 4.0)
	_play("chair_walk" if mv.length() > 0.15 else "chair_hold", 0.2)


func _st_chair_swing(_delta: float) -> void:
	_hold_still()
	var hit := _event("chair_swing", "hit", 0.4)
	if state_time >= hit and state_time - get_physics_process_delta_time() < hit:
		var landed := false
		for o in opponents:
			if not o.can_be_hit():
				continue
			var to := o.global_position - global_position
			to.y = 0
			if to.length() <= float(CHAIR_SHOT["reach"]) and rad_to_deg(facing().angle_to(to)) <= float(CHAIR_SHOT["arc"]):
				o.receive_strike(self, CHAIR_SHOT)
				landed = true
		if not landed:
			AudioDirector.play("whoosh", global_position + Vector3.UP * 1.5, -6.0)
		else:
			move_performed.emit(self, "chair_shot")
	if state_time >= _anim_length("chair_swing"):
		_enter(State.IDLE)


func drop_item(throw_velocity: Vector3 = Vector3.ZERO) -> void:
	if held_item == null:
		return
	var item := held_item
	held_item = null
	item.drop(get_parent(), throw_velocity)



# ---------------------------------------------------------------- tag team

func _st_apron(delta: float) -> void:
	global_position = apron_spot
	_face(Vector3(0, 0, -signf(apron_spot.z)), 0.0, true)
	if health < MAX_HEALTH and not match_over:
		health = minf(MAX_HEALTH, health + APRON_REGEN * delta)
		health_changed.emit(self)
	var wants := teammate != null and teammate.legal and teammate.is_standing() and not teammate.outside \
		and _flat_len(teammate.global_position - entry_spot()) < TAG_REACH + 0.8
	_play("apron_reach" if wants else "apron_wait", 0.2)
	if match_over or controller == null:
		return
	# push toward the ring to climb in (illegally, unless tagged)
	var inward := Vector3(0, 0, -signf(apron_spot.z))
	if controller.move.length() > 0.5 and controller.move.normalized().dot(inward) > 0.7:
		_edge_time += delta
		if _edge_time >= EDGE_PUSH_TIME:
			enter_from_apron()
	else:
		_edge_time = 0.0


## Step through the ropes into the ring (legal if we were just tagged in).
func enter_from_apron() -> void:
	global_position = apron_spot
	_face(Vector3(0, 0, -signf(apron_spot.z)), 0.0, true)
	_start_root_anim(State.APRON_ENTER, "apron_enter")


## Step out to the apron from just inside the ropes at our corner.
func exit_to_apron() -> void:
	var e := entry_spot()
	global_position = Vector3(e.x, global_position.y, e.z)
	_face(Vector3(0, 0, signf(apron_spot.z)), 0.0, true)
	forced_return = false
	_start_root_anim(State.APRON_EXIT, "apron_exit")


func _try_tag() -> bool:
	if teammate == null or not legal or outside or held_item or teammate.state != State.APRON:
		return false
	if _flat_len(global_position - entry_spot()) > TAG_REACH:
		return false
	var hot := health < MAX_HEALTH * 0.5
	legal = false
	teammate.legal = true
	teammate.illegal_time = 0.0
	exit_to_apron()
	teammate.enter_from_apron()
	if hot:
		teammate.gain_momentum(25.0)
	tagged.emit(self, teammate, hot)
	return true


## An illegal partner near their corner, pushing toward the apron, steps back out.
func _try_return_to_apron(mv: Vector3) -> bool:
	if outside or held_item:
		return false
	if _flat_len(entry_spot() - global_position) > 0.45:
		return false
	var out := Vector3(0, 0, signf(apron_spot.z))
	if forced_return or (mv.length() > 0.5 and mv.normalized().dot(out) > 0.7):
		exit_to_apron()
		return true
	return false


## Where the referee is steering an illegal partner: back into the ring, then to their corner.
func _forced_move() -> Vector3:
	var goal := entry_spot()
	if outside:
		# head for the near side of the ring and push in under the ropes
		var p := global_position
		var axis := 0 if absf(p.x) > absf(p.z) else 2
		var n := Vector3.ZERO
		n[axis] = -signf(p[axis])
		return n
	var to := _flat(goal - global_position, Vector3.ZERO)
	return to.normalized() if to.length() > 0.05 else Vector3.ZERO


## Teammate has an opponent in a tie-up: join in for a double suplex.
func _try_double_team(target: Wrestler) -> bool:
	var a := teammate
	if a == null or target.state != State.HELD or target.partner != a or a.state != State.TIEUP:
		return false
	if _flat_len(target.global_position - global_position) > 1.8 or target.outside != outside:
		return false
	var mv := Grapples.get_move("double_suplex")
	var anchor := a._anchor
	anchor.origin += _inside_shift(anchor, mv, target)
	var side := anchor.basis.x * 0.36
	target._begin_paired(a, mv, anchor, "d")
	a._begin_paired(target, mv, anchor.translated(side), "a")
	_begin_paired(target, mv, anchor.translated(-side), "a2")
	a._anchor_base = a._anchor
	a._anchor_shift = Vector3.ZERO
	a._impact_done = false
	a._released = false
	a._helper = self
	move_performed.emit(a, "double_suplex")
	double_team.emit(a, self, target)
	return true


## A pinner hit by the pinned wrestler's partner: the pin is broken up.
func _broken_up(by: Wrestler) -> void:
	var d := partner
	pin_saved.emit(by, self)
	by.gain_momentum(10.0)
	if d:
		d.kick_out()
	_set_solid(true)
	partner = null
	_push = by.flat_dir_to(self) * 2.5
	_enter(State.KNOCKDOWN)
	knocked_down.emit(self)


# ---------------------------------------------------------------- entrances

## From the floor in front of our apron spot, climb up to wait on the apron.
func climb_to_apron() -> void:
	_to_apron = true
	_face(Vector3(0, 0, -signf(apron_spot.z)), 0.0, true)
	_start_root_anim(State.ENTER_RING, "enter_ring")


## From the floor beside the ring, roll in under the bottom rope.
func roll_in() -> void:
	_start_root_anim(State.ENTER_RING, "enter_ring")


## Scripted walking during entrances (the director moves us; we just animate).
func entrance_walk(to: Vector3, speed: float, delta: float) -> bool:
	var d := to - global_position
	var flat := Vector3(d.x, 0, d.z)
	if flat.length() < 0.05:
		global_position = to
		return true
	var step := minf(flat.length(), speed * delta)
	global_position += flat.normalized() * step
	global_position.y = to.y if flat.length() < 0.3 else lerpf(global_position.y, to.y, step / flat.length())
	_face(flat, delta * 8.0)
	_play("walk", 0.2)
	model.anim_player.speed_scale = speed / WALK_SPEED
	return false


func entrance_pose(anim_name: String) -> void:
	model.anim_player.speed_scale = 1.0
	_play(anim_name, 0.2)
