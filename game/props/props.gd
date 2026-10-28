class_name Props
## Access to meshes in the generated props.glb (chair, table, table pieces).

const SCENE := preload("res://assets/generated/props.glb")

static var _library: Node3D


static func mesh_node(node_name: String) -> MeshInstance3D:
	if _library == null:
		_library = SCENE.instantiate()
	var src := _library.find_child(node_name, true, false) as MeshInstance3D
	var mi := MeshInstance3D.new()
	mi.mesh = src.mesh
	mi.transform = src.transform
	return mi
