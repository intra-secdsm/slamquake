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


func test_gamepad_can_drive_menus() -> void:
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var ok := false
		for e in InputMap.action_get_events(pair[0]):
			ok = ok or (e is InputEventJoypadButton and e.button_index == pair[1])
		assert_true(ok, "%s mapped to a gamepad button" % pair[0])
