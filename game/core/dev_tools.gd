extends Node
## Developer command-line hooks (pass after `--` on the godot command line):
##   --scene=res://path.tscn    switch to this scene on startup
##   --screenshot=/abs/out.png  save a frame of the main viewport, then quit
##   --frames=N                 frames to wait before the screenshot (default 30)
##   --set=key:value            arbitrary values, readable via DevTools.get_arg()
##   --fps=SECONDS              print the average frame rate after this long, then quit

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

	if _args.has("fps"):
		_measure_fps(float(_args["fps"]))


## Frame timing: the frame rate (capped by vsync / the compositor), how long the GPU takes
## per frame, and when any slow frames happened. Headless runs are uncapped, so there the
## frame times are the game's whole CPU cost.
func _measure_fps(seconds: float) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await get_tree().create_timer(2.0).timeout      # let loading settle
	var frames: Array[float] = []
	var gpu: Array[float] = []
	var spikes: Array[String] = []
	var added := {}           # what appeared in the scene this frame, to blame slow frames on
	get_tree().node_added.connect(func(n: Node) -> void:
		var key := n.get_class() + ("(%s)" % n.get_parent().name if n.get_parent() else "")
		added[key] = added.get(key, 0) + 1)
	var start := Time.get_ticks_usec()
	var last := start
	while Time.get_ticks_usec() - start < seconds * 1e6:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		frames.append(ms)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		if ms > 25.0 and spikes.size() < 40:
			spikes.append("%.1fs:%.0fms" % [(now - start) / 1e6, ms])
			if ms > 45.0 and not added.is_empty():
				print("FPS %.0f ms frame after adding %s" % [ms, added])
		added.clear()
		last = now
	print("FPS %.1f  frame avg %.2f p99 %.2f max %.1f ms  |  gpu avg %.2f p99 %.2f ms" % [
		frames.size() / ((last - start) / 1e6), _avg(frames), _p99(frames), frames.max(), _avg(gpu), _p99(gpu)])
	if not spikes.is_empty():
		print("FPS slow frames: ", " ".join(spikes))
	get_tree().quit()


func _avg(a: Array[float]) -> float:
	var t := 0.0
	for v in a:
		t += v
	return t / maxf(a.size(), 1)


func _p99(a: Array[float]) -> float:
	var s := a.duplicate()
	s.sort()
	return s[int(s.size() * 0.99)] if not s.is_empty() else 0.0


## Take the --screenshot a few frames from now instead of after --frames
## (e.g. once a dev scene has paused on the moment it wants to show).
func capture_soon(frames: int = 3) -> void:
	if _shot_path != "":
		_frames_left = frames


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
