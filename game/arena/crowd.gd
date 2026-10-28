class_name Crowd
extends Node3D
## The fans: a few thousand instanced low-poly figures standing on the arena's seating
## tiers (positions from ring_spec.json "arena"), animated in a vertex shader. Set
## `excitement` (0..1) and they go from milling about to bouncing with their arms up.
## Includes fan signs and camera flashes that pop more on big moments.

const FAN_SPACING := 0.56
const SIGN_SHARE := 0.07
const SHIRTS := [Color("ff2bd6"), Color("00e5ff"), Color("ffd400"), Color("7dff3a"), Color("f0f0f0"),
	Color("202020"), Color("d03030"), Color("3050d0"), Color("ff8c1a"), Color("8a2be2")]

var excitement := 0.3:
	set(v):
		excitement = clampf(v, 0.0, 1.0)
		if _fans:
			_fan_mat.set_shader_parameter("excitement", excitement)
			_sign_mat.set_shader_parameter("excitement", excitement)
			for f in _flashes:
				f.amount_ratio = 0.08 + 0.92 * excitement * excitement
var fan_count := 0

var _fans: MultiMeshInstance3D
var _fan_mat := ShaderMaterial.new()
var _sign_mat := ShaderMaterial.new()
var _flashes: Array[GPUParticles3D] = []
var _flash := 0.0


func _ready() -> void:
	_fan_mat.shader = preload("res://arena/crowd.gdshader")
	_sign_mat.shader = preload("res://arena/sign.gdshader")
	var spots := _seat_positions()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1990
	var fans := MultiMesh.new()
	fans.transform_format = MultiMesh.TRANSFORM_3D
	fans.use_custom_data = true
	fans.mesh = _fan_mesh()
	fans.instance_count = spots.size()
	var signs: Array[Array] = []
	for i in spots.size():
		var t: Transform3D = spots[i]
		var r := rng.randf()
		fans.set_instance_transform(i, t)
		var shirt: Color = SHIRTS[rng.randi() % SHIRTS.size()]
		fans.set_instance_custom_data(i, Color(shirt.r, shirt.g, shirt.b, r))
		if rng.randf() < SIGN_SHARE:
			signs.append([t, r, Color.from_hsv(rng.randf(), rng.randf_range(0.0, 0.8), 1.0)])
	fan_count = spots.size()
	_fans = MultiMeshInstance3D.new()
	_fans.multimesh = fans
	_fans.material_override = _fan_mat
	_fans.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fans)

	var sm := MultiMesh.new()
	sm.transform_format = MultiMesh.TRANSFORM_3D
	sm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.55)
	sm.mesh = quad
	sm.instance_count = signs.size()
	for i in signs.size():
		var t: Transform3D = signs[i][0]
		# held up above the head, facing the ring (QuadMesh faces +Z like the fans)
		sm.set_instance_transform(i, t.translated_local(Vector3(0, 2.05, 0.1)))
		var c: Color = signs[i][2]
		sm.set_instance_custom_data(i, Color(c.r, c.g, c.b, signs[i][1]))
	var sign_node := MultiMeshInstance3D.new()
	sign_node.multimesh = sm
	sign_node.material_override = _sign_mat
	sign_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sign_node)
	_build_flashes()
	excitement = excitement


## A burst of camera flashes and a brightening of the crowd (finishers, near falls).
func pop(amount: float = 1.0) -> void:
	_flash = maxf(_flash, amount)
	for f in _flashes:
		f.amount_ratio = 1.0


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 1.5)
		_fan_mat.set_shader_parameter("flash", _flash)
		if _flash <= 0.0:
			excitement = excitement


