class_name Roster
## The eight built-in wrestlers, then hidden wrestlers unlocked in career mode (Unlocks),
## then any created wrestlers (CawStore). All characters are original.
##   id: stable key (saves, career)   moves: Movesets slot -> move id   stats: see Stats
##   theme: music track   pyro: entrance pyrotechnics style   motif: titantron graphic
##   style: how the CPU fights them (CpuController.STYLES)

## "champion" is earned in career mode (Unlocks "pyro_champion")
const PYRO_STYLES := ["classic", "fireworks", "flames", "sparks", "none", "champion"]
const MOTIFS := ["grid", "storm", "bolts", "steel", "feathers", "checker", "waves", "circuit", "stars"]
## every theme a created wrestler can walk out to (roster themes first)
const THEMES := ["theme_thunder", "theme_zip", "theme_bruno", "theme_quetzal", "theme_silas", "theme_kai",
	"theme_overclock", "theme_nova", "theme_anthem", "theme_groove", "theme_grunge"]
const THEME_NAMES := {"theme_thunder": "Southside Storm", "theme_zip": "High Voltage", "theme_bruno": "Iron Wall",
	"theme_quetzal": "Alas de Neón", "theme_silas": "Opening Gambit", "theme_kai": "Breakwater",
	"theme_overclock": "Overclocked", "theme_nova": "Supernova", "theme_anthem": "Main Event Anthem",
	"theme_groove": "Ringside Groove", "theme_grunge": "Flannel Fury"}

static var _builtin: Array[Dictionary] = []
static var _hidden: Array[Dictionary] = []


## Built-in wrestlers, unlocked hidden ones, then created ones.
static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = builtin().duplicate()
	for e in hidden():
		if Unlocks.has(e["id"]):
			out.append(e)
	out.append_array(CawStore.entries())
	return out


## Pyro styles a created wrestler can pick (the champion's pyro has to be earned).
static func pyro_styles() -> Array:
	return PYRO_STYLES.filter(func(p: String) -> bool: return p != "champion" or Unlocks.has("pyro_champion"))


## The hidden wrestlers, locked or not (each one's id is its Unlocks id).
static func hidden() -> Array[Dictionary]:
	if _hidden.is_empty():
		_hidden = [
			{"id": "roxy_ravage", "style": "brawler", "name": "Roxy Ravage", "look": _roxy(), "theme": "theme_grunge",
				"color": Color("ff9ec8"), "tagline": "THE HEAVY METAL HURRICANE", "pyro": "flames", "motif": "bolts",
				"stats": {"power": 4, "speed": 3, "toughness": 3, "charisma": 2},
				"moves": {"kick": "big_boot", "running": "clothesline", "tieup_punch": "headbutt",
					"tieup_punch_dir": "neckbreaker", "tieup_kick": "suplex", "tieup_kick_dir": "piledriver",
					"back_grapple": "german", "ground_punch": "elbow_drop", "dive_punch": "dive_elbow",
					"dive_kick": "dive_splash", "taunt": "taunt_roar", "finisher": "wipeout"}},
			{"id": "mister_midnight", "style": "technician", "name": "Mister Midnight", "look": _midnight(),
				"theme": "theme_anthem", "color": Color("6a5cff"), "tagline": "THE LAST THING YOU SEE", "pyro": "none",
				"motif": "stars", "stats": {"power": 4, "speed": 2, "toughness": 4, "charisma": 2},
				"moves": {"kick": "superkick", "running": "shoulder_tackle", "tieup_punch": "chop",
					"tieup_punch_dir": "body_slam", "tieup_kick": "gutwrench", "tieup_kick_dir": "powerslam",
					"back_grapple": "back_suplex", "ground_punch": "knee_drop", "dive_punch": "dive_headbutt",
					"dive_kick": "dive_elbow", "taunt": "taunt_think", "finisher": "checkmate"}},
		]
	return _hidden


