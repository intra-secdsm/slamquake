extends GutTest
## Career mode: starting, the monthly schedule, results, titles, rivalries, unlocks and saves.
## (Save paths are test files, set up by tests/pre_run.gd.)

var c: Career


func before_each() -> void:
	Career.erase_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Unlocks.path))
	Unlocks.reload()
	c = Career.start("thunder_mack", 2, 1234)


func after_all() -> void:
	Career.erase_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Unlocks.path))
	Unlocks.reload()


func test_never_touches_the_real_saves() -> void:
	assert_ne(Career.path, "user://career.json")
	assert_ne(Unlocks.path, "user://unlocks.json")
	assert_ne(CawStore.path, "user://created_wrestlers.json")


func test_a_new_career() -> void:
	assert_eq(c.roster.size(), 7)
	assert_false("thunder_mack" in c.roster)
	assert_eq(c.points["thunder_mack"], 0, "a rookie starts at the bottom")
	assert_eq(c.rank_of("thunder_mack"), c.ranking().size())
	assert_ne(c.champion, c.partner)
	assert_ne(c.partner, "")
	assert_eq(c.teams.size(), 3)
	for t in c.teams:
		assert_false(c.partner in t)
	assert_true(c.tag_champs in c.teams)
	assert_ne(c.rival, c.partner)
	assert_ne(c.rival, c.contender)
	assert_eq(c.date_text(), "JANUARY 1996  ·  WEEK 1")
	assert_eq(c.event_name(), Career.SHOW)


func test_the_monthly_schedule() -> void:
	var kinds := []
	for i in 4:
		var card := c.card()
		kinds.append(card["kind"])
		assert_false(card["opponents"].is_empty())
		assert_false(c.you in card["opponents"])
		assert_false(c.partner in card["opponents"])
		var ents := c.entrants()
		assert_eq(ents.size(), 4 if card["kind"] == "tag" else 2)
		assert_eq(ents[0]["control"], "human")
		for e in ents:
			assert_gt(e["roster"], -1)
		c.record("win")
	assert_eq(kinds, ["singles", "tag", "singles", "grudge"])
	assert_eq(c.week, 4)
	assert_eq(c.history.size(), 4)


func test_the_first_shows_have_their_story() -> void:
	var b := c.beats()
	assert_eq(b.size(), 2, "debut, then the month's rivalry")
	assert_string_contains(b[0]["lines"][0][1], "Thunder Mack")
	for beat in b:
		for line in beat["lines"]:
			assert_false(String(line[1]).contains("{"), "every placeholder filled: " + line[1])
	c.record("win")
	assert_eq(c.beats()[0]["cast"]["partner"], c.partner, "week 2 introduces your partner")


func test_winning_climbs_the_rankings_to_a_title_shot() -> void:
	var months := 0
	while c.you != c.contender and months < 8:
		for i in 4:
			c.record("win")
		months += 1
	assert_eq(c.contender, c.you, "number one contender within %d months" % months)
	assert_eq(c.rival, c.champion)
	c.week += 3     # skip to the PPV
	var card := c.card()
	assert_eq(card["kind"], "title")
	assert_eq(card["title"], "world")
	assert_eq(card["opponents"], [c.champion])
	assert_eq(card["difficulty"], 3, "title matches are a step harder")
	var report := c.record("win")
	assert_eq(c.champion, "thunder_mack")
	assert_true(Unlocks.has("mister_midnight"))
	assert_true("Hidden wrestler: Mister Midnight" in report["unlocked"])
	assert_eq(c.belts()["thunder_mack"], 1)
	# as champion: the new month's challenger is the top contender
	assert_eq(c.story, "title_defence")
	assert_eq(c.rival, c.contender)


func test_losing_the_title() -> void:
	c.champion = c.you
	c._start_month()
	c.week += 3
	var challenger := c.contender
	c.record("loss")
	assert_eq(c.champion, challenger)


