class_name HitFx
extends Node3D
## One-shot impact burst: a flash plus a spray of sweat droplets. Frees itself.

static func spawn(parent: Node, at: Vector3, heavy: bool) -> void:
	var fx := HitFx.new()
	parent.add_child(fx)
	fx.global_position = at
	fx._build(heavy)


func _build(heavy: bool) -> void:
	var spray := CPUParticles3D.new()
	spray.one_shot = true
	spray.explosiveness = 1.0
	spray.amount = 40 if heavy else 18
	spray.lifetime = 0.45
	spray.direction = Vector3.UP
	spray.spread = 180.0
	spray.initial_velocity_min = 1.5
	spray.initial_velocity_max = 4.5 if heavy else 3.0
	spray.gravity = Vector3(0, -9.8, 0)
	spray.scale_amount_min = 0.5
	spray.scale_amount_max = 1.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.012
	mesh.height = 0.024
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.95, 0.8)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	spray.mesh = mesh
	add_child(spray)
	spray.emitting = true

	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.85, 0.6)
	flash.light_energy = 6.0 if heavy else 3.0
	flash.omni_range = 2.5
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.12)
	get_tree().create_timer(0.6).timeout.connect(queue_free)
