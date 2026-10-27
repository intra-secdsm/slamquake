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
var _body_mat := ShaderMaterial.new()
var _hair_mat := ShaderMaterial.new()
var _eyes_mat := ShaderMaterial.new()
var _model: Node3D


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
	_setup_animations()
	if look == null:
		look = WrestlerLook.new()
	apply_look()


func apply_look() -> void:
	var l := look
	_model.scale = Vector3.ONE * l.height
	_set_blend("heavy", maxf(l.mass, 0.0))
	_set_blend("slim", maxf(-l.mass, 0.0))
	_set_blend("muscle", l.muscle)
	_set_blend("gut", l.gut)
	_set_blend("kneepads", 1.0 if l.kneepads else 0.0)
	for style in _hair:
		_hair[style].visible = style == l.hair_style

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
	_hair_mat.set_shader_parameter("hair_color", l.hair_color)
	_eyes_mat.set_shader_parameter("iris_color", l.eye_color)


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
