extends GutTest

const DT := 1.0 / 60.0

var ring: Ring


func before_each() -> void:
	ring = Ring.new()
	add_child_autofree(ring)


func test_spec_loaded() -> void:
	assert_almost_eq(Ring.canvas_height(), 1.15, 0.001)
	assert_eq(Ring.spec()["rope_heights"].size(), 3)


func test_inside_outside() -> void:
	assert_true(Ring.is_inside(Vector3(0, 0, 0)))
	assert_true(Ring.is_inside(Vector3(2.5, 0, -2.5)))
	assert_false(Ring.is_inside(Vector3(3.2, 0, 0)))
	assert_false(Ring.is_inside(Vector3(0, 0, -5)))


func test_corners_are_inside_near_posts() -> void:
	for i in 4:
		var c := Ring.corner(i)
		assert_true(Ring.is_inside(c))
		assert_gt(absf(c.x), 2.0)
		assert_gt(absf(c.z), 2.0)


func test_twelve_ropes() -> void:
	assert_eq(ring.ropes.ropes.size(), 12)


func _outward(p: Vector3) -> Vector3:
	return Vector3(p.x, 0, p.z).normalized()


func _rope_at(level: int, side: int) -> RingRopes.Rope:
	for r in ring.ropes.ropes:
		if r.level == level and r.side == side:
			return r
	return null


func test_push_deflects_only_nearby_ropes_and_settles() -> void:
	var top := _rope_at(2, 0)
	var mid_point := top.rest_point(0.5)
	ring.ropes.push(mid_point, _outward(mid_point) * 3.0)
	for i in 8:
		ring.ropes._physics_process(DT)
	assert_gt(top.point(0.5).distance_to(mid_point), 0.1, "pushed rope deflects visibly")
	assert_false(_rope_at(0, 0).awake, "bottom rope is out of reach")
	assert_false(_rope_at(2, 2).awake, "opposite side untouched")
	for i in 600:
		ring.ropes._physics_process(DT)
	assert_false(top.awake, "rope settled")
	assert_almost_eq(top.point(0.5).distance_to(mid_point), 0.0, 0.001)


func test_rope_ends_stay_on_turnbuckles() -> void:
	var r := _rope_at(1, 1)
	ring.ropes.push(r.rest_point(0.3), _outward(r.rest_point(0.3)) * 4.0)
	for i in 5:
		ring.ropes._physics_process(DT)
	assert_eq(r.point(0.0), r.rest_point(0.0))
	assert_eq(r.point(1.0), r.rest_point(1.0))


func test_press_holds_then_springs_back() -> void:
	var r := _rope_at(2, 3)
	var p := r.rest_point(0.5)
	for i in 30:
		ring.ropes.press(p, _outward(p) * 0.35)
		ring.ropes._physics_process(DT)
	assert_almost_eq(r.point(0.5).distance_to(p), 0.35, 0.01, "held at the pressed depth")
	ring.ropes._physics_process(DT)
	ring.ropes._physics_process(DT)
	assert_lt(r.point(0.5).distance_to(p), 0.35, "released rope starts returning")