static func builtin() -> Array[Dictionary]:
	if _builtin.is_empty():
		_builtin = [
			{"id": "thunder_mack", "style": "brawler", "name": "Thunder Mack", "look": _thunder_mack(), "theme": "theme_thunder",
				"color": Color("ff2bd6"), "tagline": "THE STORM FROM SOUTH STREET", "pyro": "classic", "motif": "storm",
				"stats": {"power": 4, "speed": 2, "toughness": 3, "charisma": 3},
				"moves": {"kick": "big_boot", "running": "clothesline", "tieup_punch": "headbutt",
					"tieup_punch_dir": "body_slam", "tieup_kick": "suplex", "tieup_kick_dir": "piledriver",
					"back_grapple": "german", "ground_punch": "elbow_drop", "dive_punch": "dive_elbow",
					"dive_kick": "dive_splash", "taunt": "taunt", "finisher": "thunder_bomb"}},
			{"id": "zip_volta", "style": "highflyer", "name": "Zip Volta", "look": _zip_volta(), "theme": "theme_zip",
				"color": Color("00e5ff"), "tagline": "100,000 VOLTS OF HIGH-FLYING", "pyro": "sparks", "motif": "bolts",
				"stats": {"power": 2, "speed": 5, "toughness": 2, "charisma": 3},
				"moves": {"kick": "dropkick", "running": "running_knee", "tieup_punch": "knee_lift",
					"tieup_punch_dir": "arm_drag", "tieup_kick": "snap_suplex", "tieup_kick_dir": "ddt",
					"back_grapple": "back_suplex", "ground_punch": "leg_drop", "dive_punch": "dive_moonsault",
					"dive_kick": "dive_splash", "taunt": "taunt_zap", "finisher": "volt_shock"}},
			{"id": "bruno_kessler", "style": "powerhouse", "name": "Bruno Kessler", "look": _bruno(), "theme": "theme_bruno",
				"color": Color("ffd400"), "tagline": "THE IRON WALL", "pyro": "flames", "motif": "steel",
				"stats": {"power": 5, "speed": 1, "toughness": 4, "charisma": 2},
				"moves": {"kick": "big_boot", "running": "shoulder_tackle", "tieup_punch": "headbutt",
					"tieup_punch_dir": "body_slam", "tieup_kick": "gutwrench", "tieup_kick_dir": "powerslam",
					"back_grapple": "atomic_drop", "ground_punch": "elbow_drop", "dive_punch": "dive_headbutt",
					"dive_kick": "dive_splash", "taunt": "taunt_roar", "finisher": "iron_drop"}},
			{"id": "quetzal_neon", "style": "highflyer", "name": "Quetzal Neón", "look": _quetzal(), "theme": "theme_quetzal",
				"color": Color("3dff6e"), "tagline": "THE EMERALD WINGS OF LUCHA", "pyro": "fireworks", "motif": "feathers",
				"stats": {"power": 2, "speed": 4, "toughness": 2, "charisma": 4},
				"moves": {"kick": "dropkick", "running": "crossbody", "tieup_punch": "chop",
					"tieup_punch_dir": "arm_drag", "tieup_kick": "snap_suplex", "tieup_kick_dir": "ddt",
					"back_grapple": "back_suplex", "ground_punch": "leg_drop", "dive_punch": "dive_moonsault",
					"dive_kick": "dive_splash", "taunt": "taunt_wings", "finisher": "quetzal_rana"}},
			{"id": "silas_wren", "style": "technician", "name": "Silas Wren", "look": _silas(), "theme": "theme_silas",
				"color": Color("4d7cff"), "tagline": "THE GRANDMASTER OF THE MAT", "pyro": "none", "motif": "checker",
				"stats": {"power": 3, "speed": 3, "toughness": 4, "charisma": 2},
				"moves": {"kick": "superkick", "running": "running_knee", "tieup_punch": "knee_lift",
					"tieup_punch_dir": "hip_toss", "tieup_kick": "snap_suplex", "tieup_kick_dir": "neckbreaker",
					"back_grapple": "german", "ground_punch": "knee_drop", "dive_punch": "dive_elbow",
					"dive_kick": "dive_elbow", "taunt": "taunt_think", "finisher": "checkmate"}},
			{"id": "kai_breakwater", "style": "showman", "name": "Kai Breakwater", "look": _kai(), "theme": "theme_kai",
				"color": Color("ff8a1f"), "tagline": "HANG TEN. HIT HARD.", "pyro": "fireworks", "motif": "waves",
				"stats": {"power": 3, "speed": 4, "toughness": 2, "charisma": 3},
				"moves": {"kick": "superkick", "running": "clothesline", "tieup_punch": "chop",
					"tieup_punch_dir": "body_slam", "tieup_kick": "suplex", "tieup_kick_dir": "neckbreaker",
					"back_grapple": "back_suplex", "ground_punch": "leg_drop", "dive_punch": "dive_splash",
					"dive_kick": "dive_moonsault", "taunt": "taunt_shaka", "finisher": "wipeout"}},
			{"id": "overclock", "style": "powerhouse", "name": "Overclock", "look": _overclock(), "theme": "theme_overclock",
				"color": Color("b44dff"), "tagline": "THE CYBERNETIC SUPERSTAR", "pyro": "sparks", "motif": "circuit",
				"stats": {"power": 4, "speed": 2, "toughness": 4, "charisma": 2},
				"moves": {"kick": "big_boot", "running": "shoulder_tackle", "tieup_punch": "headbutt",
					"tieup_punch_dir": "body_slam", "tieup_kick": "gutwrench", "tieup_kick_dir": "powerslam",
					"back_grapple": "atomic_drop", "ground_punch": "elbow_drop", "dive_punch": "dive_headbutt",
					"dive_kick": "dive_splash", "taunt": "taunt_robot", "finisher": "system_crash"}},
			{"id": "nova_reyes", "style": "highflyer", "name": "Nova Reyes", "look": _nova(), "theme": "theme_nova",
				"color": Color("ff3b4e"), "tagline": "BRIGHTER THAN A THOUSAND SUNS", "pyro": "fireworks", "motif": "stars",
				"stats": {"power": 3, "speed": 3, "toughness": 2, "charisma": 4},
				"moves": {"kick": "dropkick", "running": "crossbody", "tieup_punch": "knee_lift",
					"tieup_punch_dir": "arm_drag", "tieup_kick": "snap_suplex", "tieup_kick_dir": "ddt",
					"back_grapple": "german", "ground_punch": "knee_drop", "dive_punch": "dive_moonsault",
					"dive_kick": "dive_splash", "taunt": "taunt_star", "finisher": "supernova"}},
		]
	return _builtin


