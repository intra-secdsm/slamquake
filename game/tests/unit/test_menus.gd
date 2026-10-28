extends GutTest
## Front-end menus driven with the mouse.

var menu: Node
var _music := 0.0


func before_each() -> void:
	_music = Settings.music_volume
	Settings.music_volume = 0.5
	menu = load("res://ui/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	await wait_frames(3)


func after_each() -> void:
	Settings.music_volume = _music      # never saved: the player's settings file isn't touched
	Settings.apply()


## A left click at `x` across the button, as Godot delivers it: the button's gui_input
## signal sees the release first, then the button reports the press.
func _click(b: Button, x: float) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = Vector2(x, b.size.y / 2.0)
	b.gui_input.emit(ev)
	b.pressed.emit()
	await wait_frames(1)


func test_clicking_an_option_arrow_steps_that_way() -> void:
	menu._show_options()
	await wait_frames(2)
	var row: Button = menu._opt_rows[0]
	assert_string_contains(row.text, "Music")
	var mid := ArrowClick.text_middle(row)
	await _click(row, mid - 120.0)
	assert_almost_eq(Settings.music_volume, 0.4, 0.001, "◀ turns it down")
	await _click(row, mid + 120.0)
	await _click(row, mid + 120.0)
	assert_almost_eq(Settings.music_volume, 0.6, 0.001, "▶ turns it up")
	row.grab_focus()
	row.pressed.emit()          # Enter / A on the row still steps forward
	assert_almost_eq(Settings.music_volume, 0.7, 0.001)


func test_loading_title_waits_then_fades_away() -> void:
	var cover := LoadingCover.new()
	add_child(cover)
	await wait_seconds(0.5)
	assert_true(is_instance_valid(cover), "stays up until the next scene has started")
	cover.start()
	await wait_seconds(LoadingCover.MIN_SHOW - 0.4)
	assert_true(is_instance_valid(cover), "stays up a while even once frames are smooth")
	await wait_seconds(LoadingCover.FADE + 1.0)
	assert_false(is_instance_valid(cover), "then fades out and goes")


func test_menu_music_plays_at_the_menu_level() -> void:
	await wait_seconds(1.0)
	assert_eq(AudioDirector.music_playing(), "theme_menu")
	var player: AudioStreamPlayer = AudioDirector._music[AudioDirector._music_on]
	assert_almost_eq(player.volume_db, AudioDirector.MENU_DB, 0.5, "same level as on the loading screen")
	AudioDirector.play_music("theme_menu", 0.0, true, AudioDirector.MENU_DB)
	assert_almost_eq(player.volume_db, AudioDirector.MENU_DB, 0.01, "asking again changes nothing")


func test_credits_show_the_engine_license_and_its_components() -> void:
	var text := CreditsScreen.engine_notices()
	assert_string_contains(text, "Permission is hereby granted")     # Godot's MIT text
	for component in ["The FreeType Project", "Jolt Physics", "Mbed TLS"]:
		assert_string_contains(text, component)
	menu._show_options()
	menu._credits_button.pressed.emit()
	assert_true(menu._credits.visible)
	assert_false(menu._options.visible)
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	menu._credits._unhandled_input(esc)
	assert_false(menu._credits.visible, "Esc / B goes back")
	assert_true(menu._options.visible)
