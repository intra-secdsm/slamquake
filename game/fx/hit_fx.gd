class_name HitFx
extends Node3D
## One-shot impact effects that free themselves: a strike burst (flash plus sweat
## spray) and a dust ring for bodies hitting the canvas. The meshes and materials are
## built once and shared: making fresh ones on every hit stalled the renderer.

static var _dust_mesh: QuadMesh
static var _dust_curve: Curve
static var _spray_mesh: SphereMesh

static func spawn(parent: Node, at: Vector3, heavy: bool) -> HitFx:
	var fx := HitFx.new()
	parent.add_child(fx)
	fx.global_position = at
	fx._build(heavy)
	return fx


## Play both effects once, shrunk to a speck just in front of `camera`, while the match
## loads: the first real hit then doesn't stall on getting them ready to draw.
static func prewarm(camera: Camera3D) -> void:
	var at := camera.to_global(Vector3(0, 0, -1.5))
	for fx: HitFx in [spawn(camera, at, true), dust(camera, at)]:
		fx.scale = Vector3.ONE * 0.01


static func dust(parent: Node, at: Vector3) -> HitFx:
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
	_make_shared()
	puff.scale_amount_curve = _dust_curve
	puff.mesh = _dust_mesh
	fx.add_child(puff)
	puff.emitting = true
	fx.get_tree().create_timer(0.9).timeout.connect(fx.queue_free)
	return fx


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
	_make_shared()
	spray.mesh = _spray_mesh
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


static func _make_shared() -> void:
	if _dust_mesh:
		return
	_dust_curve = Curve.new()
	_dust_curve.add_point(Vector2(0, 0.4))
	_dust_curve.add_point(Vector2(0.3, 1.0))
	_dust_curve.add_point(Vector2(1, 0.0))
	_dust_mesh = QuadMesh.new()
	_dust_mesh.size = Vector2(0.14, 0.14)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.93, 0.9, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_dust_mesh.material = mat
	_spray_mesh = SphereMesh.new()
	_spray_mesh.radius = 0.012
	_spray_mesh.height = 0.024
	_spray_mesh.radial_segments = 6
	_spray_mesh.rings = 3
	mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.95, 0.8)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spray_mesh.material = mat