static func get_entry(i: int) -> Dictionary:
	var r := all()
	return r[clampi(i, 0, r.size() - 1)]


## Index of the wrestler with this id, or -1.
static func find(id: String) -> int:
	var r := all()
	for i in r.size():
		if r[i]["id"] == id:
			return i
	return -1


## The same wrestler in alternate gear, for when they appear twice in one match.
static func alt_look(base: WrestlerLook) -> WrestlerLook:
	var l: WrestlerLook = base.duplicate()
	for prop in ["trunks_color", "trim_color", "pads_color", "tights_color", "top_color", "mask_color", "pattern_color"]:
		var c: Color = l.get(prop)
		l.set(prop, Color.from_hsv(fposmod(c.h + 0.45, 1.0), maxf(c.s, 0.5), c.v))
	return l


static func referee_look() -> WrestlerLook:
	var l := WrestlerLook.new()
	l.mass = -0.3
	l.muscle = 0.0
	l.gut = 0.25
	l.height = 0.97
	l.skin_color = Color(0.86, 0.66, 0.52)
	l.hair_style = "flattop"
	l.hair_color = Color(0.3, 0.3, 0.3)
	l.shirt = true
	l.stripes = 18
	l.trunks_color = Color(0.06, 0.06, 0.07)
	l.trim_color = Color(0.06, 0.06, 0.07)
	l.tights = true
	l.tights_color = Color(0.06, 0.06, 0.07)
	l.boots_color = Color(0.02, 0.02, 0.02)
	l.kneepads = false
	l.wristbands = false
	l.boot_top = 0.18
	return l