func test_simulated_title_change_books_nobody_twice() -> void:
	c.week = 3      # the PPV
	assert_true(c.is_ppv())
	assert_false(c.you in [c.champion, c.contender])
	var champ := c.champion
	var challenger := c.contender
	var changes := 0
	for i in 40:
		c.champion = champ
		c.contender = challenger
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var lines: Array = c._simulate(rng, [c.you])
		if c.champion != champ:
			changes += 1
		for id in c.roster:
			var n := c.name_of(id)
			var appearances := lines.filter(func(l: String) -> bool: return l.contains(n)).size()
			assert_lte(appearances, 1, "%s booked once (seed %d)" % [n, i])
	assert_gt(changes, 0, "at least one simulated title change was exercised")


func test_tag_titles_after_two_tag_wins() -> void:
	for month in 3:
		c.week = month * 4 + 1
		var card := c.card()
		if month < 2:
			assert_eq(card["kind"], "tag")
		else:
			assert_eq(card["kind"], "tag_title")
			assert_eq(card["opponents"], c.tag_champs)
		var report := c.record("win")
		if month == 2:
			assert_eq(c.tag_champs, [c.you, c.partner])
			assert_true(Unlocks.has("roxy_ravage"))
			assert_false(report["beats"].is_empty())
	c.week = 13
	assert_eq(c.card()["kind"], "tag_title", "defending the tag titles")


func test_grudge_match_is_no_dq_and_ppv_win_unlocks_champion_pyro() -> void:
	c.week = 3
	var card := c.card()
	assert_eq(card["kind"], "grudge")
	assert_eq(card["rules"], "nodq")
	assert_eq(card["opponents"], [c.rival])
	assert_false("champion" in Roster.pyro_styles())
	c.record("win")
	assert_true("champion" in Roster.pyro_styles())


func test_draws_change_nothing() -> void:
	var before: Dictionary = c.points.duplicate()
	var opp: String = c.card()["opponents"][0]
	c.record("draw")
	assert_eq(c.points[c.you], before[c.you])
	assert_eq(c.points[opp], before[opp])


func test_save_and_load() -> void:
	c.record("win")
	c.record("loss")
	var d := Career.load_saved()
	assert_not_null(d)
	assert_eq(d.week, 2)
	assert_eq(d.points, c.points)
	assert_eq(d.champion, c.champion)
	assert_eq(d.teams, c.teams)
	assert_eq(d.card(), c.card(), "the same card after loading")
	assert_true(d.playable())
	Career.erase_save()
	assert_null(Career.load_saved())


func test_hidden_wrestlers_are_unlocked_for_play() -> void:
	var n := Roster.all().size()
	assert_eq(Roster.find("roxy_ravage"), -1)
	Unlocks.unlock("roxy_ravage")
	assert_eq(Roster.all().size(), n + 1)
	assert_eq(Roster.find("roxy_ravage"), Roster.builtin().size())
	var d := Career.start("roxy_ravage", 2, 99)
	assert_eq(d.roster.size(), 8, "the other eight")


func _career_match(card_week: int) -> Match:
	c.week = card_week
	var card := c.card()
	GameState.career = c
	GameState.career_card = card
	GameState.match_entrants = c.entrants()
	GameState.rules = card["rules"]
	GameState.belts = c.belts()
	var m: Match = load("res://match/match.tscn").instantiate()
	add_child_autofree(m)
	return m


func after_each() -> void:
	GameState.career = null
	GameState.career_result = ""
	GameState.end_career_match()


func test_champions_wear_belts_to_the_ring_and_titles_change_hands() -> void:
	c.champion = c.you
	c._start_month()
	var entrances := Settings.entrances
	Settings.entrances = true       # headless runs skip entrances, and the bell, straight away
	var m := _career_match(3)
	Settings.entrances = entrances
	await wait_physics_frames(2)
	var me := m.wrestlers[0]
	var belt := func(w: Wrestler) -> int: return w.model._body_mat.get_shader_parameter("belt")
	assert_eq(belt.call(me), 1, "the champion's belt, before the bell")
	m._begin_fight()
	assert_eq(belt.call(me), 0, "handed over at the bell")
	assert_eq(m._title_result(m.wrestlers[1]), "AND NEW WORLD CHAMPION")
	assert_eq(belt.call(m.wrestlers[1]), 1)


