class_name RingRopes
extends Node3D
## The 12 ring ropes. A tensioned rope pushed at one point forms a "V" running straight
## to the turnbuckles, so each rope is modelled as a contact point plus a damped-spring
## displacement there. Other systems call push() (impulses: bodies hitting ropes) or
## press() (kinematic: a wrestler leaning into the ropes for a rebound).

const SEGMENTS := 24
const RADIAL := 8
const FREQUENCY := 2.6       # Hz, rope wobble
const DAMPING_RATIO := 0.14
const SAG := 0.012
const MAX_DEFLECTION := 0.6
const LEVEL_COLORS := [Color(0.1, 0.25, 0.8), Color(0.92, 0.92, 0.92), Color(0.85, 0.08, 0.1)]  # bottom..top

class Rope:
	var level: int
	var side: int
	var a: Vector3            # turnbuckle ends
	var b: Vector3
	var contact := 0.5        # 0..1 along the rope
	var offset := Vector3.ZERO
	var velocity := Vector3.ZERO
	var pressed := false      # held kinematically this frame
	var mesh := ArrayMesh.new()
	var awake := true

	## Rest point at t (0..1), including a slight sag.
	func rest_point(t: float) -> Vector3:
		return a.lerp(b, t) + Vector3.DOWN * (SAG * 4.0 * t * (1.0 - t))

	## Current point at t.
	func point(t: float) -> Vector3:
		var w := t / contact if t < contact else (1.0 - t) / (1.0 - contact)
		return rest_point(t) + offset * w

	## Closest parameter t and distance from p to the rope's rest line.
	func closest(p: Vector3) -> Vector2:
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		return Vector2(t, rest_point(t).distance_to(p))

var ropes: Array[Rope] = []
var _radius: float


func setup(spec: Dictionary) -> void:
	var ph: float = spec["post_half"]
	var inset: float = spec["pad_inset"] / sqrt(2.0)
	var mh: float = spec["mat_height"]
	_radius = spec["rope_radius"]
	var e := ph - inset
	var corners := [Vector2(e, e), Vector2(-e, e), Vector2(-e, -e), Vector2(e, -e)]
	var heights: Array = spec["rope_heights"]
	for level in heights.size():
		var mat := StandardMaterial3D.new()
		mat.albedo_color = LEVEL_COLORS[level % LEVEL_COLORS.size()]
		mat.roughness = 0.45
		mat.rim_enabled = true
		mat.rim = 0.3
		for side in 4:
			var r := Rope.new()
			r.level = level
			r.side = side
			var a2: Vector2 = corners[side]
			var b2: Vector2 = corners[(side + 1) % 4]
			var y: float = mh + heights[level]
			r.a = Vector3(a2.x, y, a2.y)
			r.b = Vector3(b2.x, y, b2.y)
			var mi := MeshInstance3D.new()
			mi.mesh = r.mesh
			mi.material_override = mat
			add_child(mi)
			ropes.append(r)
			_rebuild_mesh(r)


## Deflect ropes near `point` by `impulse` (m/s), falling off over `radius` metres.
func push(point: Vector3, impulse: Vector3, radius: float = 0.6) -> void:
	for r in ropes:
		var c := r.closest(point)
		if c.y >= radius:
			continue
		var f := 1.0 - c.y / radius
		_move_contact(r, c.x)
		r.velocity += impulse * f * f
		r.awake = true


## Hold ropes near `point` displaced by `offset` this frame (e.g. a wrestler leaning
## back into them). Released ropes spring back on their own.
func press(point: Vector3, offset: Vector3, radius: float = 0.6) -> void:
	for r in ropes:
		var c := r.closest(point)
		if c.y >= radius:
			continue
		var f := 1.0 - c.y / radius
		_move_contact(r, c.x)
		r.offset = offset.limit_length(MAX_DEFLECTION) * f
		r.velocity = Vector3.ZERO
		r.pressed = true
		r.awake = true


func _move_contact(r: Rope, t: float) -> void:
	t = clampf(t, 0.1, 0.9)
	if r.offset.length() < 0.02:
		r.contact = t
	else:
		r.contact = lerpf(r.contact, t, 0.3)


func _physics_process(delta: float) -> void:
	var omega := TAU * FREQUENCY
	var k := omega * omega
	var c := 2.0 * DAMPING_RATIO * omega
	for r in ropes:
		if not r.awake:
			continue
		if r.pressed:
			r.pressed = false
		else:
			# semi-implicit Euler, substepped for stability
			var steps := 4
			var dt := delta / steps
			for _s in steps:
				r.velocity += (-k * r.offset - c * r.velocity) * dt
				r.offset += r.velocity * dt
			r.offset = r.offset.limit_length(MAX_DEFLECTION)
			if r.offset.length_squared() < 1e-8 and r.velocity.length_squared() < 1e-6:
				r.offset = Vector3.ZERO
				r.velocity = Vector3.ZERO
				r.awake = false
		_rebuild_mesh(r)


func _rebuild_mesh(r: Rope) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var along := (r.b - r.a).normalized()
	var side := along.cross(Vector3.UP).normalized()
	for i in SEGMENTS + 1:
		var p := r.point(float(i) / SEGMENTS)
		for j in RADIAL:
			var ang := TAU * j / RADIAL
			var n := Vector3.UP * cos(ang) + side * sin(ang)
			verts.append(p + n * _radius)
			normals.append(n)
	for i in SEGMENTS:
		for j in RADIAL:
			var a := i * RADIAL + j
			var b := i * RADIAL + (j + 1) % RADIAL
			indices.append_array([a, a + RADIAL, b, b, a + RADIAL, b + RADIAL])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	r.mesh.clear_surfaces()
	r.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