static func _thunder_mack() -> WrestlerLook:
	var l := WrestlerLook.new()
	l.muscle = 0.6
	l.hair_style = "mullet"
	l.hair_color = Color(0.55, 0.38, 0.18)
	return l


static func _zip_volta() -> WrestlerLook:
	var l := WrestlerLook.new()
	l.mass = -0.6
	l.muscle = 0.2
	l.height = 0.95
	l.skin_color = Color(0.55, 0.36, 0.24)
	l.hair_style = "mohawk"
	l.hair_color = Color(0.1, 0.9, 0.8)
	l.trunks_color = Color(0.1, 0.8, 0.9)
	l.trim_color = Color(0.95, 0.95, 0.95)
	l.pads_color = Color(0.1, 0.8, 0.9)
	l.tights = true
	l.tights_color = Color(0.1, 0.12, 0.35)
	l.pattern = "bolt"
	l.pattern_color = Color(0.1, 0.9, 1.0)
	l.boots_color = Color(0.9, 0.9, 0.95)
	return l


static func _bruno() -> WrestlerLook:
	var l := WrestlerLook.new()
	l.mass = 1.0
	l.gut = 0.6
	l.muscle = 0.3
	l.height = 1.08
	l.skin_color = Color(0.9, 0.68, 0.55)
	l.hair_style = "bald"
	l.trunks_color = Color(0.1, 0.1, 0.1)
	l.trim_color = Color(0.9, 0.1, 0.1)
	l.pads_color = Color(0.1, 0.1, 0.1)
	l.elbowpads = true
	return l



static func _quetzal() -> WrestlerLook:
	var l := WrestlerLook.new()
	l.mass = -0.5
	l.muscle = 0.35
	l.height = 0.96
	l.skin_color = Color(0.7, 0.48, 0.33)
	l.hair_style = "bald"
	l.mask = "wings"
	l.mask_color = Color("1fd65a")
	l.mask_trim = Color("ffd400")
	l.trunks_color = Color("1fd65a")
	l.trim_color = Color("ffd400")
	l.tights = true
	l.tights_color = Color("0d5e2c")
	l.pattern = "flames"
	l.pattern_color = Color("ffd400")
	l.pads_color = Color("ffd400")
	l.boots_color = Color(0.95, 0.95, 0.95)
	return l


static func _silas() -> WrestlerLook:
	var l := WrestlerLook.new()
	l.muscle = 0.4
	l.height = 1.0
	l.skin_color = Color(0.86, 0.64, 0.5)
	l.hair_style = "buzz"
	l.hair_color = Color(0.42, 0.38, 0.34)
	l.facial_hair = "moustache"
	l.singlet = true
	l.trunks_color = Color("2a4fd6")
	l.trim_color = Color(0.95, 0.95, 0.95)
	l.pattern = "stripe"
	l.pattern_color = Color(0.95, 0.95, 0.95)
	l.trunks_bottom = 0.8
	l.pads_color = Color(0.08, 0.08, 0.1)
	l.boots_color = Color(0.08, 0.08, 0.1)
	l.wristbands = false
	return l