func test_a_tag_match_with_your_partner() -> void:
	var m := _career_match(1)
	await wait_physics_frames(2)
	assert_true(m.tag_mode)
	assert_eq(m.wrestlers[0].display_name, c.name_of(c.you))
	assert_true(m.wrestlers[0].controller is PlayerController)
	assert_eq(m.wrestlers[0].teammate.display_name, c.name_of(c.partner))


func test_the_result_goes_back_to_the_career() -> void:
	var m := _career_match(0)
	await wait_physics_frames(2)
	assert_eq(m.career_result(), "draw", "no result before the match ends")
	m._finish(m.wrestlers[1], m.wrestlers[0], "COUNT-OUT")
	assert_eq(m.career_result(), "loss")
	# the career screen records it when it opens
	GameState.career_result = m.career_result()
	var screen: Node = load("res://ui/career.tscn").instantiate()
	add_child_autofree(screen)
	await wait_frames(2)
	assert_eq(c.week, 1, "a week has passed")
	assert_eq(c.losses[c.you], 1)
	assert_eq(screen._page, "results")
	assert_eq(GameState.career_result, "", "recorded once")
	screen._on_row_pressed(0)       # Continue
	assert_true(screen._page in ["hub", "story"])


## An outcome promo after a match belongs to the show just finished; it must not use up the
## next show's introduction (issue #5). Results -> outcome promo -> hub -> next week's story.
func test_an_outcome_promo_does_not_skip_the_next_shows_story() -> void:
	c.week = 3                      # the month's PPV grudge match
	assert_eq(c.card()["kind"], "grudge")
	GameState.set_meta("career_story_week", 3)     # its build-up already played at the hub
	GameState.career = c
	GameState.career_result = "win"
	var screen: Node = load("res://ui/career.tscn").instantiate()
	add_child_autofree(screen)
	await wait_frames(2)
	assert_eq(screen._page, "results")
	assert_eq(c.week, 4, "on to next month's first show")
	var outcome: Array = screen._report["beats"].filter(func(b: Dictionary) -> bool: return not b["lines"].is_empty())
	assert_false(outcome.is_empty(), "the grudge win has an outcome promo")
	var intro := c.beats()
	assert_false(intro.is_empty(), "next month's show has its own introduction")
	screen._on_row_pressed(0)       # Continue
	assert_eq(screen._page, "story", "the outcome promo plays")
	assert_eq(screen._scenes[0]["lines"], outcome[0]["lines"])
	screen._end_story()
	assert_eq(screen._page, "story", "then the next show's introduction plays")
	var now_playing: Array = screen._scenes[0]["lines"] if not screen._scenes.is_empty() else []
	assert_eq(now_playing, intro[0]["lines"])
	screen._end_story()
	assert_eq(screen._page, "hub", "each story plays once")
	screen._show_hub()
	assert_eq(screen._page, "hub", "and is not repeated on the way back to the hub")


func _find_row(screen: Node, text: String) -> int:
	for i in screen._rows.size():
		if screen._rows[i].text == text:
			return i
	return -1


## A career whose save file can't be written: the failure is reported, the progress is
## kept in memory, a retry saves it once, and leaving needs an explicit discard (issue #16).
func test_a_failed_initial_save_is_reported_and_can_be_retried() -> void:
	var good := Career.path
	var screen: Node = load("res://ui/career.tscn").instantiate()
	add_child_autofree(screen)
	await wait_frames(2)
	assert_eq(screen._page, "new")
	# fault injection: a missing destination directory
	Career.path = "user://no_such_career_dir_%d/x.json" % OS.get_process_id()
	screen._on_row_pressed(2)      # ★ START CAREER ★
	assert_eq(screen._page, "save_failed", "the failed start is reported")
	assert_true(screen._save_failed)
	assert_not_null(screen.career, "the new career is kept in memory")
	assert_false(Career.has_save(), "nothing was written")
	# fix the destination and retry: the same career saves, and the file has it once
	Career.path = good
	screen._on_row_pressed(0)      # Retry save
	if screen._page == "story":
		screen._end_story()
	assert_eq(screen._page, "hub")
	assert_false(screen._save_failed)
	var back := Career.load_saved()
	assert_not_null(back)
	assert_eq(back.week, 0)
	assert_eq(back.you, screen.career.you)
	assert_eq(back.history.size(), 0, "a fresh career has no shows in the file")


