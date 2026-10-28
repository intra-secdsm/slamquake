class_name LoadingCover
extends CanvasLayer
## The box-art title, drawn over everything while the game loads: the same picture as the
## engine's boot splash, so it carries straight on from it. Once start() is called it stays
## up until frames come smoothly (the new scene has built and its shaders are ready), at
## least MIN_SHOW seconds and at most MAX_SHOW, then fades away and frees itself.

const SPLASH := preload("res://ui/splash.png")
const BG := Color(0.039, 0.0, 0.078)
const MIN_SHOW := 1.5
const MAX_SHOW := 8.0
const SMOOTH_FRAMES := 15      # this many quick frames in a row means loading is over
const FADE := 0.6

var shown := 0.0
var _running := false
var _smooth := 0
var _fading := false
var _root: Control


func _init() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var art := TextureRect.new()
	art.texture = SPLASH
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(art)


## Start the clock: from here on, wait for smooth frames, then fade.
func start() -> void:
	_running = true


func _process(delta: float) -> void:
	if not _running or _fading:
		return
	shown += delta
	_smooth = _smooth + 1 if delta < 0.05 else 0
	if (shown >= MIN_SHOW and _smooth >= SMOOTH_FRAMES) or shown >= MAX_SHOW:
		_fading = true
		var tw := create_tween()
		tw.tween_property(_root, "modulate:a", 0.0, FADE)
		tw.tween_callback(queue_free)