static func _kai() -> WrestlerLook:
	var l := WrestlerLook.new()
	l.mass = -0.15
	l.muscle = 0.45
	l.skin_color = Color(0.78, 0.55, 0.38)
	l.hair_style = "long"
	l.hair_color = Color(0.93, 0.8, 0.45)
	l.trunks_color = Color("ff8a1f")
	l.trim_color = Color("1fb5ff")
	l.trunks_bottom = 0.72
	l.pattern = "split"
	l.pattern_color = Color("1fb5ff")
	l.boots = false
	l.kneepads = false
	l.pads_color = Color("1fb5ff")
	l.tattoo = "armband"
	return l


static func _roxy() -> WrestlerLook:
	var l := WrestlerLook.new()
	l.feminine = 1.0
	l.mass = 0.1
	l.muscle = 0.6
	l.height = 0.98
	l.skin_color = Color(0.93, 0.78, 0.68)
	l.hair_style = "mohawk"
	l.hair_color = Color("ff9ec8")
	l.face_paint = "warrior"
	l.paint_color = Color(0.08, 0.08, 0.1)
	l.paint_color2 = Color("ff9ec8")
	l.top = true
	l.top_color = Color(0.08, 0.08, 0.1)
	l.trunks_color = Color(0.08, 0.08, 0.1)
	l.trim_color = Color("ff9ec8")
	l.tights = true
	l.tights_color = Color(0.08, 0.08, 0.1)
	l.pattern = "flames"
	l.pattern_color = Color("ff9ec8")
	l.tattoo = "sleeve"
	l.tattoo_color = Color(0.15, 0.2, 0.35)
	l.pads_color = Color("ff9ec8")
	l.elbowpads = true
	return l


static func _midnight() -> WrestlerLook:
	var l := WrestlerLook.new()
	l.mass = 0.3
	l.muscle = 0.7
	l.height = 1.05
	l.skin_color = Color(0.55, 0.38, 0.27)
	l.mask = "classic"
	l.mask_color = Color(0.05, 0.05, 0.09)
	l.mask_trim = Color("6a5cff")
	l.singlet = true
	l.trunks_color = Color(0.05, 0.05, 0.09)
	l.trim_color = Color("6a5cff")
	l.pattern = "stars"
	l.pattern_color = Color("6a5cff")
	l.tights = true
	l.tights_color = Color(0.05, 0.05, 0.09)
	l.boots_color = Color(0.05, 0.05, 0.09)
	l.pads_color = Color("6a5cff")
	return l


static func _overclock() -> WrestlerLook:
	var l := WrestlerLook.new()
	l.mass = 0.4
	l.muscle = 0.85
	l.height = 1.04
	l.skin_color = Color(0.62, 0.5, 0.45)
	l.hair_style = "spiky"
	l.hair_color = Color(0.85, 0.88, 0.95)
	l.face_paint = "cyber"
	l.paint_color = Color(0.82, 0.86, 0.95)
	l.paint_color2 = Color("b44dff")
	l.trunks_color = Color(0.75, 0.78, 0.85)
	l.trim_color = Color("b44dff")
	l.tights = true
	l.tights_color = Color("2a0f4a")
	l.pattern = "bolt"
	l.pattern_color = Color("b44dff")
	l.pads_color = Color(0.75, 0.78, 0.85)
	l.elbowpads = true
	return l


static func _nova() -> WrestlerLook:
	var l := WrestlerLook.new()
	l.feminine = 1.0
	l.mass = -0.35
	l.muscle = 0.35
	l.height = 0.95
	l.skin_color = Color(0.68, 0.46, 0.32)
	l.hair_style = "ponytail"
	l.hair_color = Color(0.12, 0.07, 0.05)
	l.top = true
	l.top_color = Color("ff3b4e")
	l.trunks_color = Color("ff3b4e")
	l.trim_color = Color("ffd400")
	l.pattern = "stars"
	l.pattern_color = Color("ffd400")
	l.face_paint = "star"
	l.paint_color = Color("ffd400")
	l.pads_color = Color("ffd400")
	l.boots_color = Color(0.95, 0.95, 0.95)
	return l
