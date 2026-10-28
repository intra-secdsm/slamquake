class_name Movesets
## Move slots: which move a wrestler does in each situation. Roster wrestlers and
## create-a-wrestler fill these in. A slot that is missing, unknown or whose
## animation isn't built falls back to the slot default.
##   options: move ids (Strikes / Grapples ids, or animation names for dives and taunts)

const SLOTS := [
	{"id": "kick", "label": "Kick", "input": "Kick",
		"default": "big_boot", "options": ["big_boot", "dropkick", "superkick"]},
	{"id": "running", "label": "Running attack", "input": "Run + Punch/Kick",
		"default": "clothesline", "options": ["clothesline", "shoulder_tackle", "running_knee", "crossbody"]},
	{"id": "tieup_punch", "label": "Tie-up strike", "input": "Grapple, then Punch",
		"default": "headbutt", "options": ["headbutt", "knee_lift", "chop"]},
	{"id": "tieup_punch_dir", "label": "Tie-up throw", "input": "Grapple, then direction + Punch",
		"default": "body_slam", "options": ["body_slam", "arm_drag", "hip_toss"]},
	{"id": "tieup_kick", "label": "Tie-up suplex", "input": "Grapple, then Kick",
		"default": "suplex", "options": ["suplex", "snap_suplex", "gutwrench"]},
	{"id": "tieup_kick_dir", "label": "Tie-up power move", "input": "Grapple, then direction + Kick",
		"default": "ddt", "options": ["ddt", "neckbreaker", "powerslam", "piledriver"]},
	{"id": "back_grapple", "label": "From behind", "input": "Grapple from behind",
		"default": "german", "options": ["german", "back_suplex", "atomic_drop"]},
	{"id": "ground_punch", "label": "On a downed opponent", "input": "Punch by a downed opponent",
		"default": "elbow_drop", "options": ["elbow_drop", "leg_drop", "knee_drop"]},
	{"id": "dive_punch", "label": "Top rope (Punch)", "input": "Punch on the top rope",
		"default": "dive_elbow", "options": ["dive_elbow", "dive_splash", "dive_moonsault", "dive_headbutt"]},
	{"id": "dive_kick", "label": "Top rope (Kick)", "input": "Kick on the top rope",
		"default": "dive_splash", "options": ["dive_elbow", "dive_splash", "dive_moonsault", "dive_headbutt"]},
	{"id": "taunt", "label": "Taunt", "input": "Taunt",
		"default": "taunt", "options": ["taunt", "taunt_roar", "taunt_zap", "taunt_wings", "taunt_think",
			"taunt_shaka", "taunt_robot", "taunt_star"]},
	{"id": "finisher", "label": "Finisher", "input": "Taunt with a SPECIAL",
		"default": "thunder_bomb", "options": ["thunder_bomb", "volt_shock", "iron_drop", "quetzal_rana",
			"checkmate", "wipeout", "system_crash", "supernova"]},
]

## Display names for moves that don't carry their own (finishers have "name" in Grapples).
const NAMES := {
	"big_boot": "Big Boot", "dropkick": "Dropkick", "superkick": "Superkick",
	"clothesline": "Clothesline", "shoulder_tackle": "Shoulder Tackle", "running_knee": "Running Knee",
	"crossbody": "Running Crossbody",
	"headbutt": "Headbutt", "knee_lift": "Knee Lift", "chop": "Knife-Edge Chop",
	"body_slam": "Body Slam", "arm_drag": "Arm Drag", "hip_toss": "Hip Toss",
	"suplex": "Vertical Suplex", "snap_suplex": "Snap Suplex", "gutwrench": "Gutwrench Suplex",
	"ddt": "DDT", "neckbreaker": "Neckbreaker", "powerslam": "Powerslam", "piledriver": "Piledriver",
	"german": "German Suplex", "back_suplex": "Back Suplex", "atomic_drop": "Atomic Drop",
	"elbow_drop": "Elbow Drop", "leg_drop": "Leg Drop", "knee_drop": "Knee Drop",
	"dive_elbow": "Diving Elbow", "dive_splash": "Splash", "dive_moonsault": "Moonsault",
	"dive_headbutt": "Flying Headbutt",
	"taunt": "Flex", "taunt_roar": "Roar", "taunt_zap": "Power Surge", "taunt_wings": "Spread the Wings",
	"taunt_think": "Mastermind", "taunt_shaka": "Hang Loose", "taunt_robot": "Reboot", "taunt_star": "Reach for the Stars",
}

## Damage when a dive lands on a downed opponent.
const DIVE_DAMAGE := {"dive_elbow": 16.0, "dive_splash": 14.0, "dive_moonsault": 18.0, "dive_headbutt": 16.0}


static func slot(id: String) -> Dictionary:
	for s in SLOTS:
		if s["id"] == id:
			return s
	return {}


static func slot_ids() -> Array[String]:
	var out: Array[String] = []
	for s in SLOTS:
		out.append(s["id"])
	return out


## Which slot a move belongs to ("" if none). Dives belong to dive_punch first.
static func slot_of(move_id: String) -> String:
	for s in SLOTS:
		if move_id in s["options"]:
			return s["id"]
	return ""


static func defaults() -> Dictionary:
	var out := {}
	for s in SLOTS:
		out[s["id"]] = s["default"]
	return out


## A complete moveset: every slot filled with a known, built move.
static func resolve(moves: Dictionary) -> Dictionary:
	var out := {}
	for s in SLOTS:
		var id := String(moves.get(s["id"], s["default"]))
		out[s["id"]] = id if id in s["options"] and is_available(id) else s["default"]
	return out


## The options for a slot whose animations exist in the current build.
static func options(slot_id: String) -> Array[String]:
	var out: Array[String] = []
	for id in slot(slot_id).get("options", []):
		if is_available(id):
			out.append(id)
	return out


## True when the move's animations are in the generated library.
static func is_available(id: String) -> bool:
	var anims: Dictionary = WrestlerModel.manifest()["animations"]
	if Grapples.ALL.has(id):
		return anims.has(String(Grapples.ALL[id].get("anim", id)) + "_a")
	if Strikes.ALL.has(id):
		return anims.has(String(Strikes.ALL[id]["anim"]))
	return anims.has(id)


static func move_name(id: String) -> String:
	if Grapples.ALL.has(id) and Grapples.ALL[id].has("name"):
		return Grapples.ALL[id]["name"]
	return NAMES.get(id, id.capitalize())


## A wrestler's moves as [input, move name] rows, finisher first (for move lists).
static func move_list(moves: Dictionary) -> Array:
	var rows: Array = []
	var fin := slot("finisher")
	rows.append([fin["input"], move_name(String(moves.get("finisher", fin["default"])))])
	for s in SLOTS:
		if s["id"] != "finisher":
			rows.append([s["input"], move_name(String(moves.get(s["id"], s["default"])))])
	return rows
