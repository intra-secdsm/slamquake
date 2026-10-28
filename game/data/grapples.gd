class_name Grapples
## Paired move definitions. Animation names, timing, events and root placement come
## from the animation manifest ("<id>_a" / "<id>_d").
##   end_a / end_d: state each wrestler is left in
##   align: "defender" (default) moves the defender onto the attacker's anchor;
##          "attacker" moves the attacker so a downed defender stays where they lie
##   in_place: never slide the pair inward (so pins under the ropes still break)
##   reversal: seconds after the move starts in which the defender can reverse it (block)
##   finisher: needs a SPECIAL; cinematic camera, no momentum, harder kick-outs
##   anim: reuse another move's animations

const ALL := {
	"headbutt": {"damage": 6.0, "end_a": "idle", "end_d": "stun", "sfx": "hit_light", "reversal": 0.25},
	"body_slam": {"damage": 10.0, "end_a": "idle", "end_d": "down", "sfx": "body_fall", "reversal": 0.3},
	"suplex": {"damage": 14.0, "end_a": "getup", "end_d": "down", "sfx": "body_fall", "reversal": 0.3},
	"ddt": {"damage": 15.0, "end_a": "getup", "end_d": "down", "sfx": "body_fall", "reversal": 0.3},
	"german": {"damage": 16.0, "end_a": "getup", "end_d": "down", "sfx": "body_fall"},
	"back_body_drop": {"damage": 11.0, "end_a": "idle", "end_d": "down", "sfx": "body_fall"},
	"whip": {"damage": 0.0, "end_a": "idle", "end_d": "whipped", "reversal": 0.18},
	"rope_toss": {"damage": 12.0, "end_a": "idle", "end_d": "down", "sfx": "body_fall", "in_place": true},
	"pickup": {"damage": 0.0, "end_a": "tieup", "end_d": "held", "align": "attacker"},
	"cover": {"damage": 0.0, "end_a": "pinning", "end_d": "pinned", "align": "attacker", "in_place": true},
	"elbow_drop": {"damage": 9.0, "end_a": "idle", "end_d": "down", "align": "attacker", "sfx": "hit_heavy",
		"in_place": true},
	"hip_toss": {"damage": 7.0, "end_a": "idle", "end_d": "down", "sfx": "body_fall"},
	# tag team: two attackers share the suplex animation, side by side
	"double_suplex": {"anim": "suplex", "damage": 22.0, "end_a": "getup", "end_d": "down", "sfx": "body_fall"},
	# finishers (one per roster wrestler for now; CAW picks from these in M8)
	"thunder_bomb": {"name": "Thunder Bomb", "damage": 32.0, "end_a": "idle", "end_d": "down", "sfx": "finisher_impact",
		"finisher": true, "reversal": 0.2, "down_extra": 1.5},
	"volt_shock": {"name": "Volt Shock", "damage": 30.0, "end_a": "getup", "end_d": "down", "sfx": "finisher_impact",
		"finisher": true, "reversal": 0.2, "down_extra": 1.5},
	"iron_drop": {"name": "Iron Drop", "damage": 32.0, "end_a": "idle", "end_d": "down", "sfx": "finisher_impact",
		"finisher": true, "reversal": 0.2, "down_extra": 1.5},
}


static func get_move(id: String) -> Dictionary:
	var m: Dictionary = ALL[id].duplicate()
	var anims: Dictionary = WrestlerModel.manifest()["animations"]
	var base: String = m.get("anim", id)
	var a: Dictionary = anims[base + "_a"]
	var d: Dictionary = anims[base + "_d"]
	m["id"] = id
	m["anim_a"] = base + "_a"
	m["anim_a2"] = base + "_a"
	m["anim_d"] = base + "_d"
	m["length"] = float(a["length"])
	m["events"] = a["events"]
	m["root_start_d"] = d["root_start"]
	m["root_end_a"] = a["root_end"]
	m["root_end_d"] = d["root_end"]
	m.get_or_add("align", "defender")
	return m


## Root bone placement from the manifest as a transform, scaled by the model's height.
static func root_xform(info: Dictionary, model_scale: float) -> Transform3D:
	var p: Array = info["pos"]
	# height changes (leaving the ring, climbing) are absolute; distances scale with the body
	return Transform3D(Basis(Vector3.UP, deg_to_rad(float(info["yaw"]))),
		Vector3(float(p[0]) * model_scale, float(p[1]), float(p[2]) * model_scale))


static func is_identity(info: Dictionary) -> bool:
	var p: Array = info["pos"]
	return absf(float(info["yaw"])) < 0.01 and Vector3(p[0], p[1], p[2]).length() < 0.001
