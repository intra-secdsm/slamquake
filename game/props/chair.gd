class_name Chair
extends RigidBody3D
## Steel folding chair: lies around until a wrestler picks it up, then rides in their
## right hand. Dropped chairs fall and tumble with physics.

## Chair pose relative to the right hand bone; overridable for tuning (--chair_rot=x,y,z --chair_pos=x,y,z)
static var hold_offset := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-80), 0, deg_to_rad(90))), Vector3(0.05, 0.05, 0.05))

var holder: Wrestler
var _attach: BoneAttachment3D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 4
	mass = 4.0
	var mesh := Props.mesh_node("chair")
	mesh.position = Vector3.ZERO
	add_child(mesh)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.44, 0.9, 0.42)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, 0.45, 0)
	add_child(cs)


func is_free() -> bool:
	return holder == null


func pick_up(w: Wrestler) -> void:
	holder = w
	freeze = true
	collision_layer = 0
	_attach = BoneAttachment3D.new()
	_attach.bone_name = "hand.R"
	w.model.skeleton.add_child(_attach)
	reparent(_attach, false)
	transform = hold_offset


func drop(world_parent: Node, throw_velocity: Vector3 = Vector3.ZERO) -> void:
	if holder == null:
		return
	var xform := global_transform
	holder = null
	reparent(world_parent, false)
	global_transform = xform
	if _attach:
		_attach.queue_free()
		_attach = null
	collision_layer = 4
	freeze = false
	linear_velocity = throw_velocity
	angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
