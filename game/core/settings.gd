extends Node
## Player options, saved to user://settings.cfg: volumes, display and presentation.

const PATH := "user://settings.cfg"
## Saves from before the game had its name lived in Godot's default folder for the old
## project name; they're copied across once (the old folder is left as it was).
const OLD_USER_DIR := "app_userdata/Wrestle (working title)"
const OLD_SAVES := ["settings.cfg", "created_wrestlers.json", "unlocks.json", "career.json"]

var music_volume := 0.8
var sfx_volume := 1.0
var crowd_volume := 0.8
var fullscreen := false
var crt := true             ## CRT filter on the menus
var entrances := true       ## wrestler entrances before matches
var replays := true         ## instant replay of the finish
var high_quality := true    ## graphics: haze, ambient occlusion and 4x MSAA at full resolution

signal changed


func _ready() -> void:
	_copy_old_saves()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for key in _keys():
			set(key, cfg.get_value("options", key, get(key)))
	# headless runs (tests, soak) never want entrances or replays slowing them down
	if DisplayServer.get_name() == "headless":
		entrances = false
		replays = false
	apply()


func _copy_old_saves() -> void:
	for godot_dir in ["godot", "Godot"]:
		var old := OS.get_data_dir().path_join(godot_dir).path_join(OLD_USER_DIR)
		if not DirAccess.dir_exists_absolute(old):
			continue
		for f: String in OLD_SAVES:
			var to := ProjectSettings.globalize_path("user://" + f)
			if FileAccess.file_exists(old.path_join(f)) and not FileAccess.file_exists(to):
				DirAccess.copy_absolute(old.path_join(f), to)


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
		# low quality: no MSAA, and the 3D picture drawn at 3/4 size and upscaled (FSR)
		var root := get_tree().root
		root.msaa_3d = Viewport.MSAA_4X if high_quality else Viewport.MSAA_DISABLED
		root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if high_quality else Viewport.SCALING_3D_MODE_FSR
		root.scaling_3d_scale = 1.0 if high_quality else 0.75
	changed.emit()


func _keys() -> Array[String]:
	return ["music_volume", "sfx_volume", "crowd_volume", "fullscreen", "crt", "entrances", "replays", "high_quality"]


static func _bus(bus_name: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, linear <= 0.001)
