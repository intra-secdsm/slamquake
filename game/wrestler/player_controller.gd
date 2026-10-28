class_name PlayerController
extends WrestlerController
## Reads a local player's gamepad/keyboard via InputRouter. Movement is relative to
## the active camera, so "up" always means away from the viewer.

var slot: int


func _init(input_slot: int) -> void:
	slot = input_slot


func update(w: Wrestler, _delta: float) -> void:
	var v := InputRouter.move_vector(slot)
	var cam := w.get_viewport().get_camera_3d()
	if cam:
		var fwd := -cam.global_basis.z
		fwd.y = 0
		fwd = fwd.normalized()
		var right := fwd.cross(Vector3.UP)
		move = (right * v.x - fwd * v.y).limit_length(1.0)
	else:
		move = Vector3(v.x, 0, v.y).limit_length(1.0)
	run_held = InputRouter.held(slot, "run")
	block_held = InputRouter.held(slot, "block")
	punch = InputRouter.pressed(slot, "punch")
	kick = InputRouter.pressed(slot, "kick")
	grapple = InputRouter.pressed(slot, "grapple")
	taunt = InputRouter.pressed(slot, "taunt")
	mash = InputRouter.any_pressed(slot)
