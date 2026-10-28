class_name Pyro
extends Node3D
## Entrance pyrotechnics in a wrestler's colour, in one of Roster.PYRO_STYLES:
##   classic    two spark fountains, an overhead burst and a flash of light
##   fireworks  coloured shells bursting high over the stage, with crackling trails
##   flames     a row of flame jets along the stage front, firing in sequence
##   sparks     a spark waterfall pouring off the titantron truss across the stage
##   none       no pyro: spotlights sweep in and find the wrestler
## `at` is the front edge of the stage, in the middle. Frees itself when done.

## Seconds each style's show takes to play out (entrances hold the stage shot this long).
const SHOW_TIME := {"classic": 1.8, "fireworks": 2.6, "flames": 2.3, "sparks": 2.4, "none": 2.2, "champion": 2.6}
const LIFETIME := {"classic": 4.0, "fireworks": 5.5, "flames": 4.0, "sparks": 5.0, "none": 3.4, "champion": 5.5}

var _glow: OmniLight3D       ## flames: heat glow that flickers while the jets burn
var _glow_level := 0.0


static func fire(parent: Node, at: Vector3, color: Color, style: String = "classic", width: float = 5.0) -> Pyro:
	var p := Pyro.new()
	p.process_mode = Node.PROCESS_MODE_PAUSABLE
	parent.add_child(p)
	p.global_position = at
	match style:
		"fireworks":
			p._fireworks(color, width)
		"flames":
			p._flames(color, width)
		"sparks":
			p._sparks(color)
		"none":
			p._spotlights(color)
		"champion":
			# earned in career mode: gold fountains and gold fireworks at once
			p._classic(Color(1.0, 0.78, 0.25), width)
			p._fireworks(Color(1.0, 0.85, 0.4), width)
		_:
			p._classic(color, width)
	p.create_tween().tween_callback(p.queue_free).set_delay(LIFETIME.get(style, LIFETIME["classic"]))
	return p


static func show_time(style: String) -> float:
	return SHOW_TIME.get(style, SHOW_TIME["classic"])


func _process(_delta: float) -> void:
	if _glow:
		_glow.light_energy = _glow_level * randf_range(0.7, 1.15)


# ---------------------------------------------------------------- classic

func _classic(color: Color, width: float) -> void:
	for sx in [-1.0, 1.0]:
		_fountain(Vector3(sx * width * 0.5, 0, 0), color)
	_burst(Vector3(0, 6.5, -1.0), color)
	_flash(Vector3(0, 2.5, 0.5), color.lerp(Color.WHITE, 0.5), 14.0, 14.0, 0.8)
	AudioDirector.play("pyro", global_position + Vector3.UP * 2.0, 4.0, 0.02)


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
	pm.color_ramp = _ramp([0.0, Color(1, 1, 0.85), 1.0, Color(color.r, color.g, color.b, 0.0)])
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
	pm.color_ramp = _ramp([0.0, Color(1, 1, 1), 1.0, Color(color.r, color.g, color.b, 0.0)])
	g.process_material = pm
	g.draw_pass_1 = _spark_mesh(color, 0.12)
	g.visibility_aabb = AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))
	add_child(g)
	g.emitting = false
	g.create_tween().tween_callback(g.set_emitting.bind(true)).set_delay(0.35)


# ---------------------------------------------------------------- fireworks

func _fireworks(color: Color, width: float) -> void:
	var colors: Array[Color] = [color, Color(1.0, 0.8, 0.4), color, color.lerp(Color.WHITE, 0.55), color]
	var spots := [-0.75, 0.45, -0.15, 0.85, 0.15]       # across the back of the stage
	for i in colors.size():
		var from := Vector3(spots[i] * width, 0.1, -2.3)
		var to := from + Vector3(randf_range(-0.8, 0.8), randf_range(6.4, 7.8), randf_range(-0.4, 0.4))
		create_tween().tween_callback(_shell.bind(from, to, colors[i])).set_delay(0.12 + 0.3 * i)


