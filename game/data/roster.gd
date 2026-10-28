class_name Roster
## Placeholder roster for early playtests (the full roster of 8 arrives in M8).
## All characters are original.

static func all() -> Array[Dictionary]:
	return [
		{"name": "Thunder Mack", "look": _thunder_mack()},
		{"name": "Zip Volta", "look": _zip_volta()},
		{"name": "Bruno Kessler", "look": _bruno()},
	]


static func get_entry(i: int) -> Dictionary:
	var r := all()
	return r[clampi(i, 0, r.size() - 1)]


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
