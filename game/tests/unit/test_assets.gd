extends GutTest
## Generated asset contract: what game code relies on from blender/build.py output.

const EXPECTED_BONES := ["root", "hips", "spine", "chest", "neck", "head",
	"upper_arm.L", "forearm.L", "hand.L", "fingers.L", "thumb.L",
	"thigh.R", "shin.R", "foot.R", "toe.R", "clavicle.R"]

var model: WrestlerModel


func before_each() -> void:
	model = WrestlerModel.new()
	add_child_autofree(model)


func test_skeleton_has_shared_rig_bones() -> void:
	assert_eq(model.skeleton.get_bone_count(), 26)
	for b in EXPECTED_BONES:
		assert_gt(model.skeleton.find_bone(b), -1, "bone %s" % b)


func test_body_has_blend_shapes_from_manifest() -> void:
	for shape in WrestlerModel.manifest()["blend_shapes"]:
		assert_gt(model.body.find_blend_shape_by_name(shape), -1, "blend shape %s" % shape)


func test_all_manifest_animations_exist_with_loop_flags() -> void:
	var anims: Dictionary = WrestlerModel.manifest()["animations"]
	assert_true(anims.size() >= 3)
	for anim_name in anims:
		assert_true(model.has_animation(anim_name), "animation %s" % anim_name)
		var a := model.anim_player.get_animation(anim_name)
		var want := Animation.LOOP_LINEAR if anims[anim_name]["loop"] else Animation.LOOP_NONE
		assert_eq(a.loop_mode, want, "loop mode of %s" % anim_name)
		assert_almost_eq(a.length, float(anims[anim_name]["length"]), 0.05)


func test_look_drives_blend_shapes_and_hair() -> void:
	var look := WrestlerLook.new()
	look.mass = 1.0
	look.gut = 0.5
	look.hair_style = "mohawk"
	look.kneepads = false
	model.look = look
	assert_eq(model.body.get_blend_shape_value(model.body.find_blend_shape_by_name("heavy")), 1.0)
	assert_eq(model.body.get_blend_shape_value(model.body.find_blend_shape_by_name("slim")), 0.0)
	assert_eq(model.body.get_blend_shape_value(model.body.find_blend_shape_by_name("gut")), 0.5)
	assert_eq(model.body.get_blend_shape_value(model.body.find_blend_shape_by_name("kneepads")), 0.0)
	for hair in model.skeleton.find_children("hair_*", "MeshInstance3D", true, false):
		assert_eq(hair.visible, hair.name == &"hair_mohawk", String(hair.name))


func test_bald_hides_all_hair() -> void:
	var look := WrestlerLook.new()
	look.hair_style = "bald"
	model.look = look
	for hair in model.skeleton.find_children("hair_*", "MeshInstance3D", true, false):
		assert_false(hair.visible)


func test_every_audio_file_has_a_license_entry() -> void:
	var listed := {}
	for e: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/licenses.json")):
		listed[e["file"]] = e
		assert_true(e.has("license") and e.has("source") and e.has("author"), "complete entry for %s" % e["file"])
	for dir in ["music", "sfx"]:
		for f in DirAccess.get_files_at("res://assets/audio/" + dir):
			if f.ends_with(".wav"):
				assert_true(listed.has(dir + "/" + f), "%s/%s is in licenses.json" % [dir, f])
