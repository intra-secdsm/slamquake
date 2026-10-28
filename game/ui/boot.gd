extends Node
## First scene. Puts up the box-art title (carrying on from the engine's boot splash),
## starts the menu music at its menu level, loads the main menu in the background, then
## switches to it with the title kept over it until the menu is drawing smoothly.

const MENU := "res://ui/main_menu.tscn"

var _cover: LoadingCover


func _ready() -> void:
	if DevTools.has_arg("scene"):        # dev runs go straight to the scene they asked for
		set_process(false)
		return
	_cover = LoadingCover.new()
	add_child(_cover)
	AudioDirector.play_music("theme_menu", 0.0, true, AudioDirector.MENU_DB)
	ResourceLoader.load_threaded_request(MENU)


func _process(_delta: float) -> void:
	var status := ResourceLoader.load_threaded_get_status(MENU)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	set_process(false)
	# the cover outlives this scene: it stays over the menu while that builds
	_cover.reparent(get_tree().root)
	_cover.start()
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(MENU))
	else:
		get_tree().change_scene_to_file(MENU)
