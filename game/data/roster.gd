class_name Roster
## Placeholder roster for early playtests (the full roster of 8 arrives in M8).
## All characters are original.

static func all() -> Array[Dictionary]:
	return [
		{"name": "Thunder Mack", "look": _thunder_mack(), "finisher": "thunder_bomb"},
		{"name": "Zip Volta", "look": _zip_volta(), "finisher": "volt_shock"},
		{"name": "Bruno Kessler", "look": _bruno(), "finisher": "iron_drop"},
	]


static func get_entry(i: int) -> Dictionary:
	var r := all()
	return r[clampi(i, 0, r.size() - 1)]


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
