class_name WrestlerModel
extends Node3D
## Visual wrestler: the generated rig/body with a WrestlerLook applied and an
## AnimationPlayer whose loop flags come from the generated manifest.

const MODEL_SCENE := preload("res://assets/generated/wrestler.glb")
const MANIFEST_PATH := "res://assets/generated/wrestler.json"
const BODY_SHADER := preload("res://fx/wrestler_body.gdshader")
const HAIR_SHADER := preload("res://fx/wrestler_hair.gdshader")
const EYES_SHADER := preload("res://fx/wrestler_eyes.gdshader")
## Clips whose root motion encodes absolute arena heights (canvas, floor, turnbuckle).
## The uniform model scale would scale that vertical travel, while Grapples.root_xform()
## places the wrestler at the authored absolute height; each model instance therefore
## owns a private copy of exactly these animations with height-corrected root Y keys.
const ABSOLUTE_ROOT_ANIMS := ["exit_ring", "enter_ring", "fall_over_ropes", "climb_corner", "climb_down", "rope_toss_d"]

static var _manifest: Dictionary = {}

@export var look: WrestlerLook:
	set(value):
		look = value
		if is_node_ready():
			apply_look()

var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var body: MeshInstance3D
var _hair: Dictionary = {}   # style -> MeshInstance3D
var _facial: Dictionary = {}   # facial hair style -> MeshInstance3D
var _body_mat := ShaderMaterial.new()
var _hair_mat := ShaderMaterial.new()
var _eyes_mat := ShaderMaterial.new()
var _model: Node3D
var _abs_source: Dictionary = {}  # anim name -> {"times": [], "pos": [], "trans": []} (immutable)
var _abs_track: Dictionary = {}   # anim name -> root position track index in the instance copy
var _abs_rest_y := 0.0            # root bone rest origin Y in skeleton space
var _abs_height := 0.0            # last valid height the copies were corrected for
## The last corrected clip that started on the player. Re-registering the library
## blanks current_animation (the mixer keeps the held pose but forgets the name),
## so a height change arriving while the player is stopped cannot be refreshed
## without this record.
var _abs_active: StringName = ""


func _ready() -> void:
	_model = MODEL_SCENE.instantiate()
	add_child(_model)
	skeleton = _model.find_child("Skeleton3D", true, false)
	anim_player = _model.find_child("AnimationPlayer", true, false)
	_body_mat.shader = BODY_SHADER
	_hair_mat.shader = HAIR_SHADER
	_eyes_mat.shader = EYES_SHADER
	for mi in skeleton.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		if n == "body":
			body = mi
			mi.material_override = _body_mat
		elif n == "eyes":
			mi.material_override = _eyes_mat
		elif n.begins_with("hair_"):
			_hair[n.trim_prefix("hair_")] = mi
			mi.material_override = _hair_mat
		elif n.begins_with("facial_"):
			_facial[n.trim_prefix("facial_")] = mi
			mi.material_override = _hair_mat
	_prepare_absolute_root_animations()
	_setup_animations()
	if not anim_player.animation_started.is_connected(_on_abs_anim_started):
		anim_player.animation_started.connect(_on_abs_anim_started)
	if look == null:
		look = WrestlerLook.new()
	apply_look()


## Edge glow strength (0 = off), e.g. while a SPECIAL is banked.
func set_aura(amount: float) -> void:
	_body_mat.set_shader_parameter("aura", amount)


## Wear a championship belt: 0 none, 1 world title (gold), 2 tag titles (silver).
func set_belt(kind: int) -> void:
	_body_mat.set_shader_parameter("belt", kind)


