extends GutTest
## Music crossfades: a superseded volume fade must never stomp the settled level of the
## selected track (issue #17). The director crossfades on two pooled players; when a
## player is reused before an earlier fade finished, the stale fade used to keep running
## and win out, leaving the selected theme at silence.

func after_all() -> void:
	# leave the shared director quiet so other tests' scenes start clean transitions
	AudioDirector.play_music("", 0.1)


func test_rapid_theme_changes_settle_on_the_selected_level() -> void:
	# the issue's repro: a 0.5s fade, then another theme 0.1s later with a 0.3s fade
	AudioDirector.play_music("theme_menu", 0.5, true, AudioDirector.MENU_DB)
	await wait_seconds(0.1)
	AudioDirector.play_music("theme_anthem", 0.3, true, AudioDirector.MENU_DB)
	await wait_seconds(1.0)   # every fade long finished
	var cur: AudioStreamPlayer = AudioDirector._music[AudioDirector._music_on]
	assert_eq(AudioDirector.music_playing(), "theme_anthem")
	assert_almost_eq(cur.volume_db, AudioDirector.MENU_DB, 0.1, "the selected theme is at its level")
	var old: AudioStreamPlayer = AudioDirector._music[1 - AudioDirector._music_on]
	assert_lte(old.volume_db, -79.0, "the previous theme is silent")


func test_alternating_rapid_selections_end_on_the_last_choice() -> void:
	var picks := ["theme_menu", "theme_anthem", "theme_menu"]
	for p in picks:
		AudioDirector.play_music(p, 0.5, true, AudioDirector.MENU_DB)
		await wait_seconds(0.1)
	await wait_seconds(1.5)
	assert_eq(AudioDirector.music_playing(), picks.back())
	var cur: AudioStreamPlayer = AudioDirector._music[AudioDirector._music_on]
	assert_almost_eq(cur.volume_db, AudioDirector.MENU_DB, 0.1, "the last choice is audible")
	assert_lte(AudioDirector._music[1 - AudioDirector._music_on].volume_db, -79.0, "nothing else is audible")


func test_same_track_volume_change_cancels_the_open_fade() -> void:
	# a slow fade-in is in flight; a faster same-track volume change must not be
	# stomped when the slower one finishes
	AudioDirector.play_music("theme_anthem", 1.0, true, AudioDirector.MENU_DB)
	await wait_seconds(0.1)
	AudioDirector.play_music("theme_anthem", 0.2, true, -3.0)
	await wait_seconds(1.2)   # the original 0.6s fade-in would still be running
	var cur: AudioStreamPlayer = AudioDirector._music[AudioDirector._music_on]
	assert_eq(AudioDirector.music_playing(), "theme_anthem")
	assert_almost_eq(cur.volume_db, -3.0, 0.1, "the newer volume wins, unopposed")


func test_silence_cancels_a_pending_fade_in() -> void:
	# the fade-in (0.8 * 0.6 = 0.48 s) outlives the silence fade-out (0.3 s)
	AudioDirector.play_music("theme_menu", 0.8, true, AudioDirector.MENU_DB)
	await wait_seconds(0.1)
	AudioDirector.play_music("", 0.3)
	await wait_seconds(1.2)
	for p in AudioDirector._music:
		assert_lte(p.volume_db, -79.0, "silence sticks even with a fade in flight")


func test_an_instant_start_cancels_a_stale_fade_out() -> void:
	# a quick switch leaves a player fading out; an instant start (fade 0, as at boot) on
	# that same player must not be pulled down by it
	AudioDirector.play_music("theme_menu", 0.5, true, AudioDirector.MENU_DB)
	await wait_seconds(0.1)
	AudioDirector.play_music("theme_anthem", 1.0, true, AudioDirector.MENU_DB)   # menu's player fades out over 1 s
	await wait_seconds(0.1)
	AudioDirector.play_music("theme_menu", 0.0, true, -6.0)   # back on the fading player, at once
	await wait_seconds(1.5)
	var cur: AudioStreamPlayer = AudioDirector._music[AudioDirector._music_on]
	assert_eq(AudioDirector.music_playing(), "theme_menu")
	assert_almost_eq(cur.volume_db, -6.0, 0.1, "the instantly started theme stays audible")
	assert_lte(AudioDirector._music[1 - AudioDirector._music_on].volume_db, -79.0, "the switched-from theme is silent")
