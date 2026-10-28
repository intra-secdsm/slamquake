class_name Arena
extends Node3D
## Everything around ringside: the generated arena (seating, stage, ramp, truss), the
## crowd, the titantron and sweeping house lights. `heat` (0..1) drives the crowd's
## excitement, their noise and how lively the lights are.

const ARENA_SCENE := preload("res://assets/generated/arena.glb")

var crowd: Crowd
var titantron: Titantron
var heat := 0.3:
	set(v):
		heat = clampf(v, 0.0, 1.0)
		if crowd:
			crowd.excitement = heat
var _sweeps: Array[SpotLight3D] = []
var _t := 0.0


func _ready() -> void:
	add_child(ARENA_SCENE.instantiate())
	crowd = Crowd.new()
	add_child(crowd)
	titantron = Titantron.new()
	add_child(titantron)
	# the generated screen marks the spot; show the picture on a UV-mapped quad in front of it
	var screen := find_child("titantron_screen", true, false) as MeshInstance3D
	if screen:
		screen.visible = false
	var a: Dictionary = Ring.spec()["arena"]
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0 * float(a["screen_half_width"]), float(a["screen_top"]) - float(a["screen_bottom"]))
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = titantron.screen_material()
	mi.position = Vector3(0, (float(a["screen_bottom"]) + float(a["screen_top"])) / 2.0, -float(a["stage_back"]) + 0.36)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_build_lights()
	heat = heat


## Point of the stage where wrestlers appear, and the bottom of the ramp (world space).
static func stage_point() -> Vector3:
	var a: Dictionary = Ring.spec()["arena"]
	return Vector3(0, float(a["stage_height"]), -(float(a["stage_front"]) + 1.2))


static func ramp_bottom() -> Vector3:
	var a: Dictionary = Ring.spec()["arena"]
	return Vector3(0, 0, -float(a["ramp_end"]))


## Floor height along the entrance path (stage, ramp, aisle).
static func path_height(z: float) -> float:
	var a: Dictionary = Ring.spec()["arena"]
	var front: float = a["stage_front"]
	var end: float = a["ramp_end"]
	return float(a["stage_height"]) * clampf((-z - end) / (front - end), 0.0, 1.0)


func _build_lights() -> void:
	var a: Dictionary = Ring.spec()["arena"]
	# stage wash
	for sx in [-1, 1]:
		var l := SpotLight3D.new()
		add_child(l)
		l.look_at_from_position(Vector3(sx * 5.0, 9.0, -8.0), Vector3(0, 1.0, -float(a["stage_front"]) - 1.5))
		l.light_color = Color("ff2bd6") if sx < 0 else Color("00e5ff")
		l.light_energy = 6.0
		l.spot_range = 20.0
		l.spot_angle = 28.0
		l.light_volumetric_fog_energy = 0.6
	# house lights sweeping over the crowd
	var cols := [Color("ff2bd6"), Color("00e5ff"), Color("ffd400"), Color("7dff3a")]
	for i in 4:
		var l := SpotLight3D.new()
		add_child(l)
		l.position = Vector3(0, float(a["truss_height"]) + 1.0, 0)
		l.light_color = cols[i]
		l.light_energy = 5.0
		l.spot_range = 40.0
		l.spot_angle = 9.0
		l.light_volumetric_fog_energy = 1.2
		_sweeps.append(l)


func _process(delta: float) -> void:
	_t += delta * (0.4 + heat * 1.2)
	var a: Dictionary = Ring.spec()["arena"]
	var r: float = float(a["stands_inner"]) + float(a["rows"]) * float(a["row_depth"]) * 0.5
	for i in _sweeps.size():
		var ang := _t * (0.5 + i * 0.13) + i * TAU / _sweeps.size()
		var target := Vector3(cos(ang) * r, 2.5 + sin(_t * 1.7 + i) * 1.5, sin(ang) * r)
		_sweeps[i].look_at(target)
