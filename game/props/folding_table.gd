class_name FoldingTable
extends StaticBody3D
## Folding table at ringside. Anyone landing on it smashes it into physics debris.

signal broken(table: FoldingTable)

const SIZE := Vector3(1.8, 0.76, 0.75)
const PIECES := 8

var intact := true
var _intact_mesh: MeshInstance3D
var _shape: CollisionShape3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_intact_mesh = Props.mesh_node("table")
	add_child(_intact_mesh)
	var box := BoxShape3D.new()
	box.size = SIZE
	_shape = CollisionShape3D.new()
	_shape.shape = box
	_shape.position.y = SIZE.y / 2
	add_child(_shape)


## True if a body landing at `at` (world space) hits the table top.
func covers(at: Vector3) -> bool:
	var local := global_transform.affine_inverse() * at
	return absf(local.x) < SIZE.x / 2 + 0.35 and absf(local.z) < SIZE.z / 2 + 0.45


func smash(impact_from: Vector3 = Vector3.UP) -> void:
	if not intact:
		return
	intact = false
	_intact_mesh.visible = false
	_shape.disabled = true
	for i in PIECES:
		var piece := RigidBody3D.new()
		piece.collision_layer = 4          # debris: hits the floor, not the wrestlers
		piece.collision_mask = 1 | 4
		piece.mass = 1.5
		var mesh := Props.mesh_node("table_piece_%d" % i)
		var local_xform := mesh.transform
		mesh.transform = Transform3D.IDENTITY
		piece.add_child(mesh)
		var aabb := mesh.mesh.get_aabb()
		var shape := BoxShape3D.new()
		shape.size = aabb.size.max(Vector3.ONE * 0.03)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = aabb.get_center()
		piece.add_child(cs)
		get_parent().add_child(piece)
		piece.global_transform = global_transform * local_xform
		var out := (piece.global_position - global_position)
		out.y = 0
		piece.linear_velocity = out.normalized() * randf_range(1.0, 3.0) + Vector3.DOWN * 2.0 - impact_from.normalized() * 0.5
		piece.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	AudioDirector.play("table_crash", global_position + Vector3.UP * 0.6, 2.0)
	broken.emit(self)
