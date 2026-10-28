class_name Ring
extends Node3D
## Ring + ringside: generated visuals, dynamic ropes and collision.
## Dimensions come from res://data/ring_spec.json (shared with the Blender generator).

const RING_SCENE := preload("res://assets/generated/ring.glb")
const SPEC_PATH := "res://data/ring_spec.json"

static var _spec: Dictionary = {}

var ropes: RingRopes


static func spec() -> Dictionary:
	if _spec.is_empty():
		_spec = JSON.parse_string(FileAccess.get_file_as_string(SPEC_PATH))
	return _spec


static func canvas_height() -> float:
	return spec()["mat_height"]


## True if a point (x/z) is inside the ropes.
static func canvas_half() -> float:
	return spec()["canvas_half"]


## True if a point is beyond the apron (on the arena floor side).
static func is_outside(p: Vector3) -> bool:
	return maxf(absf(p.x), absf(p.z)) > canvas_half()


static func is_inside(p: Vector3) -> bool:
	var e: float = spec()["post_half"]
	return absf(p.x) < e and absf(p.z) < e


## Turnbuckle corner positions on the canvas, in ring space (index 0..3).
static func corner(i: int) -> Vector3:
	var e: float = spec()["post_half"] - 0.35
	var signs := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	return Vector3(signs[i].x * e, canvas_height(), signs[i].y * e)


func _ready() -> void:
	add_child(RING_SCENE.instantiate())
	ropes = RingRopes.new()
	ropes.name = "Ropes"
	add_child(ropes)
	ropes.setup(spec())
	_build_collision()


func _build_collision() -> void:
	var s := spec()
	var ch: float = s["canvas_half"]
	var mh: float = s["mat_height"]
	var body := StaticBody3D.new()
	body.name = "Collision"
	add_child(body)
	_box(body, Vector3(0, mh / 2, 0), Vector3(ch * 2, mh, ch * 2))
	_box(body, Vector3(0, -0.5, 0), Vector3(60, 1, 60))
	# steel steps on two corners (mirrors blender/wrestle_gen/ring.py)
	for sx in [-1, 1]:
		for i in 3:
			var h: float = mh * (i + 1) / 3.0
			var depth := 0.36 * (3 - i)
			_box(body, Vector3(sx * (ch + depth / 2), h / 2, sx * (float(s["post_half"]) - 0.75)),
				Vector3(depth, h, float(s["steps_width"])))
	# barricade, with the entrance aisle gap on the -z side
	var bh: float = s["barricade_height"]
	var bhalf: float = s["barricade_half"]
	var aisle: float = s["aisle_width"]
	for sx in [-1, 1]:
		_box(body, Vector3(sx * bhalf, bh / 2, 0), Vector3(0.1, bh, bhalf * 2))
	_box(body, Vector3(0, bh / 2, bhalf), Vector3(bhalf * 2, bh, 0.1))
	var seg := bhalf - aisle / 2
	for sx in [-1, 1]:
		_box(body, Vector3(sx * (aisle / 2 + seg / 2), bh / 2, -bhalf), Vector3(seg, bh, 0.1))
	var ph: float = s["post_half"]
	var top: float = mh + s["post_top"]
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var shape := CylinderShape3D.new()
			shape.radius = s["post_radius"] + 0.05
			shape.height = top
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.position = Vector3(sx * ph, top / 2, sz * ph)
			body.add_child(cs)


func _box(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = center
	body.add_child(cs)
