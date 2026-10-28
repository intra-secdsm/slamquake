extends Node
## Player options, saved to user://settings.cfg: volumes, display and presentation.

const PATH := "user://settings.cfg"

var music_volume := 0.8
var sfx_volume := 1.0
var crowd_volume := 0.8
var fullscreen := false
var crt := true             ## CRT filter on the menus
var entrances := true       ## wrestler entrances before matches
var replays := true         ## instant replay of the finish


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for key in _keys():
			set(key, cfg.get_value("options", key, get(key)))
	# headless runs (tests, soak) never want entrances or replays slowing them down
	if DisplayServer.get_name() == "headless":
		entrances = false
		replays = false
	apply()


func save() -> void:
	var cfg := ConfigFile.new()
	for key in _keys():
		cfg.set_value("options", key, get(key))
	cfg.save(PATH)


func apply() -> void:
	_bus("Music", music_volume)
	_bus("SFX", sfx_volume)
	_bus("Crowd", crowd_volume)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
			else DisplayServer.WINDOW_MODE_WINDOWED)


func _keys() -> Array[String]:
	return ["music_volume", "sfx_volume", "crowd_volume", "fullscreen", "crt", "entrances", "replays"]


static func _bus(bus_name: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, linear <= 0.001)
