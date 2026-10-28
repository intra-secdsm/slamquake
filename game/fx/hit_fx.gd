class_name HitFx
extends Node3D
## One-shot impact effects that free themselves: a strike burst (flash plus sweat
## spray) and a dust ring for bodies hitting the canvas.

static func spawn(parent: Node, at: Vector3, heavy: bool) -> void:
	var fx := HitFx.new()
	parent.add_child(fx)
	fx.global_position = at
	fx._build(heavy)


static func dust(parent: Node, at: Vector3) -> void:
	var fx := HitFx.new()
	parent.add_child(fx)
	fx.global_position = at
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.explosiveness = 0.95
	puff.amount = 28
	puff.lifetime = 0.7
	puff.direction = Vector3.UP
	puff.spread = 85.0
	puff.flatness = 0.7
	puff.initial_velocity_min = 0.8
	puff.initial_velocity_max = 2.2
	puff.gravity = Vector3(0, -1.5, 0)
	puff.damping_min = 2.0
	puff.damping_max = 3.0
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = 0.35
	puff.scale_amount_min = 0.6
	puff.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.0))
	puff.scale_amount_curve = curve
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.14, 0.14)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.93, 0.9, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = mat
	puff.mesh = mesh
	fx.add_child(puff)
	puff.emitting = true
	fx.get_tree().create_timer(0.9).timeout.connect(fx.queue_free)


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