func test_a_failed_post_match_save_is_retried_without_double_recording() -> void:
	c.save()
	var good := Career.path
	GameState.career = c
	GameState.career_result = "win"
	Career.path = "user://no_such_career_dir_%d/x.json" % OS.get_process_id()
	var screen: Node = load("res://ui/career.tscn").instantiate()
	add_child_autofree(screen)
	await wait_frames(2)
	assert_eq(screen._page, "results")
	assert_true(screen._save_failed, "the results screen knows the save failed")
	assert_true("COULDN'T BE SAVED" in screen._body.text)
	assert_eq(c.week, 1, "memory advanced to the next week")
	Career.path = good
	assert_eq(Career.load_saved().week, 0, "...but the file didn't")
	screen._on_row_pressed(0)      # Continue
	if screen._page == "story":
		screen._end_story()
	assert_eq(screen._page, "hub")
	assert_true(screen._save_failed, "the hub still shows the pending failure")
	# retry from the hub: the file catches up, with the result recorded exactly once
	screen._on_row_pressed(1)      # Retry save
	assert_eq(screen._page, "hub")
	assert_false(screen._save_failed)
	var back := Career.load_saved()
	assert_eq(back.week, 1)
	assert_eq(back.history.size(), 1, "the result was recorded exactly once")
	assert_eq(back.wins[c.you], 1)


func test_save_and_quit_holds_progress_until_the_save_succeeds() -> void:
	c.save()
	var good := Career.path
	GameState.career = c
	GameState.career_result = "loss"
	Career.path = "user://no_such_career_dir_%d/x.json" % OS.get_process_id()
	var screen: Node = load("res://ui/career.tscn").instantiate()
	add_child_autofree(screen)
	await wait_frames(2)
	screen._on_row_pressed(0)      # Continue
	if screen._page == "story":
		screen._end_story()
	assert_eq(screen._page, "hub")
	# Save & quit with an unwritable file must not leave, and must not clear the career
	var quit_row := _find_row(screen, "Save & quit")
	assert_gt(quit_row, -1)
	screen._on_row_pressed(quit_row)
	assert_eq(screen._page, "save_failed", "a failed save & quit lands on the failure page")
	assert_not_null(GameState.career, "the career is still in memory")
	assert_eq(GameState.career.week, 1, "the pending week is retained")
	Career.path = good
	assert_eq(Career.load_saved().week, 0, "the file was not advanced")
	# explicit discard: two presses, and the pending progress is gone
	screen._on_row_pressed(1)      # Discard progress
	assert_eq(screen._page, "save_failed", "the first press only asks")
	screen._on_row_pressed(1)      # Really discard
	assert_null(GameState.career, "the pending career is discarded")
	assert_eq(screen._page, "start", "back to the saved (week 0) career")
	# ...and once the file is writable, Save & quit really quits
	screen._on_row_pressed(0)      # CONTINUE the week 0 save
	if screen._page == "story":
		screen._end_story()
	assert_eq(screen._page, "hub")
	screen._on_row_pressed(_find_row(screen, "Save & quit"))
	assert_null(GameState.career, "the career cleared on the way to the menu")


func test_a_career_as_a_created_wrestler() -> void:
	var e := CawStore.blank()
	e["name"] = "Rookie Rex"
	CawStore.put(e)
	var d := Career.start(e["id"], 2, 5)
	assert_eq(d.roster.size(), 8, "all eight built-in wrestlers to face")
	assert_eq(d.entrants()[0]["roster"], Roster.find(e["id"]))
	d.save()
	CawStore.remove(e["id"])
	assert_false(Career.load_saved().playable(), "the career can't go on without its wrestler")