## One shell: it climbs on a trail of sparks, then bursts.
func _shell(from: Vector3, to: Vector3, color: Color) -> void:
	var trail := GPUParticles3D.new()
	trail.position = from
	trail.amount = 50
	trail.lifetime = 0.45
	trail.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.DOWN
	pm.spread = 25.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, -4.0, 0)
	pm.lifetime_randomness = 0.4
	pm.color_ramp = _ramp([0.0, Color(1, 0.95, 0.8), 0.5, Color(1, 0.7, 0.3), 1.0, Color(1, 0.5, 0.2, 0.0)])
	trail.process_material = pm
	trail.draw_pass_1 = _spark_mesh(Color(1, 0.8, 0.5), 0.08)
	trail.visibility_aabb = AABB(Vector3(-4, -10, -4), Vector3(8, 14, 8))
	add_child(trail)
	AudioDirector.play("whoosh", to_global(from), -6.0, 0.25)
	var tw := create_tween()
	tw.tween_property(trail, "position", to, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(trail.set_emitting.bind(false))
	tw.tween_callback(_star_burst.bind(to, color))
	tw.tween_callback(trail.queue_free).set_delay(0.5)


## The shell bursting: a sphere of stars that droop, crackle and leave glittering trails.
func _star_burst(at: Vector3, color: Color) -> void:
	var glitter := GPUParticles3D.new()      # emitted by every star as it flies (sub-emitter)
	glitter.amount = 360
	glitter.lifetime = 0.5
	glitter.local_coords = false
	var gm := ParticleProcessMaterial.new()
	gm.direction = Vector3.DOWN
	gm.spread = 180.0
	gm.initial_velocity_min = 0.1
	gm.initial_velocity_max = 0.5
	gm.gravity = Vector3(0, -2.5, 0)
	gm.lifetime_randomness = 0.5
	gm.color_ramp = _ramp([0.0, Color(1, 0.9, 0.6), 0.3, Color(1, 0.75, 0.4, 0.2), 0.45, Color(1, 0.85, 0.5),
		0.65, Color(1, 0.7, 0.3, 0.15), 0.8, Color(1, 0.8, 0.45, 0.8), 1.0, Color(1, 0.6, 0.3, 0.0)])
	glitter.process_material = gm
	glitter.draw_pass_1 = _spark_mesh(Color(1, 0.85, 0.55), 0.06)
	glitter.visibility_aabb = AABB(Vector3(-8, -10, -8), Vector3(16, 18, 16))
	add_child(glitter)
	var stars := GPUParticles3D.new()
	stars.position = at
	stars.amount = 80
	stars.lifetime = 1.7
	stars.one_shot = true
	stars.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 6.0
	pm.gravity = Vector3(0, -2.2, 0)
	pm.damping_min = 1.6
	pm.damping_max = 2.2
	pm.lifetime_randomness = 0.3
	var dim := Color(color.r, color.g, color.b, 0.25)
	pm.color_ramp = _ramp([0.0, Color(1, 1, 1), 0.12, color.lerp(Color.WHITE, 0.3), 0.6, color, 0.7, dim,
		0.76, color, 0.82, dim, 0.88, color.lerp(Color.WHITE, 0.5), 1.0, Color(color.r, color.g, color.b, 0.0)])
	pm.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_CONSTANT
	pm.sub_emitter_frequency = 9.0
	stars.process_material = pm
	stars.draw_pass_1 = _spark_mesh(color, 0.17)
	stars.visibility_aabb = AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))
	add_child(stars)
	stars.sub_emitter = stars.get_path_to(glitter)
	_flash(at, color.lerp(Color.WHITE, 0.3), 9.0, 16.0, 0.7)
	AudioDirector.play("pyro", to_global(at), -3.0, 0.15)
	var tw := create_tween()
	tw.tween_callback(stars.queue_free).set_delay(stars.lifetime + 0.1)
	tw.tween_callback(glitter.queue_free).set_delay(glitter.lifetime + 0.1)


# ---------------------------------------------------------------- flames

func _flames(color: Color, width: float) -> void:
	var jets: Array[GPUParticles3D] = []
	var n := 7
	for i in n:
		var jet := _flame_jet(color)
		jet.position = Vector3(lerpf(-width, width, i / float(n - 1)) * 0.9, 0.05, 0.1)
		add_child(jet)
		jets.append(jet)
	# left to right, right to left, then all of them at once
	for i in n:
		_burn(jets[i], 0.05 + 0.1 * i, 0.3)
		_burn(jets[n - 1 - i], 0.85 + 0.1 * i, 0.3)
		_burn(jets[i], 1.65, 0.6, false)
	_glow = OmniLight3D.new()
	_glow.light_color = color.lerp(Color(1.0, 0.6, 0.2), 0.4)
	_glow.omni_range = 9.0
	_glow.position = Vector3(-width * 0.9, 2.0, 0.8)
	add_child(_glow)
	var tw := create_tween()
	tw.tween_property(self, "_glow_level", 5.0, 0.1)
	tw.parallel().tween_property(_glow, "position:x", width * 0.9, 0.7).set_delay(0.05)
	tw.tween_property(_glow, "position:x", -width * 0.9, 0.7).set_delay(0.1)
	tw.tween_property(_glow, "position:x", 0.0, 0.1)
	tw.tween_property(self, "_glow_level", 14.0, 0.1)
	tw.tween_property(self, "_glow_level", 0.0, 1.0).set_delay(0.5)
	AudioDirector.play("pyro", global_position + Vector3.UP * 2.0, -2.0, 0.05)
	create_tween().tween_callback(AudioDirector.play.bind("pyro", global_position + Vector3.UP * 2.0, 4.0, 0.03)) \
		.set_delay(1.65)


