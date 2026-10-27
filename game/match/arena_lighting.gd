class_name ArenaLighting
extends Node3D
## Arena look: dark house, bright ring, coloured 90s rim lights, haze for light beams.

@export var haze_density: float = 0.004


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.012, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.3, 0.5)
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.6
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.6
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = haze_density
	env.volumetric_fog_albedo = Color(0.8, 0.8, 0.9)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# overhead lighting truss: one strong key straight down (defined contact shadows)
	# plus four softer fills from the corners
	var key := _spot(Vector3(0, 11, 0.5), Vector3(0, 1.2, 0), Color(1.0, 0.96, 0.9), 14.0, 30.0, true)
	key.shadow_blur = 1.5
	for p in [Vector3(5, 9, 5), Vector3(-5, 9, 5), Vector3(-5, 9, -5), Vector3(5, 9, -5)]:
		_spot(p, Vector3(0, 1.2, 0), Color(1.0, 0.95, 0.88), 2.2, 32.0, false)
	# coloured rim lights from the corners, low and raking
	_spot(Vector3(9, 5, -7), Vector3(0, 1.8, 0), Color(1.0, 0.15, 0.7), 9.0, 22.0, false)
	_spot(Vector3(-9, 5, -7), Vector3(0, 1.8, 0), Color(0.1, 0.8, 1.0), 9.0, 22.0, false)
	_spot(Vector3(0, 6, 11), Vector3(0, 1.6, 0), Color(0.8, 0.85, 1.0), 2.5, 25.0, false)


func _spot(pos: Vector3, target: Vector3, color: Color, energy: float, angle: float, shadow: bool) -> SpotLight3D:
	var l := SpotLight3D.new()
	add_child(l)
	l.look_at_from_position(pos, target)
	l.light_color = color
	l.light_energy = energy
	l.spot_range = 30.0
	l.spot_angle = angle
	l.spot_attenuation = 0.6
	l.shadow_enabled = shadow
	l.light_volumetric_fog_energy = 0.35
	return l
