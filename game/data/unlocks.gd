class_name Unlocks
## Things earned in career mode, kept for good in user://unlocks.json (shared by every
## career): hidden wrestlers and extras for Create-a-Wrestler.

const ITEMS := {
	"pyro_champion": {"name": "Champion pyro (Create-a-Wrestler)", "how": "Win a match at a pay-per-view"},
	"roxy_ravage": {"name": "Hidden wrestler: Roxy Ravage", "how": "Win the Tag Team titles"},
	"mister_midnight": {"name": "Hidden wrestler: Mister Midnight", "how": "Win the World title"},
	"hall_of_fame": {"name": "Hall of Fame", "how": "Defend the World title three times"},
}

## Tests point this somewhere else (kept in ProjectSettings, like CawStore.path).
static var path: String:
	get:
		return ProjectSettings.get_setting("wrestle/unlocks_path", "user://unlocks.json")
	set(value):
		ProjectSettings.set_setting("wrestle/unlocks_path", value)
static var _have := {}
static var _loaded := false


static func has(id: String) -> bool:
	if not _loaded:
		reload()
	return _have.has(id)


## Earn an unlock and save; true if it's new.
static func unlock(id: String) -> bool:
	if has(id) or not ITEMS.has(id):
		return false
	_have[id] = true
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Unlocks: can't write %s" % path)
	else:
		f.store_string(JSON.stringify({"unlocked": _have.keys()}, "\t"))
	return true


static func reload() -> void:
	_loaded = true
	_have.clear()
	if not FileAccess.file_exists(path):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		push_warning("Unlocks: %s is not valid JSON; ignoring it" % path)
		return
	for id in json.data.get("unlocked", []):
		if ITEMS.has(String(id)):
			_have[String(id)] = true
