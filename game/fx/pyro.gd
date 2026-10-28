class_name Pyro
extends Node3D
## Entrance pyrotechnics: two spark fountains, an overhead burst and a flash of light.
## Frees itself when done.

static func fire(parent: Node, at: Vector3, color: Color, width: float = 5.0) -> void:
	var p := Pyro.new()
	parent.add_child(p)
	p.global_position = at
	p._build(color, width)


func _build(color: Color, width: float) -> void:
	for sx in [-1.0, 1.0]:
		_fountain(Vector3(sx * width * 0.5, 0, 0), color)
	_burst(Vector3(0, 6.5, -1.0), color)
	var flash := OmniLight3D.new()
	flash.light_color = color.lerp(Color.WHITE, 0.5)
	flash.light_energy = 14.0
	flash.omni_range = 14.0
	flash.position = Vector3(0, 2.5, 0.5)
	add_child(flash)
	create_tween().tween_property(flash, "light_energy", 0.0, 0.8)
	AudioDirector.play("pyro", global_position + Vector3.UP * 2.0, 4.0, 0.02)
	create_tween().tween_callback(queue_free).set_delay(4.0)


func _spark_mesh(color: Color, size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r * 3.0, color.g * 3.0, color.b * 3.0)
	m.albedo_texture = Crowd._flash_texture()
	m.vertex_color_use_as_albedo = true
	q.material = m
	return q


func _fountain(offset: Vector3, color: Color) -> void:
	var g := GPUParticles3D.new()
	g.position = offset
	g.amount = 220
	g.lifetime = 1.3
	g.one_shot = false
	g.explosiveness = 0.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 9.0
	pm.initial_velocity_min = 7.0
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.damping_min = 0.5
	pm.damping_max = 1.5
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 0.85))
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	g.process_material = pm
	g.draw_pass_1 = _spark_mesh(Color(1, 0.8, 0.4), 0.09)
	g.visibility_aabb = AABB(Vector3(-6, -2, -6), Vector3(12, 14, 12))
	add_child(g)
	g.create_tween().tween_callback(g.set_emitting.bind(false)).set_delay(2.2)


func _burst(offset: Vector3, color: Color) -> void:
	var g := GPUParticles3D.new()
	g.position = offset
	g.amount = 300
	g.lifetime = 1.6
	g.one_shot = true
	g.explosiveness = 0.95
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, -3.0, 0)
	pm.damping_min = 2.0
	pm.damping_max = 3.0
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1))
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	g.process_material = pm
	g.draw_pass_1 = _spark_mesh(color, 0.12)
	g.visibility_aabb = AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))
	add_child(g)
	g.emitting = false
	g.create_tween().tween_callback(g.set_emitting.bind(true)).set_delay(0.35)
