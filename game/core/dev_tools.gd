extends Node
## Developer command-line hooks (pass after `--` on the godot command line):
##   --scene=res://path.tscn    switch to this scene on startup
##   --screenshot=/abs/out.png  save a frame of the main viewport, then quit
##   --frames=N                 frames to wait before the screenshot (default 30)
##   --set=key:value            arbitrary values, readable via DevTools.get_arg()

var _args: Dictionary = {}
var _frames_left: int = -1
var _shot_path: String = ""

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if _args.has("scene"):
		get_tree().change_scene_to_file.call_deferred(_args["scene"])
	if _args.has("screenshot"):
		_shot_path = _args["screenshot"]
		_frames_left = int(_args.get("frames", "30"))
		process_mode = Node.PROCESS_MODE_ALWAYS

func get_arg(key: String, default: String = "") -> String:
	return _args.get(key, default)

func has_arg(key: String) -> bool:
	return _args.has(key)

func _process(_delta: float) -> void:
	if _frames_left < 0:
		return
	_frames_left -= 1
	if _frames_left == 0:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var err := img.save_png(_shot_path)
		print("screenshot %s -> %s" % [error_string(err), _shot_path])
		get_tree().quit(0 if err == OK else 1)
