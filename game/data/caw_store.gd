class_name CawStore
## Created wrestlers, kept in one JSON file under user://. Entries use the same shape
## as Roster entries (plus "caw": true), so they can be picked anywhere a roster
## wrestler can.
##   file: {"version": 1, "wrestlers": [ {id, name, tagline, color, theme, pyro, motif,
##          stats, moves, look: WrestlerLook.to_dict()}, ... ]}

const VERSION := 1
const MAX_WRESTLERS := 24
const NAME_MAX := 18
const TAGLINE_MAX := 32

static var path := "user://created_wrestlers.json"   ## tests point this somewhere else
static var _entries: Array[Dictionary] = []
static var _loaded := false


static func entries() -> Array[Dictionary]:
	if not _loaded:
		reload()
	return _entries


## Re-read the file (missing or broken files just mean no created wrestlers).
static func reload() -> void:
	_loaded = true
	_entries.clear()
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_warning("CawStore: %s is not valid JSON; ignoring it" % path)
		return
	for d in data.get("wrestlers", []):
		if d is Dictionary and _entries.size() < MAX_WRESTLERS:
			_entries.append(from_save(d))


static func save() -> bool:
	var list: Array = []
	for e in entries():
		list.append(to_save(e))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("CawStore: can't write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify({"version": VERSION, "wrestlers": list}, "\t"))
	return true


## Add or replace (by id) and save.
static func put(entry: Dictionary) -> bool:
	var e := from_save(to_save(entry))     # normalise
	var list := entries()
	for i in list.size():
		if list[i]["id"] == e["id"]:
			list[i] = e
			return save()
	if list.size() >= MAX_WRESTLERS:
		return false
	list.append(e)
	return save()


static func remove(id: String) -> bool:
	var list := entries()
	for i in list.size():
		if list[i]["id"] == id:
			list.remove_at(i)
			return save()
	return false


static func get_by_id(id: String) -> Dictionary:
	for e in entries():
		if e["id"] == id:
			return e
	return {}


## A fresh wrestler to start editing from.
static func blank() -> Dictionary:
	var look := WrestlerLook.new()
	return {"id": "caw_%d" % int(Time.get_unix_time_from_system() * 1000.0), "name": "New Wrestler",
		"tagline": "", "color": Color("ff2bd6"), "theme": "theme_anthem", "pyro": "classic", "motif": "grid",
		"stats": Stats.defaults(), "moves": Movesets.defaults(), "look": look, "caw": true}


static func to_save(e: Dictionary) -> Dictionary:
	var look: WrestlerLook = e.get("look", WrestlerLook.new())
	var color: Color = e.get("color", Color("ff2bd6"))
	return {"id": String(e.get("id", "")), "name": String(e.get("name", "New Wrestler")),
		"tagline": String(e.get("tagline", "")), "color": "#" + color.to_html(false),
		"theme": String(e.get("theme", "theme_anthem")), "pyro": String(e.get("pyro", "classic")),
		"motif": String(e.get("motif", "grid")), "stats": Stats.sanitize(e.get("stats", {})),
		"moves": (e.get("moves", {}) as Dictionary).duplicate(), "look": look.to_dict()}


static func from_save(d: Dictionary) -> Dictionary:
	var id := String(d.get("id", ""))
	if id == "":
		id = "caw_%d" % int(Time.get_unix_time_from_system() * 1000.0)
	var color := Color("ff2bd6")
	var c: Variant = d.get("color", "")
	if c is Color:
		color = c
	elif c is String and Color.html_is_valid(c):
		color = Color.html(c)
	var look: Variant = d.get("look", {})
	var moves := {}
	var saved_moves: Variant = d.get("moves", {})
	if saved_moves is Dictionary:
		for slot_id in Movesets.slot_ids():
			if saved_moves.has(slot_id) and String(saved_moves[slot_id]) in Movesets.slot(slot_id)["options"]:
				moves[slot_id] = String(saved_moves[slot_id])
	var theme := String(d.get("theme", "theme_anthem"))
	var pyro := String(d.get("pyro", "classic"))
	var motif := String(d.get("motif", "grid"))
	var stats: Variant = d.get("stats", {})
	return {"id": id, "name": String(d.get("name", "New Wrestler")).strip_edges().left(NAME_MAX),
		"tagline": String(d.get("tagline", "")).strip_edges().left(TAGLINE_MAX), "color": color,
		"theme": theme if theme in Roster.THEMES else "theme_anthem",
		"pyro": pyro if pyro in Roster.PYRO_STYLES else "classic",
		"motif": motif if motif in Roster.MOTIFS else "grid",
		"stats": Stats.sanitize(stats if stats is Dictionary else {}),
		"moves": moves,
		"look": look if look is WrestlerLook else WrestlerLook.from_dict(look if look is Dictionary else {}),
		"caw": true}
