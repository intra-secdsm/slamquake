extends GutTest
## Sanity checks that the project boots with the expected configuration.

func test_uses_jolt_physics() -> void:
	assert_eq(ProjectSettings.get_setting("physics/3d/physics_engine"), "Jolt Physics")

func test_boot_scene_loads() -> void:
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	assert_not_null(scene)
	var boot: Node = scene.instantiate()
	add_child_autofree(boot)
	assert_gt(boot.get_child_count(), 0, "boot screen builds its UI in _ready")