func _seat_positions() -> Array[Transform3D]:
	var a: Dictionary = Ring.spec()["arena"]
	var inner: float = a["stands_inner"]
	var depth: float = a["row_depth"]
	var rise: float = a["row_rise"]
	var gap: float = float(a["stage_half_width"]) + 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var out: Array[Transform3D] = []
	for r in int(a["rows"]):
		var d := inner + r * depth + depth * 0.5
		var y := (r + 1) * rise
		var half := d + depth * 0.5
		for side in 4:
			# side 0: +z (behind the hard cam), 1: +x, 2: -z (stage end), 3: -x
			var n := int(2.0 * half / FAN_SPACING)
			for k in n:
				var along := -half + (k + 0.5) * FAN_SPACING + rng.randf_range(-0.12, 0.12)
				if side == 2 and absf(along) < gap:
					continue
				if rng.randf() < 0.07:
					continue        # empty seat
				var local := Vector3(along, y, d + rng.randf_range(-0.12, 0.12))
				var basis := Basis(Vector3.UP, side * PI / 2.0)
				var pos := basis * local
				# face the ring (fans look toward the centre, +Z of the fan mesh)
				var face := Basis(Vector3.UP, atan2(-pos.x, -pos.z) + rng.randf_range(-0.25, 0.25))
				var s := rng.randf_range(0.9, 1.08)
				out.append(Transform3D(face.scaled(Vector3.ONE * s), pos))
	return out


## A blocky fan: legs, torso, head, and two arms that the shader can raise.
func _fan_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0, 0.42, 0), Vector3(0.34, 0.84, 0.2), 0.0, 0.0)          # legs
	_box(st, Vector3(0, 1.1, 0), Vector3(0.42, 0.56, 0.24), 1.0, 0.0)          # torso
	_box(st, Vector3(0, 1.5, 0.01), Vector3(0.2, 0.24, 0.21), 2.0, 0.0)        # head
	for side in [-1.0, 1.0]:
		_box(st, Vector3(0.24 * side, 1.1, 0), Vector3(0.1, 0.5, 0.11), 1.0, side)       # arm
		_box(st, Vector3(0.24 * side, 0.8, 0), Vector3(0.09, 0.11, 0.1), 2.0, side)      # hand
	st.generate_normals()
	return st.commit()


func _box(st: SurfaceTool, c: Vector3, size: Vector3, part: float, side: float) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)], [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)], [Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)], [Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var corners: Array[Vector3] = []
		for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			corners.append(c + (n * h + u * h * q.x + v * h * q.y))
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(Vector2(part, side))
			st.add_vertex(corners[idx])


func _build_flashes() -> void:
	var a: Dictionary = Ring.spec()["arena"]
	var inner: float = a["stands_inner"]
	var span := float(a["rows"]) * float(a["row_depth"])
	var hgt := float(a["rows"]) * float(a["row_rise"])
	for side in 4:
		var p := GPUParticles3D.new()
		p.amount = 60
		p.lifetime = 1.4
		p.explosiveness = 0.0
		p.randomness = 1.0
		p.local_coords = false
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(inner + span, hgt * 0.5, span * 0.5)
		pm.gravity = Vector3.ZERO
		pm.direction = Vector3.UP
		pm.initial_velocity_min = 0.0
		pm.initial_velocity_max = 0.0
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 1.0))
		curve.add_point(Vector2(0.05, 0.0))
		curve.add_point(Vector2(1.0, 0.0))
		var ct := CurveTexture.new()
		ct.curve = curve
		pm.scale_curve = ct
		p.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.18, 0.18)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.albedo_color = Color(1.4, 1.4, 1.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = _flash_texture()
		q.material = mat
		p.draw_pass_1 = q
		var basis := Basis(Vector3.UP, side * PI / 2.0)
		p.position = basis * Vector3(0, hgt * 0.5 + 1.6, inner + span * 0.5)
		p.rotation.y = side * PI / 2.0
		p.visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 40, 80))
		add_child(p)
		_flashes.append(p)


static var _flash_tex: Texture2D

static func _flash_texture() -> Texture2D:
	if _flash_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_flash_tex = t
	return _flash_tex
