class_name WrestlerModel
extends Node3D
## Visual wrestler: the generated rig/body with a WrestlerLook applied and an
## AnimationPlayer whose loop flags come from the generated manifest.

const MODEL_SCENE := preload("res://assets/generated/wrestler.glb")
const MANIFEST_PATH := "res://assets/generated/wrestler.json"
const BODY_SHADER := preload("res://fx/wrestler_body.gdshader")
const HAIR_SHADER := preload("res://fx/wrestler_hair.gdshader")
const EYES_SHADER := preload("res://fx/wrestler_eyes.gdshader")

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
# Clips that end at another arena level (floor, apron, turnbuckle): this model's own copy of each,
# with the root track's index and the untouched source key heights. See _set_absolute_root_height().
var _absolute_root: Array[Dictionary] = []
var _absolute_root_height := 1.0


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
	_setup_animations()
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
	_set_absolute_root_height(l.height)
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
	_own_absolute_root_clips(anims)


## The whole model is scaled by the wrestler's height, root motion included. That's right for
## distances, but a clip that ends at a different height (rolling out to the floor, climbing a
## turnbuckle) travels between arena levels whose heights are the same for everybody, and the
## game places the wrestler there absolutely (Grapples.root_xform). So this model gets its own
## copies of those clips (the imported ones are shared by every wrestler) and their root height
## keys are divided by the height in _set_absolute_root_height(). Clips that lift the root but
## come back down (carries, lifts) keep scaling with the body.
func _own_absolute_root_clips(anims: Dictionary) -> void:
	var root_bone := skeleton.find_bone("root")
	var track_path := NodePath("%s:root" % _model.get_path_to(skeleton))
	var source := anim_player.get_animation_library(&"")
	var lib := AnimationLibrary.new()
	for anim_name in source.get_animation_list():
		var a := source.get_animation(anim_name)
		var info: Dictionary = anims.get(String(anim_name), {})
		if info.has("root_end") and absf(float(info["root_end"]["pos"][1])) > 0.001:
			var t := a.find_track(track_path, Animation.TYPE_POSITION_3D)
			assert(t >= 0 and not a.track_is_compressed(t), "editable root track in " + anim_name)
			var heights := PackedFloat32Array()
			for k in a.track_get_key_count(t):
				heights.append(a.track_get_key_value(t, k).y)
			a = a.duplicate()
			_absolute_root.append({"anim": a, "track": t, "heights": heights,
				"rest": skeleton.get_bone_rest(root_bone).origin.y})
		lib.add_animation(anim_name, a)
	anim_player.remove_animation_library(&"")
	anim_player.add_animation_library(&"", lib)


## Rewrites the owned clips' root heights from the source keys, so that the scaled model travels
## exactly the authored height: rest + (y - rest) / height, which scales back up to
## height * rest + (y - rest).
func _set_absolute_root_height(height: float) -> void:
	if not is_finite(height) or height <= 0.0:
		push_warning("WrestlerModel: invalid height %s; keeping the last valid root motion" % height)
		return
	if is_equal_approx(height, _absolute_root_height):
		return
	_absolute_root_height = height
	for c in _absolute_root:
		var a: Animation = c["anim"]
		var t: int = c["track"]
		var rest: float = c["rest"]
		var heights: PackedFloat32Array = c["heights"]
		for k in heights.size():
			var p: Vector3 = a.track_get_key_value(t, k)
			p.y = rest + (heights[k] - rest) / height
			a.track_set_key_value(t, k, p)
