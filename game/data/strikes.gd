class_name Strikes
## Strike definitions. Timing for the moment of impact comes from the animation
## manifest ("hit" event) so data and animation can't drift apart.
##   reach/arc: hit volume in front of the attacker (metres / degrees half-angle)
##   lunge: forward speed while striking; stun: victim hitstun (s)
##   knockdown: always knocks down; knockdown_if_stunned: when it lands as a combo ender
##   cancel: earliest time the next combo strike can start
##   running: done out of a run (keeps the run's momentum)
##   end: "down" leaves the attacker on the mat afterwards (dropkick, crossbody)

const ALL := {
	"jab": {"anim": "jab", "reach": 1.15, "arc": 55.0, "damage": 3.0, "stun": 0.32,
		"lunge": 0.8, "region": "head", "cancel": 0.2, "next": "punch", "sfx": "hit_light"},
	"punch": {"anim": "punch", "reach": 1.2, "arc": 50.0, "damage": 5.0, "stun": 0.42,
		"lunge": 1.0, "region": "head", "cancel": 0.32, "next": "jab", "sfx": "hit_light"},
	"big_boot": {"anim": "big_boot", "reach": 1.4, "arc": 40.0, "damage": 9.0, "stun": 0.55,
		"lunge": 0.4, "region": "body", "knockdown_if_stunned": true, "knockback": 3.2,
		"hitstop": 0.11, "sfx": "hit_heavy"},
	"clothesline": {"anim": "clothesline", "reach": 1.25, "arc": 60.0, "damage": 12.0,
		"stun": 0.5, "lunge": 0.0, "region": "head", "knockdown": true, "knockback": 4.0,
		"hitstop": 0.13, "sfx": "hit_heavy", "running": true},
	"dropkick": {"anim": "dropkick", "reach": 1.5, "arc": 40.0, "damage": 11.0, "stun": 0.55,
		"lunge": 1.6, "region": "body", "knockdown": true, "knockback": 3.6, "hitstop": 0.12,
		"sfx": "hit_heavy", "end": "down"},
	"superkick": {"anim": "superkick", "reach": 1.35, "arc": 40.0, "damage": 10.0, "stun": 0.6,
		"lunge": 0.3, "region": "head", "knockdown_if_stunned": true, "knockback": 3.5,
		"hitstop": 0.14, "sfx": "hit_heavy"},
	"shoulder_tackle": {"anim": "shoulder_tackle", "reach": 1.3, "arc": 60.0, "damage": 11.0,
		"stun": 0.5, "lunge": 0.0, "region": "body", "knockdown": true, "knockback": 4.5,
		"hitstop": 0.12, "sfx": "hit_heavy", "running": true},
	"running_knee": {"anim": "running_knee", "reach": 1.25, "arc": 50.0, "damage": 12.0,
		"stun": 0.5, "lunge": 0.0, "region": "head", "knockdown": true, "knockback": 3.8,
		"hitstop": 0.13, "sfx": "hit_heavy", "running": true},
	"crossbody": {"anim": "crossbody", "reach": 1.4, "arc": 60.0, "damage": 13.0,
		"stun": 0.5, "lunge": 0.0, "region": "body", "knockdown": true, "knockback": 2.0,
		"hitstop": 0.12, "sfx": "body_fall", "running": true, "end": "down"},
}


static func get_move(id: String) -> Dictionary:
	var m: Dictionary = ALL[id].duplicate()
	m["id"] = id
	var events: Dictionary = WrestlerModel.manifest()["animations"][m["anim"]]["events"]
	m["hit_time"] = float(events.get("hit", 0.2))
	m["length"] = float(WrestlerModel.manifest()["animations"][m["anim"]]["length"])
	return m