## Light a jet after `delay` and let it burn for `length` seconds.
func _burn(jet: GPUParticles3D, delay: float, length: float, whoosh: bool = true) -> void:
	var tw := create_tween()
	tw.tween_callback(jet.set_emitting.bind(true)).set_delay(delay)
	if whoosh:
		tw.tween_callback(AudioDirector.play.bind("whoosh", jet.global_position + Vector3.UP, -9.0, 0.2))
	tw.tween_callback(jet.set_emitting.bind(false)).set_delay(length)


func _flame_jet(color: Color) -> GPUParticles3D:
	var g := GPUParticles3D.new()
	g.amount = 44
	g.lifetime = 0.7
	g.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.08
	pm.direction = Vector3.UP
	pm.spread = 5.0
	pm.initial_velocity_min = 8.5
	pm.initial_velocity_max = 10.5
	pm.damping_min = 7.0
	pm.damping_max = 9.0
	pm.gravity = Vector3(0, 1.5, 0)
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.scale_min = 0.8
	pm.scale_max = 1.25
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.35))
	sc.add_point(Vector2(0.4, 1.0))
	sc.add_point(Vector2(1.0, 0.55))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.5
	pm.turbulence_noise_scale = 2.5
	pm.turbulence_influence_min = 0.06
	pm.turbulence_influence_max = 0.14
	var hot := color.lerp(Color(1.0, 0.95, 0.75), 0.55)
	pm.color_ramp = _ramp([0.0, Color(1, 1, 0.9), 0.15, hot, 0.5, color, 0.8, Color(color.r * 0.5, color.g * 0.4,
		color.b * 0.4, 0.5), 1.0, Color(color.r * 0.3, color.g * 0.2, color.b * 0.2, 0.0)])
	g.process_material = pm
	g.draw_pass_1 = _soft_mesh(0.95, 2.2)
	g.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 7, 4))
	return g


# ---------------------------------------------------------------- sparks