func apply_look() -> void:
	var l := look
	_model.scale = Vector3.ONE * l.height
	_update_absolute_root_height(l.height)
	_set_blend("heavy", maxf(l.mass, 0.0))
	_set_blend("slim", maxf(-l.mass, 0.0))
	_set_blend("muscle", l.muscle)
	_set_blend("gut", l.gut)
	_set_blend("kneepads", 1.0 if l.kneepads else 0.0)
	_set_blend("fem", l.feminine)
	for style in _hair:
		_hair[style].visible = style == l.hair_style
	# a full mask covers the face, beard and all
	var face_hidden := l.mask != "none" and l.mask != "half"
	for style in _facial:
		_facial[style].visible = style == l.facial_hair and not face_hidden

	var m := _body_mat
	m.set_shader_parameter("skin_color", l.skin_color)
	m.set_shader_parameter("trunks_color", l.trunks_color)
	m.set_shader_parameter("trim_color", l.trim_color)
	m.set_shader_parameter("boots_color", l.boots_color)
	m.set_shader_parameter("pads_color", l.pads_color)
	m.set_shader_parameter("tights_color", l.tights_color)
	m.set_shader_parameter("brow_color", l.brow_color)
	m.set_shader_parameter("tights", 1.0 if l.tights else 0.0)
	m.set_shader_parameter("kneepads", 1.0 if l.kneepads else 0.0)
	m.set_shader_parameter("wristbands", 1.0 if l.wristbands else 0.0)
	m.set_shader_parameter("elbowpads", 1.0 if l.elbowpads else 0.0)
	m.set_shader_parameter("waist", l.waist)
	m.set_shader_parameter("trunks_bottom", l.trunks_bottom)
	m.set_shader_parameter("boot_top", l.boot_top)
	m.set_shader_parameter("shirt", 1.0 if l.shirt else 0.0)
	m.set_shader_parameter("shirt_color", l.shirt_color)
	m.set_shader_parameter("stripe_color", l.stripe_color)
	m.set_shader_parameter("stripes", float(l.stripes))
	m.set_shader_parameter("feminine", l.feminine)
	m.set_shader_parameter("boots", 1.0 if l.boots else 0.0)
	m.set_shader_parameter("singlet", 1.0 if l.singlet else 0.0)
	# a feminine body always has its chest covered: a top, unless a singlet does it
	m.set_shader_parameter("top", 1.0 if l.top or (l.feminine > 0.5 and not l.singlet) else 0.0)
	m.set_shader_parameter("top_color", l.top_color)
	m.set_shader_parameter("pattern_style", _choice(l, "pattern"))
	m.set_shader_parameter("pattern_color", l.pattern_color)
	m.set_shader_parameter("paint_style", _choice(l, "face_paint"))
	m.set_shader_parameter("paint_color", l.paint_color)
	m.set_shader_parameter("paint_color2", l.paint_color2)
	m.set_shader_parameter("mask_style", _choice(l, "mask"))
	m.set_shader_parameter("mask_color", l.mask_color)
	m.set_shader_parameter("mask_trim", l.mask_trim)
	m.set_shader_parameter("tattoo_style", _choice(l, "tattoo"))
	m.set_shader_parameter("tattoo_color", l.tattoo_color)
	_hair_mat.set_shader_parameter("hair_color", l.hair_color)
	_eyes_mat.set_shader_parameter("iris_color", l.eye_color)


## Index of an enum property's value (0 = the first choice, usually "none").
static func _choice(l: WrestlerLook, property: String) -> int:
	return maxi(0, l.choices(property).find(String(l.get(property))))


func play(anim_name: StringName, blend: float = 0.15, speed: float = 1.0) -> void:
	anim_player.play(anim_name, blend, speed)


func has_animation(anim_name: StringName) -> bool:
	return anim_player.has_animation(anim_name)


static func manifest() -> Dictionary:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	return _manifest


func _set_blend(shape: String, value: float) -> void:
	var idx := body.find_blend_shape_by_name(shape)
	if idx >= 0:
		body.set_blend_shape_value(idx, value)


func _setup_animations() -> void:
	var anims: Dictionary = manifest().get("animations", {})
	for anim_name in anims:
		if anim_player.has_animation(anim_name):
			var a := anim_player.get_animation(anim_name)
			a.loop_mode = Animation.LOOP_LINEAR if anims[anim_name]["loop"] else Animation.LOOP_NONE


## Give this instance a private copy of each absolute-root clip (the rest of the library
## stays shared read-only) and remember the untouched source root track, so the height
## correction is always recomputed from the original authored values.
func _prepare_absolute_root_animations() -> void:
	var libs := anim_player.get_animation_library_list()
	if libs.is_empty():
		return
	var lib_name: StringName = libs[0]
	var src: AnimationLibrary = anim_player.get_animation_library(lib_name)
	var lib := AnimationLibrary.new()
	var ridx := skeleton.find_bone("root")
	if ridx >= 0:
		_abs_rest_y = skeleton.get_bone_rest(ridx).origin.y
	for name in src.get_animation_list():
		var a: Animation = src.get_animation(name)
		var t := _abs_root_track(a)
		if ABSOLUTE_ROOT_ANIMS.has(name) and t >= 0:
			var data := {"times": [], "pos": [], "trans": []}
			for k in a.track_get_key_count(t):
				data["times"].append(a.track_get_key_time(t, k))
				data["pos"].append(a.track_get_key_value(t, k))
				data["trans"].append(a.track_get_key_transition(t, k))
			_abs_source[name] = data
			_abs_track[name] = t
			lib.add_animation(name, a.duplicate())
			continue
		lib.add_animation(name, a)
	anim_player.remove_animation_library(lib_name)
	anim_player.add_animation_library(lib_name, lib)


