extends GutTest
## Sanity checks that the project boots with the expected configuration.

func test_uses_jolt_physics() -> void:
	assert_eq(ProjectSettings.get_setting("physics/3d/physics_engine"), "Jolt Physics")

func test_main_scene_loads() -> void:
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	assert_not_null(scene)
	var main: Node = scene.instantiate()
	add_child_autofree(main)
	assert_gt(main.get_child_count(), 0, "main scene builds its content in _ready")