func _sparks(color: Color) -> void:
	var a: Dictionary = Ring.spec()["arena"]
	var g := GPUParticles3D.new()
	g.position = to_local(Vector3(0, float(a["screen_top"]) + 0.3, -float(a["stage_back"]) + 0.55))
	g.amount = 650
	g.lifetime = 1.6
	g.emitting = false
	g.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	g.collision_base_size = 0.03
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.05, 0.02, 0.04)
	pm.direction = Vector3.DOWN
	pm.spread = 6.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 1.2
	pm.gravity = Vector3(0, -9.8, 0)
	pm.lifetime_randomness = 0.25
	pm.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	pm.collision_bounce = 0.35
	pm.collision_friction = 0.25
	var dim := Color(color.r, color.g, color.b, 0.3)
	pm.color_ramp = _ramp([0.0, Color(1, 1, 1), 0.15, color.lerp(Color.WHITE, 0.45), 0.55, color, 0.68, dim,
		0.74, color, 0.82, dim, 0.88, color, 1.0, Color(color.r, color.g, color.b, 0.0)])
	g.process_material = pm
	g.draw_pass_1 = _streak_mesh(0.03, 0.3)
	g.visibility_aabb = AABB(Vector3(-8, -9, -3), Vector3(16, 11, 6))
	add_child(g)
	# the stage floor catches them
	var floor_box := GPUParticlesCollisionBox3D.new()
	var depth := float(a["stage_back"]) - float(a["stage_front"])
	floor_box.size = Vector3(2.0 * float(a["stage_half_width"]), 1.0, depth)
	add_child(floor_box)
	floor_box.global_position = Vector3(0, float(a["stage_height"]) - 0.5, -float(a["stage_front"]) - depth * 0.5)
	# the curtain opens out from the middle, pours, then dries up
	var half := float(a["screen_half_width"]) + 0.4
	var tw := create_tween()
	tw.tween_callback(g.set_emitting.bind(true)).set_delay(0.1)
	tw.tween_property(pm, "emission_box_extents:x", half, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(g.set_emitting.bind(false)).set_delay(2.3)
	_flash(g.position + Vector3(0, -3.0, 1.0), color.lerp(Color.WHITE, 0.6), 5.0, 12.0, 2.8)
	AudioDirector.play("pyro", to_global(g.position), -4.0, 0.05)


# ---------------------------------------------------------------- none: lights only

func _spotlights(color: Color) -> void:
	var a: Dictionary = Ring.spec()["arena"]
	var th := float(a["truss_height"]) - 0.4
	var half := float(a["truss_half"])
	var target := to_global(Vector3(0, 1.4, -1.0))      # the wrestler, a metre back from the edge
	var rigs := [Vector3(-half + 1.0, th, -half), Vector3(half - 1.0, th, -half), Vector3(0, th, -half),
		Vector3(-float(a["screen_half_width"]) - 0.6, float(a["screen_top"]), -float(a["stage_back"]) + 0.5),
		Vector3(float(a["screen_half_width"]) + 0.6, float(a["screen_top"]), -float(a["stage_back"]) + 0.5)]
	for i in rigs.size():
		var spot := SpotLight3D.new()
		spot.light_color = color if i != 2 else color.lerp(Color.WHITE, 0.7)
		spot.light_energy = 0.0
		spot.spot_range = 26.0
		spot.spot_angle = 6.0 if i < 3 else 9.0
		spot.spot_attenuation = 0.4
		spot.light_volumetric_fog_energy = 3.0
		add_child(spot)
		spot.global_position = rigs[i]
		# start off pointing into the crowd, sweep in, hold on the wrestler, then go dark
		var start := Vector3(randf_range(-9.0, 9.0), randf_range(1.0, 5.0), randf_range(-6.0, 6.0))
		spot.look_at(start)
		var delay := 0.15 * i
		var tw := create_tween()
		tw.tween_property(spot, "light_energy", 16.0 if i < 3 else 10.0, 0.25).set_delay(delay)
		tw.parallel().tween_method(_aim.bind(spot), start, target, 0.9).set_delay(delay) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(spot, "light_energy", 0.0, 0.6).set_delay(1.4 - delay)
	_flash(Vector3(0, 2.0, -0.5), color.lerp(Color.WHITE, 0.4), 6.0, 8.0, 0.5, 1.0)


func _aim(at: Vector3, spot: SpotLight3D) -> void:
	spot.look_at(at)


# ---------------------------------------------------------------- shared

## A burst of light that fades out (after `delay`).
func _flash(offset: Vector3, color: Color, energy: float, light_range: float, fade: float, delay: float = 0.0) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 0.0 if delay > 0.0 else energy
	l.omni_range = light_range
	l.position = offset
	add_child(l)
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_property(l, "light_energy", energy, 0.05).set_delay(delay)
	tw.tween_property(l, "light_energy", 0.0, fade)
	tw.tween_callback(l.queue_free)


## A colour ramp from [offset, colour, offset, colour, ...].
func _ramp(stops: Array) -> GradientTexture1D:
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in range(0, stops.size(), 2):
		offsets.append(stops[i])
		colors.append(stops[i + 1])
	var grad := Gradient.new()
	grad.offsets = offsets
	grad.colors = colors
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	return gt


func _spark_mesh(color: Color, size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _glow_material(Color(color.r * 3.0, color.g * 3.0, color.b * 3.0), true)
	return q


## A soft blob tinted only by the particle colour (flames).
func _soft_mesh(size: float, boost: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _glow_material(Color(boost, boost, boost), true)
	return q


## A thin streak for particles aligned to their velocity (GPUParticles3D.transform_align).
func _streak_mesh(width: float, length: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(width, length)
	q.center_offset = Vector3(0, length * 0.4, 0)     # the hot head leads, the tail trails behind
	q.material = _glow_material(Color(3.0, 3.0, 3.0), false)
	return q


func _glow_material(albedo: Color, billboard: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = albedo
	m.albedo_texture = Crowd._flash_texture()
	m.vertex_color_use_as_albedo = true
	return m