## Rewrite the selected clips' root position Y keys so that, under the uniform model
## scale `h`, the visible root displacement equals the authored one. A key holds the
## bone origin in skeleton space, rest origin r plus the authored displacement d; the
## visible travel is h * (key - r), so the corrected key is r + d / h (visible: h * d / h
## = d). The rest contribution h * r is unchanged, so body proportions keep scaling;
## X/Z, rotations and every other track are untouched. Always recomputed from the
## immutable source values, never from an already-corrected key.
func _update_absolute_root_height(h: float) -> void:
	if _abs_source.is_empty():
		return
	if not is_finite(h) or h <= 0.0:
		push_warning("WrestlerModel: invalid height %s; keeping the last valid root motion" % str(h))
		return
	if h == _abs_height:
		return
	for name in _abs_source:
		var a: Animation = anim_player.get_animation(name)
		if a == null:
			continue
		var t: int = int(_abs_track[name])
		var data: Dictionary = _abs_source[name]
		if a.track_is_compressed(t):
			_rebuild_abs_root_track(a, t, data, h)
			continue
		var n := a.track_get_key_count(t)
		for k in mini(n, (data["pos"] as Array).size()):
			var v: Vector3 = a.track_get_key_value(t, k)
			var sy: float = ((data["pos"] as Array)[k] as Vector3).y
			v.y = _abs_rest_y + (sy - _abs_rest_y) / h
			a.track_set_key_value(t, k, v)
	_abs_height = h
	_refresh_abs_pose_if_current()


## Rebuild a compressed track (not editable in place) from the stored source keys.
func _rebuild_abs_root_track(a: Animation, t: int, data: Dictionary, h: float) -> void:
	var mode := a.track_get_interpolation_type(t)
	var wrap := a.track_get_interpolation_loop_wrap(t)
	for k in range(a.track_get_key_count(t) - 1, -1, -1):
		a.track_remove_key(t, k)
	var positions: Array = data["pos"]
	var times: Array = data["times"]
	var trans: Array = data["trans"]
	for k in times.size():
		var v: Vector3 = (positions[k] as Vector3)
		v.y = _abs_rest_y + (v.y - _abs_rest_y) / h
		var idx := a.track_insert_key(t, float(times[k]), v)
		a.track_set_key_transition(t, idx, float(trans[k]))
	a.track_set_interpolation_type(t, mode)
	a.track_set_interpolation_loop_wrap(t, wrap)


## If a corrected clip is the one on the player right now, re-apply the pose from the
## corrected data immediately. The mixer caches the sampled key data of a playing
## animation and keeps using it after the resource is re-keyed, so the instance library
## is re-registered to force a re-sample; seeking to the same time then applies the pose
## without restarting playback. Verified on the pinned engine (4.7.2): plain
## clear_caches()/seek() leaves per-frame playback on the old keys, while a
## play()/seek() restart would discard an active blend.
func _on_abs_anim_started(name: StringName) -> void:
	var n := String(name)
	var slash := n.find("/")
	if slash >= 0:
		n = n.substr(slash + 1)
	if _abs_source.has(n):
		_abs_active = n


func _refresh_abs_pose_if_current() -> void:
	var cur: StringName = anim_player.current_animation
	if cur == "":
		# the library was re-registered after this clip last started (or the player
		# is stopped on a held pose): fall back to the recorded clip
		cur = _abs_active
	if cur == "" or not _abs_source.has(cur):
		return
	var libs := anim_player.get_animation_library_list()
	if libs.is_empty():
		return
	var lib_name: StringName = libs[0]
	var lib := anim_player.get_animation_library(lib_name)
	anim_player.remove_animation_library(lib_name)
	anim_player.add_animation_library(lib_name, lib)
	# The re-registration is only picked up by the mixer on its next update; a zero
	# advance flushes that update without moving the play head. Verified on the
	# pinned engine (4.7.2), including finished-but-holding players, where a plain
	# seek in the same call chain is a no-op.
	anim_player.advance(0.0)
	var pos := anim_player.current_animation_position
	# The mixer only re-samples key data on a seek that actually changes the time
	# (a same-time seek is a no-op, and waiting for the next frame update leaves the
	# old pose visible), so the head is nudged a sub-frame toward the clip interior
	# and back. Verified on the pinned engine (4.7.2) for playing, paused and
	# finished-but-holding players; the play head ends exactly where it was.
	var length: float = (anim_player.get_animation(cur) as Animation).length
	var nudge := 0.001
	if pos + nudge > length:
		nudge = -nudge
	if pos + nudge < 0.0:
		nudge = -nudge
	anim_player.seek(pos + nudge, true)
	anim_player.seek(pos, true)


## The root bone's position track in an animation, resolved by target (skeleton node +
## bone name) and track type, never by track number. glTF-imported track node paths are
## relative to the AnimationPlayer's parent (the model root) in Godot 4.7, while the
## public get_node_or_null() resolves relative to the player itself.
func _abs_root_track(a: Animation) -> int:
	if skeleton == null:
		return -1
	var rname: StringName = skeleton.get_bone_name(skeleton.find_bone("root"))
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		var path: String = a.track_get_path(t)
		var ci := path.rfind(":")
		if ci == -1 or path.substr(ci + 1) != rname:
			continue
		if anim_player.get_parent().get_node_or_null(path.substr(0, ci)) != skeleton:
			continue
		return t
	return -1
